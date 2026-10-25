-- =====================================================================
-- Yiriclick – base v4 : promotions de la vitrine et prix barrés
-- À coller dans Supabase > SQL Editor > New query, puis "Run".
-- Prérequis : scripts v2 et v3 déjà exécutés. Peut être relancé sans risque.
-- =====================================================================

-- 1. Prix avant réduction (prix barré) ---------------------------------------
alter table public.produits add column if not exists prix_avant numeric(14, 2);
alter table public.produits drop constraint if exists produits_prix_avant_check;
alter table public.produits add constraint produits_prix_avant_check check (prix_avant is null or prix_avant >= 0);

create or replace function public.produits_controle()
returns trigger language plpgsql security definer set search_path = public as $$
declare f text; lim integer; nb integer;
begin
  -- un prix barré n'a de sens que s'il est plus élevé que le prix actuel
  if new.prix_avant is not null and new.prix_avant <= new.prix then new.prix_avant := null; end if;
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

-- 2. Promotions de la vitrine (gérées uniquement par l'admin) ----------------
create table if not exists public.promotions (
  id          uuid primary key default gen_random_uuid(),
  created_at  timestamptz not null default now(),
  type        text not null check (type in ('banniere', 'tuile', 'offre_jour')),
  titre       text not null check (char_length(titre) between 1 and 80),
  sous_titre  text check (char_length(sous_titre) <= 140),
  image       text,
  lien        text check (char_length(lien) <= 300),
  couleur     text not null default 'teal' check (couleur in ('navy', 'teal', 'orange', 'sand', 'mint', 'rose')),
  produit_id  uuid references public.produits (id) on delete cascade,
  fin         timestamptz,
  ordre       integer not null default 0,
  actif       boolean not null default true
);
alter table public.promotions enable row level security;
grant select on table public.promotions to anon, authenticated;
grant insert, update, delete on table public.promotions to authenticated;
drop policy if exists "Public lit promotions" on public.promotions;
create policy "Public lit promotions" on public.promotions
  for select to anon, authenticated using ((actif and (fin is null or fin > now())) or public.is_admin());
drop policy if exists "Admin ajoute promotions" on public.promotions;
create policy "Admin ajoute promotions" on public.promotions
  for insert to authenticated with check (public.is_admin());
drop policy if exists "Admin modifie promotions" on public.promotions;
create policy "Admin modifie promotions" on public.promotions
  for update to authenticated using (public.is_admin()) with check (public.is_admin());
drop policy if exists "Admin supprime promotions" on public.promotions;
create policy "Admin supprime promotions" on public.promotions
  for delete to authenticated using (public.is_admin());

-- 3. Images des promotions : publiques, déposées par l'admin seulement --------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('promos', 'promos', true, 3145728, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update set public = true, file_size_limit = 3145728,
  allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp'];
drop policy if exists "Admin depose promos" on storage.objects;
create policy "Admin depose promos" on storage.objects
  for insert to authenticated with check (bucket_id = 'promos' and public.is_admin());
drop policy if exists "Admin gere promos" on storage.objects;
create policy "Admin gere promos" on storage.objects
  for select to authenticated using (bucket_id = 'promos' and public.is_admin());
drop policy if exists "Admin supprime promos" on storage.objects;
create policy "Admin supprime promos" on storage.objects
  for delete to authenticated using (bucket_id = 'promos' and public.is_admin());
