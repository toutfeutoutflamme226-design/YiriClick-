-- =====================================================================
-- Yiriclick – base v6 : commandes enregistrées, suivi client, variantes
-- À coller dans Supabase > SQL Editor > New query, puis "Run".
-- Prérequis : scripts v2 à v5 déjà exécutés. Peut être relancé sans risque.
-- =====================================================================

-- 1. Variantes des produits (tailles, couleurs…) ----------------------------
-- Format : {"options": [{"nom": "Taille", "valeurs": ["S", "M"]}, ...],
--           "combis":  [{"v": ["S"], "stock": 3, "prix": null}, ...]}
alter table public.produits add column if not exists variantes jsonb not null default '{}'::jsonb;

create or replace function public.a_variantes(v jsonb)
returns boolean language sql immutable as $$
  select coalesce(jsonb_typeof(v -> 'options') = 'array' and jsonb_array_length(v -> 'options') > 0, false);
$$;

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

-- 2. Commandes ---------------------------------------------------------------
create table if not exists public.commandes (
  id            uuid primary key default gen_random_uuid(),
  numero        text not null unique,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  boutique_id   uuid not null references public.boutiques (id) on delete cascade,
  client_nom    text not null check (char_length(client_nom) between 2 and 80),
  client_tel    text not null check (char_length(client_tel) between 8 and 25),
  client_adresse text not null check (char_length(client_adresse) between 3 and 300),
  client_note   text check (char_length(client_note) <= 600),
  articles      jsonb not null,
  total         numeric(14, 2),
  devise        text,
  statut        text not null default 'nouvelle' check (statut in ('nouvelle', 'confirmee', 'expediee', 'livree', 'annulee')),
  note_vendeur  text check (char_length(note_vendeur) <= 1000),
  langue        text,
  stock_retire  boolean not null default false
);
create index if not exists commandes_boutique_idx on public.commandes (boutique_id, created_at desc);
create index if not exists commandes_tel_idx on public.commandes (client_tel, created_at desc);
alter table public.commandes enable row level security;
revoke all on table public.commandes from anon;
grant select, update on table public.commandes to authenticated;
drop policy if exists "Vendeur lit ses commandes" on public.commandes;
create policy "Vendeur lit ses commandes" on public.commandes
  for select to authenticated using (
    public.is_admin() or exists (select 1 from public.boutiques b where b.id = boutique_id and b.owner = auth.uid()));
drop policy if exists "Vendeur suit ses commandes" on public.commandes;
create policy "Vendeur suit ses commandes" on public.commandes
  for update to authenticated
  using (public.is_admin() or exists (select 1 from public.boutiques b where b.id = boutique_id and b.owner = auth.uid()))
  with check (public.is_admin() or exists (select 1 from public.boutiques b where b.id = boutique_id and b.owner = auth.uid()));

-- Retire ou remet le stock des articles d'une commande (sens = -1 retire, +1 remet)
create or replace function public.commande_stock(arts jsonb, sens integer)
returns void language plpgsql security definer set search_path = public as $$
declare a jsonb; p record; i integer; cs jsonb;
begin
  for a in select * from jsonb_array_elements(arts) loop
    select id, stock, variantes into p from public.produits where id = (a ->> 'produit_id')::uuid for update;
    if not found then continue; end if;
    if public.a_variantes(p.variantes) and jsonb_typeof(a -> 'v') = 'array' then
      cs := coalesce(p.variantes -> 'combis', '[]');
      for i in 0 .. jsonb_array_length(cs) - 1 loop
        if cs -> i -> 'v' = a -> 'v' and jsonb_typeof(cs -> i -> 'stock') = 'number' then
          cs := jsonb_set(cs, array[i::text, 'stock'], to_jsonb(greatest(0, (cs -> i ->> 'stock')::integer + sens * (a ->> 'qty')::integer)));
        end if;
      end loop;
      update public.produits set variantes = jsonb_set(p.variantes, '{combis}', cs) where id = p.id;
    elsif p.stock is not null then
      update public.produits set stock = greatest(0, p.stock + sens * (a ->> 'qty')::integer) where id = p.id;
    end if;
  end loop;
end $$;
revoke all on function public.commande_stock(jsonb, integer) from public, anon, authenticated;

