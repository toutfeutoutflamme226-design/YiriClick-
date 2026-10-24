-- =====================================================================
-- Yiriclick – base v2 : dossiers vendeurs, pièces d'identité, visites, admin
-- À coller dans Supabase > SQL Editor > New query, puis "Run".
-- Prérequis : avoir déjà exécuté inscriptions.sql (table des essais).
-- Le script peut être relancé sans risque.
-- =====================================================================

-- 1. Administrateurs ----------------------------------------------------
create table if not exists public.admins (
  user_id uuid primary key references auth.users (id) on delete cascade
);
alter table public.admins enable row level security;
grant select on table public.admins to authenticated;
drop policy if exists "Admin se voit" on public.admins;
create policy "Admin se voit" on public.admins
  for select to authenticated using (user_id = auth.uid());

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.admins where user_id = auth.uid());
$$;
revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to authenticated;

-- 2. Essais gratuits : suivi par l'admin --------------------------------
alter table public.inscriptions add column if not exists statut text not null default 'nouveau';
alter table public.inscriptions add column if not exists note_admin text;
alter table public.inscriptions drop constraint if exists inscriptions_statut_check;
alter table public.inscriptions add constraint inscriptions_statut_check
  check (statut in ('nouveau', 'contacte', 'actif', 'refuse'));
grant select, update on table public.inscriptions to authenticated;
drop policy if exists "Admin lit inscriptions" on public.inscriptions;
create policy "Admin lit inscriptions" on public.inscriptions
  for select to authenticated using (public.is_admin());
drop policy if exists "Admin modifie inscriptions" on public.inscriptions;
create policy "Admin modifie inscriptions" on public.inscriptions
  for update to authenticated using (public.is_admin()) with check (public.is_admin());

-- 3. Dossiers vendeurs (Basique, Pro, Entreprise) -----------------------
create table if not exists public.dossiers (
  id                      uuid primary key default gen_random_uuid(),
  created_at              timestamptz not null default now(),
  statut                  text not null default 'en_attente' check (statut in ('en_attente', 'verifie', 'actif', 'refuse')),
  note_admin              text,
  formule                 text not null check (formule in ('basique', 'pro', 'entreprise')),
  zone                    text not null check (zone in ('af', 'eu', 'am')),
  langue                  text check (langue in ('fr', 'en', 'es')),
  nom                     text not null,
  email                   text not null,
  whatsapp                text not null,
  pays                    text not null,
  pays_code               text,
  statut_juridique        text not null,
  nom_legal               text,
  boutique                text not null,
  categorie               text not null,
  produits                text not null,
  immatriculation         text,
  numero_fiscal           text,
  adresse                 text not null,
  ville                   text not null,
  representant            text not null,
  date_naissance          date not null,
  nationalite             text not null,
  nationalite_code        text,
  piece_type              text not null,
  piece_numero            text not null,
  piece_expiration        date not null,
  fichier_recto           text not null,
  fichier_verso           text,
  fichier_selfie          text not null,
  versement               text not null check (versement in ('mm', 'bank')),
  operateur               text,
  numero_mobile           text,
  titulaire               text,
  iban                    text,
  accepte_cgv             boolean not null,
  accepte_confidentialite boolean not null,
  certifie_exact          boolean not null,
  engagement_conformite   boolean not null
);
alter table public.dossiers enable row level security;
grant insert on table public.dossiers to anon;
grant select, update on table public.dossiers to authenticated;
drop policy if exists "Depot de dossier" on public.dossiers;
create policy "Depot de dossier" on public.dossiers
  for insert to anon
  with check (statut = 'en_attente' and note_admin is null
              and accepte_cgv and accepte_confidentialite and certifie_exact and engagement_conformite);
drop policy if exists "Admin lit dossiers" on public.dossiers;
create policy "Admin lit dossiers" on public.dossiers
  for select to authenticated using (public.is_admin());
drop policy if exists "Admin modifie dossiers" on public.dossiers;
create policy "Admin modifie dossiers" on public.dossiers
  for update to authenticated using (public.is_admin()) with check (public.is_admin());

-- 4. Pièces d'identité : espace privé ------------------------------------
-- Les visiteurs peuvent déposer un fichier, jamais le lire, le lister ni le remplacer.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('pieces-identite', 'pieces-identite', false, 10485760, array['image/jpeg', 'image/png', 'application/pdf'])
on conflict (id) do update set public = false, file_size_limit = 10485760,
  allowed_mime_types = array['image/jpeg', 'image/png', 'application/pdf'];
drop policy if exists "Depot pieces identite" on storage.objects;
create policy "Depot pieces identite" on storage.objects
  for insert to anon with check (bucket_id = 'pieces-identite');
drop policy if exists "Admin lit pieces identite" on storage.objects;
create policy "Admin lit pieces identite" on storage.objects
  for select to authenticated using (bucket_id = 'pieces-identite' and public.is_admin());

-- 5. Visites du site (anonymes : aucun nom, aucune adresse IP, aucun cookie) --
create table if not exists public.visites (
  id         bigint generated always as identity primary key,
  created_at timestamptz not null default now(),
  type       text not null check (type in ('visite', 'formulaire', 'essai', 'dossier')),
  detail     text check (char_length(detail) <= 40),
  langue     text check (langue in ('fr', 'en', 'es')),
  zone       text check (zone in ('af', 'eu', 'am')),
  page       text check (char_length(page) <= 100),
  source     text check (char_length(source) <= 100)
);
alter table public.visites enable row level security;
grant insert on table public.visites to anon;
grant select on table public.visites to authenticated;
drop policy if exists "Enregistrer une visite" on public.visites;
create policy "Enregistrer une visite" on public.visites
  for insert to anon with check (true);
drop policy if exists "Admin lit visites" on public.visites;
create policy "Admin lit visites" on public.visites
  for select to authenticated using (public.is_admin());

-- 6. Te nommer administrateur --------------------------------------------
-- D'abord : Authentication > Users > Add user > Create new user
-- (ton e-mail + un mot de passe solide, coche "Auto Confirm User").
-- Puis remplace l'adresse ci-dessous par la tienne et exécute ces 2 lignes :
insert into public.admins (user_id)
select id from auth.users where email = 'TON_EMAIL@exemple.com'
on conflict do nothing;
