-- =====================================================================
-- Yiriclick – base v28 : prix fondateur garanti 5 ans (au lieu de « à vie »)
-- À coller dans Supabase > SQL Editor > New query, puis "Run". Prérequis : v27. Peut être relancé sans risque.
--  1. Un vendeur fondateur garde son prix 5 ans à partir de son entrée dans le Club (date fondateur_le).
--  2. Les autres abonnés gardent leur prix jusqu'au renouvellement : quand l'admin prolonge, le prix du moment s'applique.
--  3. 30 jours avant la fin des 5 ans : message dans l'espace vendeur et e-mail (tâche quotidienne yiriclick-fondateurs).
-- =====================================================================

alter table public.dossiers add column if not exists prix_garanti_jusqu date;

create or replace function public.fondateur_garantie(p_email text)
returns date language sql stable security definer set search_path = public as $$
  select (coalesce(min(b.fondateur_le), now())::date + interval '5 years')::date
  from public.boutiques b join auth.users u on u.id = b.owner where lower(u.email) = lower(p_email) and b.fondateur;
$$;

-- Every founder subscription gets its end date of guarantee (also when it becomes founder later: v27 sets prix_a_vie)
create or replace function public.dossiers_prix_garantie()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.prix_a_vie and new.prix_garanti_jusqu is null then new.prix_garanti_jusqu := public.fondateur_garantie(new.email); end if;
  if not new.prix_a_vie then new.prix_garanti_jusqu := null; end if;
  return new;
end $$;
drop trigger if exists dossiers_prix_garantie on public.dossiers;
create trigger dossiers_prix_garantie before insert or update on public.dossiers
  for each row execute function public.dossiers_prix_garantie();
update public.dossiers set prix_garanti_jusqu = public.fondateur_garantie(email) where prix_a_vie and prix_garanti_jusqu is null;

-- Renewal by the admin: price of the day, except during the founder guarantee
create or replace function public.admin_prolonger(p_dossier uuid, p_mois integer)
returns date language plpgsql security definer set search_path = public as $$
declare d public.dossiers; nf date; np numeric; garde boolean;
begin
  if not public.is_admin() then raise exception 'Réservé à l’administration.'; end if;
  if p_mois is null or p_mois < 1 or p_mois > 36 then raise exception 'Durée invalide (1 à 36 mois).'; end if;
  select * into d from public.dossiers where id = p_dossier;
  if d.id is null then raise exception 'Abonnement introuvable.'; end if;
  nf := (greatest(coalesce(d.abonnement_fin, current_date), current_date) + make_interval(months => p_mois))::date;
  garde := d.prix_a_vie and d.prix_garanti_jusqu is not null and d.prix_garanti_jusqu >= current_date;
  np := case when garde then d.prix else coalesce(public.prix_formule(d.zone, d.formule, d.periode), d.prix) end;
  update public.dossiers set abonnement_fin = nf, abonnement_debut = coalesce(abonnement_debut, current_date), prix = np,
    prix_a_vie = garde where id = p_dossier;
  update public.boutiques b set visible = true, masquee_pour = null
  from auth.users u where u.id = b.owner and lower(u.email) = lower(d.email) and b.masquee_pour = 'abonnement';
  insert into public.vendeurs_suivi (email, de, type, texte, lu_admin)
  values (lower(d.email), 'admin', 'info', 'Ton abonnement ' || d.formule || ' est prolongé jusqu’au ' || to_char(nf, 'DD/MM/YYYY') || '. Merci de ta confiance !', true);
  return nf;
end $$;
revoke all on function public.admin_prolonger(uuid, integer) from public, anon;
grant execute on function public.admin_prolonger(uuid, integer) to authenticated;

-- 30 days before the end of the guarantee: one message and one e-mail
create or replace function public.fondateurs_garantie_rappel()
returns integer language plpgsql security definer set search_path = public as $$
declare d record; e record; nb integer := 0; t text;
begin
  select * into e from public.reglages_email where id = 1;
  for d in select * from public.dossiers where statut = 'actif' and prix_a_vie and prix_garanti_jusqu is not null
             and prix_garanti_jusqu between current_date and current_date + 30
             and not exists (select 1 from public.abonnement_rappels r where r.email = lower(dossiers.email) and r.fin = dossiers.prix_garanti_jusqu and r.etape = -30)
  loop
    t := 'Ton prix de vendeur fondateur est garanti jusqu’au ' || to_char(d.prix_garanti_jusqu, 'DD/MM/YYYY') || '. Après cette date, ton abonnement passera au prix en vigueur. Merci d’avoir fait partie des premiers vendeurs Yiriclick !';
    insert into public.vendeurs_suivi (email, de, type, texte, lu_admin) values (lower(d.email), 'systeme', 'relance', t, true);
    if e.id is not null then
      perform public.envoyer_email(d.email, 'Ton prix fondateur Yiriclick', public.email_cadre('Ton prix fondateur', '<p style="font-size:15px;line-height:1.5">' || t || '</p>', coalesce(e.site_url, 'https://yiriclick.com/') || 'vendeur#abo', 'Voir mon abonnement'), 'fondateur_garantie');
    end if;
    insert into public.abonnement_rappels (email, fin, etape) values (lower(d.email), d.prix_garanti_jusqu, -30) on conflict do nothing;
    nb := nb + 1;
  end loop;
  return nb;
end $$;
revoke all on function public.fondateurs_garantie_rappel() from public, anon, authenticated;
do $$ begin
  if to_regclass('cron.job') is not null then
    perform cron.schedule('yiriclick-fondateurs', '47 10 * * *', 'select public.fondateurs_garantie_rappel()');
  end if;
end $$;

create or replace function public.mon_abonnement()
returns jsonb language sql stable security definer set search_path = public as $$
  with d as (select * from public.dossiers where lower(email) = lower(auth.jwt() ->> 'email') and statut = 'actif' order by created_at desc limit 1),
       b as (select * from public.boutiques where owner = auth.uid() limit 1),
       g as (select coalesce((select grace_jours from public.reglages_abonnements where id = 1), 7) as j)
  select jsonb_build_object(
    'formule', (select formule from d), 'periode', (select periode from d), 'zone', (select zone from d),
    'prix', (select prix from d), 'prix_a_vie', (select prix_a_vie from d), 'garanti_jusqu', (select prix_garanti_jusqu from d),
    'debut', (select abonnement_debut from d), 'fin', (select abonnement_fin from d), 'grace', (select j from g),
    'visible', (select visible from b), 'masquee_pour', (select masquee_pour from b),
    'demande', (select visibilite_demande from b), 'demande_le', (select visibilite_demande_le from b),
    'boost', (select case when boost_fin is null or boost_fin >= current_date then boost end from b),
    'boost_debut', (select boost_debut from b), 'boost_fin', (select boost_fin from b), 'boost_raison', (select boost_raison from b),
    'boost_vues', (select count(*) from public.evenements ev join b on ev.boutique_id = b.id
                   where ev.type = 'vue_boutique' and b.boost is not null and ev.created_at >= coalesce(b.boost_debut, current_date)),
    'non_lus', (select count(*) from public.vendeurs_suivi s where lower(s.email) = lower(auth.jwt() ->> 'email') and s.type <> 'note' and not s.lu_vendeur)
  );
$$;

insert into public.versions_base (version) values ('v28') on conflict (version) do nothing;
