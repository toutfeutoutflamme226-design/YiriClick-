-- Yiriclick : table des inscriptions vendeurs
-- À coller dans Supabase > SQL Editor > New query, puis cliquer sur "Run".

create table if not exists public.inscriptions (
  id            uuid primary key default gen_random_uuid(),
  created_at    timestamptz not null default now(),
  nom           text not null,
  boutique      text not null,
  pays          text not null,
  whatsapp      text not null,
  email         text not null,
  formule       text not null check (formule in ('essai', 'basique', 'pro', 'entreprise')),
  zone          text not null check (zone in ('af', 'eu', 'am')),
  langue        text check (langue in ('fr', 'en', 'es')),
  consentement  boolean not null default false
);

-- Sécurité : le public peut seulement AJOUTER une inscription.
-- Personne ne peut lire, modifier ou supprimer les inscriptions depuis le site.
-- Toi, tu les consultes dans Supabase > Table Editor > inscriptions.
alter table public.inscriptions enable row level security;

-- Le projet n'expose pas automatiquement les nouvelles tables :
-- on autorise uniquement l'ajout pour les visiteurs du site.
grant insert on table public.inscriptions to anon;

drop policy if exists "Inscription publique" on public.inscriptions;
create policy "Inscription publique"
  on public.inscriptions
  for insert
  to anon
  with check (consentement = true);
