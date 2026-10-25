-- =====================================================================
-- Yiriclick – base v11 : vitrine rapide (recherche, filtres, tri et pages côté base)
-- La vitrine ne charge plus tous les produits d'un coup : elle demande seulement
-- la page affichée. Recherche sans tenir compte des accents ("karite" trouve "Karité").
-- À coller dans Supabase > SQL Editor > New query, puis "Run".
-- Prérequis : scripts v2 à v10 déjà exécutés. Peut être relancé sans risque.
-- =====================================================================

create extension if not exists unaccent with schema extensions;
create extension if not exists pg_trgm with schema extensions;

-- Texte comparable : minuscules, sans accents
create or replace function public.sans_accent(t text)
returns text language sql immutable parallel safe set search_path = public, extensions as $$
  select lower(extensions.unaccent('extensions.unaccent'::regdictionary, coalesce(t, '')));
$$;

-- Index pour une recherche rapide dans le nom et la description
create index if not exists produits_recherche_idx on public.produits
  using gin (public.sans_accent(nom || ' ' || coalesce(description, '')) extensions.gin_trgm_ops);
create index if not exists produits_categorie_idx on public.produits (categorie);

-- Taux de change pour comparer et trier des prix en monnaies différentes (1 EUR = x)
create table if not exists public.taux (
  devise   text primary key,
  par_eur  numeric(14, 6) not null check (par_eur > 0),
  maj      timestamptz not null default now()
);
insert into public.taux (devise, par_eur) values ('EUR', 1), ('XOF', 655.957), ('USD', 1.1193) on conflict (devise) do nothing;
alter table public.taux enable row level security;
grant select on table public.taux to anon, authenticated;
drop policy if exists "Public lit taux" on public.taux;
create policy "Public lit taux" on public.taux for select to anon, authenticated using (true);

-- Une fiche produit au format attendu par la vitrine
create or replace function public.vitrine_json(p public.produits, b public.boutiques)
returns jsonb language sql stable as $$
  select jsonb_build_object('id', p.id, 'boutique_id', p.boutique_id, 'nom', p.nom, 'description', p.description, 'prix', p.prix, 'prix_avant', p.prix_avant,
    'devise', p.devise, 'categorie', p.categorie, 'stock', p.stock, 'photos', p.photos, 'created_at', p.created_at, 'variantes', p.variantes,
    'solde_prix', p.solde_prix, 'solde_debut', p.solde_debut, 'solde_fin', p.solde_fin,
    'boutiques', jsonb_build_object('nom', b.nom, 'slug', b.slug, 'ville', b.ville, 'pays', b.pays, 'whatsapp', b.whatsapp, 'logo', b.logo));
$$;

-- Recherche de la vitrine
--  p_q        : mots cherchés (tous doivent être présents, accents ignorés)
--  p_qcats    : catégories dont le nom correspond aux mots (calculé par la page, dans la langue du visiteur)
--  p_cats     : catégories à garder ; p_pays : noms de pays acceptés (sans accents, minuscules)
--  p_min_eur / p_max_eur : fourchette de prix convertie en euros ; p_tri : new | asc | desc | promo
create or replace function public.vitrine_produits(
  p_q text default null, p_qcats text[] default null, p_cats text[] default null, p_promo boolean default false,
  p_pays text[] default null, p_stock boolean default false, p_min_eur numeric default null, p_max_eur numeric default null,
  p_tri text default 'new', p_limit integer default 24, p_offset integer default 0)
