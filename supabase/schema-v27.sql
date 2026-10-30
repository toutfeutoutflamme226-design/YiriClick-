-- =====================================================================
-- Yiriclick – base v27 : prix et contenus du site gérés depuis l'admin, parrainage, codes promo d'abonnement
-- À coller dans Supabase > SQL Editor > New query, puis "Run". Prérequis : v26. Peut être relancé sans risque.
--  1. site_reglages : prix des formules (mois, trimestre, an, par région), prix du Boost, coordonnées,
--     bandeau d'annonce, textes modifiés en « mode édition ». Lecture publique, écriture admin. Historique gardé.
--  2. Prix verrouillé : chaque abonnement garde le prix du jour de son activation (les anciens abonnés ne subissent
--     pas une hausse). Les vendeurs fondateurs gardent leur prix à vie.
--  3. Paiement trimestriel (en plus de mensuel et annuel).
--  4. Parrainage : un vendeur qui fait venir un vendeur abonné reçoit 1 mois offert, automatiquement.
--  5. Codes promo d'abonnement (ex. TABASKI2026 : -20 % le premier paiement).
-- =====================================================================

-- 1. Réglages du site --------------------------------------------------------------------
create table if not exists public.site_reglages (
  cle      text primary key check (cle in ('prix', 'contact', 'annonce', 'textes')),
  valeur   jsonb not null default '{}'::jsonb,
  maj_le   timestamptz not null default now()
);
alter table public.site_reglages enable row level security;
grant select on table public.site_reglages to anon, authenticated;
grant insert, update on table public.site_reglages to authenticated;
drop policy if exists "Public lit reglages site" on public.site_reglages;
create policy "Public lit reglages site" on public.site_reglages for select to anon, authenticated using (true);
drop policy if exists "Admin modifie reglages site" on public.site_reglages;
create policy "Admin modifie reglages site" on public.site_reglages for all to authenticated using (public.is_admin()) with check (public.is_admin());

insert into public.site_reglages (cle, valeur) values
('prix', '{
  "mois":      {"af": {"basique": 6000,  "pro": 12000,  "entreprise": 18000},  "eu": {"basique": 12.9,  "pro": 24.9,  "entreprise": 39.9},  "am": {"basique": 14.9,  "pro": 28.9,  "entreprise": 45.9}},
  "trimestre": {"af": {"basique": 17100, "pro": 34200,  "entreprise": 51300},  "eu": {"basique": 36.9,  "pro": 70.9,  "entreprise": 113.9}, "am": {"basique": 42.9,  "pro": 82.9,  "entreprise": 130.9}},
  "an":        {"af": {"basique": 60000, "pro": 120000, "entreprise": 180000}, "eu": {"basique": 129,   "pro": 249,   "entreprise": 399},   "am": {"basique": 149,   "pro": 289,   "entreprise": 459}},
  "boost":     {"af": 2500, "eu": 4.9, "am": 5.9},
  "parrainage_mois": 1
}'::jsonb),
('contact', '{"email": "contact@yiriclick.com", "whatsapp": "", "instagram": "", "facebook": "", "tiktok": ""}'::jsonb),
('annonce', '{"actif": false, "texte": {"fr": "", "en": "", "es": "", "nl": ""}, "lien": "", "fin": null}'::jsonb),
('textes', '{}'::jsonb)
on conflict (cle) do nothing;

create table if not exists public.site_historique (
  id        bigint generated always as identity primary key,
  le        timestamptz not null default now(),
  cle       text not null,
  detail    text,
  avant     jsonb,
  apres     jsonb
);
alter table public.site_historique enable row level security;
grant select on table public.site_historique to authenticated;
drop policy if exists "Admin lit historique site" on public.site_historique;
create policy "Admin lit historique site" on public.site_historique for select to authenticated using (public.is_admin());

create or replace function public.site_reglages_journal()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  new.maj_le := now();
  if tg_op = 'UPDATE' and new.valeur is distinct from old.valeur then
    insert into public.site_historique (cle, avant, apres) values (new.cle, old.valeur, new.valeur);
    delete from public.site_historique where id in (select id from public.site_historique order by id desc offset 500);
  end if;
  return new;
end $$;
drop trigger if exists site_reglages_journal on public.site_reglages;
create trigger site_reglages_journal before update on public.site_reglages
  for each row execute function public.site_reglages_journal();

