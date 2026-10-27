-- =====================================================================
-- Yiriclick – base v16 : boutiques validées avant la vitrine, formulaire de contact, état du site
-- À coller dans Supabase > SQL Editor > New query, puis "Run".
-- Prérequis : scripts v2 à v15 (v9 pour les e-mails, v11 pour la vitrine). Peut être relancé sans risque.
-- Ne remplace aucune fonction des avis (v14, v15) ; remplace les 3 fonctions de recherche de la vitrine (v11).
--  1. Une nouvelle boutique d'essai fonctionne tout de suite (lien direct), mais n'entre dans la vitrine
--     qu'après validation par l'admin. Les boutiques déjà en ligne au premier passage de ce script restent visibles.
--     Une boutique dont le dossier d'identité est validé est approuvée automatiquement.
--  2. Formulaire de contact : les messages arrivent dans l'admin (et par e-mail si configuré), sans adresse affichée.
--  3. État du site : l'admin voit quels scripts sont installés et si les services tournent.
-- =====================================================================

-- 0. Suivi des versions de la base ----------------------------------------------
create table if not exists public.versions_base (
  version   text primary key,
  appliquee timestamptz not null default now()
);
alter table public.versions_base enable row level security;
revoke all on table public.versions_base from anon, authenticated;

-- 1. Validation des boutiques -----------------------------------------------------
alter table public.boutiques add column if not exists approuvee    boolean not null default false;
alter table public.boutiques add column if not exists approuvee_le timestamptz;

-- Premier passage seulement : les boutiques déjà publiques restent dans la vitrine
do $$
begin
  if not exists (select 1 from public.versions_base where version = 'v16') then
    update public.boutiques set approuvee = true, approuvee_le = now() where not approuvee;
  end if;
end $$;

-- Règle de validation, dans son propre déclencheur (les fonctions existantes ne sont pas modifiées)
create or replace function public.boutiques_approbation()
returns trigger language plpgsql security definer set search_path = public as $$
declare ok boolean;
begin
  if auth.uid() is not null and not public.is_admin() then
    if tg_op = 'INSERT' then
      -- identité vérifiée : directement dans la vitrine ; essai : après validation
      ok := exists (select 1 from public.dossiers d where lower(d.email) = lower(auth.jwt() ->> 'email') and d.statut = 'actif');
      new.approuvee := ok; new.approuvee_le := case when ok then now() end;
    else
      new.approuvee := old.approuvee; new.approuvee_le := old.approuvee_le;
    end if;
  elsif tg_op = 'UPDATE' and new.approuvee and not old.approuvee then
    new.approuvee_le := coalesce(new.approuvee_le, now());
  end if;
  return new;
end $$;
drop trigger if exists boutiques_approbation on public.boutiques;
create trigger boutiques_approbation before insert or update on public.boutiques for each row execute function public.boutiques_approbation();

-- Quand l'admin valide un dossier d'identité, la boutique du vendeur entre dans la vitrine
create or replace function public.dossiers_approbation()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.statut = 'actif' and new.statut is distinct from old.statut then
    update public.boutiques b set approuvee = true, approuvee_le = coalesce(b.approuvee_le, now())
    from auth.users u where u.id = b.owner and lower(u.email) = lower(new.email) and not b.approuvee;
  end if;
  return new;
end $$;
drop trigger if exists dossiers_approbation on public.dossiers;
create trigger dossiers_approbation after update on public.dossiers for each row execute function public.dossiers_approbation();

-- Alerte à l'admin : une boutique attend sa validation
create or replace function public.boutiques_email()
returns trigger language plpgsql security definer set search_path = public as $$
declare r record; corps text;
begin
  if new.approuvee then return new; end if;
  select * into r from public.reglages_email where id = 1;
  if r is null or not r.alertes_admin or r.admin_email is null then return new; end if;
  corps := '<p style="margin:0;font-size:15px;line-height:1.6"><b>' || public.html_esc(new.nom) || '</b><br>'
    || public.html_esc(coalesce(new.ville || ', ', '') || coalesce(new.pays, '')) || '<br>WhatsApp : ' || public.html_esc(coalesce(new.whatsapp, '—'))
    || '<br>Lien : ' || public.html_esc(r.site_url || 'boutique.html?b=' || new.slug) || '</p>'
    || '<p style="margin:12px 0 0;font-size:14px">Elle fonctionne par lien direct. Elle entrera dans la vitrine quand tu l’auras approuvée.</p>';
  perform public.envoyer_email(r.admin_email, '[Yiriclick] Boutique à valider · ' || new.nom,
    public.email_cadre('Nouvelle boutique à valider', corps, r.site_url || 'admin.html', 'Ouvrir l’admin'), 'admin_boutique');
  return new;
