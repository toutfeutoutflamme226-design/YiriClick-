-- =====================================================================
-- Yiriclick – base v7 : soldes programmées, codes promo, avis clients
-- À coller dans Supabase > SQL Editor > New query, puis "Run".
-- Prérequis : scripts v2 à v6 déjà exécutés. Peut être relancé sans risque.
-- =====================================================================

-- 1. Soldes programmées --------------------------------------------------------
alter table public.produits add column if not exists solde_prix  numeric(14, 2);
alter table public.produits add column if not exists solde_debut timestamptz;
alter table public.produits add column if not exists solde_fin   timestamptz;

-- Prix à payer maintenant : le prix soldé pendant la période, sinon le prix normal
create or replace function public.prix_du_moment(prix numeric, solde numeric, debut timestamptz, fin timestamptz)
returns numeric language sql stable as $$
  select case when solde is not null and solde < prix and (debut is null or debut <= now()) and (fin is null or fin > now())
              then solde else prix end;
$$;
grant execute on function public.prix_du_moment(numeric, numeric, timestamptz, timestamptz) to anon, authenticated;

create or replace function public.produits_soldes()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.solde_prix is not null and (new.solde_prix < 0 or new.solde_prix >= new.prix) then
    raise exception 'Le prix soldé doit être plus bas que le prix normal.';
  end if;
  if new.solde_prix is null then new.solde_debut := null; new.solde_fin := null; end if;
  if new.solde_fin is not null and new.solde_debut is not null and new.solde_fin <= new.solde_debut then
    raise exception 'La fin des soldes doit être après le début.';
  end if;
  if new.solde_prix is not null and auth.uid() is not null and not public.is_admin()
     and (tg_op = 'INSERT' or new.solde_prix is distinct from old.solde_prix or new.solde_debut is distinct from old.solde_debut or new.solde_fin is distinct from old.solde_fin)
     and coalesce(public.vendeur_formule(), '') not in ('pro', 'entreprise') then
    raise exception 'Les soldes programmées sont disponibles avec les formules Pro et Entreprise.';
  end if;
  return new;
end $$;
drop trigger if exists produits_soldes on public.produits;
create trigger produits_soldes before insert or update on public.produits
  for each row execute function public.produits_soldes();

-- Contrôle des produits (version v6) : les actions faites depuis l'éditeur SQL ne sont plus bloquées
create or replace function public.produits_controle()
returns trigger language plpgsql security definer set search_path = public as $$
declare f text; lim integer; nb integer; o jsonb; total integer; c jsonb; complet boolean := true;
begin
  -- un prix barré n'a de sens que s'il est plus élevé que le prix actuel
  if new.prix_avant is not null and new.prix_avant <= new.prix then new.prix_avant := null; end if;
  -- variantes : forme, tailles limitées, stock total = somme des stocks par combinaison
  if new.variantes is null or jsonb_typeof(new.variantes) <> 'object' then new.variantes := '{}'::jsonb; end if;
  if public.a_variantes(new.variantes) then
    if jsonb_array_length(new.variantes -> 'options') > 2 then raise exception 'Deux options de variantes au maximum (ex. taille et couleur).'; end if;
    for o in select * from jsonb_array_elements(new.variantes -> 'options') loop
      if jsonb_typeof(o -> 'valeurs') <> 'array' or jsonb_array_length(o -> 'valeurs') not between 1 and 30
         or char_length(coalesce(o ->> 'nom', '')) not between 1 and 30 then
        raise exception 'Chaque option de variante doit avoir un nom et entre 1 et 30 valeurs.';
      end if;
    end loop;
    if jsonb_typeof(coalesce(new.variantes -> 'combis', '[]')) <> 'array' or jsonb_array_length(coalesce(new.variantes -> 'combis', '[]')) > 200
       or char_length(new.variantes::text) > 20000 then
      raise exception 'Trop de combinaisons de variantes.';
    end if;
    total := 0;
    for c in select * from jsonb_array_elements(coalesce(new.variantes -> 'combis', '[]')) loop
      if jsonb_typeof(c -> 'stock') = 'number' then total := total + greatest((c ->> 'stock')::integer, 0); else complet := false; end if;
    end loop;
    if complet and jsonb_array_length(coalesce(new.variantes -> 'combis', '[]')) > 0 then new.stock := total; end if;
  end if;

  -- appel sans utilisateur connecté (éditeur SQL de Supabase, fonctions internes) : pas de contrôle vendeur
  if auth.uid() is null then
    new.updated_at := now();
    return new;
  end if;
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
  if public.a_variantes(new.variantes) and f not in ('pro', 'entreprise')
     and (tg_op = 'INSERT' or (new.variantes -> 'options') is distinct from (old.variantes -> 'options')) then
    raise exception 'Les variantes (tailles, couleurs) sont disponibles avec les formules Pro et Entreprise.';
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

