-- =====================================================================
-- Yiriclick – base v32 : les outils promis aux formules Pro et Entreprise
-- À coller dans Supabase > SQL Editor > New query, puis "Run". Prérequis : v31. Peut être relancé sans risque.
--  1. Factures (Pro et Entreprise) : numéro de facture qui se suit pour chaque boutique (F-2026-0001, F-2026-0002…)
--     et coordonnées de facturation de la boutique (nom légal, adresse, numéro IFU / RCCM / KvK…).
--  2. Comptes employés (Entreprise) : le vendeur ajoute jusqu'à 10 employés par e-mail. Ils traitent les commandes
--     et mettent le stock à jour depuis la page « Espace équipe » (yiriclick.com/equipe), sans accès au reste.
--     Chaque action d'un employé est notée, le vendeur la voit dans son espace.
--  3. Analyse du marché (Entreprise) : chiffres de toute la place de marché, par catégorie (prix médians, vues,
--     ventes, tendance), pays des acheteurs, meilleurs jours et heures. Uniquement des totaux : aucun nom de
--     boutique, aucun client ; les prix d'une catégorie ne sont montrés que si au moins 3 boutiques y vendent.
--  4. Support prioritaire (Entreprise) : chaque message d'un vendeur Entreprise prévient l'admin par e-mail.
-- =====================================================================

-- 0. Formule d'un vendeur à partir de son e-mail (même règle que vendeur_formule, pour le propriétaire d'une boutique)
create or replace function public.formule_email(p_email text)
returns text language sql stable security definer set search_path = public as $$
  select coalesce(
    (select d.formule from public.dossiers d
      where lower(d.email) = lower(p_email) and d.statut = 'actif'
        and (d.abonnement_fin is null or d.abonnement_fin + coalesce((select grace_jours from public.reglages_abonnements where id = 1), 7) >= current_date)
      order by d.created_at desc limit 1),
    (select 'essai' from public.inscriptions i
      where lower(i.email) = lower(p_email) and i.statut = 'actif'
        and (i.essai_fin is null or i.essai_fin > now()) limit 1));
$$;
revoke all on function public.formule_email(text) from public, anon, authenticated;

-- 1. Factures ----------------------------------------------------------------
alter table public.boutiques add column if not exists facturation jsonb not null default '{}'::jsonb;
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'boutiques_facturation_taille') then
    alter table public.boutiques add constraint boutiques_facturation_taille
      check (jsonb_typeof(facturation) = 'object' and char_length(facturation::text) <= 3000);
  end if;
end $$;

create table if not exists public.factures (
  commande_id uuid primary key references public.commandes (id) on delete cascade,
  boutique_id uuid not null references public.boutiques (id) on delete cascade,
  numero      text not null,
  annee       integer not null,
  rang        integer not null,
  emise_le    timestamptz not null default now(),
  unique (boutique_id, annee, rang)
);
alter table public.factures enable row level security;
revoke all on table public.factures from anon, authenticated;
grant select on table public.factures to authenticated;
drop policy if exists "Vendeur lit ses factures" on public.factures;
create policy "Vendeur lit ses factures" on public.factures for select to authenticated using (
  public.is_admin() or exists (select 1 from public.boutiques b where b.id = boutique_id and b.owner = auth.uid()));

