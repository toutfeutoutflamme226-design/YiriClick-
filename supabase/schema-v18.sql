-- =====================================================================
-- Yiriclick – base v18 : sécurité et données personnelles
-- À coller dans Supabase > SQL Editor > New query, puis "Run".
-- Prérequis : scripts v2 à v17. Peut être relancé sans risque.
--  1. Administration : dès que l'admin a activé son code à 6 chiffres (application d'authentification),
--     ses droits d'admin ne s'appliquent qu'après ce code. Avant, rien ne change (aucun risque de blocage).
--     En cas de téléphone perdu : delete from auth.mfa_factors where user_id = '<ton id>';
--  2. Un vendeur peut supprimer son compte lui-même (boutique, produits, commandes, avis, accès).
--     Son dossier d'identité est gardé 6 mois (traçabilité des vendeurs, règlement européen DSA), puis effacé.
--  3. Ménage automatique chaque mois : coordonnées des clients effacées des commandes de plus de 2 ans,
--     messages de contact de plus d'un an, visites de plus de 13 mois, journal des e-mails de plus d'un an.
-- =====================================================================

-- 1. Code à 6 chiffres pour l'administration ------------------------------------------
create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.admins where user_id = auth.uid())
    and (
      -- pas encore de code à 6 chiffres : le mot de passe suffit (le temps de l'activer)
      not exists (select 1 from auth.mfa_factors f where f.user_id = auth.uid() and f.status = 'verified')
      -- code activé : la session doit avoir été confirmée par le code
      or coalesce(auth.jwt() ->> 'aal', '') = 'aal2'
    );
$$;
revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to authenticated;

-- État de connexion de l'admin, pour la page admin.html
create or replace function public.admin_statut()
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'admin', exists (select 1 from public.admins where user_id = auth.uid()),
    'code_active', exists (select 1 from auth.mfa_factors f where f.user_id = auth.uid() and f.status = 'verified'),
    'session_confirmee', coalesce(auth.jwt() ->> 'aal', '') = 'aal2');
$$;
revoke all on function public.admin_statut() from public;
grant execute on function public.admin_statut() to authenticated;

-- 2. Suppression de compte par le vendeur ------------------------------------------------
alter table public.dossiers add column if not exists compte_supprime_le timestamptz;

create or replace function public.supprimer_mon_compte()
returns void language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); mail text;
begin
  if uid is null then raise exception 'Connecte-toi d''abord.'; end if;
  if exists (select 1 from public.admins where user_id = uid) then
    raise exception 'Un compte administrateur ne peut pas être supprimé depuis le site.';
  end if;
  select lower(email) into mail from auth.users where id = uid;
  -- dossier d'identité : gardé 6 mois puis effacé par le ménage mensuel
  update public.dossiers set compte_supprime_le = now() where lower(email) = mail and compte_supprime_le is null;
  delete from public.inscriptions where lower(email) = mail;
  -- boutique, produits, commandes, avis, codes promo, statistiques : supprimés en cascade avec l'accès
  delete from auth.users where id = uid;
end $$;
revoke all on function public.supprimer_mon_compte() from public, anon;
grant execute on function public.supprimer_mon_compte() to authenticated;

-- 3. Ménage mensuel des données personnelles ---------------------------------------------
create or replace function public.donnees_menage()
returns jsonb language plpgsql security definer set search_path = public as $$
declare a bigint := 0; b bigint := 0; c bigint := 0; d bigint := 0; e bigint := 0;
begin
  update public.commandes set client_nom = 'Client anonymisé', client_tel = '00000000', client_adresse = 'Effacée', client_note = null
    where created_at < now() - interval '24 months' and client_nom <> 'Client anonymisé';
  get diagnostics a = row_count;
  if to_regclass('public.messages_contact') is not null then
    execute 'delete from public.messages_contact where created_at < now() - interval ''12 months''';
    get diagnostics b = row_count;
  end if;
  if to_regclass('public.visites') is not null then
    execute 'delete from public.visites where created_at < now() - interval ''13 months''';
    get diagnostics c = row_count;
  end if;
  if to_regclass('public.emails_journal') is not null then
    execute 'delete from public.emails_journal where created_at < now() - interval ''12 months''';
    get diagnostics d = row_count;
  end if;
  -- les fichiers des pièces d'identité se suppriment depuis l'admin (Supabase interdit de les effacer en SQL)
  delete from public.dossiers where compte_supprime_le < now() - interval '6 months';
  get diagnostics e = row_count;
  return jsonb_build_object('commandes_anonymisees', a, 'messages', b, 'visites', c, 'emails', d, 'dossiers', e);
end $$;
revoke all on function public.donnees_menage() from public, anon, authenticated;

select cron.schedule('yiriclick-menage', '0 3 1 * *', 'select public.donnees_menage()');

