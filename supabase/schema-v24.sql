-- =====================================================================
-- Yiriclick – base v24 : relances des nouveaux vendeurs et suivi de leur parcours
-- À coller dans Supabase > SQL Editor > New query, puis "Run". Prérequis : v23 (et v9 pour les e-mails).
-- Peut être relancé sans risque.
--  1. Chaque jour à 11 h 17 (heure d'Amsterdam en hiver), un e-mail part aux vendeurs en essai gratuit qui en ont besoin :
--     - 48 h après l'inscription, s'ils n'ont pas encore créé leur accès ;
--     - 48 h après l'inscription, s'ils n'ont encore publié aucun produit ;
--     - au 7e jour : point à mi-parcours (bravo ou coup de pouce) ;
--     - au 12e jour : l'essai se termine dans 2 jours, choisir sa formule (pas envoyé aux vendeurs fondateurs).
--     Un vendeur ne reçoit qu'un seul e-mail par étape, jamais deux le même jour. En français, anglais ou espagnol
--     selon sa langue d'inscription. À couper dans Table Editor > reglages_email > relances_vendeurs.
--  2. L'admin voit où en est chaque vendeur en essai (accès créé, boutique, produits, boutique complète).
-- =====================================================================

alter table public.reglages_email add column if not exists relances_vendeurs boolean not null default true;

-- 1. Journal des relances : une ligne par vendeur et par étape --------------------
create table if not exists public.relances_vendeurs (
  email      text not null,
  etape      text not null check (etape in ('acces_48h', 'produit_48h', 'jour7', 'jour12')),
  envoye_le  timestamptz not null default now(),
  envoye     boolean not null default true,   -- false = étape passée sans e-mail (déjà dépassée à l'installation, ou plus utile)
  primary key (email, etape)
);
alter table public.relances_vendeurs enable row level security;
revoke all on table public.relances_vendeurs from anon, authenticated;
grant select on table public.relances_vendeurs to authenticated;
drop policy if exists "Admin lit relances" on public.relances_vendeurs;
create policy "Admin lit relances" on public.relances_vendeurs for select to authenticated using (public.is_admin());

-- 2. Où en est chaque vendeur en essai -------------------------------------------
create or replace function public.vendeur_etat(p_email text)
returns jsonb language sql stable security definer set search_path = public as $$
  with u as (select id, email_confirmed_at from auth.users where lower(email) = lower(p_email) order by created_at limit 1),
       b as (select bo.* from public.boutiques bo join u on bo.owner = u.id order by bo.created_at limit 1),
       p as (select count(*) as n,
                    count(*) filter (where cardinality(pr.photos) = 0) as sans_photo,
                    bool_or(coalesce(pr.a_la_une, false)) as une
             from public.produits pr join b on pr.boutique_id = b.id)
  select jsonb_build_object(
    'acces', exists (select 1 from u where email_confirmed_at is not null),
    'boutique', exists (select 1 from b),
    'boutique_nom', (select nom from b),
    'slug', (select slug from b),
    'fondateur', coalesce((select fondateur from b), false),
    'produits', coalesce((select n from p), 0),
    'etapes', (select
        (case when b.logo is not null then 1 else 0 end) + (case when b.couverture is not null then 1 else 0 end)
      + (case when coalesce(b.slogan, '') <> '' then 1 else 0 end) + (case when char_length(coalesce(b.description, '')) >= 40 then 1 else 0 end)
      + (case when char_length(regexp_replace(coalesce(b.whatsapp, ''), '\D', '', 'g')) >= 8 then 1 else 0 end)
      + (case when coalesce(b.livraison, '') <> '' then 1 else 0 end)
      + (case when exists (select 1 from jsonb_each_text(coalesce(b.reseaux, '{}'::jsonb)) r where coalesce(r.value, '') <> '') then 1 else 0 end)
      + (case when coalesce((select n from p), 0) >= 5 then 1 else 0 end)
      + (case when coalesce((select n from p), 0) > 0 and coalesce((select sans_photo from p), 0) = 0 then 1 else 0 end)
      + (case when coalesce((select une from p), false) then 1 else 0 end) + 1
      from b)
  );
$$;
revoke all on function public.vendeur_etat(text) from public, anon, authenticated;

-- 3. Textes des e-mails (fr / en / es) -------------------------------------------
create or replace function public.relance_textes(p_etape text, p_lang text, p_prenom text, p_produits int)
returns jsonb language plpgsql immutable as $$
declare l text := case when p_lang in ('en', 'es') then p_lang else 'fr' end; n text := coalesce(nullif(p_prenom, ''), '');
begin
  if p_etape = 'acces_48h' then
    return case l
      when 'en' then jsonb_build_object('sujet', 'Your Yiriclick shop is waiting for you', 'titre', 'Your free trial is open' || case when n <> '' then ', ' || n else '' end,
        'corps', '<p>You signed up for Yiriclick two days ago, but your access is not created yet. It takes one minute: choose your password with the same e-mail address, confirm it, and your shop is yours.</p><p>Yiri, your assistant, then guides you step by step.</p>', 'bouton', 'Create my access')
      when 'es' then jsonb_build_object('sujet', 'Tu tienda Yiriclick te espera', 'titre', 'Tu prueba gratuita está abierta' || case when n <> '' then ', ' || n else '' end,
        'corps', '<p>Te inscribiste en Yiriclick hace dos días, pero tu acceso aún no está creado. Solo te lleva un minuto: elige tu contraseña con el mismo correo, confírmalo y tu tienda es tuya.</p><p>Yiri, tu asistente, te guía después paso a paso.</p>', 'bouton', 'Crear mi acceso')
      else jsonb_build_object('sujet', 'Ta boutique Yiriclick t’attend', 'titre', 'Ton essai gratuit est ouvert' || case when n <> '' then ', ' || n else '' end,
        'corps', '<p>Tu t’es inscrit sur Yiriclick il y a deux jours, mais ton accès n’est pas encore créé. Ça prend une minute : choisis ton mot de passe avec la même adresse e-mail, confirme-la, et ta boutique est à toi.</p><p>Yiri, ton assistante, te guide ensuite pas à pas.</p>', 'bouton', 'Créer mon accès') end;
  elsif p_etape = 'produit_48h' then
    return case l
      when 'en' then jsonb_build_object('sujet', 'Add your first product in 2 minutes', 'titre', 'Your shop is still empty' || case when n <> '' then ', ' || n else '' end,
        'corps', '<p>Customers can only order what they can see. Add your first product now: a sharp photo in daylight, a name, a price. That is all.</p><p>Tip: start with your 5 best sellers, you can add the rest later.</p>', 'bouton', 'Add a product')
      when 'es' then jsonb_build_object('sujet', 'Añade tu primer producto en 2 minutos', 'titre', 'Tu tienda todavía está vacía' || case when n <> '' then ', ' || n else '' end,
        'corps', '<p>Los clientes solo pueden pedir lo que ven. Añade ahora tu primer producto: una foto nítida con luz de día, un nombre y un precio. Nada más.</p><p>Consejo: empieza por tus 5 productos más vendidos, el resto lo añades después.</p>', 'bouton', 'Añadir un producto')
      else jsonb_build_object('sujet', 'Ajoute ton premier produit en 2 minutes', 'titre', 'Ta boutique est encore vide' || case when n <> '' then ', ' || n else '' end,
        'corps', '<p>Les clients ne peuvent commander que ce qu’ils voient. Ajoute ton premier produit maintenant : une photo nette à la lumière du jour, un nom, un prix. C’est tout.</p><p>Astuce : commence par tes 5 meilleures ventes, tu ajouteras le reste après.</p>', 'bouton', 'Ajouter un produit') end;
  elsif p_etape = 'jour7' then
    if p_produits > 0 then
      return case l
        when 'en' then jsonb_build_object('sujet', 'Halfway through your trial: share your shop', 'titre', 'Well done' || case when n <> '' then ', ' || n else '' end || '!',
          'corps', '<p>One week already, and your shop has ' || p_produits || ' product(s). Now bring customers in: put your link in your WhatsApp status, in your Instagram, TikTok and Facebook bio, and print your QR code (Marketing tab).</p>', 'bouton', 'Open my Marketing tools')
        when 'es' then jsonb_build_object('sujet', 'Mitad de tu prueba: comparte tu tienda', 'titre', '¡Bravo' || case when n <> '' then ', ' || n else '' end || '!',
          'corps', '<p>Ya una semana, y tu tienda tiene ' || p_produits || ' producto(s). Ahora atrae clientes: pon tu enlace en tu estado de WhatsApp, en tu bio de Instagram, TikTok y Facebook, e imprime tu código QR (pestaña Marketing).</p>', 'bouton', 'Abrir mis herramientas de marketing')
        else jsonb_build_object('sujet', 'Mi-parcours de ton essai : partage ta boutique', 'titre', 'Bravo' || case when n <> '' then ' ' || n else '' end || ' !',
          'corps', '<p>Déjà une semaine, et ta boutique compte ' || p_produits || ' produit(s). Maintenant, fais venir les clients : mets ton lien en statut WhatsApp, dans ta bio Instagram, TikTok et Facebook, et imprime ton QR code (onglet Marketing).</p>', 'bouton', 'Ouvrir mes outils Marketing') end;
    end if;
    return case l
      when 'en' then jsonb_build_object('sujet', 'One week left to make the most of your trial', 'titre', 'Need a hand' || case when n <> '' then ', ' || n else '' end || '?',
        'corps', '<p>Your trial is halfway through and your shop has no product yet. Yiri, your assistant in the seller space, shows you each step. Stuck? Reply to this e-mail or write to us on WhatsApp: we set up your shop with you, remotely.</p>', 'bouton', 'Open my seller space')
      when 'es' then jsonb_build_object('sujet', 'Te queda una semana para aprovechar tu prueba', 'titre', '¿Te echamos una mano' || case when n <> '' then ', ' || n else '' end || '?',
        'corps', '<p>Tu prueba va por la mitad y tu tienda todavía no tiene productos. Yiri, tu asistente en el espacio vendedor, te muestra cada paso. ¿Atascado? Responde a este correo o escríbenos por WhatsApp: montamos tu tienda contigo, a distancia.</p>', 'bouton', 'Abrir mi espacio vendedor')
      else jsonb_build_object('sujet', 'Encore une semaine pour profiter de ton essai', 'titre', 'Besoin d’un coup de main' || case when n <> '' then ' ' || n else '' end || ' ?',
        'corps', '<p>Ton essai est à mi-parcours et ta boutique n’a pas encore de produit. Yiri, ton assistante dans l’espace vendeur, te montre chaque étape. Tu bloques ? Réponds à cet e-mail ou écris-nous sur WhatsApp : on installe ta boutique avec toi, à distance.</p>', 'bouton', 'Ouvrir mon espace vendeur') end;
  else -- jour12
    return case l
      when 'en' then jsonb_build_object('sujet', 'Your free trial ends in 2 days', 'titre', 'Keep your shop open' || case when n <> '' then ', ' || n else '' end,
        'corps', '<p>Your 14-day trial ends in 2 days. Your shop and your products are kept, but to keep selling, choose your plan and send your verification file (ID).</p><p>Basic plan: 7,500 FCFA or €15 per month.</p>', 'bouton', 'Choose my plan')
      when 'es' then jsonb_build_object('sujet', 'Tu prueba gratuita termina en 2 días', 'titre', 'Mantén tu tienda abierta' || case when n <> '' then ', ' || n else '' end,
        'corps', '<p>Tu prueba de 14 días termina en 2 días. Tu tienda y tus productos se conservan, pero para seguir vendiendo, elige tu plan y envía tu expediente de verificación (documento de identidad).</p><p>Plan Básico: 7 500 FCFA o 15 € al mes.</p>', 'bouton', 'Elegir mi plan')
      else jsonb_build_object('sujet', 'Ton essai gratuit se termine dans 2 jours', 'titre', 'Garde ta boutique ouverte' || case when n <> '' then ', ' || n else '' end,
        'corps', '<p>Ton essai de 14 jours se termine dans 2 jours. Ta boutique et tes produits sont conservés, mais pour continuer à vendre, choisis ta formule et envoie ton dossier de vérification (pièce d’identité).</p><p>Formule Basique : 7 500 FCFA ou 15 € par mois.</p>', 'bouton', 'Choisir ma formule') end;
  end if;
end $$;

-- 4. La relance quotidienne --------------------------------------------------------
create or replace function public.vendeurs_relancer()
returns integer language plpgsql security definer set search_path = public as $$
declare r record; i record; e jsonb; debut timestamptz; etapes text[]; dues text[]; cible text; tx jsonb; lien text; prenom text; nb integer := 0;
begin
  select * into r from public.reglages_email where id = 1;
  if r is null or not r.relances_vendeurs then return 0; end if;
  for i in
    select distinct on (lower(x.email)) x.* from public.inscriptions x
    where x.statut = 'actif' and x.essai_fin is not null and x.essai_fin > now() and x.essai_fin < now() + interval '15 days'
    order by lower(x.email), x.created_at desc
  loop
    debut := i.essai_fin - interval '14 days';
    e := public.vendeur_etat(i.email);
    dues := '{}';
    if now() >= debut + interval '48 hours' and not (e ->> 'acces')::boolean then dues := dues || 'acces_48h'::text; end if;
    if now() >= debut + interval '48 hours' and (e ->> 'acces')::boolean and (e ->> 'produits')::int = 0 then dues := dues || 'produit_48h'::text; end if;
    if now() >= debut + interval '7 days' then dues := dues || 'jour7'::text; end if;
    if now() >= debut + interval '12 days' and not (e ->> 'fondateur')::boolean then dues := dues || 'jour12'::text; end if;
    -- only the latest step not yet handled is e-mailed; earlier ones are marked as passed (no pile of e-mails at once)
    select array_agg(d) into etapes from unnest(dues) d where not exists (select 1 from public.relances_vendeurs rv where rv.email = lower(i.email) and rv.etape = d);
    if etapes is null or cardinality(etapes) = 0 then continue; end if;
    cible := etapes[cardinality(etapes)];
    insert into public.relances_vendeurs (email, etape, envoye) select lower(i.email), d, false from unnest(etapes) d where d <> cible on conflict do nothing;
    prenom := split_part(trim(coalesce(i.nom, '')), ' ', 1);
    tx := public.relance_textes(cible, i.langue, prenom, (e ->> 'produits')::int);
    lien := case cible
      when 'acces_48h' then r.site_url || 'vendeur.html?inscrit=' || replace(lower(i.email), '+', '%2B')
      when 'produit_48h' then r.site_url || 'vendeur.html#prod'
      when 'jour7' then r.site_url || 'vendeur.html#' || case when (e ->> 'produits')::int > 0 then 'share' else 'dash' end
      else r.site_url || 'vendre?email=' || replace(lower(i.email), '+', '%2B') || '#dossier-basique' end;
    perform public.envoyer_email(i.email, tx ->> 'sujet', public.email_cadre(tx ->> 'titre', '<div style="font-size:15px;line-height:1.5">' || (tx ->> 'corps') || '</div>', lien, tx ->> 'bouton'), 'relance_' || cible);
    insert into public.relances_vendeurs (email, etape, envoye) values (lower(i.email), cible, true) on conflict do nothing;
    nb := nb + 1;
  end loop;
  return nb;
end $$;
revoke all on function public.vendeurs_relancer() from public, anon, authenticated;

-- Installation : les étapes déjà dépassées des essais en cours sont marquées « passées » (pas de rattrapage)
insert into public.relances_vendeurs (email, etape, envoye)
select lower(x.email), s.etape, false
from public.inscriptions x
cross join lateral (values ('acces_48h', interval '48 hours'), ('produit_48h', interval '48 hours'), ('jour7', interval '7 days'), ('jour12', interval '12 days')) as s(etape, delai)
where x.statut = 'actif' and x.essai_fin is not null and now() >= x.essai_fin - interval '14 days' + s.delai
  and not exists (select 1 from public.versions_base where version = 'v24')
on conflict do nothing;

do $$ begin
  if to_regclass('cron.job') is not null then
    perform cron.schedule('yiriclick-relances', '17 10 * * *', 'select public.vendeurs_relancer()');
  end if;
end $$;

-- 5. Parcours des vendeurs en essai, pour l'admin --------------------------------------
create or replace function public.vendeurs_parcours()
returns table (email text, nom text, boutique_inscrite text, inscrit_le timestamptz, essai_fin timestamptz, langue text, etat jsonb, relances jsonb)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'Réservé à l’administration.'; end if;
  return query
    select x.email, x.nom, x.boutique, x.essai_fin - interval '14 days', x.essai_fin, x.langue, public.vendeur_etat(x.email),
      coalesce((select jsonb_agg(jsonb_build_object('etape', rv.etape, 'le', rv.envoye_le, 'envoye', rv.envoye) order by rv.envoye_le)
                from public.relances_vendeurs rv where rv.email = lower(x.email)), '[]'::jsonb)
    from (select distinct on (lower(i.email)) i.* from public.inscriptions i
          where i.statut = 'actif' and i.essai_fin is not null and i.essai_fin > now() - interval '30 days'
          order by lower(i.email), i.created_at desc) x
    order by x.essai_fin desc;
end $$;
revoke all on function public.vendeurs_parcours() from public, anon;
grant execute on function public.vendeurs_parcours() to authenticated;

insert into public.versions_base (version) values ('v24') on conflict (version) do nothing;
