-- =====================================================================
-- Yiriclick – base v21 : limites contre le spam (commandes, inscriptions, statistiques)
-- À coller dans Supabase > SQL Editor > New query, puis "Run". Prérequis : v20. Peut être relancé sans risque.
--  1. Commandes : 30 par heure et par boutique (en plus des 6 par heure et par téléphone), 300 par heure au total.
--     Empêche quelqu'un d'inonder un vendeur de fausses commandes en changeant de numéro.
--  2. Inscriptions à l'essai : 30 par heure au total.
--  3. Statistiques des boutiques (événements) : 5 000 par heure au total ; au-delà, ignorées sans erreur.
-- =====================================================================

create index if not exists commandes_boutique_created_idx on public.commandes (boutique_id, created_at);
create or replace function public.commandes_limite()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if (select count(*) from public.commandes where boutique_id = new.boutique_id and created_at > now() - interval '1 hour') >= 30 then
    raise exception 'Trop de commandes pour cette boutique en peu de temps. Réessaie dans une heure.';
  end if;
  if (select count(*) from public.commandes where created_at > now() - interval '1 hour') >= 300 then
    raise exception 'Trop de commandes en peu de temps. Réessaie dans une heure.';
  end if;
  return new;
end $$;
drop trigger if exists commandes_limite on public.commandes;
create trigger commandes_limite before insert on public.commandes
  for each row execute function public.commandes_limite();

create index if not exists inscriptions_created_idx on public.inscriptions (created_at);
create or replace function public.inscriptions_limite()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if (select count(*) from public.inscriptions where created_at > now() - interval '1 hour') >= 30 then
    raise exception 'Trop d’inscriptions en peu de temps. Réessaie dans une heure.';
  end if;
  return new;
end $$;
drop trigger if exists inscriptions_limite on public.inscriptions;
create trigger inscriptions_limite before insert on public.inscriptions
  for each row execute function public.inscriptions_limite();

create index if not exists evenements_created_idx on public.evenements (created_at);
create or replace function public.evenements_limite()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if (select count(*) from public.evenements where created_at > now() - interval '1 hour') >= 5000 then
    return null;
  end if;
  return new;
end $$;
drop trigger if exists evenements_limite on public.evenements;
create trigger evenements_limite before insert on public.evenements
  for each row execute function public.evenements_limite();

insert into public.versions_base (version) values ('v21') on conflict (version) do nothing;
