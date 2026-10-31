-- =====================================================================
-- Yiriclick – base v29 : corrections de sécurité (audit du 31 octobre 2026)
-- À coller dans Supabase > SQL Editor > New query, puis "Run". Prérequis : v28. Peut être relancé sans risque.
--  1. FAILLE CORRIGÉE : un dossier envoyé depuis le site (sans être admin) pouvait fixer lui-même son prix,
--     sa remise, sa date de fin d'abonnement ou son « prix fondateur ». Ces champs sont maintenant toujours
--     remis à zéro à l'envoi : seuls l'admin et la base les remplissent.
--  2. La date de garantie fondateur d'une adresse e-mail n'est plus lisible depuis l'extérieur.
--  3. Les liens du bandeau d'annonce et des réglages doivent commencer par https:// ou être une page du site.
-- =====================================================================

create or replace function public.dossiers_champs_proteges()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then
    if tg_op = 'INSERT' then
      new.statut := 'en_attente'; new.note_admin := null;
      new.prix := null; new.prix_a_vie := false; new.prix_garanti_jusqu := null;
      new.abonnement_debut := null; new.abonnement_fin := null; new.remise_pct := null;
    else
      new.prix := old.prix; new.prix_a_vie := old.prix_a_vie; new.prix_garanti_jusqu := old.prix_garanti_jusqu;
      new.abonnement_debut := old.abonnement_debut; new.abonnement_fin := old.abonnement_fin; new.remise_pct := old.remise_pct;
    end if;
  end if;
  return new;
end $$;
-- « a_ » : runs before the other dossier triggers (alphabetical order), so the promo code is applied after the reset
drop trigger if exists a_dossiers_champs_proteges on public.dossiers;
create trigger a_dossiers_champs_proteges before insert or update on public.dossiers
  for each row execute function public.dossiers_champs_proteges();

-- Files already received with forged values: cleaned while still waiting for review
update public.dossiers set prix = null, prix_a_vie = false, prix_garanti_jusqu = null, abonnement_debut = null, abonnement_fin = null
where statut in ('en_attente', 'verifie') and (prix is not null or prix_a_vie or abonnement_fin is not null);

revoke all on function public.fondateur_garantie(text) from public, anon, authenticated;

create or replace function public.site_reglages_liens()
returns trigger language plpgsql as $$
declare l text;
begin
  if new.cle = 'annonce' then
    l := coalesce(new.valeur ->> 'lien', '');
    if l <> '' and l !~* '^(https://|[a-z0-9#?/._=&-]+$)' then raise exception 'Lien refusé : il doit commencer par https:// ou être une page du site.'; end if;
  end if;
  if new.cle = 'contact' then
    if exists (select 1 from jsonb_each_text(new.valeur) e where e.key in ('instagram', 'facebook', 'tiktok') and coalesce(e.value, '') <> '' and e.value !~* '^https://') then
      raise exception 'Les liens des réseaux doivent commencer par https://';
    end if;
  end if;
  return new;
end $$;
drop trigger if exists site_reglages_liens on public.site_reglages;
create trigger site_reglages_liens before insert or update on public.site_reglages
  for each row execute function public.site_reglages_liens();

insert into public.versions_base (version) values ('v29') on conflict (version) do nothing;
