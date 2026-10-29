-- =====================================================================
-- Yiriclick – base v19 : protections contre les abus et surveillance des tâches automatiques
-- À coller dans Supabase > SQL Editor > New query, puis "Run". Prérequis : v18. Peut être relancé sans risque.
--  1. Pièces d'identité : un visiteur ne peut plus déposer n'importe quel fichier sans limite
--     (nom de fichier imposé, 40 fichiers par heure au total, 3 000 fichiers au maximum).
--  2. Dossiers vendeurs : 20 par heure au total.
--  3. Statistiques de visite : 3 000 par heure au total (au-delà, les robots sont ignorés).
--  4. État du site : alerte si une tâche automatique ne s'est pas exécutée depuis plus de 26 heures,
--     et taux de change en retard signalé après 30 heures (au lieu de 5 jours).
-- =====================================================================

-- 1. Pièces d'identité --------------------------------------------------
create or replace function public.pieces_depot_ok(p_nom text)
returns boolean language sql stable security definer set search_path = public, storage as $$
  select p_nom ~ '^[0-9a-f-]{16,40}/(recto|verso|selfie)\.(jpg|png|pdf)$'
     and (select count(*) from storage.objects where bucket_id = 'pieces-identite' and created_at > now() - interval '1 hour') < 40
     and (select count(*) from storage.objects where bucket_id = 'pieces-identite') < 3000;
$$;
revoke all on function public.pieces_depot_ok(text) from public;
grant execute on function public.pieces_depot_ok(text) to anon, authenticated;

drop policy if exists "Depot pieces identite" on storage.objects;
create policy "Depot pieces identite" on storage.objects
  for insert to anon, authenticated
  with check (bucket_id = 'pieces-identite' and public.pieces_depot_ok(name));

-- 2. Dossiers vendeurs ----------------------------------------------------
create index if not exists dossiers_created_idx on public.dossiers (created_at);
create or replace function public.dossiers_limite()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if (select count(*) from public.dossiers where created_at > now() - interval '1 hour') >= 20 then
    raise exception 'Trop de dossiers envoyés en peu de temps. Réessaie dans une heure.';
  end if;
  return new;
end $$;
drop trigger if exists dossiers_limite on public.dossiers;
create trigger dossiers_limite before insert on public.dossiers
  for each row execute function public.dossiers_limite();

-- 3. Statistiques de visite -------------------------------------------------
create index if not exists visites_created_idx on public.visites (created_at);
create or replace function public.visites_limite()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if (select count(*) from public.visites where created_at > now() - interval '1 hour') >= 3000 then
    return null;  -- ignorée sans erreur : le visiteur ne voit rien
  end if;
  return new;
end $$;
drop trigger if exists visites_limite on public.visites;
create trigger visites_limite before insert on public.visites
  for each row execute function public.visites_limite();

-- 4. Surveillance des tâches automatiques -------------------------------------
-- Dernière exécution réussie de chaque tâche Yiriclick (ménage mensuel exclu : il ne tourne qu'une fois par mois)
create or replace function public.taches_etat()
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare r jsonb := '[]'::jsonb; j record; t timestamptz;
begin
  if to_regclass('cron.job') is null or to_regclass('cron.job_run_details') is null then return null; end if;
  for j in execute 'select jobid, jobname from cron.job where jobname like ''yiriclick-%'' and jobname <> ''yiriclick-menage'' and active' loop
    execute 'select max(end_time) from cron.job_run_details where jobid = $1 and status = ''succeeded''' into t using j.jobid;
    r := r || jsonb_build_object('nom', j.jobname, 'dernier', t, 'ok', t is not null and t > now() - interval '26 hours');
  end loop;
  return r;
end $$;
revoke all on function public.taches_etat() from public, anon, authenticated;

create or replace function public.etat_site()
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v jsonb := '[]'::jsonb; s jsonb := '[]'::jsonb; n bigint; t timestamptz; txt text; te jsonb;
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
  v := v || jsonb_build_object('v', 'v19', 'ok', exists (select 1 from pg_proc where proname = 'taches_etat'));

  -- services
  if to_regclass('public.taux') is not null then
    execute 'select max(maj) from public.taux where devise = ''USD''' into t;
    s := s || jsonb_build_object('k', 'taux', 'ok', t is not null and t > now() - interval '30 hours', 'detail', t);
  end if;
  if to_regclass('cron.job') is not null then
    execute 'select count(*) from cron.job where jobname like ''yiriclick-%''' into n;
    s := s || jsonb_build_object('k', 'cron', 'ok', n >= 2, 'detail', n);
  else
    s := s || jsonb_build_object('k', 'cron', 'ok', false, 'detail', null);
  end if;
  -- tâches qui ne tournent plus (cas du 25 au 27 octobre 2026)
  te := public.taches_etat();
  if te is not null then
    s := s || jsonb_build_object('k', 'taches', 'ok', not exists (select 1 from jsonb_array_elements(te) x where not (x->>'ok')::boolean), 'detail', te);
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
      execute 'select count(*) from public.emails_journal j join net._http_response r on r.id = j.request_id where r.status_code is null or r.status_code >= 300' into n;
    end if;
    s := s || jsonb_build_object('k', 'emails', 'ok', n = 0, 'detail', jsonb_build_object('dernier', t, 'refus', n));
  end if;
  if to_regclass('auth.mfa_factors') is not null then
    execute 'select count(*) from auth.mfa_factors where user_id = auth.uid() and status = ''verified''' into n;
    s := s || jsonb_build_object('k', 'mfa', 'ok', n > 0, 'detail', n);
  end if;
  if to_regclass('cron.job') is not null then
    execute 'select count(*) from cron.job where jobname = ''yiriclick-menage''' into n;
    s := s || jsonb_build_object('k', 'menage', 'ok', n > 0, 'detail', n);
  end if;
  execute 'select count(*) from storage.objects where bucket_id = ''pieces-identite''' into n;
  s := s || jsonb_build_object('k', 'pieces', 'ok', n < 2500, 'detail', n);
  execute 'select count(*) from public.boutiques where not approuvee and not masque_admin' into n;
  s := s || jsonb_build_object('k', 'a_valider', 'ok', n = 0, 'detail', n);
  execute 'select count(*) from public.messages_contact where not traite' into n;
  s := s || jsonb_build_object('k', 'messages', 'ok', n = 0, 'detail', n);

  return jsonb_build_object('scripts', v, 'services', s, 'heure', now());
end $$;
revoke all on function public.etat_site() from public;
grant execute on function public.etat_site() to authenticated;

insert into public.versions_base (version) values ('v19') on conflict (version) do nothing;
