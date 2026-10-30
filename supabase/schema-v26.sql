-- =====================================================================
-- Yiriclick – base v26 : suivi des abonnements, visibilité réservée à l'admin, Boost
-- À coller dans Supabase > SQL Editor > New query, puis "Run". Prérequis : v25. Peut être relancé sans risque.
--  1. Chaque abonnement payant (dossier « actif ») a une date de début, une date de fin et une période (mois / an).
--     Les abonnements déjà actifs reçoivent une fin dans 30 jours : à ajuster dans l'admin (page Abonnements).
--  2. Chaque jour à 10 h 37 UTC : rappels par e-mail et dans l'espace vendeur avant la fin (J-14, J-7, J-1, J0 par défaut),
--     puis, après le délai de grâce (7 jours par défaut), la boutique est masquée sans rien supprimer.
--     Elle revient toute seule quand l'admin prolonge l'abonnement.
--  3. Fil de suivi admin <-> vendeur : notes privées, questions, réponses, relances, demandes de pause.
--  4. Visibilité : seul l'admin peut afficher ou masquer une boutique. Le vendeur peut demander une pause ou une reprise.
--  5. Boost Yiriclick : mise en avant, vedette, boutique de la semaine, décidés par l'admin, avec dates.
--  6. Partenaires : nouvel emplacement « Espace vendeurs » (contenus sponsorisés montrés aux vendeurs).
-- =====================================================================

-- 1. Dates d'abonnement ----------------------------------------------------------------
alter table public.dossiers add column if not exists abonnement_debut date;
alter table public.dossiers add column if not exists abonnement_fin   date;
alter table public.dossiers add column if not exists periode          text not null default 'mois';
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'dossiers_periode_check') then
    alter table public.dossiers add constraint dossiers_periode_check check (periode in ('mois', 'an'));
  end if;
end $$;
update public.dossiers set abonnement_debut = coalesce(abonnement_debut, created_at::date),
                           abonnement_fin   = coalesce(abonnement_fin, current_date + 30)
where statut = 'actif' and abonnement_fin is null;

-- A dossier that becomes active gets its dates automatically (1 month or 1 year)
create or replace function public.dossiers_abonnement()
returns trigger language plpgsql as $$
begin
  if new.statut = 'actif' and (tg_op = 'INSERT' or old.statut is distinct from 'actif') and new.abonnement_fin is null then
    new.abonnement_debut := current_date;
    new.abonnement_fin := (current_date + case when new.periode = 'an' then interval '1 year' else interval '1 month' end)::date;
  end if;
  return new;
end $$;
drop trigger if exists dossiers_abonnement on public.dossiers;
create trigger dossiers_abonnement before insert or update on public.dossiers
  for each row execute function public.dossiers_abonnement();

-- Réglages (une seule ligne)
create table if not exists public.reglages_abonnements (
  id             integer primary key default 1 check (id = 1),
  rappels        integer[] not null default '{14,7,1,0}',   -- jours avant la fin
  grace_jours    integer not null default 7 check (grace_jours between 0 and 60),
  masquer_auto   boolean not null default true,              -- masquer la boutique après le délai de grâce
  rappels_actifs boolean not null default true
);
insert into public.reglages_abonnements (id) values (1) on conflict (id) do nothing;
alter table public.reglages_abonnements enable row level security;
grant select, update on table public.reglages_abonnements to authenticated;
drop policy if exists "Admin lit reglages abonnements" on public.reglages_abonnements;
create policy "Admin lit reglages abonnements" on public.reglages_abonnements for select to authenticated using (public.is_admin());
drop policy if exists "Admin modifie reglages abonnements" on public.reglages_abonnements;
create policy "Admin modifie reglages abonnements" on public.reglages_abonnements for update to authenticated using (public.is_admin()) with check (public.is_admin());

-- Paid plan counts until the end date + grace period
create or replace function public.vendeur_formule()
returns text language sql stable security definer set search_path = public as $$
  select case when not exists (
      select 1 from auth.users u where u.id = auth.uid() and u.email_confirmed_at is not null
    ) then null
  else coalesce(
    (select d.formule from public.dossiers d
      where lower(d.email) = lower(auth.jwt() ->> 'email') and d.statut = 'actif'
        and (d.abonnement_fin is null or d.abonnement_fin + coalesce((select grace_jours from public.reglages_abonnements where id = 1), 7) >= current_date)
      order by d.created_at desc limit 1),
    (select 'essai' from public.inscriptions i
      where lower(i.email) = lower(auth.jwt() ->> 'email') and i.statut = 'actif'
        and (i.essai_fin is null or i.essai_fin > now()) limit 1)
  ) end;