-- Le vendeur ne change que le statut et sa note ; le stock suit le statut
create or replace function public.commandes_controle()
returns trigger language plpgsql security definer set search_path = public as $$
declare garde text := new.statut; note text := new.note_vendeur;
begin
  if not public.is_admin() then new := old; new.statut := garde; new.note_vendeur := note; end if;
  if new.statut in ('confirmee', 'expediee', 'livree') and not old.stock_retire then
    perform public.commande_stock(new.articles, -1); new.stock_retire := true;
  elsif new.statut in ('nouvelle', 'annulee') and old.stock_retire then
    perform public.commande_stock(new.articles, 1); new.stock_retire := false;
  end if;
  new.updated_at := now();
  return new;
end $$;
drop trigger if exists commandes_controle on public.commandes;
create trigger commandes_controle before update on public.commandes
  for each row execute function public.commandes_controle();

-- 3. Passer commande (visiteurs) : prix et stock vérifiés dans la base --------
create or replace function public.passer_commande(p_boutique uuid, p_nom text, p_tel text, p_adresse text, p_note text, p_articles jsonb, p_langue text default 'fr')
returns table (id uuid, numero text)
language plpgsql security definer set search_path = public as $$
declare a jsonb; p record; c jsonb; q integer; prix numeric; dispo integer; lignes jsonb := '[]'; tot numeric := 0; dev text; mixte boolean := false; num text; nid uuid;
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
    select pr.id, pr.nom, pr.prix, pr.devise, pr.stock, pr.variantes into p from public.produits pr
      where pr.id = (a ->> 'id')::uuid and pr.boutique_id = p_boutique and pr.visible and not pr.masque_admin;
    if not found then raise exception 'Un produit n''est plus disponible.'; end if;
    prix := p.prix; dispo := p.stock; c := null;
    if public.a_variantes(p.variantes) then
      if jsonb_typeof(a -> 'v') <> 'array' or jsonb_array_length(a -> 'v') <> jsonb_array_length(p.variantes -> 'options') then
        raise exception 'Choisis la variante de « % ».', p.nom;
      end if;
      select x into c from jsonb_array_elements(coalesce(p.variantes -> 'combis', '[]')) x where x -> 'v' = a -> 'v' limit 1;
      if c is null and jsonb_array_length(coalesce(p.variantes -> 'combis', '[]')) > 0 then raise exception 'Variante indisponible pour « % ».', p.nom; end if;
      if c is not null then
        if jsonb_typeof(c -> 'prix') = 'number' then prix := (c ->> 'prix')::numeric; end if;
        dispo := case when jsonb_typeof(c -> 'stock') = 'number' then (c ->> 'stock')::integer else null end;
      end if;
    end if;
    if dispo is not null and q > dispo then raise exception 'Stock insuffisant pour « % » (% disponible).', p.nom, dispo; end if;
    if dev is null then dev := p.devise; elsif dev <> p.devise then mixte := true; end if;
    tot := tot + prix * q;
    lignes := lignes || jsonb_build_array(jsonb_build_object('produit_id', p.id, 'nom', p.nom, 'v', case when public.a_variantes(p.variantes) then a -> 'v' else null end,
      'qty', q, 'prix', prix, 'devise', p.devise));
  end loop;
  loop
    num := 'YC-' || upper(substr(md5(random()::text || clock_timestamp()::text), 1, 6));
    exit when not exists (select 1 from public.commandes x where x.numero = num);
  end loop;
  insert into public.commandes (numero, boutique_id, client_nom, client_tel, client_adresse, client_note, articles, total, devise, langue)
  values (num, p_boutique, trim(p_nom), trim(p_tel), trim(p_adresse), nullif(trim(coalesce(p_note, '')), ''), lignes,
          case when mixte then null else tot end, case when mixte then null else dev end, left(coalesce(p_langue, 'fr'), 5))
  returning commandes.id into nid;
  -- statistiques anonymes
  insert into public.evenements (boutique_id, type, source) values (p_boutique, 'commande_envoyee', null);
  return query select nid, num;
end $$;
revoke all on function public.passer_commande(uuid, text, text, text, text, jsonb, text) from public;
grant execute on function public.passer_commande(uuid, text, text, text, text, jsonb, text) to anon, authenticated;

-- 4. Suivi par le client : il connaît l'identifiant (impossible à deviner) de ses commandes
create or replace function public.suivi_commandes(ids uuid[])
returns table (id uuid, numero text, statut text, updated_at timestamptz)
language sql stable security definer set search_path = public as $$
  select c.id, c.numero, c.statut, c.updated_at from public.commandes c where c.id = any (ids[1:20]);
$$;
revoke all on function public.suivi_commandes(uuid[]) from public;
grant execute on function public.suivi_commandes(uuid[]) to anon, authenticated;