-- Émet (ou retrouve) la facture d'une commande confirmée, expédiée ou livrée
create or replace function public.facture_emettre(p_commande uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare k record; f record; pre text; y integer; r integer;
begin
  select c.statut, b.id as bid, b.facturation, b.owner into k
    from public.commandes c join public.boutiques b on b.id = c.boutique_id where c.id = p_commande;
  if not found or not (k.owner = auth.uid() or public.is_admin()) then raise exception 'Commande introuvable.'; end if;
  if not public.is_admin() and coalesce(public.vendeur_formule(), '') not in ('pro', 'entreprise') then
    raise exception 'Les factures font partie des formules Pro et Entreprise.';
  end if;
  select * into f from public.factures where commande_id = p_commande;
  if found then return jsonb_build_object('numero', f.numero, 'emise_le', f.emise_le); end if;
  if k.statut not in ('confirmee', 'expediee', 'livree') then
    raise exception 'Confirme d’abord la commande : une facture ne s’émet que pour une commande confirmée.';
  end if;
  perform 1 from public.boutiques where id = k.bid for update;  -- un seul numéro à la fois par boutique
  pre := upper(regexp_replace(coalesce(nullif(k.facturation ->> 'prefixe', ''), 'F'), '[^A-Za-z0-9]', '', 'g'));
  if pre = '' then pre := 'F'; end if;
  pre := left(pre, 8);
  y := extract(year from now() at time zone 'UTC')::integer;
  select coalesce(max(rang), 0) + 1 into r from public.factures where boutique_id = k.bid and annee = y;
  insert into public.factures (commande_id, boutique_id, numero, annee, rang)
    values (p_commande, k.bid, pre || '-' || y || '-' || lpad(r::text, 4, '0'), y, r)
    returning * into f;
  return jsonb_build_object('numero', f.numero, 'emise_le', f.emise_le);
end $$;
revoke all on function public.facture_emettre(uuid) from public, anon;
grant execute on function public.facture_emettre(uuid) to authenticated;

-- 2. Comptes employés ----------------------------------------------------------
create table if not exists public.boutique_equipe (
  id          uuid primary key default gen_random_uuid(),
  boutique_id uuid not null references public.boutiques (id) on delete cascade,
  email       text not null check (position('@' in email) > 1 and char_length(email) <= 200),
  nom         text check (char_length(nom) <= 80),
  droits      text not null default 'commandes_stock' check (droits in ('commandes', 'commandes_stock')),
  created_at  timestamptz not null default now(),
  vu_le       timestamptz
);
create unique index if not exists boutique_equipe_email_idx on public.boutique_equipe (boutique_id, lower(email));
create index if not exists boutique_equipe_mail_idx on public.boutique_equipe (lower(email));
alter table public.boutique_equipe enable row level security;
revoke all on table public.boutique_equipe from anon, authenticated;  -- uniquement par les fonctions ci-dessous

create table if not exists public.equipe_actions (
  id          bigint generated always as identity primary key,
  created_at  timestamptz not null default now(),
  boutique_id uuid not null references public.boutiques (id) on delete cascade,
  email       text not null,
  action      text not null,
  detail      text
);
create index if not exists equipe_actions_idx on public.equipe_actions (boutique_id, created_at desc);
alter table public.equipe_actions enable row level security;
revoke all on table public.equipe_actions from anon, authenticated;

-- Droits de l'employé connecté sur une boutique (null = aucun). La boutique doit être en formule Entreprise.
create or replace function public.equipe_droits(p_boutique uuid)
returns text language sql stable security definer set search_path = public as $$
  select q.droits from public.boutique_equipe q
    join public.boutiques b on b.id = q.boutique_id
    join auth.users o on o.id = b.owner
    join auth.users u on u.id = auth.uid() and u.email_confirmed_at is not null
  where q.boutique_id = p_boutique and lower(q.email) = lower(u.email)
    and public.formule_email(o.email) = 'entreprise'
  limit 1;
$$;
revoke all on function public.equipe_droits(uuid) from public, anon, authenticated;

create or replace function public.equipe_noter(p_boutique uuid, p_action text, p_detail text)
returns void language sql security definer set search_path = public as $$
  insert into public.equipe_actions (boutique_id, email, action, detail)
  values (p_boutique, lower(coalesce(auth.jwt() ->> 'email', '?')), p_action, left(p_detail, 300));
$$;
revoke all on function public.equipe_noter(uuid, text, text) from public, anon, authenticated;

-- 2a. Côté vendeur (propriétaire, formule Entreprise)
create or replace function public.equipe_liste()
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare bid uuid;
begin
  select id into bid from public.boutiques where owner = auth.uid() limit 1;
  if bid is null then return jsonb_build_object('membres', '[]'::jsonb, 'actions', '[]'::jsonb); end if;
  return jsonb_build_object(
    'membres', coalesce((select jsonb_agg(jsonb_build_object('id', q.id, 'email', q.email, 'nom', q.nom, 'droits', q.droits,
                 'created_at', q.created_at, 'vu_le', q.vu_le,
                 'inscrit', exists (select 1 from auth.users u where lower(u.email) = lower(q.email) and u.email_confirmed_at is not null))
               order by q.created_at) from public.boutique_equipe q where q.boutique_id = bid), '[]'::jsonb),
    'actions', coalesce((select jsonb_agg(x order by (x ->> 'created_at') desc) from (
                 select jsonb_build_object('created_at', a.created_at, 'email', a.email, 'action', a.action, 'detail', a.detail) x
                 from public.equipe_actions a where a.boutique_id = bid order by a.created_at desc limit 60) s), '[]'::jsonb));
end $$;
revoke all on function public.equipe_liste() from public, anon;
grant execute on function public.equipe_liste() to authenticated;

create or replace function public.equipe_ajouter(p_email text, p_nom text default null, p_droits text default 'commandes_stock')
returns uuid language plpgsql security definer set search_path = public as $$
declare b record; e text := lower(trim(p_email)); i uuid; r record; l text; t text; s text; btn text;
begin
  select bo.id, bo.nom into b from public.boutiques bo where bo.owner = auth.uid() limit 1;
  if b.id is null then raise exception 'Crée d’abord ta boutique.'; end if;
  if coalesce(public.vendeur_formule(), '') <> 'entreprise' then raise exception 'Les comptes employés font partie de la formule Entreprise.'; end if;
  if e !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then raise exception 'Adresse e-mail invalide.'; end if;
  if e = lower(auth.jwt() ->> 'email') then raise exception 'C’est ta propre adresse : tu as déjà accès à tout.'; end if;
  if p_droits not in ('commandes', 'commandes_stock') then p_droits := 'commandes_stock'; end if;
  if (select count(*) from public.boutique_equipe where boutique_id = b.id) >= 10 then raise exception 'Dix employés au maximum.'; end if;
  insert into public.boutique_equipe (boutique_id, email, nom, droits) values (b.id, e, nullif(left(trim(coalesce(p_nom, '')), 80), ''), p_droits)
    on conflict (boutique_id, lower(email)) do update set nom = excluded.nom, droits = excluded.droits
    returning id into i;
  -- invitation, dans la langue du vendeur
  select * into r from public.reglages_email where id = 1;
  l := coalesce(public.vendeur_langue(auth.jwt() ->> 'email'), 'fr');
  perform set_config('yc.lang', l, true);
  s := case l when 'en' then 'You have been added to the team of ' when 'es' then 'Te han añadido al equipo de ' when 'nl' then 'Je bent toegevoegd aan het team van ' else 'Tu es ajouté à l’équipe de ' end || b.nom;
  t := case l
    when 'en' then 'The shop <b>' || public.html_esc(b.nom) || '</b> gives you access to its orders on Yiriclick. Create your access with this e-mail address (' || public.html_esc(e) || '), then open the team space.'
    when 'es' then 'La tienda <b>' || public.html_esc(b.nom) || '</b> te da acceso a sus pedidos en Yiriclick. Crea tu acceso con esta dirección de correo (' || public.html_esc(e) || ') y abre el espacio del equipo.'
    when 'nl' then 'De winkel <b>' || public.html_esc(b.nom) || '</b> geeft je toegang tot zijn bestellingen op Yiriclick. Maak je toegang aan met dit e-mailadres (' || public.html_esc(e) || ') en open daarna de teamomgeving.'
    else 'La boutique <b>' || public.html_esc(b.nom) || '</b> te donne accès à ses commandes sur Yiriclick. Crée ton accès avec cette adresse e-mail (' || public.html_esc(e) || '), puis ouvre l’espace équipe.' end;
  btn := case l when 'en' then 'Open the team space' when 'es' then 'Abrir el espacio del equipo' when 'nl' then 'Teamomgeving openen' else 'Ouvrir l’espace équipe' end;
  if r is not null then
    perform public.envoyer_email(e, s, public.email_cadre(s, '<p style="font-size:15px;line-height:1.5">' || t || '</p>',
      coalesce(r.site_url, 'https://yiriclick.com/') || 'equipe?email=' || replace(e, '+', '%2B'), btn), 'equipe_invitation');
  end if;
  return i;
end $$;
revoke all on function public.equipe_ajouter(text, text, text) from public, anon;
grant execute on function public.equipe_ajouter(text, text, text) to authenticated;

create or replace function public.equipe_retirer(p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  delete from public.boutique_equipe q using public.boutiques b
   where q.id = p_id and b.id = q.boutique_id and b.owner = auth.uid();
end $$;
revoke all on function public.equipe_retirer(uuid) from public, anon;
grant execute on function public.equipe_retirer(uuid) to authenticated;

-- 2b. Côté employé
create or replace function public.equipe_mes_boutiques()
returns jsonb language plpgsql security definer set search_path = public as $$
declare e text;
begin
  select lower(u.email) into e from auth.users u where u.id = auth.uid() and u.email_confirmed_at is not null;
  if e is null then return '[]'::jsonb; end if;
  update public.boutique_equipe set vu_le = now() where lower(email) = e and (vu_le is null or vu_le < now() - interval '10 minutes');
  return coalesce((select jsonb_agg(jsonb_build_object('boutique_id', b.id, 'nom', b.nom, 'slug', b.slug, 'logo', b.logo,
            'devise', b.devise, 'droits', q.droits, 'actif', public.formule_email(o.email) = 'entreprise') order by b.nom)
    from public.boutique_equipe q join public.boutiques b on b.id = q.boutique_id join auth.users o on o.id = b.owner
    where lower(q.email) = e), '[]'::jsonb);
end $$;
revoke all on function public.equipe_mes_boutiques() from public, anon;
grant execute on function public.equipe_mes_boutiques() to authenticated;

create or replace function public.equipe_commandes(p_boutique uuid)
returns setof public.commandes language plpgsql stable security definer set search_path = public as $$
begin
  if public.equipe_droits(p_boutique) is null then raise exception 'Accès refusé.'; end if;
  return query select * from public.commandes where boutique_id = p_boutique order by created_at desc limit 300;
end $$;
revoke all on function public.equipe_commandes(uuid) from public, anon;
grant execute on function public.equipe_commandes(uuid) to authenticated;

create or replace function public.equipe_commande_maj(p_commande uuid, p_statut text default null, p_note text default null)
returns public.commandes language plpgsql security definer set search_path = public as $$
declare c public.commandes; ok boolean;
begin
  select * into c from public.commandes where id = p_commande;
  if not found or public.equipe_droits(c.boutique_id) is null then raise exception 'Accès refusé.'; end if;
  if p_statut is not null and p_statut <> c.statut then
    ok := (c.statut = 'nouvelle' and p_statut in ('confirmee', 'annulee'))
       or (c.statut = 'confirmee' and p_statut in ('expediee', 'annulee'))
       or (c.statut = 'expediee' and p_statut in ('livree', 'annulee'))
       or (c.statut = 'annulee' and p_statut = 'nouvelle');
    if not ok then raise exception 'Changement de statut impossible.'; end if;
    update public.commandes set statut = p_statut where id = p_commande returning * into c;
    perform public.equipe_noter(c.boutique_id, 'statut', c.numero || ' → ' || p_statut);
  end if;
  if p_note is not null and p_note is distinct from coalesce(c.note_vendeur, '') then
    update public.commandes set note_vendeur = nullif(left(trim(p_note), 1000), '') where id = p_commande returning * into c;
    perform public.equipe_noter(c.boutique_id, 'note', c.numero);
  end if;
  return c;
end $$;
revoke all on function public.equipe_commande_maj(uuid, text, text) from public, anon;
grant execute on function public.equipe_commande_maj(uuid, text, text) to authenticated;

create or replace function public.equipe_produits(p_boutique uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  if coalesce(public.equipe_droits(p_boutique), '') <> 'commandes_stock' then raise exception 'Accès refusé.'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', p.id, 'nom', p.nom, 'photo', p.photos[1], 'stock', p.stock,
            'prix', p.prix, 'devise', p.devise, 'visible', p.visible, 'variantes', p.variantes) order by p.nom)
    from public.produits p where p.boutique_id = p_boutique), '[]'::jsonb);