$$;

-- 2. Fil de suivi admin <-> vendeur ---------------------------------------------------
create table if not exists public.vendeurs_suivi (
  id          bigint generated always as identity primary key,
  created_at  timestamptz not null default now(),
  email       text not null,
  de          text not null check (de in ('admin', 'vendeur', 'systeme')),
  type        text not null check (type in ('note', 'question', 'reponse', 'message', 'relance', 'pause', 'reprise', 'info')),
  texte       text not null check (char_length(texte) between 1 and 2000),
  lu_vendeur  boolean not null default false,
  lu_admin    boolean not null default false
);
create index if not exists vendeurs_suivi_idx on public.vendeurs_suivi (lower(email), created_at desc);
alter table public.vendeurs_suivi enable row level security;
grant select, insert, update, delete on table public.vendeurs_suivi to authenticated;
drop policy if exists "Admin gere suivi" on public.vendeurs_suivi;
create policy "Admin gere suivi" on public.vendeurs_suivi for all to authenticated using (public.is_admin()) with check (public.is_admin());
drop policy if exists "Vendeur lit son suivi" on public.vendeurs_suivi;
create policy "Vendeur lit son suivi" on public.vendeurs_suivi for select to authenticated
  using (lower(email) = lower(auth.jwt() ->> 'email') and type <> 'note');

-- Limit: 20 messages per hour per seller
create or replace function public.vendeur_ecrire(p_texte text, p_type text default 'reponse')
returns void language plpgsql security definer set search_path = public as $$
declare e text := lower(auth.jwt() ->> 'email');
begin
  if auth.uid() is null or e is null then raise exception 'Connecte-toi d’abord.'; end if;
  if p_type not in ('reponse', 'message') then p_type := 'message'; end if;
  if (select count(*) from public.vendeurs_suivi where lower(email) = e and de = 'vendeur' and created_at > now() - interval '1 hour') >= 20 then
    raise exception 'Trop de messages en peu de temps. Réessaie dans une heure.';
  end if;
  insert into public.vendeurs_suivi (email, de, type, texte, lu_vendeur) values (e, 'vendeur', p_type, left(trim(p_texte), 2000), true);
end $$;
revoke all on function public.vendeur_ecrire(text, text) from public, anon;
grant execute on function public.vendeur_ecrire(text, text) to authenticated;

create or replace function public.vendeur_suivi_lu()
returns void language sql security definer set search_path = public as $$
  update public.vendeurs_suivi set lu_vendeur = true where lower(email) = lower(auth.jwt() ->> 'email') and not lu_vendeur;
$$;
revoke all on function public.vendeur_suivi_lu() from public, anon;
grant execute on function public.vendeur_suivi_lu() to authenticated;