exception when others then
  raise warning 'Yiriclick : alerte boutique non préparée : %', sqlerrm;
  return new;
end $$;
drop trigger if exists boutiques_email on public.boutiques;
create trigger boutiques_email after insert on public.boutiques for each row execute function public.boutiques_email();

-- La vitrine ne montre que les boutiques approuvées (le lien direct d'une boutique marche toujours)
create or replace function public.vitrine_produits(
  p_q text default null, p_qcats text[] default null, p_cats text[] default null, p_promo boolean default false,
  p_pays text[] default null, p_stock boolean default false, p_min_eur numeric default null, p_max_eur numeric default null,
  p_tri text default 'new', p_limit integer default 24, p_offset integer default 0)
returns jsonb language sql stable security definer set search_path = public, extensions as $$
  with base as (
    select p, b,
      public.prix_du_moment(p.prix, p.solde_prix, p.solde_debut, p.solde_fin) as actuel,
      public.prix_du_moment(p.prix, p.solde_prix, p.solde_debut, p.solde_fin) / coalesce(tx.par_eur, 1) as eur,
      public.sans_accent(b.pays) as pays_n,
      public.sans_accent(p.nom || ' ' || coalesce(p.description, '')) as hay,
      public.sans_accent(b.nom || ' ' || coalesce(b.ville, '') || ' ' || coalesce(b.pays, '')) as hay_b
    from public.produits p
    join public.boutiques b on b.id = p.boutique_id and b.visible and not b.masque_admin and b.approuvee
    left join public.taux tx on tx.devise = p.devise
    where p.visible and not p.masque_admin
      and (p_cats is null or p.categorie = any (p_cats))
      and (not coalesce(p_stock, false) or p.stock is null or p.stock > 0)
  ), f as (
    select *, case when greatest(coalesce((p).prix_avant, 0), (p).prix) > actuel then 1 - actuel / greatest(coalesce((p).prix_avant, 0), (p).prix) else 0 end as remise
    from base
    where (p_min_eur is null or eur >= p_min_eur) and (p_max_eur is null or eur <= p_max_eur)
      and (p_pays is null or exists (select 1 from unnest(p_pays) n where n = pays_n or n like pays_n || ' %' or pays_n like n || ' %'))
      and (p_q is null or trim(p_q) = '' or (p).categorie = any (coalesce(p_qcats, '{}'))
           or not exists (select 1 from unnest(string_to_array(public.sans_accent(trim(p_q)), ' ')) w
                          where w <> '' and position(w in hay) = 0 and position(w in hay_b) = 0))
  ), g as (
    select * from f where not coalesce(p_promo, false) or remise > 0
  )
  select jsonb_build_object(
    'total', (select count(*) from g),
    'items', coalesce((select jsonb_agg(public.vitrine_json((x).p, (x).b) order by x.rn) from (
        select g.*, row_number() over (order by
          case when p_tri = 'asc' then eur end asc nulls last,
          case when p_tri = 'desc' then eur end desc nulls last,
          case when p_tri = 'promo' then remise end desc nulls last,
          (p).created_at desc) as rn
        from g
        order by rn
        limit least(greatest(coalesce(p_limit, 24), 1), 60) offset greatest(coalesce(p_offset, 0), 0)) x), '[]'::jsonb));
$$;
grant execute on function public.vitrine_produits(text, text[], text[], boolean, text[], boolean, numeric, numeric, text, integer, integer) to anon, authenticated;

create or replace function public.vitrine_stats()
returns jsonb language sql stable security definer set search_path = public as $$
  with v as (
    select p.categorie, b.id as bid, b.nom, b.slug, b.ville, b.pays, b.logo
    from public.produits p join public.boutiques b on b.id = p.boutique_id and b.visible and not b.masque_admin and b.approuvee
    where p.visible and not p.masque_admin)
  select jsonb_build_object(
    'total', (select count(*) from v),
    'cats', coalesce((select jsonb_object_agg(categorie, n) from (select categorie, count(*) n from v where categorie is not null group by 1) c), '{}'::jsonb),
    'pays', coalesce((select jsonb_agg(pays order by pays) from (select distinct pays from v where pays is not null and pays <> '') d), '[]'::jsonb),
    'shops', coalesce((select jsonb_agg(jsonb_build_object('nom', nom, 'slug', slug, 'ville', ville, 'pays', pays, 'logo', logo, 'n', n) order by n desc) from (
        select nom, slug, ville, pays, logo, count(*) n from v group by bid, nom, slug, ville, pays, logo order by count(*) desc limit 16) s), '[]'::jsonb));
$$;
grant execute on function public.vitrine_stats() to anon, authenticated;

create or replace function public.vitrine_suggest(p_q text)
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'produits', public.vitrine_produits(p_q := p_q, p_limit := 5) -> 'items',
    'boutiques', coalesce((select jsonb_agg(jsonb_build_object('nom', b.nom, 'slug', b.slug, 'ville', b.ville, 'pays', b.pays)) from (
        select b.* from public.boutiques b where b.visible and not b.masque_admin and b.approuvee
          and position(public.sans_accent(trim(p_q)) in public.sans_accent(b.nom)) > 0 order by b.nom limit 3) b), '[]'::jsonb));