-- Edit one text from the « mode édition » (p_texte null or empty = back to the original text)
create or replace function public.admin_texte(p_cle text, p_lang text, p_texte text)
returns void language plpgsql security definer set search_path = public as $$
declare v jsonb;
begin
  if not public.is_admin() then raise exception 'Réservé à l’administration (reconnecte-toi dans l’admin).'; end if;
  if p_cle is null or char_length(p_cle) > 120 or p_lang not in ('fr', 'en', 'es', 'nl') then raise exception 'Texte inconnu.'; end if;
  select valeur into v from public.site_reglages where cle = 'textes';
  v := coalesce(v, '{}'::jsonb);
  if coalesce(trim(p_texte), '') = '' then
    v := v #- array[p_cle, p_lang];
    if v -> p_cle = '{}'::jsonb then v := v - p_cle; end if;
  else
    v := jsonb_set(v, array[p_cle], coalesce(v -> p_cle, '{}'::jsonb) || jsonb_build_object(p_lang, left(p_texte, 2000)));
  end if;
  insert into public.site_reglages (cle, valeur) values ('textes', v) on conflict (cle) do update set valeur = excluded.valeur;
end $$;
revoke all on function public.admin_texte(text, text, text) from public, anon;
grant execute on function public.admin_texte(text, text, text) to authenticated;

-- 2-3. Prix verrouillé, trimestre, code promo, parrain sur les dossiers ----------------------
alter table public.dossiers drop constraint if exists dossiers_periode_check;
alter table public.dossiers add constraint dossiers_periode_check check (periode in ('mois', 'trimestre', 'an'));
alter table public.dossiers add column if not exists prix        numeric(12, 2);   -- prix de la période, verrouillé à l'activation
alter table public.dossiers add column if not exists prix_a_vie  boolean not null default false;
alter table public.dossiers add column if not exists code_promo  text check (char_length(code_promo) <= 30);
alter table public.dossiers add column if not exists remise_pct  integer check (remise_pct between 0 and 100);
alter table public.dossiers add column if not exists parrain     text check (char_length(parrain) <= 40);
alter table public.inscriptions add column if not exists parrain text check (char_length(parrain) <= 40);

create or replace function public.prix_formule(p_zone text, p_formule text, p_periode text)
returns numeric language sql stable security definer set search_path = public as $$
  select nullif(valeur -> coalesce(nullif(p_periode, ''), 'mois') -> coalesce(p_zone, 'af') ->> p_formule, '')::numeric
  from public.site_reglages where cle = 'prix';
$$;
grant execute on function public.prix_formule(text, text, text) to anon, authenticated;

-- 5. Codes promo d'abonnement --------------------------------------------------------------
create table if not exists public.codes_abonnement (
  code          text primary key check (code ~ '^[A-Z0-9_-]{3,30}$'),
  remise_pct    integer not null check (remise_pct between 1 and 100),
  formules      text[] not null default '{basique,pro,entreprise}',
  fin           date,
  max_utilisations integer,
  utilisations  integer not null default 0,
  actif         boolean not null default true,
  created_at    timestamptz not null default now()
);
alter table public.codes_abonnement enable row level security;
grant select, insert, update, delete on table public.codes_abonnement to authenticated;
drop policy if exists "Admin gere codes abonnement" on public.codes_abonnement;
create policy "Admin gere codes abonnement" on public.codes_abonnement for all to authenticated using (public.is_admin()) with check (public.is_admin());

create or replace function public.verifier_code_abonnement(p_code text, p_formule text)
returns integer language sql stable security definer set search_path = public as $$
  select c.remise_pct from public.codes_abonnement c
  where c.code = upper(trim(p_code)) and c.actif and (c.fin is null or c.fin >= current_date)
    and (c.max_utilisations is null or c.utilisations < c.max_utilisations) and p_formule = any (c.formules);
$$;
revoke all on function public.verifier_code_abonnement(text, text) from public;
grant execute on function public.verifier_code_abonnement(text, text) to anon, authenticated;

-- Insert: the code is checked, the discount stored; the referral code is cleaned
create or replace function public.dossiers_code_parrain()
returns trigger language plpgsql security definer set search_path = public as $$
declare r integer;
begin
  if new.code_promo is not null then
    new.code_promo := upper(trim(new.code_promo));
    r := public.verifier_code_abonnement(new.code_promo, new.formule);
    if r is null then new.code_promo := null; new.remise_pct := null;
    elsif tg_op = 'INSERT' or new.code_promo is distinct from old.code_promo then
      new.remise_pct := r;
      update public.codes_abonnement set utilisations = utilisations + 1 where code = new.code_promo;
    end if;
  elsif tg_op = 'INSERT' then new.remise_pct := null;
  end if;
  if new.parrain is not null then new.parrain := nullif(lower(regexp_replace(new.parrain, '[^a-zA-Z0-9-]', '', 'g')), ''); end if;
  if tg_op = 'INSERT' and auth.uid() is not null and not public.is_admin() then new.prix := null; new.prix_a_vie := false; end if;
  return new;
