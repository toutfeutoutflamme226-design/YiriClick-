-- =====================================================================
-- Yiriclick – base v33 : suivi de commande et problèmes signalés par les clients
-- À coller dans Supabase > SQL Editor > New query, puis "Run". Prérequis : v32. Peut être relancé sans risque.
--  1. Retrouver ma commande (page yiriclick.com/suivi) : le client tape le numéro de sa commande et son téléphone,
--     depuis n'importe quel téléphone ou ordinateur. Il voit où en est la commande. Après 10 mauvais essais sur un
--     même numéro en une heure, la recherche est bloquée une heure (protection contre ceux qui devinent).
--  2. Signaler un problème : colis pas reçu, abîmé, différent, incomplet, en retard… Le vendeur reçoit un e-mail
--     et voit le problème sur la commande, il répond depuis son espace. Si le vendeur ne répond pas en 48 h, ou si
--     sa réponse ne suffit pas, le client demande l'aide de Yiriclick (médiation) : l'admin est prévenu par e-mail.
-- =====================================================================

-- 1. Signalements -------------------------------------------------------------
create table if not exists public.reclamations (
  id              uuid primary key default gen_random_uuid(),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  commande_id     uuid not null unique references public.commandes (id) on delete cascade,
  boutique_id     uuid not null references public.boutiques (id) on delete cascade,
  motif           text not null check (motif in ('pas_recu', 'retard', 'abime', 'different', 'incomplet', 'autre')),
  message         text not null check (char_length(message) between 5 and 1500),
  langue          text,
  statut          text not null default 'ouverte' check (statut in ('ouverte', 'repondue', 'escaladee', 'resolue')),
  reponse_vendeur text check (char_length(reponse_vendeur) <= 1500),
  repondu_le      timestamptz,
  escalade_le     timestamptz,
  resolue_le      timestamptz,
  resolue_par     text check (resolue_par in ('client', 'vendeur', 'admin')),
  note_admin      text check (char_length(note_admin) <= 2000)
);
create index if not exists reclamations_boutique_idx on public.reclamations (boutique_id, created_at desc);
create index if not exists reclamations_statut_idx on public.reclamations (statut, created_at desc);
alter table public.reclamations enable row level security;
revoke all on table public.reclamations from anon, authenticated;
grant select on table public.reclamations to authenticated;
drop policy if exists "Vendeur et admin lisent les signalements" on public.reclamations;
create policy "Vendeur et admin lisent les signalements" on public.reclamations for select to authenticated using (
  public.is_admin() or exists (select 1 from public.boutiques b where b.id = boutique_id and b.owner = auth.uid()));

-- Essais de recherche ratés (numéro existant, mauvais téléphone), gardés une heure
create table if not exists public.suivi_essais (
  id         bigint generated always as identity primary key,
  created_at timestamptz not null default now(),
  numero     text not null
);
create index if not exists suivi_essais_idx on public.suivi_essais (numero, created_at desc);
alter table public.suivi_essais enable row level security;
revoke all on table public.suivi_essais from anon, authenticated;

-- Commande correspondant au numéro et au téléphone (8 derniers chiffres), sinon null
create or replace function public.commande_client(p_numero text, p_tel text)
returns public.commandes language plpgsql security definer set search_path = public as $$
declare n text := upper(regexp_replace(coalesce(p_numero, ''), '\s', '', 'g')); t text := right(regexp_replace(coalesce(p_tel, ''), '\D', '', 'g'), 8); c public.commandes;
begin
  if n !~ '^YC-' then n := 'YC-' || n; end if;
  if char_length(t) < 8 or char_length(n) > 30 then return null; end if;
  if (select count(*) from public.suivi_essais where numero = n and created_at > now() - interval '1 hour') >= 10 then
    raise exception 'Trop d’essais pour ce numéro. Réessaie dans une heure.';
  end if;
  select * into c from public.commandes where upper(numero) = n;
  if not found then return null; end if;
  if right(regexp_replace(c.client_tel, '\D', '', 'g'), 8) <> t then
    insert into public.suivi_essais (numero) values (n);
    delete from public.suivi_essais where created_at < now() - interval '1 day';
    return null;
  end if;
  return c;
end $$;
revoke all on function public.commande_client(text, text) from public, anon, authenticated;