$$;
grant execute on function public.vitrine_suggest(text) to anon, authenticated;

-- 2. Formulaire de contact ----------------------------------------------------------
create table if not exists public.messages_contact (
  id         uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  nom        text not null check (char_length(nom) between 1 and 80),
  contact    text not null check (char_length(contact) between 3 and 120),
  sujet      text check (sujet in ('acheteur', 'vendeur', 'partenariat', 'signalement', 'autre')),
  message    text not null check (char_length(message) between 5 and 3000),
  page       text check (char_length(page) <= 300),
  langue     text check (langue in ('fr', 'en', 'es')),
  traite     boolean not null default false
);
create index if not exists messages_contact_recents on public.messages_contact (created_at desc);
alter table public.messages_contact enable row level security;
revoke all on table public.messages_contact from anon, authenticated;
grant insert on table public.messages_contact to anon, authenticated;
grant select, update, delete on table public.messages_contact to authenticated;
drop policy if exists "Public envoie un message" on public.messages_contact;
create policy "Public envoie un message" on public.messages_contact for insert to anon, authenticated with check (not traite);
drop policy if exists "Admin lit les messages" on public.messages_contact;
create policy "Admin lit les messages" on public.messages_contact for select to authenticated using (public.is_admin());
drop policy if exists "Admin traite les messages" on public.messages_contact;
create policy "Admin traite les messages" on public.messages_contact for update to authenticated using (public.is_admin()) with check (public.is_admin());
drop policy if exists "Admin supprime les messages" on public.messages_contact;
create policy "Admin supprime les messages" on public.messages_contact for delete to authenticated using (public.is_admin());

-- Anti-abus : pas plus de 3 messages par heure pour un même contact, ni de 30 en 10 minutes au total
create or replace function public.messages_contact_controle()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if (select count(*) from public.messages_contact where lower(contact) = lower(new.contact) and created_at > now() - interval '1 hour') >= 3
     or (select count(*) from public.messages_contact where created_at > now() - interval '10 minutes') >= 30 then
    raise exception 'Trop de messages envoyés. Réessaie un peu plus tard.';
  end if;
  new.traite := false; new.created_at := now();
  return new;
end $$;
drop trigger if exists messages_contact_controle on public.messages_contact;
create trigger messages_contact_controle before insert on public.messages_contact for each row execute function public.messages_contact_controle();

create or replace function public.messages_contact_email()
returns trigger language plpgsql security definer set search_path = public as $$
declare r record; corps text;
begin
  select * into r from public.reglages_email where id = 1;
  if r is null or r.admin_email is null then return new; end if;
  corps := '<p style="margin:0;font-size:15px;line-height:1.6"><b>' || public.html_esc(new.nom) || '</b> · ' || public.html_esc(new.contact)
    || '<br>Sujet : ' || public.html_esc(coalesce(new.sujet, 'autre')) || '</p>'
    || '<p style="margin:12px 0 0;font-size:15px;line-height:1.6;white-space:pre-wrap">' || public.html_esc(new.message) || '</p>';
  perform public.envoyer_email(r.admin_email, '[Yiriclick] Message de ' || left(new.nom, 40),
    public.email_cadre('Nouveau message de contact', corps, r.site_url || 'admin.html', 'Ouvrir l’admin'), 'contact');
  return new;
exception when others then
  raise warning 'Yiriclick : message de contact non transmis par e-mail : %', sqlerrm;
  return new;
end $$;
drop trigger if exists messages_contact_email on public.messages_contact;
create trigger messages_contact_email after insert on public.messages_contact for each row execute function public.messages_contact_email();