-- 3. Visibilité réservée à l'admin, demandes de pause, Boost -------------------------------
alter table public.boutiques add column if not exists masquee_pour          text;   -- 'pause' | 'abonnement' | 'admin'
alter table public.boutiques add column if not exists visibilite_demande    text;   -- 'pause' | 'reprise'
alter table public.boutiques add column if not exists visibilite_demande_le timestamptz;
alter table public.boutiques add column if not exists visibilite_motif      text;
alter table public.boutiques add column if not exists boost                 text;   -- 'avant' | 'vedette' | 'semaine'
alter table public.boutiques add column if not exists boost_debut           date;
alter table public.boutiques add column if not exists boost_fin             date;
alter table public.boutiques add column if not exists boost_raison          text;
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'boutiques_boost_check') then
    alter table public.boutiques add constraint boutiques_boost_check check (boost is null or boost in ('avant', 'vedette', 'semaine'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'boutiques_vis_demande_check') then
    alter table public.boutiques add constraint boutiques_vis_demande_check check (visibilite_demande is null or visibilite_demande in ('pause', 'reprise'));
  end if;
end $$;
-- Shops already hidden by their seller before v26 are counted as a pause
update public.boutiques set masquee_pour = 'pause' where not visible and masquee_pour is null;

create or replace function public.boutiques_visibilite_garde()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is not null and not public.is_admin() then
    if tg_op = 'INSERT' then
      new.visible := true; new.masquee_pour := null; new.boost := null; new.boost_debut := null; new.boost_fin := null; new.boost_raison := null;
      new.visibilite_demande := null; new.visibilite_demande_le := null; new.visibilite_motif := null;
    else
      new.visible := old.visible; new.masquee_pour := old.masquee_pour;
      new.boost := old.boost; new.boost_debut := old.boost_debut; new.boost_fin := old.boost_fin; new.boost_raison := old.boost_raison;
      if coalesce(current_setting('yiriclick.demande', true), '') <> '1' then
        new.visibilite_demande := old.visibilite_demande; new.visibilite_demande_le := old.visibilite_demande_le; new.visibilite_motif := old.visibilite_motif;
      end if;
    end if;
  end if;
  return new;
end $$;
drop trigger if exists boutiques_visibilite_garde on public.boutiques;
create trigger boutiques_visibilite_garde before insert or update on public.boutiques
  for each row execute function public.boutiques_visibilite_garde();

-- Seller: ask for a pause or to reopen (p_action 'pause' | 'reprise' | 'annuler')
create or replace function public.demander_visibilite(p_action text, p_motif text default null)
returns void language plpgsql security definer set search_path = public as $$
declare b public.boutiques; e text := lower(auth.jwt() ->> 'email');
begin
  select * into b from public.boutiques where owner = auth.uid();
  if b.id is null then raise exception 'Aucune boutique.'; end if;
  if p_action not in ('pause', 'reprise', 'annuler') then raise exception 'Demande inconnue.'; end if;
  perform set_config('yiriclick.demande', '1', true);
  if p_action = 'annuler' then
    update public.boutiques set visibilite_demande = null, visibilite_demande_le = null, visibilite_motif = null where id = b.id;
    perform set_config('yiriclick.demande', '', true);
    return;
  end if;
  update public.boutiques set visibilite_demande = p_action, visibilite_demande_le = now(), visibilite_motif = left(nullif(trim(coalesce(p_motif, '')), ''), 500) where id = b.id;
  insert into public.vendeurs_suivi (email, de, type, texte, lu_vendeur)
  values (e, 'vendeur', p_action, case when p_action = 'pause' then 'Demande de pause' else 'Demande de réouverture' end
    || coalesce(' : ' || left(nullif(trim(coalesce(p_motif, '')), ''), 500), ''), true);
  perform set_config('yiriclick.demande', '', true);
end $$;
revoke all on function public.demander_visibilite(text, text) from public, anon;
grant execute on function public.demander_visibilite(text, text) to authenticated;

-- Admin: show or hide a shop (answers any pending request)
create or replace function public.admin_visibilite(p_boutique uuid, p_visible boolean, p_raison text default 'admin')
returns void language plpgsql security definer set search_path = public as $$
declare e text; b public.boutiques;
begin
  if not public.is_admin() then raise exception 'Réservé à l’administration.'; end if;
  select * into b from public.boutiques where id = p_boutique;
  if b.id is null then raise exception 'Boutique introuvable.'; end if;
  update public.boutiques set visible = p_visible,
    masquee_pour = case when p_visible then null else coalesce(nullif(p_raison, ''), 'admin') end,
    visibilite_demande = null, visibilite_demande_le = null, visibilite_motif = null
  where id = p_boutique;
  select lower(u.email) into e from auth.users u where u.id = b.owner;
  if e is not null then
    insert into public.vendeurs_suivi (email, de, type, texte, lu_admin)
    values (e, 'admin', 'info', case when p_visible then 'Ta boutique est de nouveau visible par les clients.'
      when p_raison = 'pause' then 'Ta pause est acceptée : ta boutique est masquée. Rien n’est supprimé. Demande la réouverture quand tu es prêt.'
      else 'Ta boutique est masquée par l’équipe Yiriclick. Écris-nous ici si tu as une question.' end, true);
  end if;
end $$;
revoke all on function public.admin_visibilite(uuid, boolean, text) from public, anon;
grant execute on function public.admin_visibilite(uuid, boolean, text) to authenticated;

-- 4. Situation du vendeur (abonnement, visibilité, Boost, messages) --------------------------
create or replace function public.mon_abonnement()
returns jsonb language sql stable security definer set search_path = public as $$
  with d as (select * from public.dossiers where lower(email) = lower(auth.jwt() ->> 'email') and statut = 'actif' order by created_at desc limit 1),
       b as (select * from public.boutiques where owner = auth.uid() limit 1),
       g as (select coalesce((select grace_jours from public.reglages_abonnements where id = 1), 7) as j)
  select jsonb_build_object(
    'formule', (select formule from d), 'periode', (select periode from d),
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
revoke all on function public.mon_abonnement() from public, anon;
grant execute on function public.mon_abonnement() to authenticated;

-- 5. Liste des abonnements pour l'admin ---------------------------------------------------
create or replace function public.abonnements_liste()
returns table (cle text, email text, nom text, whatsapp text, langue text, formule text, periode text, statut text,
               debut date, fin date, jours integer, dossier_id uuid, inscription_id uuid,
               boutique_id uuid, boutique text, slug text, visible boolean, masquee_pour text, demande text, demande_le timestamptz, motif text,
               fondateur boolean, boost text, boost_fin date, non_lus bigint, dernier timestamptz)
language plpgsql stable security definer set search_path = public as $$
declare g integer := coalesce((select grace_jours from public.reglages_abonnements where id = 1), 7);
begin
  if not public.is_admin() then raise exception 'Réservé à l’administration.'; end if;
  return query
  with v as (
    select distinct on (lower(d.email)) lower(d.email) as em, d.nom as n, d.whatsapp as w, d.langue as l, d.formule as f, d.periode as p,
           d.abonnement_debut as db, d.abonnement_fin as fn, d.id as did, null::uuid as iid
    from public.dossiers d where d.statut = 'actif' order by lower(d.email), d.created_at desc
  ), t as (
    select distinct on (lower(i.email)) lower(i.email) as em, i.nom as n, i.whatsapp as w, i.langue as l, 'essai'::text as f, null::text as p,
           (i.essai_fin - interval '14 days')::date as db, i.essai_fin::date as fn, null::uuid as did, i.id as iid
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
    (select max(s.created_at) from public.vendeurs_suivi s where lower(s.email) = a.em)
  from a
  left join auth.users u on lower(u.email) = a.em
  left join public.boutiques b on b.owner = u.id
  order by a.fn nulls last;
end $$;
revoke all on function public.abonnements_liste() from public, anon;
grant execute on function public.abonnements_liste() to authenticated;

-- Admin: extend a paid subscription by N months (and reopen a shop hidden for expiry)
create or replace function public.admin_prolonger(p_dossier uuid, p_mois integer)
returns date language plpgsql security definer set search_path = public as $$
declare d public.dossiers; nf date;
begin
  if not public.is_admin() then raise exception 'Réservé à l’administration.'; end if;
  if p_mois is null or p_mois < 1 or p_mois > 36 then raise exception 'Durée invalide (1 à 36 mois).'; end if;
  select * into d from public.dossiers where id = p_dossier;
  if d.id is null then raise exception 'Abonnement introuvable.'; end if;
  nf := (greatest(coalesce(d.abonnement_fin, current_date), current_date) + make_interval(months => p_mois))::date;
  update public.dossiers set abonnement_fin = nf, abonnement_debut = coalesce(abonnement_debut, current_date) where id = p_dossier;
  update public.boutiques b set visible = true, masquee_pour = null
  from auth.users u where u.id = b.owner and lower(u.email) = lower(d.email) and b.masquee_pour = 'abonnement';
  insert into public.vendeurs_suivi (email, de, type, texte, lu_admin)
  values (lower(d.email), 'admin', 'info', 'Ton abonnement ' || d.formule || ' est prolongé jusqu’au ' || to_char(nf, 'DD/MM/YYYY') || '. Merci de ta confiance !', true);
  return nf;
end $$;
revoke all on function public.admin_prolonger(uuid, integer) from public, anon;
grant execute on function public.admin_prolonger(uuid, integer) to authenticated;

-- 6. Rappels quotidiens et masquage après le délai de grâce --------------------------------
create table if not exists public.abonnement_rappels (
  email     text not null,
  fin       date not null,
  etape     integer not null,         -- jours avant la fin ; -1 = boutique masquée
  envoye_le timestamptz not null default now(),
  envoye    boolean not null default true,
  primary key (email, fin, etape)
);
alter table public.abonnement_rappels enable row level security;
grant select on table public.abonnement_rappels to authenticated;
drop policy if exists "Admin lit rappels abonnements" on public.abonnement_rappels;
create policy "Admin lit rappels abonnements" on public.abonnement_rappels for select to authenticated using (public.is_admin());

create or replace function public.abonnement_textes(p_jours integer, p_lang text, p_formule text, p_fin date)
returns jsonb language plpgsql immutable as $$
declare l text := case when p_lang in ('en', 'es', 'nl') then p_lang else 'fr' end; f text := to_char(p_fin, 'DD/MM/YYYY');
begin
  if p_jours < 0 then
    return case l
      when 'en' then jsonb_build_object('sujet', 'Your shop is paused: subscription ended', 'corps', 'Your ' || p_formule || ' subscription ended on ' || f || '. Your shop is hidden for now, nothing is deleted. Renew to reopen it right away.', 'bouton', 'Renew my subscription')
      when 'es' then jsonb_build_object('sujet', 'Tu tienda está en pausa: suscripción terminada', 'corps', 'Tu suscripción ' || p_formule || ' terminó el ' || f || '. Tu tienda está oculta por ahora, no se borra nada. Renueva para reabrirla enseguida.', 'bouton', 'Renovar mi suscripción')
      when 'nl' then jsonb_build_object('sujet', 'Je winkel is gepauzeerd: abonnement afgelopen', 'corps', 'Je abonnement ' || p_formule || ' is op ' || f || ' afgelopen. Je winkel is voorlopig verborgen, er wordt niets verwijderd. Verleng om hem meteen weer te openen.', 'bouton', 'Mijn abonnement verlengen')
      else jsonb_build_object('sujet', 'Ta boutique est en pause : abonnement terminé', 'corps', 'Ton abonnement ' || p_formule || ' s’est terminé le ' || f || '. Ta boutique est masquée pour l’instant, rien n’est supprimé. Renouvelle-le pour la rouvrir tout de suite.', 'bouton', 'Renouveler mon abonnement') end;
  elsif p_jours = 0 then
    return case l
      when 'en' then jsonb_build_object('sujet', 'Your subscription ends today', 'corps', 'Your ' || p_formule || ' subscription ends today (' || f || '). Renew it now to keep selling without interruption.', 'bouton', 'Renew my subscription')
      when 'es' then jsonb_build_object('sujet', 'Tu suscripción termina hoy', 'corps', 'Tu suscripción ' || p_formule || ' termina hoy (' || f || '). Renuévala ahora para seguir vendiendo sin interrupción.', 'bouton', 'Renovar mi suscripción')
      when 'nl' then jsonb_build_object('sujet', 'Je abonnement loopt vandaag af', 'corps', 'Je abonnement ' || p_formule || ' loopt vandaag af (' || f || '). Verleng het nu om zonder onderbreking te blijven verkopen.', 'bouton', 'Mijn abonnement verlengen')
      else jsonb_build_object('sujet', 'Ton abonnement se termine aujourd’hui', 'corps', 'Ton abonnement ' || p_formule || ' se termine aujourd’hui (' || f || '). Renouvelle-le maintenant pour continuer à vendre sans coupure.', 'bouton', 'Renouveler mon abonnement') end;
  end if;
  return case l
    when 'en' then jsonb_build_object('sujet', 'Your subscription ends in ' || p_jours || ' day(s)', 'corps', 'Your ' || p_formule || ' subscription ends on ' || f || '. Renew it before that date so your shop stays open.', 'bouton', 'Renew my subscription')
    when 'es' then jsonb_build_object('sujet', 'Tu suscripción termina en ' || p_jours || ' día(s)', 'corps', 'Tu suscripción ' || p_formule || ' termina el ' || f || '. Renuévala antes de esa fecha para que tu tienda siga abierta.', 'bouton', 'Renovar mi suscripción')
    when 'nl' then jsonb_build_object('sujet', 'Je abonnement loopt over ' || p_jours || ' dag(en) af', 'corps', 'Je abonnement ' || p_formule || ' loopt af op ' || f || '. Verleng het vóór die datum zodat je winkel open blijft.', 'bouton', 'Mijn abonnement verlengen')
    else jsonb_build_object('sujet', 'Ton abonnement se termine dans ' || p_jours || ' jour(s)', 'corps', 'Ton abonnement ' || p_formule || ' se termine le ' || f || '. Renouvelle-le avant cette date pour que ta boutique reste ouverte.', 'bouton', 'Renouveler mon abonnement') end;
end $$;

create or replace function public.abonnements_controle()
returns integer language plpgsql security definer set search_path = public as $$
declare r record; d record; e record; due integer[]; cible integer; tx jsonb; nb integer := 0; lien text;
begin
  select * into r from public.reglages_abonnements where id = 1;
  select * into e from public.reglages_email where id = 1;
  for d in
    select distinct on (lower(x.email)) x.* from public.dossiers x
    where x.statut = 'actif' and x.abonnement_fin is not null and x.abonnement_fin <= current_date + 60
    order by lower(x.email), x.created_at desc
  loop
    lien := coalesce(e.site_url, 'https://yiriclick.com/') || 'vendeur#abo';
    -- after the grace period: hide the shop once
    if d.abonnement_fin + r.grace_jours < current_date then
      if r.masquer_auto and not exists (select 1 from public.abonnement_rappels where email = lower(d.email) and fin = d.abonnement_fin and etape = -1) then
        update public.boutiques b set visible = false, masquee_pour = 'abonnement'
        from auth.users u where u.id = b.owner and lower(u.email) = lower(d.email) and b.visible;
        tx := public.abonnement_textes(-1, d.langue, d.formule, d.abonnement_fin);
        insert into public.vendeurs_suivi (email, de, type, texte, lu_admin) values (lower(d.email), 'systeme', 'relance', tx ->> 'corps', true);
        if e.id is not null then
          perform public.envoyer_email(d.email, tx ->> 'sujet', public.email_cadre(tx ->> 'sujet', '<p style="font-size:15px;line-height:1.5">' || (tx ->> 'corps') || '</p>', lien, tx ->> 'bouton'), 'abonnement_masque');
        end if;
        insert into public.abonnement_rappels (email, fin, etape) values (lower(d.email), d.abonnement_fin, -1) on conflict do nothing;
        nb := nb + 1;
      end if;
      continue;
    end if;
    if not r.rappels_actifs then continue; end if;
    -- reminders: only the closest step not yet handled is sent
    select array_agg(s order by s desc) into due from unnest(r.rappels) s
    where current_date >= d.abonnement_fin - s
      and not exists (select 1 from public.abonnement_rappels a where a.email = lower(d.email) and a.fin = d.abonnement_fin and a.etape = s);
    if due is null or cardinality(due) = 0 then continue; end if;
    cible := due[cardinality(due)];
    insert into public.abonnement_rappels (email, fin, etape, envoye) select lower(d.email), d.abonnement_fin, s, false from unnest(due) s where s <> cible on conflict do nothing;
    tx := public.abonnement_textes(greatest(d.abonnement_fin - current_date, 0), d.langue, d.formule, d.abonnement_fin);
    insert into public.vendeurs_suivi (email, de, type, texte, lu_admin) values (lower(d.email), 'systeme', 'relance', tx ->> 'corps', true);
    if e.id is not null then
      perform public.envoyer_email(d.email, tx ->> 'sujet', public.email_cadre(tx ->> 'sujet', '<p style="font-size:15px;line-height:1.5">' || (tx ->> 'corps') || '</p>', lien, tx ->> 'bouton'), 'abonnement_rappel');
    end if;
    insert into public.abonnement_rappels (email, fin, etape) values (lower(d.email), d.abonnement_fin, cible) on conflict do nothing;
    nb := nb + 1;
  end loop;
  -- expired Boosts are cleared
  update public.boutiques set boost = null where boost is not null and boost_fin is not null and boost_fin < current_date;
  return nb;
end $$;
revoke all on function public.abonnements_controle() from public, anon, authenticated;

do $$ begin
  if to_regclass('cron.job') is not null then
    perform cron.schedule('yiriclick-abonnements', '37 10 * * *', 'select public.abonnements_controle()');
  end if;
end $$;

-- 7. Emplacement « Espace vendeurs » pour les contenus sponsorisés par Yiriclick (carte affichée aux vendeurs
--    dont la boutique est complète à 100 %). Se gère dans l'admin, carte Partenaires.
alter table public.partenaires drop constraint if exists partenaires_emplacement_check;
alter table public.partenaires add constraint partenaires_emplacement_check check (emplacement in ('principal', 'bande', 'vendeurs'));

insert into public.versions_base (version) values ('v26') on conflict (version) do nothing;