-- 2. Retrouver ma commande ----------------------------------------------------
create or replace function public.retrouver_commande(p_numero text, p_tel text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare c public.commandes; b record; r record;
begin
  c := public.commande_client(p_numero, p_tel);
  if c.id is null then return null; end if;
  select bo.nom, bo.slug, bo.logo, bo.whatsapp into b from public.boutiques bo where bo.id = c.boutique_id;
  select * into r from public.reclamations where commande_id = c.id;
  return jsonb_build_object(
    'id', c.id, 'numero', c.numero, 'statut', c.statut, 'created_at', c.created_at, 'updated_at', c.updated_at,
    'articles', (select coalesce(jsonb_agg(jsonb_build_object('nom', a ->> 'nom', 'qty', a ->> 'qty', 'prix', a ->> 'prix', 'devise', a ->> 'devise', 'v', a -> 'v')), '[]'::jsonb) from jsonb_array_elements(c.articles) a),
    'total', c.total, 'devise', c.devise, 'remise', c.remise, 'client_nom', split_part(trim(c.client_nom), ' ', 1),
    'boutique', jsonb_build_object('nom', b.nom, 'slug', b.slug, 'logo', b.logo, 'whatsapp', b.whatsapp),
    'a_avis', exists (select 1 from public.avis v where v.commande_id = c.id and v.cible = 'boutique'),
    'probleme', case when r.id is null then null else jsonb_build_object('motif', r.motif, 'message', r.message, 'statut', r.statut,
      'created_at', r.created_at, 'reponse', r.reponse_vendeur, 'repondu_le', r.repondu_le, 'escalade_le', r.escalade_le, 'resolue_le', r.resolue_le,
      'peut_escalader', r.statut = 'repondue' or (r.statut = 'ouverte' and r.created_at < now() - interval '48 hours')) end);
end $$;
revoke all on function public.retrouver_commande(text, text) from public;
grant execute on function public.retrouver_commande(text, text) to anon, authenticated;

-- Texte des motifs, pour les e-mails
create or replace function public.motif_txt(p_motif text, p_lang text)
returns text language sql immutable as $$
  select case coalesce(p_lang, 'fr')
    when 'en' then case p_motif when 'pas_recu' then 'Order not received' when 'retard' then 'Delivery late' when 'abime' then 'Item damaged' when 'different' then 'Item different from the description' when 'incomplet' then 'Order incomplete' else 'Other problem' end
    when 'es' then case p_motif when 'pas_recu' then 'Pedido no recibido' when 'retard' then 'Entrega con retraso' when 'abime' then 'Artículo dañado' when 'different' then 'Artículo distinto de la descripción' when 'incomplet' then 'Pedido incompleto' else 'Otro problema' end
    when 'nl' then case p_motif when 'pas_recu' then 'Bestelling niet ontvangen' when 'retard' then 'Levering te laat' when 'abime' then 'Artikel beschadigd' when 'different' then 'Artikel anders dan beschreven' when 'incomplet' then 'Bestelling onvolledig' else 'Ander probleem' end
    else case p_motif when 'pas_recu' then 'Commande pas reçue' when 'retard' then 'Livraison en retard' when 'abime' then 'Article abîmé' when 'different' then 'Article différent de la description' when 'incomplet' then 'Commande incomplète' else 'Autre problème' end end;
$$;

-- 3. Le client signale un problème -------------------------------------------
create or replace function public.signaler_probleme(p_numero text, p_tel text, p_motif text, p_message text, p_langue text default 'fr')
returns jsonb language plpgsql security definer set search_path = public as $$
declare c public.commandes; r record; e record; b record; l text; tx jsonb; m text := left(trim(coalesce(p_message, '')), 1500);
begin
  c := public.commande_client(p_numero, p_tel);
  if c.id is null then raise exception 'Commande introuvable : vérifie le numéro et le téléphone.'; end if;
  if p_motif not in ('pas_recu', 'retard', 'abime', 'different', 'incomplet', 'autre') then raise exception 'Choisis le type de problème.'; end if;
  if char_length(m) < 5 then raise exception 'Explique le problème en quelques mots.'; end if;
  if c.statut = 'annulee' then raise exception 'Cette commande est annulée.'; end if;
  if c.statut = 'nouvelle' and c.created_at > now() - interval '24 hours' then
    raise exception 'Le vendeur a 24 heures pour confirmer ta commande. Écris-lui sur WhatsApp en attendant.';
  end if;
  select * into r from public.reclamations where commande_id = c.id;
  if r.id is not null and r.statut <> 'resolue' then raise exception 'Un signalement est déjà en cours pour cette commande.'; end if;
  if r.id is not null then
    update public.reclamations set motif = p_motif, message = m, statut = 'ouverte', reponse_vendeur = null, repondu_le = null, escalade_le = null,
      resolue_le = null, resolue_par = null, langue = p_langue, created_at = now(), updated_at = now() where id = r.id;
  else
    insert into public.reclamations (commande_id, boutique_id, motif, message, langue) values (c.id, c.boutique_id, p_motif, m, p_langue);
  end if;
  -- e-mail au vendeur, dans sa langue
  select * into e from public.reglages_email where id = 1;
  select bo.nom, u.email into b from public.boutiques bo join auth.users u on u.id = bo.owner where bo.id = c.boutique_id;
  if e is not null and b.email is not null then
    l := coalesce(public.vendeur_langue(b.email), 'fr'); if l not in ('fr', 'en', 'es', 'nl') then l := 'fr'; end if;
    perform set_config('yc.lang', l, true);
    tx := case l
      when 'en' then jsonb_build_object('s', 'A customer reports a problem · ' || c.numero, 't', 'Problem with order ' || c.numero, 'p', 'Answer within 48 hours in your seller space. Without an answer, the customer can ask Yiriclick for help.', 'b', 'Answer the customer')
      when 'es' then jsonb_build_object('s', 'Un cliente informa de un problema · ' || c.numero, 't', 'Problema con el pedido ' || c.numero, 'p', 'Responde en 48 horas desde tu espacio vendedor. Sin respuesta, el cliente puede pedir ayuda a Yiriclick.', 'b', 'Responder al cliente')
      when 'nl' then jsonb_build_object('s', 'Een klant meldt een probleem · ' || c.numero, 't', 'Probleem met bestelling ' || c.numero, 'p', 'Antwoord binnen 48 uur in je verkopersruimte. Zonder antwoord kan de klant Yiriclick om hulp vragen.', 'b', 'De klant antwoorden')
      else jsonb_build_object('s', 'Un client signale un problème · ' || c.numero, 't', 'Problème sur la commande ' || c.numero, 'p', 'Réponds sous 48 heures depuis ton espace vendeur. Sans réponse, le client peut demander l’aide de Yiriclick.', 'b', 'Répondre au client') end;
    perform public.envoyer_email(b.email, tx ->> 's', public.email_cadre(tx ->> 't',
      '<p style="font-size:15px;line-height:1.5"><b>' || public.html_esc(public.motif_txt(p_motif, l)) || '</b> · ' || public.html_esc(c.client_nom) || '</p>'
      || '<p style="font-size:15px;line-height:1.5;white-space:pre-wrap;background:#F3F6F7;padding:12px">' || public.html_esc(m) || '</p>'
      || '<p style="font-size:14px;color:#4A5A5F">' || (tx ->> 'p') || '</p>',
      e.site_url || 'vendeur.html#orders', tx ->> 'b'), 'reclamation_vendeur');
  end if;
  if e is not null and e.alertes_admin and e.admin_email is not null then
    perform set_config('yc.lang', 'fr', true);
    perform public.envoyer_email(e.admin_email, '[Admin] Problème signalé · ' || c.numero || ' · ' || coalesce(b.nom, ''),
      public.email_cadre('Problème signalé sur ' || c.numero, '<p style="font-size:15px"><b>' || public.motif_txt(p_motif, 'fr') || '</b> chez ' || public.html_esc(coalesce(b.nom, '')) || '</p><p style="font-size:15px;white-space:pre-wrap">' || public.html_esc(m) || '</p><p style="font-size:14px;color:#4A5A5F">Pour information : le vendeur a 48 h pour répondre.</p>',
      e.site_url || 'admin', 'Voir dans l’admin'), 'reclamation_admin');
  end if;
  return public.retrouver_commande(p_numero, p_tel);
end $$;
revoke all on function public.signaler_probleme(text, text, text, text, text) from public;
grant execute on function public.signaler_probleme(text, text, text, text, text) to anon, authenticated;

-- 4. Le client demande l'aide de Yiriclick, ou dit que c'est réglé ---------------
create or replace function public.reclamation_client(p_numero text, p_tel text, p_action text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare c public.commandes; r record; e record; bn text;
begin
  c := public.commande_client(p_numero, p_tel);
  if c.id is null then raise exception 'Commande introuvable : vérifie le numéro et le téléphone.'; end if;
  select * into r from public.reclamations where commande_id = c.id;
  if r.id is null then raise exception 'Aucun signalement pour cette commande.'; end if;
  if p_action = 'resolue' then
    update public.reclamations set statut = 'resolue', resolue_le = now(), resolue_par = 'client', updated_at = now() where id = r.id;
  elsif p_action = 'escalader' then
    if not (r.statut = 'repondue' or (r.statut = 'ouverte' and r.created_at < now() - interval '48 hours')) then
      raise exception 'Le vendeur a 48 heures pour te répondre. Tu pourras ensuite demander l’aide de Yiriclick.';
    end if;
    update public.reclamations set statut = 'escaladee', escalade_le = now(), updated_at = now() where id = r.id;
    select * into e from public.reglages_email where id = 1; select nom into bn from public.boutiques where id = c.boutique_id;
    if e is not null and e.admin_email is not null then
      perform set_config('yc.lang', 'fr', true);
      perform public.envoyer_email(e.admin_email, '⚠ Médiation demandée · ' || c.numero || ' · ' || coalesce(bn, ''),
        public.email_cadre('Un client demande l’aide de Yiriclick', '<p style="font-size:15px"><b>' || public.motif_txt(r.motif, 'fr') || '</b> sur la commande ' || c.numero || ' chez ' || public.html_esc(coalesce(bn, '')) || '.</p>'
          || '<p style="font-size:15px;white-space:pre-wrap;background:#F3F6F7;padding:12px">' || public.html_esc(r.message) || '</p>'
          || case when r.reponse_vendeur is not null then '<p style="font-size:15px"><b>Réponse du vendeur :</b></p><p style="font-size:15px;white-space:pre-wrap">' || public.html_esc(r.reponse_vendeur) || '</p>' else '<p style="font-size:15px">Le vendeur n’a pas répondu en 48 h.</p>' end
          || '<p style="font-size:15px">Client : ' || public.html_esc(c.client_nom) || ' · ' || public.html_esc(c.client_tel) || '</p>',
          e.site_url || 'admin', 'Ouvrir l’admin'), 'reclamation_escalade');
    end if;
  else raise exception 'Action inconnue.';
  end if;
  return public.retrouver_commande(p_numero, p_tel);
end $$;
revoke all on function public.reclamation_client(text, text, text) from public;
grant execute on function public.reclamation_client(text, text, text) to anon, authenticated;

-- 5. Le vendeur (ou l'admin) répond ----------------------------------------------
create or replace function public.reclamation_repondre(p_id uuid, p_texte text, p_resolue boolean default false)
returns public.reclamations language plpgsql security definer set search_path = public as $$
declare r public.reclamations; t text := left(trim(coalesce(p_texte, '')), 1500);
begin
  select * into r from public.reclamations where id = p_id;
  if not found or not (public.is_admin() or exists (select 1 from public.boutiques b where b.id = r.boutique_id and b.owner = auth.uid())) then
    raise exception 'Signalement introuvable.';
  end if;
  if char_length(t) < 2 and not p_resolue then raise exception 'Écris ta réponse au client.'; end if;
  update public.reclamations set
    reponse_vendeur = coalesce(nullif(t, ''), reponse_vendeur), repondu_le = case when t <> '' then now() else repondu_le end,
    statut = case when p_resolue then 'resolue' when statut = 'escaladee' then 'escaladee' else 'repondue' end,
    resolue_le = case when p_resolue then now() else resolue_le end,
    resolue_par = case when p_resolue then case when public.is_admin() and r.boutique_id not in (select id from public.boutiques where owner = auth.uid()) then 'admin' else 'vendeur' end else resolue_par end,
    updated_at = now()
  where id = p_id returning * into r;
  return r;
end $$;
revoke all on function public.reclamation_repondre(uuid, text, boolean) from public, anon;
grant execute on function public.reclamation_repondre(uuid, text, boolean) to authenticated;

-- 6. Admin : liste et décision ---------------------------------------------------
create or replace function public.reclamations_admin(p_tout boolean default false)
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'Réservé à l’administrateur.'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', r.id, 'created_at', r.created_at, 'motif', r.motif, 'message', r.message, 'statut', r.statut,
      'reponse', r.reponse_vendeur, 'repondu_le', r.repondu_le, 'escalade_le', r.escalade_le, 'resolue_le', r.resolue_le, 'resolue_par', r.resolue_par, 'note_admin', r.note_admin,
      'numero', c.numero, 'commande_statut', c.statut, 'total', c.total, 'devise', c.devise, 'client_nom', c.client_nom, 'client_tel', c.client_tel, 'langue', r.langue,
      'boutique', b.nom, 'boutique_wa', b.whatsapp, 'vendeur_email', u.email)
      order by (r.statut = 'escaladee') desc, r.created_at desc)
    from public.reclamations r join public.commandes c on c.id = r.commande_id join public.boutiques b on b.id = r.boutique_id join auth.users u on u.id = b.owner
    where p_tout or r.statut <> 'resolue'), '[]'::jsonb);
end $$;
revoke all on function public.reclamations_admin(boolean) from public, anon;
grant execute on function public.reclamations_admin(boolean) to authenticated;

create or replace function public.reclamation_admin(p_id uuid, p_note text, p_resolue boolean default false)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'Réservé à l’administrateur.'; end if;
  update public.reclamations set note_admin = nullif(left(trim(coalesce(p_note, '')), 2000), ''),
    statut = case when p_resolue then 'resolue' else statut end, resolue_le = case when p_resolue then now() else resolue_le end,
    resolue_par = case when p_resolue then 'admin' else resolue_par end, updated_at = now()
  where id = p_id;
end $$;
revoke all on function public.reclamation_admin(uuid, text, boolean) from public, anon;
grant execute on function public.reclamation_admin(uuid, text, boolean) to authenticated;

insert into public.versions_base (version) values ('v33') on conflict (version) do nothing;
