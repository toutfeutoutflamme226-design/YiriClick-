-- =====================================================================
-- Yiriclick – base v20 : partenaires (sponsors) et Club des 50 vendeurs fondateurs
-- À coller dans Supabase > SQL Editor > New query, puis "Run". Prérequis : v19. Peut être relancé sans risque.
--  1. Partenaires : gérés dans l'admin (logo, lien, texte, dates, emplacement), affichés sur l'accueil,
--     avec un compteur d'affichages et de clics par jour (aucune donnée personnelle).
--  2. Fondateurs : l'admin coche « fondateur » sur une boutique ; le site affiche les places restantes
--     sur 50 et un badge « Fondateur » sur la boutique.
-- =====================================================================

-- 1. Partenaires ----------------------------------------------------------
create table if not exists public.partenaires (
  id          uuid primary key default gen_random_uuid(),
  created_at  timestamptz not null default now(),
  nom         text not null check (char_length(nom) between 1 and 80),
  texte       text check (char_length(texte) <= 200),
  lien        text check (lien is null or lien ~ '^https://'),
  logo        text check (char_length(logo) <= 300),       -- chemin dans l'espace « partenaires »
  affiche     text check (char_length(affiche) <= 300),    -- grande image (emplacement « principal »)
  emplacement text not null default 'bande' check (emplacement in ('principal', 'bande')),
  debut       date,
  fin         date,
  actif       boolean not null default true,
  ordre       integer not null default 0
);
alter table public.partenaires enable row level security;
grant select on table public.partenaires to anon, authenticated;
grant insert, update, delete on table public.partenaires to authenticated;
drop policy if exists "Public voit partenaires en cours" on public.partenaires;
create policy "Public voit partenaires en cours" on public.partenaires for select to anon, authenticated
  using (actif and (debut is null or debut <= current_date) and (fin is null or fin >= current_date) or public.is_admin());
drop policy if exists "Admin gere partenaires" on public.partenaires;
create policy "Admin gere partenaires" on public.partenaires for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

create table if not exists public.partenaires_stats (
  partenaire uuid not null references public.partenaires(id) on delete cascade,
  jour       date not null default current_date,
  vues       integer not null default 0,
  clics      integer not null default 0,
  primary key (partenaire, jour)
);
alter table public.partenaires_stats enable row level security;
grant select on table public.partenaires_stats to authenticated;
drop policy if exists "Admin lit stats partenaires" on public.partenaires_stats;
create policy "Admin lit stats partenaires" on public.partenaires_stats for select to authenticated using (public.is_admin());

-- Compte un affichage ou un clic (appelé par le site ; limité pour éviter les abus)
create or replace function public.partenaire_compter(p_id uuid, p_type text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if p_type not in ('vue', 'clic') then return; end if;
  if not exists (select 1 from public.partenaires where id = p_id and actif) then return; end if;
  insert into public.partenaires_stats (partenaire, jour, vues, clics)
  values (p_id, current_date, case when p_type = 'vue' then 1 else 0 end, case when p_type = 'clic' then 1 else 0 end)
  on conflict (partenaire, jour) do update
    set vues = least(public.partenaires_stats.vues + excluded.vues, 1000000),
        clics = least(public.partenaires_stats.clics + excluded.clics, 1000000);
end $$;
revoke all on function public.partenaire_compter(uuid, text) from public;
grant execute on function public.partenaire_compter(uuid, text) to anon, authenticated;

-- Espace public pour les logos et affiches ; seul l'admin dépose
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('partenaires', 'partenaires', true, 3145728, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update set public = true, file_size_limit = 3145728, allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp'];
drop policy if exists "Admin depose partenaires" on storage.objects;
create policy "Admin depose partenaires" on storage.objects for insert to authenticated
  with check (bucket_id = 'partenaires' and public.is_admin());
drop policy if exists "Admin modifie partenaires" on storage.objects;
create policy "Admin modifie partenaires" on storage.objects for update to authenticated
  using (bucket_id = 'partenaires' and public.is_admin());
drop policy if exists "Admin supprime partenaires" on storage.objects;
create policy "Admin supprime partenaires" on storage.objects for delete to authenticated
  using (bucket_id = 'partenaires' and public.is_admin());

-- 2. Club des 50 fondateurs ------------------------------------------------
alter table public.boutiques add column if not exists fondateur boolean not null default false;

-- Seul l'admin peut cocher ou décocher « fondateur » (un vendeur ne peut pas se l'attribuer)
create or replace function public.boutiques_fondateur()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    if not public.is_admin() then new.fondateur := false; end if;
  elsif new.fondateur is distinct from old.fondateur and not public.is_admin() then
    new.fondateur := old.fondateur;
  end if;
  if new.fondateur and (tg_op = 'INSERT' or not old.fondateur)
     and (select count(*) from public.boutiques where fondateur) >= 50 then
    raise exception 'Les 50 places de vendeurs fondateurs sont déjà prises.';
  end if;
  return new;
end $$;
drop trigger if exists boutiques_fondateur on public.boutiques;
create trigger boutiques_fondateur before insert or update on public.boutiques
  for each row execute function public.boutiques_fondateur();

create or replace function public.fondateurs_places()
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object('total', 50, 'prises', (select count(*) from public.boutiques where fondateur));
$$;
revoke all on function public.fondateurs_places() from public;
grant execute on function public.fondateurs_places() to anon, authenticated;

insert into public.versions_base (version) values ('v20') on conflict (version) do nothing;
