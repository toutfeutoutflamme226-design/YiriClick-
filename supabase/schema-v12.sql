-- =====================================================================
-- Yiriclick – base v12 : taux de change mis à jour chaque jour
-- Source : Banque centrale européenne, via l'API gratuite Frankfurter (sans clé).
-- Le franc CFA est fixe (1 EUR = 655,957 FCFA). Dollar et autres monnaies (démo de la page vendeurs) mis à jour.
-- À coller dans Supabase > SQL Editor > New query, puis "Run".
-- Prérequis : scripts v2 à v11 (v9 pour pg_net, v11 pour la table taux). Peut être relancé sans risque.
-- =====================================================================

-- 1. Tâches planifiées de Supabase
create extension if not exists pg_cron with schema pg_catalog;
grant usage on schema cron to postgres;
grant all privileges on all tables in schema cron to postgres;

-- 2. Demandes en cours (la réponse arrive quelques secondes après)
create table if not exists public.taux_requetes (
  id         bigint primary key,
  created_at timestamptz not null default now()
);
alter table public.taux_requetes enable row level security;
revoke all on table public.taux_requetes from anon, authenticated;

create or replace function public.taux_demander()
returns void language plpgsql security definer set search_path = public as $$
begin
  insert into public.taux_requetes (id)
  select net.http_get(url := 'https://api.frankfurter.dev/v1/latest?base=EUR&symbols=USD,GBP,CAD,CHF,CNY,JPY,AUD,BRL,INR,ZAR', timeout_milliseconds := 10000);
end $$;

-- Lit la réponse et met à jour le dollar ; ignore toute valeur incohérente
create or replace function public.taux_lire()
returns void language plpgsql security definer set search_path = public as $$
declare r record; v numeric;
begin
  for r in select resp.id, resp.status_code, resp.content from net._http_response resp join public.taux_requetes q on q.id = resp.id loop
    begin
      if r.status_code = 200 then
        v := (r.content::jsonb -> 'rates' ->> 'USD')::numeric;
        if v between 0.5 and 2.5 then
          update public.taux set par_eur = v, maj = now() where devise = 'USD';
          update public.taux set maj = now() where devise in ('EUR', 'XOF');
          -- autres monnaies : seulement affichées sur la page vendeurs
          insert into public.taux (devise, par_eur, maj)
          select k, (x.value #>> '{}')::numeric, now() from jsonb_each(r.content::jsonb -> 'rates') x(k, value)
          where k <> 'USD' and (x.value #>> '{}')::numeric > 0
          on conflict (devise) do update set par_eur = excluded.par_eur, maj = excluded.maj;
        end if;
      end if;
    exception when others then null;
    end;
    delete from public.taux_requetes where id = r.id;
  end loop;
  delete from public.taux_requetes where created_at < now() - interval '2 days';
end $$;
revoke all on function public.taux_demander() from public, anon, authenticated;
revoke all on function public.taux_lire() from public, anon, authenticated;

-- 3. Chaque jour de semaine : demande à 15:30 UTC (après la publication BCE), lecture 5 minutes plus tard
select cron.schedule('yiriclick-taux-demande', '30 15 * * 1-5', 'select public.taux_demander()');
select cron.schedule('yiriclick-taux-lecture', '35 15 * * 1-5', 'select public.taux_lire()');

-- Premier essai tout de suite (la lecture se fera au prochain passage, ou lance « select public.taux_lire(); » dans 10 secondes)
select public.taux_demander();
