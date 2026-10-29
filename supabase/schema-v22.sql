-- =====================================================================
-- Yiriclick – base v22 : promotions honnêtes et suivi des vendeurs fondateurs
-- À coller dans Supabase > SQL Editor > New query, puis "Run". Prérequis : v21. Peut être relancé sans risque.
--  1. Promotions honnêtes (règle européenne « Omnibus ») : le prix barré affiché ne peut pas être plus haut
--     que le prix le plus bas pratiqué pendant les 30 derniers jours. Sinon il est corrigé automatiquement.
--     Les promotions déjà en place restent affichées tant que le vendeur ne change pas ses prix.
--  2. Fondateurs : date d'entrée dans le Club enregistrée, date de lancement officiel réglable dans l'admin,
--     fin des 4 mois offerts calculée automatiquement.
-- =====================================================================

-- 1. Historique des prix ------------------------------------------------------
create table if not exists public.produits_prix (
  produit_id uuid not null references public.produits(id) on delete cascade,
  prix       numeric(14, 2) not null,
  le         timestamptz not null default now()
);
create index if not exists produits_prix_idx on public.produits_prix (produit_id, le desc);
alter table public.produits_prix enable row level security;   -- aucune lecture publique : sert seulement au contrôle

-- Point de départ : le prix actuel de chaque produit. Les promotions déjà affichées restent telles quelles
-- tant que le vendeur ne modifie pas son prix ou son prix barré.
insert into public.produits_prix (produit_id, prix, le)
select p.id, p.prix, now()
from public.produits p
where not exists (select 1 from public.produits_prix h where h.produit_id = p.id);

create or replace function public.produits_prix_honnete()
returns trigger language plpgsql security definer set search_path = public as $$
declare plus_bas numeric;
begin
  if new.prix_avant is null then return new; end if;
  if tg_op = 'UPDATE' and new.prix_avant is not distinct from old.prix_avant and new.prix is not distinct from old.prix then
    return new;  -- rien ne change côté prix : on ne revérifie pas
  end if;
  select min(h.prix) into plus_bas from public.produits_prix h
  where h.produit_id = new.id and h.le > now() - interval '30 days';
  if tg_op = 'UPDATE' and old.prix is not null then plus_bas := least(coalesce(plus_bas, old.prix), old.prix); end if;
  if plus_bas is null then
    new.prix_avant := null;                       -- nouveau produit : pas encore d'ancien prix réel
  elsif new.prix_avant > plus_bas then
    new.prix_avant := plus_bas;                   -- prix barré ramené au plus bas des 30 derniers jours
  end if;
  if new.prix_avant is not null and new.prix_avant <= new.prix then new.prix_avant := null; end if;
  return new;
end $$;
drop trigger if exists produits_prix_honnete on public.produits;
create trigger produits_prix_honnete before insert or update on public.produits
  for each row execute function public.produits_prix_honnete();

create or replace function public.produits_prix_journal()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' or new.prix is distinct from old.prix then
    insert into public.produits_prix (produit_id, prix) values (new.id, new.prix);
  end if;
  return null;
end $$;
drop trigger if exists produits_prix_journal on public.produits;
create trigger produits_prix_journal after insert or update of prix on public.produits
  for each row execute function public.produits_prix_journal();

-- Ménage : historique gardé 60 jours (assez pour la règle des 30 jours)
create or replace function public.produits_prix_menage()
returns void language sql security definer set search_path = public as $$
  delete from public.produits_prix h
  where h.le < now() - interval '60 days'
    and exists (select 1 from public.produits_prix r where r.produit_id = h.produit_id and r.le > h.le);
$$;
revoke all on function public.produits_prix_menage() from public, anon, authenticated;
do $$ begin
  if to_regclass('cron.job') is not null then
    perform cron.schedule('yiriclick-prix-menage', '17 3 * * 0', 'select public.produits_prix_menage()');
  end if;
end $$;

-- 2. Suivi des fondateurs -------------------------------------------------------
alter table public.boutiques add column if not exists fondateur_le timestamptz;
update public.boutiques set fondateur_le = coalesce(fondateur_le, now()) where fondateur and fondateur_le is null;

create or replace function public.boutiques_fondateur_le()
returns trigger language plpgsql as $$
begin
  if new.fondateur and (tg_op = 'INSERT' or not old.fondateur) then new.fondateur_le := now(); end if;
  if not new.fondateur then new.fondateur_le := null; end if;
  return new;
end $$;
drop trigger if exists boutiques_fondateur_le on public.boutiques;
create trigger boutiques_fondateur_le before insert or update of fondateur on public.boutiques
  for each row execute function public.boutiques_fondateur_le();

create table if not exists public.reglages_site (
  id          integer primary key default 1 check (id = 1),
  lancement   date            -- date du lancement officiel (début des 4 mois offerts aux fondateurs)
);
insert into public.reglages_site (id) values (1) on conflict (id) do nothing;
alter table public.reglages_site enable row level security;
grant select, update on table public.reglages_site to authenticated;
drop policy if exists "Admin lit reglages site" on public.reglages_site;
create policy "Admin lit reglages site" on public.reglages_site for select to authenticated using (public.is_admin());
drop policy if exists "Admin modifie reglages site" on public.reglages_site;
create policy "Admin modifie reglages site" on public.reglages_site for update to authenticated using (public.is_admin()) with check (public.is_admin());

insert into public.versions_base (version) values ('v22') on conflict (version) do nothing;