-- 2. Codes promo (gérés par le vendeur, jamais lisibles par le public) -----------
create table if not exists public.codes_promo (
  id               uuid primary key default gen_random_uuid(),
  created_at       timestamptz not null default now(),
  boutique_id      uuid not null references public.boutiques (id) on delete cascade,
  code             text not null check (code ~ '^[A-Z0-9-]{3,20}$'),
  type             text not null check (type in ('pct', 'montant')),
  valeur           numeric(14, 2) not null check (valeur > 0),
  min_achat        numeric(14, 2) not null default 0 check (min_achat >= 0),
  debut            timestamptz,
  fin              timestamptz,
  max_utilisations integer check (max_utilisations is null or max_utilisations > 0),
  utilisations     integer not null default 0,
  actif            boolean not null default true,
  unique (boutique_id, code),
  check (type <> 'pct' or valeur <= 90)
);
alter table public.codes_promo enable row level security;
revoke all on table public.codes_promo from anon;
grant select, delete on table public.codes_promo to authenticated;
-- le compteur d'utilisations n'est modifiable que par la commande elle-même
grant insert (boutique_id, code, type, valeur, min_achat, debut, fin, max_utilisations, actif) on table public.codes_promo to authenticated;
grant update (code, type, valeur, min_achat, debut, fin, max_utilisations, actif) on table public.codes_promo to authenticated;
drop policy if exists "Vendeur gere ses codes" on public.codes_promo;
create policy "Vendeur gere ses codes" on public.codes_promo
  for all to authenticated
  using (public.is_admin() or exists (select 1 from public.boutiques b where b.id = boutique_id and b.owner = auth.uid()))
  with check (exists (select 1 from public.boutiques b where b.id = boutique_id and b.owner = auth.uid())
              and public.vendeur_formule() in ('pro', 'entreprise'));

create or replace function public.codes_promo_controle()
returns trigger language plpgsql as $$
begin
  new.code := upper(trim(new.code));
  return new;
end $$;
drop trigger if exists codes_promo_controle on public.codes_promo;
create trigger codes_promo_controle before insert or update on public.codes_promo
  for each row execute function public.codes_promo_controle();

-- Le client vérifie un code avant de commander (réponse : la remise, ou rien)
create or replace function public.verifier_code(p_boutique uuid, p_code text)
returns table (code text, type text, valeur numeric, min_achat numeric)
language sql stable security definer set search_path = public as $$
  select c.code, c.type, c.valeur, c.min_achat from public.codes_promo c
  where c.boutique_id = p_boutique and c.code = upper(trim(p_code)) and c.actif
    and (c.debut is null or c.debut <= now()) and (c.fin is null or c.fin > now())
    and (c.max_utilisations is null or c.utilisations < c.max_utilisations);
$$;
revoke all on function public.verifier_code(uuid, text) from public;
grant execute on function public.verifier_code(uuid, text) to anon, authenticated;

-- 3. Commandes : remise et code utilisé ---------------------------------------
alter table public.commandes add column if not exists sous_total numeric(14, 2);
alter table public.commandes add column if not exists remise     numeric(14, 2) not null default 0;
alter table public.commandes add column if not exists code_promo text;

drop function if exists public.passer_commande(uuid, text, text, text, text, jsonb, text);
create or replace function public.passer_commande(p_boutique uuid, p_nom text, p_tel text, p_adresse text, p_note text, p_articles jsonb, p_langue text default 'fr', p_code text default null)
returns table (id uuid, numero text, total numeric, remise numeric)
language plpgsql security definer set search_path = public as $$
declare a jsonb; p record; c jsonb; q integer; prix numeric; base numeric; dispo integer; lignes jsonb := '[]'; tot numeric := 0; dev text; mixte boolean := false;
        num text; nid uuid; cp record; rem numeric := 0; code_ok text;
