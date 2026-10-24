-- =====================================================================
-- Yiriclick – base v3 : boutiques, produits, photos, limites par formule
-- À coller dans Supabase > SQL Editor > New query, puis "Run".
-- Prérequis : inscriptions.sql et schema-v2.sql déjà exécutés.
-- Le script peut être relancé sans risque.
-- =====================================================================

-- 0. is_admin() utilisable aussi par les visiteurs (répond toujours "non" pour eux)
grant execute on function public.is_admin() to anon;

-- 1. Quelle formule a le vendeur connecté ? -------------------------------
-- Un vendeur a accès à son espace seulement si :
--  - son e-mail est confirmé, ET
--  - son dossier est "Actif" (Basique, Pro, Entreprise) ou son essai est "Client actif".
create or replace function public.vendeur_formule()
returns text language sql stable security definer set search_path = public as $$
  select case when not exists (
      select 1 from auth.users u where u.id = auth.uid() and u.email_confirmed_at is not null
    ) then null
  else coalesce(
    (select d.formule from public.dossiers d
      where lower(d.email) = lower(auth.jwt() ->> 'email') and d.statut = 'actif'
      order by d.created_at desc limit 1),
    (select 'essai' from public.inscriptions i
      where lower(i.email) = lower(auth.jwt() ->> 'email') and i.statut = 'actif' limit 1)
  ) end;
$$;
revoke all on function public.vendeur_formule() from public;
grant execute on function public.vendeur_formule() to authenticated;

create or replace function public.limite_produits(f text)
returns integer language sql immutable as $$
  select case f when 'essai' then 15 when 'basique' then 100 when 'pro' then 500 else null end;
$$;
create or replace function public.limite_photos(f text)
returns integer language sql immutable as $$
  select case f when 'entreprise' then 10 when 'pro' then 6 else 4 end;
$$;
grant execute on function public.limite_produits(text) to anon, authenticated;
grant execute on function public.limite_photos(text) to anon, authenticated;