end $$;
drop trigger if exists dossiers_code_parrain on public.dossiers;
create trigger dossiers_code_parrain before insert or update of code_promo, parrain on public.dossiers
  for each row execute function public.dossiers_code_parrain();
create or replace function public.inscriptions_parrain()
returns trigger language plpgsql as $$
begin
  if new.parrain is not null then new.parrain := nullif(lower(regexp_replace(new.parrain, '[^a-zA-Z0-9-]', '', 'g')), ''); end if;
  return new;
end $$;
drop trigger if exists inscriptions_parrain on public.inscriptions;
create trigger inscriptions_parrain before insert on public.inscriptions
  for each row execute function public.inscriptions_parrain();

-- Activation: dates (v26) + locked price + founder lifetime price (runs after dossiers_abonnement, alphabetical order)
create or replace function public.dossiers_prix_verrou()
returns trigger language plpgsql security definer set search_path = public as $$
declare fond boolean;
begin
  if new.statut = 'actif' and (tg_op = 'INSERT' or old.statut is distinct from 'actif') then
    if new.prix is null then
      new.prix := public.prix_formule(new.zone, new.formule, new.periode);
      if new.prix is not null and coalesce(new.remise_pct, 0) > 0 then
        new.prix := round(new.prix * (100 - new.remise_pct) / 100.0, case when new.zone = 'af' then 0 else 2 end);
      end if;
    end if;
    select coalesce(bool_or(b.fondateur), false) into fond
    from public.boutiques b join auth.users u on u.id = b.owner where lower(u.email) = lower(new.email);
    if fond then new.prix_a_vie := true; end if;
  end if;
  if tg_op = 'UPDATE' then
    if new.periode is distinct from old.periode and new.statut = 'actif' and new.prix is not distinct from old.prix and not new.prix_a_vie then
      new.prix := public.prix_formule(new.zone, new.formule, new.periode);   -- period changed by the admin: price of the new period
    end if;
  end if;
  return new;
end $$;
drop trigger if exists dossiers_prix_verrou on public.dossiers;
create trigger dossiers_prix_verrou before insert or update on public.dossiers
  for each row execute function public.dossiers_prix_verrou();

-- Activation from the dossier (v26 trigger) knows only mois/an: quarterly = 3 months
create or replace function public.dossiers_abonnement()
returns trigger language plpgsql as $$
begin
  if new.statut = 'actif' and (tg_op = 'INSERT' or old.statut is distinct from 'actif') and new.abonnement_fin is null then
    new.abonnement_debut := current_date;
    new.abonnement_fin := (current_date + case when new.periode = 'an' then interval '1 year' when new.periode = 'trimestre' then interval '3 months' else interval '1 month' end)::date;
  end if;
  return new;
end $$;

-- Prix déjà en place : les abonnés actuels gardent le prix de leur formule (ancienne grille, ou nouvelle si plus basse)
update public.dossiers d set prix = public.prix_formule(d.zone, d.formule, d.periode)
where d.statut = 'actif' and d.prix is null;
update public.dossiers d set prix_a_vie = true
where d.statut = 'actif' and not d.prix_a_vie and exists (
  select 1 from public.boutiques b join auth.users u on u.id = b.owner where lower(u.email) = lower(d.email) and b.fondateur);

-- Founder joins later: lock his current subscription for life
create or replace function public.boutiques_fondateur_prix()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.fondateur and (tg_op = 'INSERT' or not old.fondateur) then
    update public.dossiers d set prix_a_vie = true from auth.users u where u.id = new.owner and lower(d.email) = lower(u.email) and d.statut = 'actif';
  end if;
  return null;
end $$;
drop trigger if exists boutiques_fondateur_prix on public.boutiques;
create trigger boutiques_fondateur_prix after insert or update of fondateur on public.boutiques
  for each row execute function public.boutiques_fondateur_prix();