begin
  if not exists (select 1 from public.boutiques b where b.id = p_boutique and b.visible and not b.masque_admin) then
    raise exception 'Cette boutique n''accepte pas de commande pour le moment.';
  end if;
  if jsonb_typeof(p_articles) <> 'array' or jsonb_array_length(p_articles) not between 1 and 50 then
    raise exception 'Le panier est vide ou trop grand.';
  end if;
  if (select count(*) from public.commandes x where x.client_tel = trim(p_tel) and x.created_at > now() - interval '1 hour') >= 6 then
    raise exception 'Trop de commandes en peu de temps. Réessaie dans une heure.';
  end if;
  for a in select * from jsonb_array_elements(p_articles) loop
    q := (a ->> 'qty')::integer;
    if q is null or q < 1 or q > 99 then raise exception 'Quantité invalide.'; end if;
    select pr.id, pr.nom, pr.prix, pr.devise, pr.stock, pr.variantes, pr.solde_prix, pr.solde_debut, pr.solde_fin into p from public.produits pr
      where pr.id = (a ->> 'id')::uuid and pr.boutique_id = p_boutique and pr.visible and not pr.masque_admin;
    if not found then raise exception 'Un produit n''est plus disponible.'; end if;
    base := p.prix; dispo := p.stock; c := null;
    if public.a_variantes(p.variantes) then
      if jsonb_typeof(a -> 'v') <> 'array' or jsonb_array_length(a -> 'v') <> jsonb_array_length(p.variantes -> 'options') then
        raise exception 'Choisis la variante de « % ».', p.nom;
      end if;
      select x into c from jsonb_array_elements(coalesce(p.variantes -> 'combis', '[]')) x where x -> 'v' = a -> 'v' limit 1;
      if c is null and jsonb_array_length(coalesce(p.variantes -> 'combis', '[]')) > 0 then raise exception 'Variante indisponible pour « % ».', p.nom; end if;
      if c is not null then
        if jsonb_typeof(c -> 'prix') = 'number' then base := (c ->> 'prix')::numeric; end if;
        dispo := case when jsonb_typeof(c -> 'stock') = 'number' then (c ->> 'stock')::integer else null end;
      end if;
    end if;
    -- soldes : même pourcentage appliqué au prix de la variante
    prix := round(base * public.prix_du_moment(p.prix, p.solde_prix, p.solde_debut, p.solde_fin) / nullif(p.prix, 0), 2);
    if prix is null then prix := base; end if;
    if dispo is not null and q > dispo then raise exception 'Stock insuffisant pour « % » (% disponible).', p.nom, dispo; end if;
    if dev is null then dev := p.devise; elsif dev <> p.devise then mixte := true; end if;
    tot := tot + prix * q;
    lignes := lignes || jsonb_build_array(jsonb_build_object('produit_id', p.id, 'nom', p.nom, 'v', case when public.a_variantes(p.variantes) then a -> 'v' else null end,
      'qty', q, 'prix', prix, 'devise', p.devise));
  end loop;
  if nullif(trim(coalesce(p_code, '')), '') is not null then
    select * into cp from public.codes_promo k
      where k.boutique_id = p_boutique and k.code = upper(trim(p_code)) and k.actif
        and (k.debut is null or k.debut <= now()) and (k.fin is null or k.fin > now())
        and (k.max_utilisations is null or k.utilisations < k.max_utilisations)
      for update;
    if not found then raise exception 'Ce code promo n''est pas valable.'; end if;
    if mixte and cp.type = 'montant' then raise exception 'Ce code ne s''applique pas à un panier en plusieurs monnaies.'; end if;
    if tot < cp.min_achat then raise exception 'Ce code demande un achat minimum de %.', cp.min_achat; end if;
    rem := case when cp.type = 'pct' then round(tot * cp.valeur / 100, 2) else least(cp.valeur, tot) end;
    update public.codes_promo set utilisations = utilisations + 1 where codes_promo.id = cp.id;
    code_ok := cp.code;
  end if;
  loop
    num := 'YC-' || upper(substr(md5(random()::text || clock_timestamp()::text), 1, 6));
    exit when not exists (select 1 from public.commandes x where x.numero = num);
  end loop;
  insert into public.commandes (numero, boutique_id, client_nom, client_tel, client_adresse, client_note, articles, sous_total, remise, code_promo, total, devise, langue)
  values (num, p_boutique, trim(p_nom), trim(p_tel), trim(p_adresse), nullif(trim(coalesce(p_note, '')), ''), lignes,
          case when mixte then null else tot end, rem, code_ok,
          case when mixte then null else tot - rem end, case when mixte then null else dev end, left(coalesce(p_langue, 'fr'), 5))
  returning commandes.id into nid;
  insert into public.evenements (boutique_id, type, source) values (p_boutique, 'commande_envoyee', null);
  return query select nid, num, case when mixte then null else tot - rem end, rem;
