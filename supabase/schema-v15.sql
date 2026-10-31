-- =====================================================================
-- Yiriclick – base v15 : demander un avis après la livraison
-- À coller dans Supabase > SQL Editor > New query, puis "Run". Prérequis : v14. Peut être relancé sans risque.
--
-- Fichier reconstruit le 31 octobre 2026 à partir de la base en production (pg_get_functiondef) :
-- le script d'origine avait été exécuté dans Supabase mais jamais envoyé sur GitHub.
--
--  1. Chaque commande garde la date de la dernière demande d'avis et le nombre de demandes.
--  2. Lien d'avis noter?c=<numéro interne> : le client voit sa commande (boutique, numéro, articles) sans compte.
--  3. Le vendeur (ou l'admin) note qu'une demande a été envoyée ; l'admin liste les commandes livrées sans avis.
-- =====================================================================

-- 1. Suivi des demandes d'avis sur chaque commande
alter table public.commandes add column if not exists avis_demande_at timestamptz;
alter table public.commandes add column if not exists avis_demandes   integer not null default 0;

-- 2. Contrôle des commandes (base v6) : une demande d'avis ne change rien d'autre que ces deux colonnes
create or replace function public.commandes_controle()
returns trigger language plpgsql security definer set search_path = public as $function$
declare garde text := new.statut; note text := new.note_vendeur; dem timestamptz := new.avis_demande_at; nb integer := new.avis_demandes;
begin
  if current_setting('yc.avis_demande', true) = '1' then
    new := old; new.avis_demande_at := dem; new.avis_demandes := nb;
    return new;
  end if;
  if not public.is_admin() then new := old; new.statut := garde; new.note_vendeur := note; end if;
  if new.statut in ('confirmee', 'expediee', 'livree') and not old.stock_retire then
    perform public.commande_stock(new.articles, -1); new.stock_retire := true;
  elsif new.statut in ('nouvelle', 'annulee') and old.stock_retire then
    perform public.commande_stock(new.articles, 1); new.stock_retire := false;
  end if;
  new.updated_at := now();
  return new;
end $function$;
drop trigger if exists commandes_controle on public.commandes;
create trigger commandes_controle before update on public.commandes
  for each row execute function public.commandes_controle();

-- 3. Page d'avis du client (noter) : seulement la boutique, le numéro et les articles
create or replace function public.commande_pour_avis(p_commande uuid)
returns jsonb language sql stable security definer set search_path = public as $function$
  select jsonb_build_object(
    'id', c.id, 'numero', c.numero, 'statut', c.statut, 'langue', c.langue,
    'prenom', split_part(trim(c.client_nom), ' ', 1),
    'articles', (select coalesce(jsonb_agg(jsonb_build_object('qty', a ->> 'qty', 'nom', a ->> 'nom')), '[]'::jsonb) from jsonb_array_elements(c.articles) a),
    'boutique', jsonb_build_object('id', b.id, 'nom', b.nom, 'slug', b.slug, 'logo', b.logo, 'theme', b.theme),
    'a_avis', exists (select 1 from public.avis v where v.commande_id = c.id and v.cible = 'boutique'))
  from public.commandes c join public.boutiques b on b.id = c.boutique_id
  where c.id = p_commande;
$function$;
revoke all on function public.commande_pour_avis(uuid) from public;
grant execute on function public.commande_pour_avis(uuid) to anon, authenticated;

-- 4. Le vendeur de la commande (ou l'admin) enregistre l'envoi d'une demande d'avis
create or replace function public.avis_demande_envoyee(p_commande uuid)
returns timestamptz language plpgsql security definer set search_path = public as $function$
declare t timestamptz := now();
begin
  if not (public.is_admin() or exists (select 1 from public.commandes c join public.boutiques b on b.id = c.boutique_id
                                       where c.id = p_commande and b.owner = auth.uid())) then
    raise exception 'Commande introuvable.';
  end if;
  perform set_config('yc.avis_demande', '1', true);
  update public.commandes set avis_demande_at = t, avis_demandes = avis_demandes + 1 where id = p_commande;
  return t;
end $function$;
revoke all on function public.avis_demande_envoyee(uuid) from public, anon;
grant execute on function public.avis_demande_envoyee(uuid) to authenticated;

-- 5. Admin : commandes livrées depuis moins de 60 jours, sans avis sur la boutique
create or replace function public.commandes_sans_avis()
returns table (id uuid, numero text, client_nom text, client_tel text, langue text, boutique text,
               livree_at timestamptz, avis_demande_at timestamptz, avis_demandes integer)
language plpgsql stable security definer set search_path = public as $function$
begin
  if not public.is_admin() then raise exception 'Réservé à l’administrateur.'; end if;
  return query
    select c.id, c.numero, c.client_nom, c.client_tel, c.langue, b.nom, c.updated_at, c.avis_demande_at, c.avis_demandes
    from public.commandes c join public.boutiques b on b.id = c.boutique_id
    where c.statut = 'livree' and c.updated_at > now() - interval '60 days'
      and not exists (select 1 from public.avis v where v.commande_id = c.id and v.cible = 'boutique')
    order by c.avis_demande_at nulls first, c.updated_at desc
    limit 200;
end $function$;
revoke all on function public.commandes_sans_avis() from public, anon;
grant execute on function public.commandes_sans_avis() to authenticated;
