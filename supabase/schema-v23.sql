-- =====================================================================
-- Yiriclick – base v23 : surveillance des tâches selon leur rythme, horaires dans l'admin
-- À coller dans Supabase > SQL Editor > New query, puis "Run". Prérequis : v22. Peut être relancé sans risque.
--  1. Chaque tâche est jugée selon son propre rythme : 26 h pour une tâche quotidienne,
--     8 jours pour une tâche hebdomadaire (ex. prix-menage, le dimanche), 32 jours pour une tâche mensuelle.
--     Avant, toute tâche sans passage depuis 26 h était signalée « arrêtée », même prix-menage.
--  2. Une tâche qui n'a encore jamais tourné (et jamais échoué) est « en attente du 1er passage », pas « arrêtée ».
--  3. L'état du site renvoie l'horaire de chaque tâche : l'admin affiche le prochain passage avec un compte à rebours.
-- =====================================================================

create or replace function public.taches_etat()
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  r jsonb := '[]'::jsonb; j record; t timestamptz; d timestamptz; st text; n bigint;
  f text[]; tol interval; etat text;
begin
  if to_regclass('cron.job') is null or to_regclass('cron.job_run_details') is null then return null; end if;
  for j in execute 'select jobid, jobname, schedule, active from cron.job where jobname like ''yiriclick-%'' order by jobname' loop
    execute 'select max(end_time) from cron.job_run_details where jobid = $1 and status = ''succeeded''' into t using j.jobid;
    execute 'select start_time, status from cron.job_run_details where jobid = $1 order by start_time desc limit 1' into d, st using j.jobid;
    execute 'select count(*) from cron.job_run_details where jobid = $1' into n using j.jobid;
    -- rythme déduit de l'horaire : minute heure jour-du-mois mois jour-de-semaine
    f := regexp_split_to_array(trim(j.schedule), '\s+');
    if array_length(f, 1) = 5 and f[3] <> '*' then tol := interval '32 days';
    elsif array_length(f, 1) = 5 and f[5] <> '*' then tol := interval '8 days';
    else tol := interval '26 hours';
    end if;
    if not j.active then etat := 'desactivee';
    elsif n = 0 then etat := 'attente';
    elsif t is not null and t > now() - tol then etat := 'ok';
    elsif st = 'failed' then etat := 'echec';
    else etat := 'retard';
    end if;
    r := r || jsonb_build_object(
      'nom', j.jobname, 'horaire', j.schedule, 'active', j.active,
      'dernier', t, 'dernier_essai', d, 'dernier_statut', st,
      'etat', etat, 'ok', etat in ('ok', 'attente'));
  end loop;
  return r;
end $$;
revoke all on function public.taches_etat() from public, anon, authenticated;

insert into public.versions_base (version) values ('v23') on conflict (version) do nothing;