end $$;
revoke all on function public.passer_commande(uuid, text, text, text, text, jsonb, text, text) from public;
grant execute on function public.passer_commande(uuid, text, text, text, text, jsonb, text, text) to anon, authenticated;

-- 4. Avis clients : seulement après une commande livrée, un avis par commande ---
create table if not exists public.avis (
  id           uuid primary key default gen_random_uuid(),
  created_at   timestamptz not null default now(),
  boutique_id  uuid not null references public.boutiques (id) on delete cascade,
  commande_id  uuid not null unique references public.commandes (id) on delete cascade,
  note         integer not null check (note between 1 and 5),
  commentaire  text check (char_length(commentaire) <= 1000),
  nom          text not null,
  reponse      text check (char_length(reponse) <= 1000),
  reponse_at   timestamptz,
  signale      boolean not null default false,
  masque       boolean not null default false
);
create index if not exists avis_boutique_idx on public.avis (boutique_id, created_at desc);
alter table public.avis enable row level security;
grant select on table public.avis to anon, authenticated;
grant update on table public.avis to authenticated;
drop policy if exists "Public lit avis" on public.avis;
create policy "Public lit avis" on public.avis for select to anon, authenticated using (
  not masque or public.is_admin() or exists (select 1 from public.boutiques b where b.id = boutique_id and b.owner = auth.uid()));
drop policy if exists "Vendeur repond avis" on public.avis;
create policy "Vendeur repond avis" on public.avis for update to authenticated
  using (public.is_admin() or exists (select 1 from public.boutiques b where b.id = boutique_id and b.owner = auth.uid()))
  with check (public.is_admin() or exists (select 1 from public.boutiques b where b.id = boutique_id and b.owner = auth.uid()));

-- Le vendeur peut seulement répondre ou signaler ; l'admin peut masquer
create or replace function public.avis_controle()
returns trigger language plpgsql security definer set search_path = public as $$
declare rep text := new.reponse; sig boolean := new.signale; mas boolean := new.masque;
begin
  new := old;
  new.signale := sig;
  if rep is distinct from old.reponse then new.reponse := nullif(trim(coalesce(rep, '')), ''); new.reponse_at := now(); end if;
  if public.is_admin() then new.masque := mas; end if;
  return new;
end $$;
drop trigger if exists avis_controle on public.avis;
create trigger avis_controle before update on public.avis
  for each row execute function public.avis_controle();

create or replace function public.laisser_avis(p_commande uuid, p_note integer, p_commentaire text)
returns void language plpgsql security definer set search_path = public as $$
declare c record; n text;
begin
  select * into c from public.commandes where id = p_commande;
  if not found then raise exception 'Commande introuvable.'; end if;
  if c.statut <> 'livree' then raise exception 'Tu pourras donner ton avis une fois la commande livrée.'; end if;
  if exists (select 1 from public.avis where commande_id = p_commande) then raise exception 'Tu as déjà donné ton avis pour cette commande.'; end if;
  if p_note is null or p_note not between 1 and 5 then raise exception 'Choisis une note de 1 à 5 étoiles.'; end if;
  -- prénom + initiale du nom, pour la discrétion
  n := split_part(trim(c.client_nom), ' ', 1);
  if split_part(trim(c.client_nom), ' ', 2) <> '' then n := n || ' ' || upper(left(split_part(trim(c.client_nom), ' ', 2), 1)) || '.'; end if;
  insert into public.avis (boutique_id, commande_id, note, commentaire, nom)
  values (c.boutique_id, c.id, p_note, nullif(left(trim(coalesce(p_commentaire, '')), 1000), ''), left(n, 40));
end $$;
revoke all on function public.laisser_avis(uuid, integer, text) from public;
grant execute on function public.laisser_avis(uuid, integer, text) to anon, authenticated;

-- Suivi des commandes par le client : statut et avis déjà donné ou non
drop function if exists public.suivi_commandes(uuid[]);
create or replace function public.suivi_commandes(ids uuid[])
returns table (id uuid, numero text, statut text, updated_at timestamptz, a_avis boolean)
language sql stable security definer set search_path = public as $$
  select c.id, c.numero, c.statut, c.updated_at, exists (select 1 from public.avis v where v.commande_id = c.id)
  from public.commandes c where c.id = any (ids[1:20]);
$$;
revoke all on function public.suivi_commandes(uuid[]) from public;
grant execute on function public.suivi_commandes(uuid[]) to anon, authenticated;
