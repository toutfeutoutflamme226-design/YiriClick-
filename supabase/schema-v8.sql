-- =====================================================================
-- Yiriclick – base v8 : tailles et pointures pour toutes les formules
-- À coller dans Supabase > SQL Editor > New query, puis "Run".
-- Prérequis : scripts v2 à v7 déjà exécutés. Peut être relancé sans risque.
--  - Essai et Basique : une option (taille, pointure…) avec un stock par taille.
--  - Pro et Entreprise : deux options (taille et couleur) et un prix par variante.
-- =====================================================================

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
  -- tailles (une option, stock par taille) : toutes les formules ;
  -- deux options ou un prix par variante : Pro et Entreprise
  if public.a_variantes(new.variantes) and f not in ('pro', 'entreprise')
     and (tg_op = 'INSERT' or new.variantes is distinct from old.variantes)
     and (jsonb_array_length(new.variantes -> 'options') > 1
          or exists (select 1 from jsonb_array_elements(coalesce(new.variantes -> 'combis', '[]')) x where jsonb_typeof(x -> 'prix') = 'number')) then
    raise exception 'Avec ta formule : une seule option (ex. taille) et le même prix pour toutes les tailles. Deux options et un prix par variante : formules Pro et Entreprise.';
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