-- 4. Parrainage ----------------------------------------------------------------------------
create table if not exists public.parrainages (
  filleul_email text primary key,
  parrain_slug  text not null,
  parrain_email text,
  statut        text not null default 'en_attente' check (statut in ('en_attente', 'offert')),
  le            timestamptz not null default now(),
  offert_le     timestamptz
);
alter table public.parrainages enable row level security;
grant select, update on table public.parrainages to authenticated;
drop policy if exists "Admin gere parrainages" on public.parrainages;
create policy "Admin gere parrainages" on public.parrainages for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- Reward: 1 month (setting) added to the sponsor's paid subscription, or kept « en attente » for the admin
create or replace function public.parrainage_offrir(p_filleul text)
returns boolean language plpgsql security definer set search_path = public as $$
declare p public.parrainages; d public.dossiers; m integer;
begin
  if auth.uid() is not null and not public.is_admin() then raise exception 'Réservé à l’administration.'; end if;
  select * into p from public.parrainages where filleul_email = lower(p_filleul);
  if p.filleul_email is null or p.statut = 'offert' then return false; end if;
  m := coalesce((select (valeur ->> 'parrainage_mois')::int from public.site_reglages where cle = 'prix'), 1);
  select x.* into d from public.dossiers x where lower(x.email) = lower(p.parrain_email) and x.statut = 'actif' order by x.created_at desc limit 1;
  if d.id is null then return false; end if;
  update public.dossiers set abonnement_fin = (greatest(coalesce(abonnement_fin, current_date), current_date) + make_interval(months => m))::date where id = d.id;
  update public.boutiques b set visible = true, masquee_pour = null from auth.users u where u.id = b.owner and lower(u.email) = lower(d.email) and b.masquee_pour = 'abonnement';
  update public.parrainages set statut = 'offert', offert_le = now() where filleul_email = p.filleul_email;
  insert into public.vendeurs_suivi (email, de, type, texte, lu_admin)
  values (lower(d.email), 'systeme', 'info', 'Merci pour ton parrainage ! Un nouveau vendeur s’est abonné grâce à toi : ' || m || ' mois offert(s) sur ton abonnement.', true);
  return true;
end $$;
revoke all on function public.parrainage_offrir(text) from public, anon;
grant execute on function public.parrainage_offrir(text) to authenticated;   -- the function itself is harmless; the admin button uses it

create or replace function public.dossiers_parrainage()
returns trigger language plpgsql security definer set search_path = public as $$
declare pe text; ps text;
begin
  if new.statut = 'actif' and (tg_op = 'INSERT' or old.statut is distinct from 'actif') then
    ps := coalesce(new.parrain, (select i.parrain from public.inscriptions i where lower(i.email) = lower(new.email) and i.parrain is not null order by i.created_at desc limit 1));
    if ps is null then return null; end if;
    select lower(u.email) into pe from public.boutiques b join auth.users u on u.id = b.owner where b.slug = ps;
    if pe is null or pe = lower(new.email) then return null; end if;
    insert into public.parrainages (filleul_email, parrain_slug, parrain_email) values (lower(new.email), ps, pe) on conflict do nothing;
    perform public.parrainage_offrir(new.email);
  end if;
  return null;
end $$;
drop trigger if exists dossiers_parrainage on public.dossiers;
create trigger dossiers_parrainage after insert or update of statut on public.dossiers
  for each row execute function public.dossiers_parrainage();

-- Seller: his referral link stats
create or replace function public.mes_parrainages()
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'slug', (select slug from public.boutiques where owner = auth.uid() limit 1),
    'mois', coalesce((select (valeur ->> 'parrainage_mois')::int from public.site_reglages where cle = 'prix'), 1),
    'inscrits', (select count(*) from public.inscriptions i where i.parrain = (select slug from public.boutiques where owner = auth.uid() limit 1)),
    'abonnes', (select count(*) from public.parrainages p where p.parrain_email = lower(auth.jwt() ->> 'email')),
    'offerts', (select count(*) from public.parrainages p where p.parrain_email = lower(auth.jwt() ->> 'email') and p.statut = 'offert'));
$$;
revoke all on function public.mes_parrainages() from public, anon;
grant execute on function public.mes_parrainages() to authenticated;