-- 2. Boutiques ---------------------------------------------------------------
create table if not exists public.boutiques (
  id           uuid primary key default gen_random_uuid(),
  owner        uuid not null unique default auth.uid() references auth.users (id) on delete cascade,
  slug         text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$' and char_length(slug) between 3 and 40),
  nom          text not null check (char_length(nom) between 2 and 80),
  description  text check (char_length(description) <= 1000),
  whatsapp     text check (char_length(whatsapp) <= 25),
  ville        text check (char_length(ville) <= 80),
  pays         text check (char_length(pays) <= 80),
  devise       text not null default 'XOF' check (devise in ('XOF', 'EUR', 'USD')),
  logo         text,
  couverture   text,
  visible      boolean not null default true,
  masque_admin boolean not null default false,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
alter table public.boutiques enable row level security;
grant select on table public.boutiques to anon, authenticated;
grant insert, update, delete on table public.boutiques to authenticated;

drop policy if exists "Public lit boutiques" on public.boutiques;
create policy "Public lit boutiques" on public.boutiques
  for select to anon using (visible and not masque_admin);
drop policy if exists "Connecte lit boutiques" on public.boutiques;
create policy "Connecte lit boutiques" on public.boutiques
  for select to authenticated using ((visible and not masque_admin) or owner = auth.uid() or public.is_admin());
drop policy if exists "Vendeur cree sa boutique" on public.boutiques;
create policy "Vendeur cree sa boutique" on public.boutiques
  for insert to authenticated with check (owner = auth.uid() and public.vendeur_formule() is not null);
drop policy if exists "Vendeur modifie sa boutique" on public.boutiques;
create policy "Vendeur modifie sa boutique" on public.boutiques
  for update to authenticated using (owner = auth.uid() or public.is_admin())
  with check ((owner = auth.uid() and public.vendeur_formule() is not null) or public.is_admin());
drop policy if exists "Vendeur supprime sa boutique" on public.boutiques;
create policy "Vendeur supprime sa boutique" on public.boutiques
  for delete to authenticated using (owner = auth.uid());

create or replace function public.boutiques_controle()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then
    if tg_op = 'INSERT' then new.masque_admin := false; new.owner := auth.uid();
    else new.masque_admin := old.masque_admin; new.owner := old.owner; end if;
  end if;
  new.updated_at := now();
  return new;
end $$;
drop trigger if exists boutiques_controle on public.boutiques;
create trigger boutiques_controle before insert or update on public.boutiques
  for each row execute function public.boutiques_controle();

-- 3. Produits ---------------------------------------------------------------
create table if not exists public.produits (
  id           uuid primary key default gen_random_uuid(),
  boutique_id  uuid not null references public.boutiques (id) on delete cascade,
  owner        uuid not null default auth.uid() references auth.users (id) on delete cascade,
  nom          text not null check (char_length(nom) between 2 and 120),
  description  text check (char_length(description) <= 3000),
  prix         numeric(14, 2) not null check (prix >= 0),
  devise       text not null check (devise in ('XOF', 'EUR', 'USD')),
  categorie    text check (char_length(categorie) <= 40),
  stock        integer check (stock >= 0),
  photos       text[] not null default '{}',
  visible      boolean not null default true,
  masque_admin boolean not null default false,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create index if not exists produits_boutique_idx on public.produits (boutique_id);
create index if not exists produits_recents_idx on public.produits (created_at desc);
alter table public.produits enable row level security;
grant select on table public.produits to anon, authenticated;
grant insert, update, delete on table public.produits to authenticated;

drop policy if exists "Public lit produits" on public.produits;
create policy "Public lit produits" on public.produits
  for select to anon using (
    visible and not masque_admin
    and exists (select 1 from public.boutiques b where b.id = boutique_id and b.visible and not b.masque_admin));
drop policy if exists "Connecte lit produits" on public.produits;
create policy "Connecte lit produits" on public.produits
  for select to authenticated using (
    owner = auth.uid() or public.is_admin()
    or (visible and not masque_admin
        and exists (select 1 from public.boutiques b where b.id = boutique_id and b.visible and not b.masque_admin)));
drop policy if exists "Vendeur ajoute produit" on public.produits;
create policy "Vendeur ajoute produit" on public.produits
  for insert to authenticated with check (owner = auth.uid());
drop policy if exists "Vendeur modifie produit" on public.produits;
create policy "Vendeur modifie produit" on public.produits
  for update to authenticated using (owner = auth.uid() or public.is_admin())
  with check (owner = auth.uid() or public.is_admin());
drop policy if exists "Vendeur supprime produit" on public.produits;
create policy "Vendeur supprime produit" on public.produits
  for delete to authenticated using (owner = auth.uid());

-- Contrôles : compte actif, bonne boutique, nombre de produits et de photos selon la formule
create or replace function public.produits_controle()
returns trigger language plpgsql security definer set search_path = public as $$
declare f text; lim integer; nb integer;
begin
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
drop trigger if exists produits_controle on public.produits;
create trigger produits_controle before insert or update on public.produits
  for each row execute function public.produits_controle();

-- 4. Photos des boutiques et produits : publiques, rangées par vendeur --------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('boutiques', 'boutiques', true, 3145728, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update set public = true, file_size_limit = 3145728,
  allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp'];
drop policy if exists "Vendeur depose photos" on storage.objects;
create policy "Vendeur depose photos" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'boutiques' and (storage.foldername(name))[1] = auth.uid()::text and public.vendeur_formule() is not null);
drop policy if exists "Vendeur gere ses photos" on storage.objects;
create policy "Vendeur gere ses photos" on storage.objects
  for select to authenticated
  using (bucket_id = 'boutiques' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "Vendeur supprime ses photos" on storage.objects;
create policy "Vendeur supprime ses photos" on storage.objects
  for delete to authenticated
  using (bucket_id = 'boutiques' and (storage.foldername(name))[1] = auth.uid()::text);
