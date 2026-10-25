-- =====================================================================
-- Yiriclick – base v5 : boutique personnalisable, produits à la une, statistiques
-- À coller dans Supabase > SQL Editor > New query, puis "Run".
-- Prérequis : scripts v2, v3 et v4 déjà exécutés. Peut être relancé sans risque.
-- =====================================================================

-- 1. Boutique : apparence, infos pratiques, réseaux, FAQ -----------------------
alter table public.boutiques add column if not exists slogan    text;
alter table public.boutiques add column if not exists theme     text not null default 'teal';
alter table public.boutiques add column if not exists sections  jsonb not null default '{"une": true, "promos": true, "nouveautes": true, "infos": true}'::jsonb;
alter table public.boutiques add column if not exists adresse   text;
alter table public.boutiques add column if not exists horaires  text;
alter table public.boutiques add column if not exists livraison text;
alter table public.boutiques add column if not exists retours   text;
alter table public.boutiques add column if not exists reseaux   jsonb not null default '{}'::jsonb;
alter table public.boutiques add column if not exists faq       jsonb not null default '[]'::jsonb;

alter table public.boutiques drop constraint if exists boutiques_v5_check;
alter table public.boutiques add constraint boutiques_v5_check check (
  (slogan is null or char_length(slogan) <= 120)
  and theme in ('teal', 'navy', 'orange', 'rouge', 'vert', 'violet', 'or', 'rose', 'noir')
  and jsonb_typeof(sections) = 'object'
  and (adresse is null or char_length(adresse) <= 200)
  and (horaires is null or char_length(horaires) <= 400)
  and (livraison is null or char_length(livraison) <= 800)
  and (retours is null or char_length(retours) <= 800)
  and jsonb_typeof(reseaux) = 'object' and char_length(reseaux::text) <= 1200
  and jsonb_typeof(faq) = 'array' and jsonb_array_length(faq) <= 10 and char_length(faq::text) <= 6000
);

-- 2. Produits mis « à la une » dans la boutique --------------------------------
alter table public.produits add column if not exists a_la_une boolean not null default false;

-- 3. Statistiques : événements anonymes (aucune donnée personnelle) ------------
create table if not exists public.evenements (
  id          bigint generated always as identity primary key,
  created_at  timestamptz not null default now(),
  boutique_id uuid not null references public.boutiques (id) on delete cascade,
  produit_id  uuid references public.produits (id) on delete set null,
  type        text not null check (type in ('vue_boutique', 'vue_produit', 'ajout_panier', 'favori', 'clic_whatsapp', 'commande_envoyee')),
  source      text check (source in ('vitrine', 'boutique'))
);
create index if not exists evenements_boutique_idx on public.evenements (boutique_id, created_at desc);
alter table public.evenements enable row level security;
grant insert on table public.evenements to anon, authenticated;
grant select on table public.evenements to authenticated;
drop policy if exists "Public ajoute evenement" on public.evenements;
create policy "Public ajoute evenement" on public.evenements
  for insert to anon, authenticated with check (true);
drop policy if exists "Vendeur lit ses evenements" on public.evenements;
create policy "Vendeur lit ses evenements" on public.evenements
  for select to authenticated using (
    public.is_admin() or exists (select 1 from public.boutiques b where b.id = boutique_id and b.owner = auth.uid()));

-- Chiffres agrégés pour l'espace vendeur : par jour, par type et par produit
create or replace function public.mes_stats(jours integer default 30)
returns table (jour date, type text, produit_id uuid, n bigint)
language sql stable security definer set search_path = public as $$
  select (e.created_at at time zone 'UTC')::date, e.type, e.produit_id, count(*)
  from public.evenements e
  join public.boutiques b on b.id = e.boutique_id and b.owner = auth.uid()
  where e.created_at >= now() - make_interval(days => least(greatest(jours, 1), 90))
  group by 1, 2, 3;
$$;
revoke all on function public.mes_stats(integer) from public;
grant execute on function public.mes_stats(integer) to authenticated;