returns jsonb language sql stable security definer set search_path = public, extensions as $$
  with base as (
    select p, b,
      public.prix_du_moment(p.prix, p.solde_prix, p.solde_debut, p.solde_fin) as actuel,
      public.prix_du_moment(p.prix, p.solde_prix, p.solde_debut, p.solde_fin) / coalesce(tx.par_eur, 1) as eur,
      public.sans_accent(b.pays) as pays_n,
      public.sans_accent(p.nom || ' ' || coalesce(p.description, '')) as hay,
      public.sans_accent(b.nom || ' ' || coalesce(b.ville, '') || ' ' || coalesce(b.pays, '')) as hay_b
    from public.produits p
    join public.boutiques b on b.id = p.boutique_id and b.visible and not b.masque_admin
    left join public.taux tx on tx.devise = p.devise
    where p.visible and not p.masque_admin
      and (p_cats is null or p.categorie = any (p_cats))
      and (not coalesce(p_stock, false) or p.stock is null or p.stock > 0)
  ), f as (
    select *, case when greatest(coalesce((p).prix_avant, 0), (p).prix) > actuel then 1 - actuel / greatest(coalesce((p).prix_avant, 0), (p).prix) else 0 end as remise
    from base
    where (p_min_eur is null or eur >= p_min_eur) and (p_max_eur is null or eur <= p_max_eur)
      and (p_pays is null or exists (select 1 from unnest(p_pays) n where n = pays_n or n like pays_n || ' %' or pays_n like n || ' %'))
      and (p_q is null or trim(p_q) = '' or (p).categorie = any (coalesce(p_qcats, '{}'))
           or not exists (select 1 from unnest(string_to_array(public.sans_accent(trim(p_q)), ' ')) w
                          where w <> '' and position(w in hay) = 0 and position(w in hay_b) = 0))
  ), g as (
    select * from f where not coalesce(p_promo, false) or remise > 0
  )
  select jsonb_build_object(
    'total', (select count(*) from g),
    'items', coalesce((select jsonb_agg(public.vitrine_json((x).p, (x).b) order by x.rn) from (
        select g.*, row_number() over (order by
          case when p_tri = 'asc' then eur end asc nulls last,
          case when p_tri = 'desc' then eur end desc nulls last,
          case when p_tri = 'promo' then remise end desc nulls last,
          (p).created_at desc) as rn
        from g
        order by rn
        limit least(greatest(coalesce(p_limit, 24), 1), 60) offset greatest(coalesce(p_offset, 0), 0)) x), '[]'::jsonb));
$$;
grant execute on function public.vitrine_produits(text, text[], text[], boolean, text[], boolean, numeric, numeric, text, integer, integer) to anon, authenticated;

-- Chiffres de la vitrine : produits par catégorie, pays des vendeurs, boutiques à découvrir
create or replace function public.vitrine_stats()
returns jsonb language sql stable security definer set search_path = public as $$
  with v as (
    select p.categorie, b.id as bid, b.nom, b.slug, b.ville, b.pays, b.logo
    from public.produits p join public.boutiques b on b.id = p.boutique_id and b.visible and not b.masque_admin
    where p.visible and not p.masque_admin)
  select jsonb_build_object(
    'total', (select count(*) from v),
    'cats', coalesce((select jsonb_object_agg(categorie, n) from (select categorie, count(*) n from v where categorie is not null group by 1) c), '{}'::jsonb),
    'pays', coalesce((select jsonb_agg(pays order by pays) from (select distinct pays from v where pays is not null and pays <> '') d), '[]'::jsonb),
    'shops', coalesce((select jsonb_agg(jsonb_build_object('nom', nom, 'slug', slug, 'ville', ville, 'pays', pays, 'logo', logo, 'n', n) order by n desc) from (
        select nom, slug, ville, pays, logo, count(*) n from v group by bid, nom, slug, ville, pays, logo order by count(*) desc limit 16) s), '[]'::jsonb));
$$;
grant execute on function public.vitrine_stats() to anon, authenticated;

-- Suggestions pendant la frappe : 5 produits et 3 boutiques
create or replace function public.vitrine_suggest(p_q text)
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'produits', public.vitrine_produits(p_q := p_q, p_limit := 5) -> 'items',
    'boutiques', coalesce((select jsonb_agg(jsonb_build_object('nom', b.nom, 'slug', b.slug, 'ville', b.ville, 'pays', b.pays)) from (
        select b.* from public.boutiques b where b.visible and not b.masque_admin
          and position(public.sans_accent(trim(p_q)) in public.sans_accent(b.nom)) > 0 order by b.nom limit 3) b), '[]'::jsonb));
$$;
grant execute on function public.vitrine_suggest(text) to anon, authenticated;
