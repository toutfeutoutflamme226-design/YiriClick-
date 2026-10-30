-- =====================================================================
-- Yiriclick – base v25 : le néerlandais dans la base de données
-- À coller dans Supabase > SQL Editor > New query, puis "Run". Prérequis : v24. Peut être relancé sans risque.
--  1. Les colonnes « langue » acceptent aussi 'nl' (inscriptions, dossiers vendeurs, visites, messages de contact).
--     Avant ce script, un visiteur néerlandophone était enregistré en anglais.
--  2. Les e-mails de relance des vendeurs en essai existent aussi en néerlandais.
-- =====================================================================

-- 1. Langues acceptées ----------------------------------------------------------------
do $$
declare r record; t text;
begin
  for r in
    select c.conrelid::regclass::text as tbl, c.conname
    from pg_constraint c join pg_attribute a on a.attrelid = c.conrelid and a.attnum = any (c.conkey)
    where c.contype = 'c' and a.attname = 'langue' and c.connamespace = 'public'::regnamespace
      and c.conrelid::regclass::text in ('inscriptions', 'dossiers', 'visites', 'messages_contact', 'public.inscriptions', 'public.dossiers', 'public.visites', 'public.messages_contact')
  loop
    execute format('alter table %s drop constraint %I', r.tbl, r.conname);
  end loop;
  foreach t in array array['inscriptions', 'dossiers', 'visites', 'messages_contact'] loop
    if to_regclass('public.' || t) is not null then
      execute format('alter table public.%I add constraint %I check (langue in (''fr'', ''en'', ''es'', ''nl''))', t, t || '_langue_check');
    end if;
  end loop;
end $$;

-- Le site demande à la base si le néerlandais est accepté avant de l'enregistrer
create or replace function public.langues_acceptees()
returns text[] language sql immutable as $$ select array['fr', 'en', 'es', 'nl'] $$;
grant execute on function public.langues_acceptees() to anon, authenticated;