end $$;
revoke all on function public.equipe_produits(uuid) from public, anon;
grant execute on function public.equipe_produits(uuid) to authenticated;

-- Stock d'un produit, ou d'une combinaison de variantes (p_combi = position dans la liste, à partir de 0)
create or replace function public.equipe_stock(p_produit uuid, p_stock integer, p_combi integer default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare p record; v jsonb;
begin
  select id, boutique_id, nom, stock, variantes into p from public.produits where id = p_produit;
  if not found or coalesce(public.equipe_droits(p.boutique_id), '') <> 'commandes_stock' then raise exception 'Accès refusé.'; end if;
  if p_stock is not null and (p_stock < 0 or p_stock > 1000000) then raise exception 'Stock invalide.'; end if;
  perform set_config('yc.equipe', '1', true);
  if p_combi is null then
    if public.a_variantes(p.variantes) then raise exception 'Ce produit a des variantes : mets à jour le stock de chaque variante.'; end if;
    update public.produits set stock = p_stock where id = p_produit;
    perform public.equipe_noter(p.boutique_id, 'stock', p.nom || ' : ' || coalesce(p_stock::text, '–'));
  else
    if p_combi < 0 or p_combi >= jsonb_array_length(coalesce(p.variantes -> 'combis', '[]')) then raise exception 'Variante introuvable.'; end if;
    v := jsonb_set(p.variantes, array['combis', p_combi::text, 'stock'], coalesce(to_jsonb(p_stock), 'null'::jsonb));
    update public.produits set variantes = v where id = p_produit;
    perform public.equipe_noter(p.boutique_id, 'stock', p.nom || ' (' || coalesce((select string_agg(x, ' / ') from jsonb_array_elements_text(v -> 'combis' -> p_combi -> 'v') x), '') || ') : ' || coalesce(p_stock::text, '–'));
  end if;
  perform set_config('yc.equipe', '', true);
  return (select jsonb_build_object('stock', stock, 'variantes', variantes) from public.produits where id = p_produit);
end $$;
revoke all on function public.equipe_stock(uuid, integer, integer) from public, anon;
grant execute on function public.equipe_stock(uuid, integer, integer) to authenticated;

-- Contrôle des produits (repris de v8) : laisse passer la mise à jour du stock faite par equipe_stock
create or replace function public.produits_controle()
returns trigger language plpgsql security definer set search_path = public as $$
declare f text; lim integer; nb integer; o jsonb; total integer; c jsonb; complet boolean := true;
begin
  -- un prix barré n'a de sens que s'il est plus élevé que le prix actuel
  if new.prix_avant is not null and new.prix_avant <= new.prix then new.prix_avant := null; end if;
  -- variantes : forme, tailles limitées, stock total = somme des stocks par combinaison
  if new.variantes is null or jsonb_typeof(new.variantes) <> 'object' then new.variantes := '{}'::jsonb; end if;
  if public.a_variantes(new.variantes) then
    if jsonb_array_length(new.variantes -> 'options') > 2 then raise exception 'Deux options de variantes au maximum (ex. taille et couleur).'; end if;
    for o in select * from jsonb_array_elements(new.variantes -> 'options') loop
      if jsonb_typeof(o -> 'valeurs') <> 'array' or jsonb_array_length(o -> 'valeurs') not between 1 and 30
         or char_length(coalesce(o ->> 'nom', '')) not between 1 and 30 then
        raise exception 'Chaque option de variante doit avoir un nom et entre 1 et 30 valeurs.';
      end if;
    end loop;
    if jsonb_typeof(coalesce(new.variantes -> 'combis', '[]')) <> 'array' or jsonb_array_length(coalesce(new.variantes -> 'combis', '[]')) > 200
       or char_length(new.variantes::text) > 20000 then
      raise exception 'Trop de combinaisons de variantes.';
    end if;
    total := 0;
    for c in select * from jsonb_array_elements(coalesce(new.variantes -> 'combis', '[]')) loop
      if jsonb_typeof(c -> 'stock') = 'number' then total := total + greatest((c ->> 'stock')::integer, 0); else complet := false; end if;
    end loop;
    if complet and jsonb_array_length(coalesce(new.variantes -> 'combis', '[]')) > 0 then new.stock := total; end if;
  end if;

  -- appel sans utilisateur connecté (éditeur SQL de Supabase, fonctions internes) : pas de contrôle vendeur
  if auth.uid() is null then
    new.updated_at := now();
    return new;
  end if;
  -- employé d'une boutique Entreprise (equipe_stock) : seul le stock change, le reste du produit est gardé
  if tg_op = 'UPDATE' and current_setting('yc.equipe', true) = '1' then
    new.nom := old.nom; new.prix := old.prix; new.prix_avant := old.prix_avant; new.photos := old.photos;
    new.owner := old.owner; new.boutique_id := old.boutique_id; new.masque_admin := old.masque_admin; new.visible := old.visible;
    new.updated_at := now();
    return new;
  end if;
  if tg_op = 'UPDATE' and public.is_admin() and old.owner <> auth.uid() then
    new.updated_at := now();
    return new;
  end if;
  if tg_op = 'UPDATE' then new.masque_admin := old.masque_admin; new.owner := old.owner;
  else new.masque_admin := false; new.owner := auth.uid(); end if;
  f := public.vendeur_formule();
  if f is null then
    raise exception 'Ton compte vendeur n''est pas actif.';
  end if;
  if not exists (select 1 from public.boutiques b where b.id = new.boutique_id and b.owner = auth.uid()) then
    raise exception 'Cette boutique ne t''appartient pas.';
  end if;
  if coalesce(array_length(new.photos, 1), 0) > public.limite_photos(f) then
    raise exception 'Ta formule permet % photos par produit.', public.limite_photos(f);
  end if;
  -- tailles (une option, stock par taille) : toutes les formules ;
  -- deux options ou un prix par variante : Pro et Entreprise
  if public.a_variantes(new.variantes) and f not in ('pro', 'entreprise')
     and (tg_op = 'INSERT' or new.variantes is distinct from old.variantes)
     and (jsonb_array_length(new.variantes -> 'options') > 1
          or exists (select 1 from jsonb_array_elements(coalesce(new.variantes -> 'combis', '[]')) x where jsonb_typeof(x -> 'prix') = 'number')) then
    raise exception 'Avec ta formule : une seule option (ex. taille) et le même prix pour toutes les tailles. Deux options et un prix par variante : formules Pro et Entreprise.';
  end if;
  if tg_op = 'INSERT' then
    lim := public.limite_produits(f);
    if lim is not null then
      select count(*) into nb from public.produits where owner = auth.uid();
      if nb >= lim then
        raise exception 'Tu as atteint la limite de % produits de ta formule.', lim;
      end if;
    end if;
  end if;
  new.updated_at := now();
  return new;
end $$;

-- 3. Analyse du marché ----------------------------------------------------------
-- Pays d'un numéro de téléphone (indicatif), pour compter d'où viennent les commandes
create or replace function public.pays_du_tel(p_tel text)
returns text language sql immutable as $$
  with d as (select regexp_replace(coalesce(p_tel, ''), '\D', '', 'g') as n)
  select case
    when n like '226%' then 'BF' when n like '223%' then 'ML' when n like '227%' then 'NE' when n like '228%' then 'TG'
    when n like '221%' then 'SN' when n like '224%' then 'GN' when n like '225%' then 'CI' when n like '229%' then 'BJ'
    when n like '237%' then 'CM' when n like '233%' then 'GH' when n like '234%' then 'NG' when n like '222%' then 'MR'
    when n like '33%' then 'FR' when n like '31%' then 'NL' when n like '32%' then 'BE' when n like '49%' then 'DE'
    when n like '34%' then 'ES' when n like '39%' then 'IT' when n like '44%' then 'GB' when n like '41%' then 'CH'
    when n like '1%' and char_length(n) = 11 then 'US'
    else 'XX' end
  from d;
$$;

create or replace function public.marche_tendances(p_jours integer default 30)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare j integer := least(greatest(coalesce(p_jours, 30), 7), 90); d1 timestamptz; d0 timestamptz; bid uuid; res jsonb;
begin
  if not public.is_admin() and coalesce(public.vendeur_formule(), '') <> 'entreprise' then
    raise exception 'L’analyse du marché fait partie de la formule Entreprise.';
  end if;
  d1 := now() - make_interval(days => j); d0 := now() - make_interval(days => 2 * j);
  select id into bid from public.boutiques where owner = auth.uid() limit 1;

  with prod as (
    select p.id, p.boutique_id, p.categorie, p.prix, p.devise, p.stock from public.produits p
      join public.boutiques b on b.id = p.boutique_id
     where p.visible and not p.masque_admin and b.visible and not b.masque_admin
  ), ev as (
    select e.produit_id, e.boutique_id, e.type, e.created_at >= d1 as recent from public.evenements e
     where e.created_at >= d0 and e.type in ('vue_produit', 'ajout_panier', 'favori')
  ), lignes as (
    select c.boutique_id, (a ->> 'produit_id')::uuid as produit_id, greatest(coalesce((a ->> 'qty')::integer, 1), 1) as qty,
           c.created_at >= d1 as recent
      from public.commandes c cross join lateral jsonb_array_elements(c.articles) a
     where c.created_at >= d0 and c.statut <> 'annulee' and (a ->> 'produit_id') ~ '^[0-9a-f-]{36}$'
  ), cat as (
    select pr.categorie,
      count(distinct pr.boutique_id) as boutiques, count(*) as produits,
      percentile_cont(0.5) within group (order by pr.prix) filter (where pr.devise = 'XOF') as med_xof,
      percentile_cont(0.5) within group (order by pr.prix) filter (where pr.devise = 'EUR') as med_eur,
      count(*) filter (where pr.stock = 0) as ruptures
    from prod pr group by pr.categorie
  ), catev as (
    select p.categorie,
      count(*) filter (where ev.type = 'vue_produit' and ev.recent) as vues,
      count(*) filter (where ev.type = 'vue_produit' and not ev.recent) as vues_avant,
      count(*) filter (where ev.type in ('ajout_panier', 'favori') and ev.recent) as envies
    from ev join public.produits p on p.id = ev.produit_id group by p.categorie
  ), catv as (
    select p.categorie, coalesce(sum(l.qty) filter (where l.recent), 0) as ventes, coalesce(sum(l.qty) filter (where not l.recent), 0) as ventes_avant
    from lignes l join public.produits p on p.id = l.produit_id group by p.categorie
  ), mine as (
    select p.categorie,
      percentile_cont(0.5) within group (order by p.prix) filter (where p.devise = 'XOF') as med_xof,
      percentile_cont(0.5) within group (order by p.prix) filter (where p.devise = 'EUR') as med_eur,
      count(*) as produits
    from public.produits p where p.boutique_id = bid group by p.categorie
  ), minev as (
    select p.categorie, count(*) as vues from ev join public.produits p on p.id = ev.produit_id
     where ev.recent and ev.type = 'vue_produit' and ev.boutique_id = bid group by p.categorie
  )
  select jsonb_build_object(
    'jours', j,
    'total', jsonb_build_object(
      'boutiques', (select count(distinct boutique_id) from prod),
      'produits', (select count(*) from prod),
      'vues', (select count(*) from ev where recent and type = 'vue_produit'),
      'vues_avant', (select count(*) from ev where not recent and type = 'vue_produit'),
      'commandes', (select count(*) from public.commandes where created_at >= d1 and statut <> 'annulee'),
      'commandes_avant', (select count(*) from public.commandes where created_at >= d0 and created_at < d1 and statut <> 'annulee')),
    'categories', coalesce((select jsonb_agg(jsonb_build_object(
        'categorie', cat.categorie, 'boutiques', cat.boutiques, 'produits', cat.produits, 'ruptures', cat.ruptures,
        'med_xof', case when cat.boutiques >= 3 then round(cat.med_xof::numeric) end,
        'med_eur', case when cat.boutiques >= 3 then round(cat.med_eur::numeric, 2) end,
        'vues', coalesce(ce.vues, 0), 'vues_avant', coalesce(ce.vues_avant, 0), 'envies', coalesce(ce.envies, 0),
        'ventes', coalesce(cv.ventes, 0), 'ventes_avant', coalesce(cv.ventes_avant, 0),
        'moi', case when m.categorie is null then null else jsonb_build_object('produits', m.produits,
                 'med_xof', round(m.med_xof::numeric), 'med_eur', round(m.med_eur::numeric, 2), 'vues', coalesce(mv.vues, 0)) end)
        order by coalesce(ce.vues, 0) + 5 * coalesce(cv.ventes, 0) desc)
      from cat left join catev ce on ce.categorie = cat.categorie left join catv cv on cv.categorie = cat.categorie
      left join mine m on m.categorie = cat.categorie left join minev mv on mv.categorie = cat.categorie), '[]'::jsonb),
    'pays', coalesce((select jsonb_agg(jsonb_build_object('pays', x.pays, 'n', x.n) order by x.n desc) from (
        select public.pays_du_tel(client_tel) as pays, count(*) as n from public.commandes
         where created_at >= d1 and statut <> 'annulee' group by 1) x), '[]'::jsonb),
    'jours_semaine', coalesce((select jsonb_agg(jsonb_build_object('j', x.j, 'n', x.n) order by x.j) from (
        select extract(isodow from created_at at time zone 'UTC')::integer as j, count(*) as n from public.commandes
         where created_at >= now() - interval '90 days' and statut <> 'annulee' group by 1) x), '[]'::jsonb),
    'heures', coalesce((select jsonb_agg(jsonb_build_object('h', x.h, 'n', x.n) order by x.h) from (
        select extract(hour from created_at at time zone 'UTC')::integer as h, count(*) as n from public.commandes
         where created_at >= now() - interval '90 days' and statut <> 'annulee' group by 1) x), '[]'::jsonb)
  ) into res;
  return res;
end $$;
revoke all on function public.marche_tendances(integer) from public, anon;
grant execute on function public.marche_tendances(integer) to authenticated;

-- 4. Support prioritaire : message d'un vendeur Entreprise → e-mail immédiat à l'admin
create or replace function public.vendeur_ecrire(p_texte text, p_type text default 'reponse')
returns void language plpgsql security definer set search_path = public as $$
declare e text := lower(auth.jwt() ->> 'email'); r record; bn text;
begin
  if auth.uid() is null or e is null then raise exception 'Connecte-toi d’abord.'; end if;
  if p_type not in ('reponse', 'message') then p_type := 'message'; end if;
  if (select count(*) from public.vendeurs_suivi where lower(email) = e and de = 'vendeur' and created_at > now() - interval '1 hour') >= 20 then
    raise exception 'Trop de messages en peu de temps. Réessaie dans une heure.';
  end if;
  insert into public.vendeurs_suivi (email, de, type, texte, lu_vendeur) values (e, 'vendeur', p_type, left(trim(p_texte), 2000), true);
  if public.vendeur_formule() = 'entreprise' then
    select * into r from public.reglages_email where id = 1;
    select nom into bn from public.boutiques where owner = auth.uid() limit 1;
    if r is not null and r.admin_email is not null then
      perform set_config('yc.lang', 'fr', true);
      perform public.envoyer_email(r.admin_email, '⭐ Support prioritaire : ' || coalesce(bn, e),
        public.email_cadre('Message d’un vendeur Entreprise',
          '<p style="font-size:15px;line-height:1.5"><b>' || public.html_esc(coalesce(bn, '')) || '</b> (' || public.html_esc(e) || ') a écrit :</p>'
          || '<p style="font-size:15px;line-height:1.5;white-space:pre-wrap;background:#F3F6F7;padding:12px">' || public.html_esc(left(trim(p_texte), 2000)) || '</p>'
          || '<p style="font-size:14px;color:#4A5A5F">Support prioritaire : réponds dans la journée.</p>',
          coalesce(r.site_url, 'https://yiriclick.com/') || 'admin', 'Répondre dans l’admin'), 'support_prioritaire');
    end if;
  end if;
end $$;
revoke all on function public.vendeur_ecrire(text, text) from public, anon;
grant execute on function public.vendeur_ecrire(text, text) to authenticated;

insert into public.versions_base (version) values ('v32') on conflict (version) do nothing;