-- État du site : lignes v18, code admin et ménage
create or replace function public.etat_site()
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v jsonb := '[]'::jsonb; s jsonb := '[]'::jsonb; n bigint; t timestamptz; txt text;
begin
  if not public.is_admin() then raise exception 'Réservé à l’administration.'; end if;

  -- scripts installés : un objet caractéristique de chacun
  v := v || jsonb_build_object('v', 'inscriptions', 'ok', to_regclass('public.inscriptions') is not null);
  v := v || jsonb_build_object('v', 'v2', 'ok', to_regclass('public.dossiers') is not null and to_regclass('public.admins') is not null);
  v := v || jsonb_build_object('v', 'v3', 'ok', to_regclass('public.boutiques') is not null and to_regclass('public.produits') is not null);
  v := v || jsonb_build_object('v', 'v4', 'ok', to_regclass('public.promotions') is not null);
  v := v || jsonb_build_object('v', 'v5', 'ok', to_regclass('public.evenements') is not null);
  v := v || jsonb_build_object('v', 'v6', 'ok', to_regclass('public.commandes') is not null);
  v := v || jsonb_build_object('v', 'v7', 'ok', to_regclass('public.avis') is not null and to_regclass('public.codes_promo') is not null);
  v := v || jsonb_build_object('v', 'v8', 'ok', exists (select 1 from pg_proc where proname = 'produits_controle' and prosrc like '%une seule option (ex. taille)%'));
  v := v || jsonb_build_object('v', 'v9', 'ok', to_regclass('public.emails_journal') is not null);
  v := v || jsonb_build_object('v', 'v10', 'ok', exists (select 1 from pg_proc where proname = 'mon_compte'));
  v := v || jsonb_build_object('v', 'v11', 'ok', to_regclass('public.taux') is not null and exists (select 1 from pg_proc where proname = 'vitrine_produits'));
  v := v || jsonb_build_object('v', 'v12', 'ok', exists (select 1 from pg_proc where proname = 'taux_lire'));
  v := v || jsonb_build_object('v', 'v13', 'ok', exists (select 1 from pg_proc where proname = 'mon_profil'));
  v := v || jsonb_build_object('v', 'v14', 'ok', to_regclass('public.reglages_avis') is not null);
  v := v || jsonb_build_object('v', 'v15', 'ok', exists (select 1 from pg_proc where proname = 'commande_pour_avis'));
  v := v || jsonb_build_object('v', 'v16', 'ok', to_regclass('public.messages_contact') is not null);
  v := v || jsonb_build_object('v', 'v17', 'ok', exists (select 1 from pg_proc where proname = 'taux_demander_matin'));
  v := v || jsonb_build_object('v', 'v18', 'ok', exists (select 1 from pg_proc where proname = 'supprimer_mon_compte'));

  -- services
  if to_regclass('public.taux') is not null then
    execute 'select max(maj) from public.taux where devise = ''USD''' into t;
    s := s || jsonb_build_object('k', 'taux', 'ok', t is not null and t > now() - interval '5 days', 'detail', t);
  end if;
  if to_regclass('cron.job') is not null then
    execute 'select count(*) from cron.job where jobname like ''yiriclick-%''' into n;
    s := s || jsonb_build_object('k', 'cron', 'ok', n >= 2, 'detail', n);
  else
    s := s || jsonb_build_object('k', 'cron', 'ok', false, 'detail', null);
  end if;
  if to_regclass('vault.decrypted_secrets') is not null then
    execute 'select count(*) from vault.decrypted_secrets where name = ''resend_api_key'' and coalesce(decrypted_secret, '''') <> ''''' into n;
    s := s || jsonb_build_object('k', 'resend', 'ok', n > 0, 'detail', null);
  else
    s := s || jsonb_build_object('k', 'resend', 'ok', false, 'detail', null);
  end if;
  if to_regclass('public.reglages_email') is not null then
    execute 'select admin_email from public.reglages_email where id = 1' into txt;
    s := s || jsonb_build_object('k', 'admin_email', 'ok', txt is not null and txt like '%@%', 'detail', txt);
    execute 'select site_url from public.reglages_email where id = 1' into txt;
    s := s || jsonb_build_object('k', 'site_url', 'ok', txt is not null, 'detail', txt);
  end if;
  if to_regclass('public.emails_journal') is not null then
    execute 'select max(created_at) from public.emails_journal' into t;
    n := 0;
    if to_regclass('net._http_response') is not null then
      -- réponses de Resend encore gardées par pg_net (quelques heures) : refus = clé ou domaine à vérifier
      execute 'select count(*) from public.emails_journal j join net._http_response r on r.id = j.request_id where r.status_code is null or r.status_code >= 300' into n;
    end if;
    s := s || jsonb_build_object('k', 'emails', 'ok', n = 0, 'detail', jsonb_build_object('dernier', t, 'refus', n));
  end if;
  -- double authentification de l'admin connecté (v18)
  if to_regclass('auth.mfa_factors') is not null then
    execute 'select count(*) from auth.mfa_factors where user_id = auth.uid() and status = ''verified''' into n;
    s := s || jsonb_build_object('k', 'mfa', 'ok', n > 0, 'detail', n);
  end if;
  if to_regclass('cron.job') is not null then
    execute 'select count(*) from cron.job where jobname = ''yiriclick-menage''' into n;
    s := s || jsonb_build_object('k', 'menage', 'ok', n > 0, 'detail', n);
  end if;
  execute 'select count(*) from public.boutiques where not approuvee and not masque_admin' into n;
  s := s || jsonb_build_object('k', 'a_valider', 'ok', n = 0, 'detail', n);
  execute 'select count(*) from public.messages_contact where not traite' into n;
  s := s || jsonb_build_object('k', 'messages', 'ok', n = 0, 'detail', n);

  return jsonb_build_object('scripts', v, 'services', s, 'heure', now());
end $$;
revoke all on function public.etat_site() from public;
grant execute on function public.etat_site() to authenticated;

insert into public.versions_base (version) values ('v18') on conflict (version) do nothing;