-- 2. Textes des relances, néerlandais compris ------------------------------------------
create or replace function public.relance_textes(p_etape text, p_lang text, p_prenom text, p_produits int)
returns jsonb language plpgsql immutable as $$
declare l text := case when p_lang in ('en', 'es', 'nl') then p_lang else 'fr' end; n text := coalesce(nullif(p_prenom, ''), '');
begin
  if p_etape = 'acces_48h' then
    return case l
      when 'nl' then jsonb_build_object('sujet', 'Je Yiriclick-winkel wacht op je', 'titre', 'Je gratis proefperiode is gestart' || case when n <> '' then ', ' || n else '' end,
        'corps', '<p>Je hebt je twee dagen geleden ingeschreven op Yiriclick, maar je toegang is nog niet aangemaakt. Het kost een minuut: kies je wachtwoord met hetzelfde e-mailadres, bevestig het, en je winkel is van jou.</p><p>Yiri, je assistent, begeleidt je daarna stap voor stap.</p>', 'bouton', 'Mijn toegang maken')
      when 'en' then jsonb_build_object('sujet', 'Your Yiriclick shop is waiting for you', 'titre', 'Your free trial is open' || case when n <> '' then ', ' || n else '' end,
        'corps', '<p>You signed up for Yiriclick two days ago, but your access is not created yet. It takes one minute: choose your password with the same e-mail address, confirm it, and your shop is yours.</p><p>Yiri, your assistant, then guides you step by step.</p>', 'bouton', 'Create my access')
      when 'es' then jsonb_build_object('sujet', 'Tu tienda Yiriclick te espera', 'titre', 'Tu prueba gratuita está abierta' || case when n <> '' then ', ' || n else '' end,
        'corps', '<p>Te inscribiste en Yiriclick hace dos días, pero tu acceso aún no está creado. Solo te lleva un minuto: elige tu contraseña con el mismo correo, confírmalo y tu tienda es tuya.</p><p>Yiri, tu asistente, te guía después paso a paso.</p>', 'bouton', 'Crear mi acceso')
      else jsonb_build_object('sujet', 'Ta boutique Yiriclick t’attend', 'titre', 'Ton essai gratuit est ouvert' || case when n <> '' then ', ' || n else '' end,
        'corps', '<p>Tu t’es inscrit sur Yiriclick il y a deux jours, mais ton accès n’est pas encore créé. Ça prend une minute : choisis ton mot de passe avec la même adresse e-mail, confirme-la, et ta boutique est à toi.</p><p>Yiri, ton assistante, te guide ensuite pas à pas.</p>', 'bouton', 'Créer mon accès') end;
  elsif p_etape = 'produit_48h' then
    return case l
      when 'nl' then jsonb_build_object('sujet', 'Voeg je eerste product toe in 2 minuten', 'titre', 'Je winkel is nog leeg' || case when n <> '' then ', ' || n else '' end,
        'corps', '<p>Klanten kunnen alleen bestellen wat ze zien. Voeg nu je eerste product toe: een scherpe foto bij daglicht, een naam, een prijs. Meer is het niet.</p><p>Tip: begin met je 5 bestverkopende producten, de rest voeg je later toe.</p>', 'bouton', 'Een product toevoegen')
      when 'en' then jsonb_build_object('sujet', 'Add your first product in 2 minutes', 'titre', 'Your shop is still empty' || case when n <> '' then ', ' || n else '' end,
        'corps', '<p>Customers can only order what they can see. Add your first product now: a sharp photo in daylight, a name, a price. That is all.</p><p>Tip: start with your 5 best sellers, you can add the rest later.</p>', 'bouton', 'Add a product')
      when 'es' then jsonb_build_object('sujet', 'Añade tu primer producto en 2 minutos', 'titre', 'Tu tienda todavía está vacía' || case when n <> '' then ', ' || n else '' end,
        'corps', '<p>Los clientes solo pueden pedir lo que ven. Añade ahora tu primer producto: una foto nítida con luz de día, un nombre y un precio. Nada más.</p><p>Consejo: empieza por tus 5 productos más vendidos, el resto lo añades después.</p>', 'bouton', 'Añadir un producto')
      else jsonb_build_object('sujet', 'Ajoute ton premier produit en 2 minutes', 'titre', 'Ta boutique est encore vide' || case when n <> '' then ', ' || n else '' end,
        'corps', '<p>Les clients ne peuvent commander que ce qu’ils voient. Ajoute ton premier produit maintenant : une photo nette à la lumière du jour, un nom, un prix. C’est tout.</p><p>Astuce : commence par tes 5 meilleures ventes, tu ajouteras le reste après.</p>', 'bouton', 'Ajouter un produit') end;
  elsif p_etape = 'jour7' then
    if p_produits > 0 then
      return case l
        when 'nl' then jsonb_build_object('sujet', 'Halverwege je proefperiode: deel je winkel', 'titre', 'Bravo' || case when n <> '' then ' ' || n else '' end || '!',
          'corps', '<p>Al een week, en je winkel heeft ' || p_produits || ' product(en). Breng nu klanten binnen: zet je link in je WhatsApp-status, in je bio op Instagram, TikTok en Facebook, en print je QR-code (tabblad Marketing).</p>', 'bouton', 'Mijn marketingtools openen')
        when 'en' then jsonb_build_object('sujet', 'Halfway through your trial: share your shop', 'titre', 'Well done' || case when n <> '' then ', ' || n else '' end || '!',
          'corps', '<p>One week already, and your shop has ' || p_produits || ' product(s). Now bring customers in: put your link in your WhatsApp status, in your Instagram, TikTok and Facebook bio, and print your QR code (Marketing tab).</p>', 'bouton', 'Open my Marketing tools')
        when 'es' then jsonb_build_object('sujet', 'Mitad de tu prueba: comparte tu tienda', 'titre', '¡Bravo' || case when n <> '' then ', ' || n else '' end || '!',
          'corps', '<p>Ya una semana, y tu tienda tiene ' || p_produits || ' producto(s). Ahora atrae clientes: pon tu enlace en tu estado de WhatsApp, en tu bio de Instagram, TikTok y Facebook, e imprime tu código QR (pestaña Marketing).</p>', 'bouton', 'Abrir mis herramientas de marketing')
        else jsonb_build_object('sujet', 'Mi-parcours de ton essai : partage ta boutique', 'titre', 'Bravo' || case when n <> '' then ' ' || n else '' end || ' !',
          'corps', '<p>Déjà une semaine, et ta boutique compte ' || p_produits || ' produit(s). Maintenant, fais venir les clients : mets ton lien en statut WhatsApp, dans ta bio Instagram, TikTok et Facebook, et imprime ton QR code (onglet Marketing).</p>', 'bouton', 'Ouvrir mes outils Marketing') end;
    end if;
    return case l
      when 'nl' then jsonb_build_object('sujet', 'Nog een week om van je proefperiode te profiteren', 'titre', 'Hulp nodig' || case when n <> '' then ', ' || n else '' end || '?',
        'corps', '<p>Je proefperiode is halverwege en je winkel heeft nog geen producten. Yiri, je assistent in de verkopersruimte, laat je elke stap zien. Kom je er niet uit? Antwoord op deze e-mail of stuur ons een WhatsApp: we zetten je winkel samen met je op, op afstand.</p>', 'bouton', 'Mijn verkopersruimte openen')
      when 'en' then jsonb_build_object('sujet', 'One week left to make the most of your trial', 'titre', 'Need a hand' || case when n <> '' then ', ' || n else '' end || '?',
        'corps', '<p>Your trial is halfway through and your shop has no product yet. Yiri, your assistant in the seller space, shows you each step. Stuck? Reply to this e-mail or write to us on WhatsApp: we set up your shop with you, remotely.</p>', 'bouton', 'Open my seller space')
      when 'es' then jsonb_build_object('sujet', 'Te queda una semana para aprovechar tu prueba', 'titre', '¿Te echamos una mano' || case when n <> '' then ', ' || n else '' end || '?',
        'corps', '<p>Tu prueba va por la mitad y tu tienda todavía no tiene productos. Yiri, tu asistente en el espacio vendedor, te muestra cada paso. ¿Atascado? Responde a este correo o escríbenos por WhatsApp: montamos tu tienda contigo, a distancia.</p>', 'bouton', 'Abrir mi espacio vendedor')
      else jsonb_build_object('sujet', 'Encore une semaine pour profiter de ton essai', 'titre', 'Besoin d’un coup de main' || case when n <> '' then ' ' || n else '' end || ' ?',
        'corps', '<p>Ton essai est à mi-parcours et ta boutique n’a pas encore de produit. Yiri, ton assistante dans l’espace vendeur, te montre chaque étape. Tu bloques ? Réponds à cet e-mail ou écris-nous sur WhatsApp : on installe ta boutique avec toi, à distance.</p>', 'bouton', 'Ouvrir mon espace vendeur') end;
  else -- jour12
    return case l
      when 'nl' then jsonb_build_object('sujet', 'Je gratis proefperiode eindigt over 2 dagen', 'titre', 'Houd je winkel open' || case when n <> '' then ', ' || n else '' end,
        'corps', '<p>Je proefperiode van 14 dagen eindigt over 2 dagen. Je winkel en je producten blijven bewaard, maar om verder te verkopen kies je je formule en stuur je je verificatiedossier (identiteitsbewijs).</p><p>Formule Basis: 7 500 FCFA of € 15 per maand.</p>', 'bouton', 'Mijn formule kiezen')
      when 'en' then jsonb_build_object('sujet', 'Your free trial ends in 2 days', 'titre', 'Keep your shop open' || case when n <> '' then ', ' || n else '' end,
        'corps', '<p>Your 14-day trial ends in 2 days. Your shop and your products are kept, but to keep selling, choose your plan and send your verification file (ID).</p><p>Basic plan: 7,500 FCFA or €15 per month.</p>', 'bouton', 'Choose my plan')
      when 'es' then jsonb_build_object('sujet', 'Tu prueba gratuita termina en 2 días', 'titre', 'Mantén tu tienda abierta' || case when n <> '' then ', ' || n else '' end,
        'corps', '<p>Tu prueba de 14 días termina en 2 días. Tu tienda y tus productos se conservan, pero para seguir vendiendo, elige tu plan y envía tu expediente de verificación (documento de identidad).</p><p>Plan Básico: 7 500 FCFA o 15 € al mes.</p>', 'bouton', 'Elegir mi plan')
      else jsonb_build_object('sujet', 'Ton essai gratuit se termine dans 2 jours', 'titre', 'Garde ta boutique ouverte' || case when n <> '' then ', ' || n else '' end,
        'corps', '<p>Ton essai de 14 jours se termine dans 2 jours. Ta boutique et tes produits sont conservés, mais pour continuer à vendre, choisis ta formule et envoie ton dossier de vérification (pièce d’identité).</p><p>Formule Basique : 7 500 FCFA ou 15 € par mois.</p>', 'bouton', 'Choisir ma formule') end;
  end if;
end $$;


insert into public.versions_base (version) values ('v25') on conflict (version) do nothing;