-- mon_abonnement (v26) + price, lifetime price, Boost price
create or replace function public.mon_abonnement()
returns jsonb language sql stable security definer set search_path = public as $$
  with d as (select * from public.dossiers where lower(email) = lower(auth.jwt() ->> 'email') and statut = 'actif' order by created_at desc limit 1),
       b as (select * from public.boutiques where owner = auth.uid() limit 1),
       g as (select coalesce((select grace_jours from public.reglages_abonnements where id = 1), 7) as j)
  select jsonb_build_object(
    'formule', (select formule from d), 'periode', (select periode from d), 'zone', (select zone from d),
    'prix', (select prix from d), 'prix_a_vie', (select prix_a_vie from d),
    'debut', (select abonnement_debut from d), 'fin', (select abonnement_fin from d), 'grace', (select j from g),
    'visible', (select visible from b), 'masquee_pour', (select masquee_pour from b),
    'demande', (select visibilite_demande from b), 'demande_le', (select visibilite_demande_le from b),
    'boost', (select case when boost_fin is null or boost_fin >= current_date then boost end from b),
    'boost_debut', (select boost_debut from b), 'boost_fin', (select boost_fin from b), 'boost_raison', (select boost_raison from b),
    'boost_vues', (select count(*) from public.evenements ev join b on ev.boutique_id = b.id
                   where ev.type = 'vue_boutique' and b.boost is not null and ev.created_at >= coalesce(b.boost_debut, current_date)),
    'non_lus', (select count(*) from public.vendeurs_suivi s where lower(s.email) = lower(auth.jwt() ->> 'email') and s.type <> 'note' and not s.lu_vendeur)
  );
$$;

-- abonnements_liste (v26) + price columns
drop function if exists public.abonnements_liste();
create or replace function public.abonnements_liste()
returns table (cle text, email text, nom text, whatsapp text, langue text, formule text, periode text, statut text,
               debut date, fin date, jours integer, dossier_id uuid, inscription_id uuid,
               boutique_id uuid, boutique text, slug text, visible boolean, masquee_pour text, demande text, demande_le timestamptz, motif text,
               fondateur boolean, boost text, boost_fin date, non_lus bigint, dernier timestamptz,
               zone text, prix numeric, prix_a_vie boolean, code_promo text, remise_pct integer, parrain text)
language plpgsql stable security definer set search_path = public as $$
declare g integer := coalesce((select grace_jours from public.reglages_abonnements where id = 1), 7);
begin
  if not public.is_admin() then raise exception 'Réservé à l’administration.'; end if;
  return query
  with v as (
    select distinct on (lower(d.email)) lower(d.email) as em, d.nom as n, d.whatsapp as w, d.langue as l, d.formule as f, d.periode as p,
           d.abonnement_debut as db, d.abonnement_fin as fn, d.id as did, null::uuid as iid, d.zone as z, d.prix as px, d.prix_a_vie as pv,
           d.code_promo as cp, d.remise_pct as rp, d.parrain as pa
    from public.dossiers d where d.statut = 'actif' order by lower(d.email), d.created_at desc
  ), t as (
    select distinct on (lower(i.email)) lower(i.email) as em, i.nom as n, i.whatsapp as w, i.langue as l, 'essai'::text as f, null::text as p,
           (i.essai_fin - interval '14 days')::date as db, i.essai_fin::date as fn, null::uuid as did, i.id as iid, i.zone as z, null::numeric as px, false as pv,
           null::text as cp, null::integer as rp, i.parrain as pa
    from public.inscriptions i where i.statut = 'actif' and i.essai_fin is not null and i.essai_fin > now() - interval '60 days'
      and not exists (select 1 from v where v.em = lower(i.email))
    order by lower(i.email), i.created_at desc
  ), a as (select * from v union all select * from t)
  select a.em, a.em, a.n, a.w, a.l, a.f, a.p,
    case when a.f = 'essai' then (case when a.fn < current_date then 'essai_fini' else 'essai' end)
         when a.fn is null then 'actif'
         when a.fn < current_date - g then 'expire'
         when a.fn < current_date then 'grace'
         when a.fn <= current_date + 14 then 'bientot'
         else 'actif' end,
    a.db, a.fn, (a.fn - current_date)::integer, a.did, a.iid,
    b.id, b.nom, b.slug, b.visible, b.masquee_pour, b.visibilite_demande, b.visibilite_demande_le, b.visibilite_motif,
    coalesce(b.fondateur, false), case when b.boost_fin is null or b.boost_fin >= current_date then b.boost end, b.boost_fin,
    (select count(*) from public.vendeurs_suivi s where lower(s.email) = a.em and not s.lu_admin and s.de = 'vendeur'),
    (select max(s.created_at) from public.vendeurs_suivi s where lower(s.email) = a.em),
    a.z, a.px, a.pv, a.cp, a.rp, a.pa
  from a
  left join auth.users u on lower(u.email) = a.em
  left join public.boutiques b on b.owner = u.id
  order by a.fn nulls last;
end $$;
revoke all on function public.abonnements_liste() from public, anon;
grant execute on function public.abonnements_liste() to authenticated;

insert into public.versions_base (version) values ('v27') on conflict (version) do nothing;