-- 3. État du site (admin) -----------------------------------------------------------
create or replace function public.etat_site()
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v jsonb := '[]'::jsonb; s jsonb := '[]'::jsonb; n bigint; t timestamptz; txt text;
begin
  if not public.is_admin() then raise exception 'Réservé à l’administration.'; end if;

  -- scripts installés : un objet caractéristique de chacun
  v := v || jsonb_build_object('v', 'inscriptions', 'ok', to_regclass('public.inscriptions') is not null);
  v := v || jsonb_build_object('v', 'v2', 'ok', to_regclass('public.dossiers') is not null and to_regclass('public.admins') is not null);
  v := v || jsonb_build_object('v', 'v3', 'ok', to_regclass('public.boutiques') is not null and to_regclass('public.produits') is not null);
  v := v || jsonb_build_object('v', 'v4', 'ok', to_regclass('public.promotions') is not null);
  v := v || jsonb_build_object('v', 'v5', 'ok', to_regclass('public.evenements') is not null);
  v := v || jsonb_build_object('v', 'v6', 'ok', to_regclass('public.commandes') is not null);
  v := v || jsonb_build_object('v', 'v7', 'ok', to_regclass('public.avis') is not null and to_regclass('public.codes_promo') is not null);
  v := v || jsonb_build_object('v', 'v8', 'ok', exists (select 1 from pg_proc where proname = 'produits_controle' and prosrc like '%une seule option (ex. taille)%'));
  v := v || jsonb_build_object('v', 'v9', 'ok', to_regclass('public.emails_journal') is not null);
  v := v || jsonb_build_object('v', 'v10', 'ok', exists (select 1 from pg_proc where proname = 'mon_compte'));
  v := v || jsonb_build_object('v', 'v11', 'ok', to_regclass('public.taux') is not null and exists (select 1 from pg_proc where proname = 'vitrine_produits'));
  v := v || jsonb_build_object('v', 'v12', 'ok', exists (select 1 from pg_proc where proname = 'taux_lire'));
  v := v || jsonb_build_object('v', 'v13', 'ok', exists (select 1 from pg_proc where proname = 'mon_profil'));
  v := v || jsonb_build_object('v', 'v14', 'ok', to_regclass('public.reglages_avis') is not null);
  v := v || jsonb_build_object('v', 'v15', 'ok', exists (select 1 from pg_proc where proname = 'commande_pour_avis'));
  v := v || jsonb_build_object('v', 'v16', 'ok', to_regclass('public.messages_contact') is not null);

  -- services
  if to_regclass('public.taux') is not null then
    execute 'select max(maj) from public.taux where devise = ''USD''' into t;
    s := s || jsonb_build_object('k', 'taux', 'ok', t is not null and t > now() - interval '5 days', 'detail', t);
  end if;
  if to_regclass('cron.job') is not null then
    execute 'select count(*) from cron.job where jobname like ''yiriclick-%''' into n;
    s := s || jsonb_build_object('k', 'cron', 'ok', n >= 2, 'detail', n);
  else
    s := s || jsonb_build_object('k', 'cron', 'ok', false, 'detail', null);
  end if;
  if to_regclass('vault.decrypted_secrets') is not null then
    execute 'select count(*) from vault.decrypted_secrets where name = ''resend_api_key'' and coalesce(decrypted_secret, '''') <> ''''' into n;
    s := s || jsonb_build_object('k', 'resend', 'ok', n > 0, 'detail', null);
  else
    s := s || jsonb_build_object('k', 'resend', 'ok', false, 'detail', null);
  end if;
  if to_regclass('public.reglages_email') is not null then
    execute 'select admin_email from public.reglages_email where id = 1' into txt;
    s := s || jsonb_build_object('k', 'admin_email', 'ok', txt is not null and txt like '%@%', 'detail', txt);
    execute 'select site_url from public.reglages_email where id = 1' into txt;
    s := s || jsonb_build_object('k', 'site_url', 'ok', txt is not null, 'detail', txt);
  end if;
  if to_regclass('public.emails_journal') is not null then
    execute 'select max(created_at) from public.emails_journal' into t;
    n := 0;
    if to_regclass('net._http_response') is not null then
      -- réponses de Resend encore gardées par pg_net (quelques heures) : refus = clé ou domaine à vérifier
      execute 'select count(*) from public.emails_journal j join net._http_response r on r.id = j.request_id where r.status_code is null or r.status_code >= 300' into n;
    end if;
    s := s || jsonb_build_object('k', 'emails', 'ok', n = 0, 'detail', jsonb_build_object('dernier', t, 'refus', n));
  end if;
  execute 'select count(*) from public.boutiques where not approuvee and not masque_admin' into n;
  s := s || jsonb_build_object('k', 'a_valider', 'ok', n = 0, 'detail', n);
  execute 'select count(*) from public.messages_contact where not traite' into n;
  s := s || jsonb_build_object('k', 'messages', 'ok', n = 0, 'detail', n);

  return jsonb_build_object('scripts', v, 'services', s, 'heure', now());
end $$;
revoke all on function public.etat_site() from public;
grant execute on function public.etat_site() to authenticated;

insert into public.versions_base (version) values ('v16') on conflict (version) do nothing;
