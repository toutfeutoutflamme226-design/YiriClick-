-- =====================================================================
-- Yiriclick – base v17 : taux de change mis à jour chaque matin à 07:00 (heure des Pays-Bas)
-- À coller dans Supabase > SQL Editor > New query, puis "Run".
-- Prérequis : scripts v9 et v12. Peut être relancé sans risque.
--  - Les tâches planifiées de Supabase suivent l'heure UTC. 07:00 aux Pays-Bas = 06:00 UTC en hiver,
--    05:00 UTC en été : la demande est programmée aux deux heures et ne part que s'il est 7 h à Amsterdam.
--  - À 7 h, ce sont les taux publiés par la Banque centrale européenne la veille vers 16 h (elle ne publie pas le week-end).
--  - Si tu relances un jour schema-v12.sql, relance ensuite ce script (v12 remet l'ancien horaire).
-- =====================================================================

create or replace function public.taux_demander_matin()
returns void language plpgsql security definer set search_path = public as $$
begin
  if extract(hour from (now() at time zone 'Europe/Amsterdam')) = 7 then
    perform public.taux_demander();
  end if;
end $$;
revoke all on function public.taux_demander_matin() from public, anon, authenticated;

-- Mêmes noms de tâches : l'ancien horaire (15:30 UTC en semaine) est remplacé
select cron.schedule('yiriclick-taux-demande', '0 5,6 * * *', 'select public.taux_demander_matin()');
select cron.schedule('yiriclick-taux-lecture', '5 5,6 * * *', 'select public.taux_lire()');

-- État du site : ajoute la ligne v17
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
  execute 'select count(*) from public.boutiques where not approuvee and not masque_admin' into n;
  s := s || jsonb_build_object('k', 'a_valider', 'ok', n = 0, 'detail', n);
  execute 'select count(*) from public.messages_contact where not traite' into n;
  s := s || jsonb_build_object('k', 'messages', 'ok', n = 0, 'detail', n);

  return jsonb_build_object('scripts', v, 'services', s, 'heure', now());
end $$;
revoke all on function public.etat_site() from public;
grant execute on function public.etat_site() to authenticated;

insert into public.versions_base (version) values ('v17') on conflict (version) do nothing;

-- Vérifier : select jobname, schedule, command from cron.job where jobname like 'yiriclick-%';
