-- =====================================================================
-- Yiriclick – base v10 : inscription simplifiée
--  - L'essai gratuit s'ouvre tout de suite (plus besoin d'attendre l'admin), pour 14 jours.
--  - La vérification d'identité (dossier) est demandée seulement pour passer en formule payante.
--  - Le badge « Vendeur vérifié » n'apparaît que pour les vendeurs au dossier validé.
-- À coller dans Supabase > SQL Editor > New query, puis "Run".
-- Prérequis : scripts v2 à v9 déjà exécutés. Peut être relancé sans risque.
-- =====================================================================

-- 1. Fin d'essai ---------------------------------------------------------------
alter table public.inscriptions add column if not exists essai_fin timestamptz;
-- les essais déjà actifs gardent 14 jours à partir d'aujourd'hui
update public.inscriptions set essai_fin = now() + interval '14 days' where statut = 'actif' and essai_fin is null;

create or replace function public.inscriptions_auto()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    -- une même adresse ne peut pas enchaîner les essais
    if exists (select 1 from public.inscriptions i where lower(i.email) = lower(new.email)) then
      new.statut := 'nouveau'; new.note_admin := 'Adresse déjà inscrite : essai non renouvelé automatiquement.';
    else
      new.statut := 'actif'; new.essai_fin := now() + interval '14 days';
    end if;
  elsif new.statut = 'actif' and new.essai_fin is null then
    new.essai_fin := now() + interval '14 days';
  end if;
  return new;
end $$;
drop trigger if exists inscriptions_auto on public.inscriptions;
create trigger inscriptions_auto before insert or update on public.inscriptions
  for each row execute function public.inscriptions_auto();

-- 2. Formule du vendeur connecté : l'essai expire après sa date de fin --------------
create or replace function public.vendeur_formule()
returns text language sql stable security definer set search_path = public as $$
  select case when not exists (
      select 1 from auth.users u where u.id = auth.uid() and u.email_confirmed_at is not null
    ) then null
  else coalesce(
    (select d.formule from public.dossiers d
      where lower(d.email) = lower(auth.jwt() ->> 'email') and d.statut = 'actif'
      order by d.created_at desc limit 1),
    (select 'essai' from public.inscriptions i
      where lower(i.email) = lower(auth.jwt() ->> 'email') and i.statut = 'actif'
        and (i.essai_fin is null or i.essai_fin > now()) limit 1)
  ) end;
$$;

-- 3. Situation du compte, pour l'espace vendeur (essai, dossier en cours…) ---------
create or replace function public.mon_compte()
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'formule', public.vendeur_formule(),
    'email_confirme', exists (select 1 from auth.users u where u.id = auth.uid() and u.email_confirmed_at is not null),
    'essai_fin', (select i.essai_fin from public.inscriptions i where lower(i.email) = lower(auth.jwt() ->> 'email') order by (i.statut = 'actif') desc, i.created_at desc limit 1),
    'essai_statut', (select i.statut from public.inscriptions i where lower(i.email) = lower(auth.jwt() ->> 'email') order by (i.statut = 'actif') desc, i.created_at desc limit 1),
    'formule_souhaitee', (select i.formule from public.inscriptions i where lower(i.email) = lower(auth.jwt() ->> 'email') order by (i.statut = 'actif') desc, i.created_at desc limit 1),
    'dossier_statut', (select d.statut from public.dossiers d where lower(d.email) = lower(auth.jwt() ->> 'email') order by d.created_at desc limit 1),
    'dossier_formule', (select d.formule from public.dossiers d where lower(d.email) = lower(auth.jwt() ->> 'email') order by d.created_at desc limit 1)
  );
$$;
revoke all on function public.mon_compte() from public;
grant execute on function public.mon_compte() to authenticated;

-- 4. Badge « Vendeur vérifié » ----------------------------------------------------
alter table public.boutiques add column if not exists verifie boolean not null default false;

create or replace function public.boutiques_controle()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is not null and not public.is_admin() then
    if tg_op = 'INSERT' then
      new.masque_admin := false; new.owner := auth.uid();
      new.verifie := exists (select 1 from public.dossiers d where lower(d.email) = lower(auth.jwt() ->> 'email') and d.statut = 'actif');
    else
      new.masque_admin := old.masque_admin; new.owner := old.owner; new.verifie := old.verifie;
    end if;
  end if;
  new.updated_at := now();
  return new;
end $$;

-- Quand l'admin valide (ou retire) un dossier, le badge suit
create or replace function public.dossiers_badge()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.statut is distinct from old.statut or new.email is distinct from old.email then
    update public.boutiques b set verifie = exists (
      select 1 from public.dossiers d where lower(d.email) = lower(u.email) and d.statut = 'actif')
    from auth.users u where u.id = b.owner and lower(u.email) in (lower(new.email), lower(old.email));
  end if;
  return new;
end $$;
drop trigger if exists dossiers_badge on public.dossiers;
create trigger dossiers_badge after update on public.dossiers
  for each row execute function public.dossiers_badge();

-- Rattrapage pour les boutiques existantes
update public.boutiques b set verifie = exists (
  select 1 from public.dossiers d join auth.users u on lower(u.email) = lower(d.email) where u.id = b.owner and d.statut = 'actif');
