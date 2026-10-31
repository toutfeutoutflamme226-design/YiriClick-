-- =====================================================================
-- Yiriclick – base v31 : e-mails aux vendeurs dans leur langue
-- À coller dans Supabase > SQL Editor > New query, puis "Run". Prérequis : v30. Peut être relancé sans risque.
--  1. L'e-mail « Nouvelle commande » part dans la langue du vendeur (français, anglais, espagnol ou néerlandais),
--     celle de son inscription ou de son dossier. Avant, il partait en français pour tout le monde.
--  2. Le bas de chaque e-mail (« E-mail automatique de Yiriclick… ») suit la langue de l'e-mail : relances d'essai,
--     rappels d'abonnement et commandes. Les e-mails pour l'admin restent en français.
-- =====================================================================

-- 1. Cadre commun : le pied de page suit la langue choisie juste avant (réglage yc.lang, français par défaut)
create or replace function public.email_cadre(titre text, corps text, lien text, bouton text)
returns text language sql stable as $$
  select '<!doctype html><html><body style="margin:0;background:#F3F6F7;font-family:Arial,Helvetica,sans-serif;color:#10232A">'
    || '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#F3F6F7;padding:20px 0"><tr><td align="center">'
    || '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:560px;background:#FFFFFF">'
    || '<tr><td style="background:#10232A;padding:16px 22px;font-size:22px;font-weight:bold"><span style="color:#FF7A2E">yiri</span><span style="color:#4FC7CF">click</span></td></tr>'
    || '<tr><td style="padding:24px 22px 8px"><h1 style="margin:0 0 14px;font-size:22px;line-height:1.25">' || public.html_esc(titre) || '</h1>' || corps || '</td></tr>'
    || case when lien is null then '' else
         '<tr><td style="padding:8px 22px 26px"><a href="' || public.html_esc(lien) || '" style="display:inline-block;background:#FF7A2E;color:#10232A;font-weight:bold;text-decoration:none;padding:13px 22px">' || public.html_esc(bouton) || '</a></td></tr>' end
    || '<tr><td style="padding:14px 22px;border-top:1px solid #D5DEE0;font-size:12px;color:#4A5A5F">'
    || case coalesce(nullif(current_setting('yc.lang', true), ''), 'fr')
         when 'en' then 'Automatic e-mail from Yiriclick, the marketplace for small sellers.'
         when 'es' then 'Correo automático de Yiriclick, el mercado de los pequeños vendedores.'
         when 'nl' then 'Automatische e-mail van Yiriclick, de marktplaats van kleine verkopers.'
         else 'E-mail automatique de Yiriclick, la place de marché des petits vendeurs.' end
    || '</td></tr>'
    || '</table></td></tr></table></body></html>';
$$;

-- 2. Langue d'un vendeur : celle de son dernier dossier, sinon de sa dernière inscription
create or replace function public.vendeur_langue(p_email text)
returns text language sql stable security definer set search_path = public as $$
  select coalesce(
    (select d.langue from public.dossiers d where lower(d.email) = lower(p_email) and d.langue is not null order by d.created_at desc limit 1),
    (select i.langue from public.inscriptions i where lower(i.email) = lower(p_email) and i.langue is not null order by i.created_at desc limit 1),
    'fr');
$$;
revoke all on function public.vendeur_langue(text) from public, anon, authenticated;

-- 3. Nouvelle commande -> e-mail au vendeur dans sa langue (copie admin en français)
create or replace function public.commandes_email()
returns trigger language plpgsql security definer set search_path = public as $$
declare b record; r record; a jsonb; lignes text := ''; n integer := 0; corps text; corps_admin text; lien text; wa text; l text; tx jsonb; quand text;
begin
  select * into r from public.reglages_email where id = 1;
  if r is null then return new; end if;
  select bo.nom, bo.notif_email, u.email into b from public.boutiques bo join auth.users u on u.id = bo.owner where bo.id = new.boutique_id;
  l := public.vendeur_langue(b.email); if l not in ('fr', 'en', 'es', 'nl') then l := 'fr'; end if;
  for a in select * from jsonb_array_elements(new.articles) loop
    n := n + (a ->> 'qty')::integer;
    lignes := lignes || '<tr><td style="padding:6px 0;border-bottom:1px solid #EEF2F3">' || (a ->> 'qty') || ' × ' || public.html_esc(a ->> 'nom')
      || case when jsonb_typeof(a -> 'v') = 'array' then ' <span style="color:#4A5A5F">(' || public.html_esc((select string_agg(x, ' / ') from jsonb_array_elements_text(a -> 'v') x)) || ')</span>' else '' end
      || '</td><td align="right" style="padding:6px 0;border-bottom:1px solid #EEF2F3;white-space:nowrap">' || public.prix_txt((a ->> 'prix')::numeric * (a ->> 'qty')::integer, a ->> 'devise') || '</td></tr>';
  end loop;
  wa := regexp_replace(new.client_tel, '\D', '', 'g');
  lien := r.site_url || 'vendeur.html#orders';
  quand := to_char(new.created_at at time zone 'Europe/Amsterdam', 'DD/MM/YYYY HH24:MI');
  tx := case l
    when 'en' then jsonb_build_object('recue', 'Order <b>' || new.numero || '</b> received on ' || quand || ' (Amsterdam time).', 'code', 'Code', 'total', 'Total',
      'msg', 'Customer’s message: ', 'wa', 'Write to the customer on WhatsApp', 'conf', 'Confirm the order in your seller space: the stock is updated and the customer sees the tracking.',
      'sujet', 'New order ' || new.numero || ' · ' || n || ' item(s)', 'titre', 'New order for ' || b.nom, 'bouton', 'See the order')
    when 'es' then jsonb_build_object('recue', 'Pedido <b>' || new.numero || '</b> recibido el ' || quand || ' (hora de Ámsterdam).', 'code', 'Código', 'total', 'Total',
      'msg', 'Mensaje del cliente: ', 'wa', 'Escribir al cliente por WhatsApp', 'conf', 'Confirma el pedido en tu espacio vendedor: el stock se actualiza y el cliente ve el seguimiento.',
      'sujet', 'Nuevo pedido ' || new.numero || ' · ' || n || ' artículo(s)', 'titre', 'Nuevo pedido para ' || b.nom, 'bouton', 'Ver el pedido')
    when 'nl' then jsonb_build_object('recue', 'Bestelling <b>' || new.numero || '</b> ontvangen op ' || quand || ' (Amsterdamse tijd).', 'code', 'Code', 'total', 'Totaal',
      'msg', 'Bericht van de klant: ', 'wa', 'De klant schrijven via WhatsApp', 'conf', 'Bevestig de bestelling in je verkopersruimte: de voorraad wordt bijgewerkt en de klant ziet de status.',
      'sujet', 'Nieuwe bestelling ' || new.numero || ' · ' || n || ' artikel(en)', 'titre', 'Nieuwe bestelling voor ' || b.nom, 'bouton', 'Bekijk de bestelling')
    else jsonb_build_object('recue', 'Commande <b>' || new.numero || '</b> reçue le ' || replace(quand, ' ', ' à ') || ' (heure d’Amsterdam).', 'code', 'Code', 'total', 'Total',
      'msg', 'Message du client : ', 'wa', 'Écrire au client sur WhatsApp', 'conf', 'Confirme la commande dans ton espace vendeur : le stock se met à jour et le client voit le suivi.',
      'sujet', 'Nouvelle commande ' || new.numero || ' · ' || n || ' article(s)', 'titre', 'Nouvelle commande pour ' || b.nom, 'bouton', 'Voir la commande') end;
  corps := '<p style="margin:0 0 14px;font-size:15px">' || (tx ->> 'recue') || '</p>'
    || '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="font-size:15px">' || lignes
    || case when coalesce(new.remise, 0) > 0 then '<tr><td style="padding:6px 0;color:#1E7F4F">' || (tx ->> 'code') || ' ' || public.html_esc(new.code_promo) || '</td><td align="right" style="padding:6px 0;color:#1E7F4F">− ' || public.prix_txt(new.remise, new.devise) || '</td></tr>' else '' end
    || case when new.total is not null then '<tr><td style="padding:10px 0;font-weight:bold">' || (tx ->> 'total') || '</td><td align="right" style="padding:10px 0;font-weight:bold">' || public.prix_txt(new.total, new.devise) || '</td></tr>' else '' end
    || '</table>'
    || '<p style="margin:16px 0 4px;font-size:15px"><b>' || public.html_esc(new.client_nom) || '</b><br>' || public.html_esc(new.client_tel) || '<br>' || public.html_esc(new.client_adresse) || '</p>'
    || case when new.client_note is not null then '<p style="margin:10px 0;padding:10px;background:#F3F6F7;font-size:14px">' || (tx ->> 'msg') || public.html_esc(new.client_note) || '</p>' else '' end
    || '<p style="margin:14px 0 0;font-size:14px"><a href="https://wa.me/' || wa || '" style="color:#0E6E78;font-weight:bold">' || (tx ->> 'wa') || '</a></p>'
    || '<p style="margin:14px 0 0;font-size:14px;color:#4A5A5F">' || (tx ->> 'conf') || '</p>';
  if r.commandes_vendeur and b.notif_email then
    perform set_config('yc.lang', l, true);
    perform public.envoyer_email(b.email, (tx ->> 'sujet') || case when new.total is not null then ' · ' || public.prix_txt(new.total, new.devise) else '' end,
      public.email_cadre(tx ->> 'titre', corps, lien, tx ->> 'bouton'), 'commande');
  end if;
  if r.copie_admin and r.admin_email is not null then
    perform set_config('yc.lang', 'fr', true);
    perform public.envoyer_email(r.admin_email, '[Admin] Commande ' || new.numero || ' · ' || b.nom || ' (vendeur : ' || upper(l) || ')', public.email_cadre('Commande chez ' || b.nom, corps, null, null), 'commande_admin');
  end if;
  return new;
exception when others then
  raise warning 'Yiriclick : e-mail de commande non préparé : %', sqlerrm;
  return new;
end $$;

-- 4. Relances d'essai (v24/v30) et rappels d'abonnement (v26) : le cadre suit la langue du texte
create or replace function public.relance_textes(p_etape text, p_lang text, p_prenom text, p_produits int)
returns jsonb language plpgsql volatile as $$
declare px jsonb := (select valeur -> 'mois' from public.site_reglages where cle = 'prix'); pa text; pe text; l text := case when p_lang in ('en', 'es', 'nl') then p_lang else 'fr' end; n text := coalesce(nullif(p_prenom, ''), '');
begin
  perform set_config('yc.lang', l, true);   -- language of the e-mail frame (footer), base v31
  pa := public.prix_txt(coalesce((px #>> '{af,basique}')::numeric, 6000), 'XOF');
  pe := public.prix_txt(coalesce((px #>> '{eu,basique}')::numeric, 12.9), 'EUR');
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
        'corps', '<p>Je proefperiode van 14 dagen eindigt over 2 dagen. Je winkel en je producten blijven bewaard, maar om verder te verkopen kies je je formule en stuur je je verificatiedossier (identiteitsbewijs).</p><p>Formule Basis: ' || pa || ' of ' || pe || ' per maand.</p>', 'bouton', 'Mijn formule kiezen')
      when 'en' then jsonb_build_object('sujet', 'Your free trial ends in 2 days', 'titre', 'Keep your shop open' || case when n <> '' then ', ' || n else '' end,
        'corps', '<p>Your 14-day trial ends in 2 days. Your shop and your products are kept, but to keep selling, choose your plan and send your verification file (ID).</p><p>Basic plan: ' || pa || ' or ' || pe || ' per month.</p>', 'bouton', 'Choose my plan')
      when 'es' then jsonb_build_object('sujet', 'Tu prueba gratuita termina en 2 días', 'titre', 'Mantén tu tienda abierta' || case when n <> '' then ', ' || n else '' end,
        'corps', '<p>Tu prueba de 14 días termina en 2 días. Tu tienda y tus productos se conservan, pero para seguir vendiendo, elige tu plan y envía tu expediente de verificación (documento de identidad).</p><p>Plan Básico: ' || pa || ' o ' || pe || ' al mes.</p>', 'bouton', 'Elegir mi plan')
      else jsonb_build_object('sujet', 'Ton essai gratuit se termine dans 2 jours', 'titre', 'Garde ta boutique ouverte' || case when n <> '' then ', ' || n else '' end,
        'corps', '<p>Ton essai de 14 jours se termine dans 2 jours. Ta boutique et tes produits sont conservés, mais pour continuer à vendre, choisis ta formule et envoie ton dossier de vérification (pièce d’identité).</p><p>Formule Basique : ' || pa || ' ou ' || pe || ' par mois.</p>', 'bouton', 'Choisir ma formule') end;
  end if;
end $$;

create or replace function public.abonnement_textes(p_jours integer, p_lang text, p_formule text, p_fin date)
returns jsonb language plpgsql volatile as $$
declare l text := case when p_lang in ('en', 'es', 'nl') then p_lang else 'fr' end; f text := to_char(p_fin, 'DD/MM/YYYY');
begin
  perform set_config('yc.lang', l, true);   -- language of the e-mail frame (footer), base v31
  if p_jours < 0 then
    return case l
      when 'en' then jsonb_build_object('sujet', 'Your shop is paused: subscription ended', 'corps', 'Your ' || p_formule || ' subscription ended on ' || f || '. Your shop is hidden for now, nothing is deleted. Renew to reopen it right away.', 'bouton', 'Renew my subscription')
      when 'es' then jsonb_build_object('sujet', 'Tu tienda está en pausa: suscripción terminada', 'corps', 'Tu suscripción ' || p_formule || ' terminó el ' || f || '. Tu tienda está oculta por ahora, no se borra nada. Renueva para reabrirla enseguida.', 'bouton', 'Renovar mi suscripción')
      when 'nl' then jsonb_build_object('sujet', 'Je winkel is gepauzeerd: abonnement afgelopen', 'corps', 'Je abonnement ' || p_formule || ' is op ' || f || ' afgelopen. Je winkel is voorlopig verborgen, er wordt niets verwijderd. Verleng om hem meteen weer te openen.', 'bouton', 'Mijn abonnement verlengen')
      else jsonb_build_object('sujet', 'Ta boutique est en pause : abonnement terminé', 'corps', 'Ton abonnement ' || p_formule || ' s’est terminé le ' || f || '. Ta boutique est masquée pour l’instant, rien n’est supprimé. Renouvelle-le pour la rouvrir tout de suite.', 'bouton', 'Renouveler mon abonnement') end;
  elsif p_jours = 0 then
    return case l
      when 'en' then jsonb_build_object('sujet', 'Your subscription ends today', 'corps', 'Your ' || p_formule || ' subscription ends today (' || f || '). Renew it now to keep selling without interruption.', 'bouton', 'Renew my subscription')
      when 'es' then jsonb_build_object('sujet', 'Tu suscripción termina hoy', 'corps', 'Tu suscripción ' || p_formule || ' termina hoy (' || f || '). Renuévala ahora para seguir vendiendo sin interrupción.', 'bouton', 'Renovar mi suscripción')
      when 'nl' then jsonb_build_object('sujet', 'Je abonnement loopt vandaag af', 'corps', 'Je abonnement ' || p_formule || ' loopt vandaag af (' || f || '). Verleng het nu om zonder onderbreking te blijven verkopen.', 'bouton', 'Mijn abonnement verlengen')
      else jsonb_build_object('sujet', 'Ton abonnement se termine aujourd’hui', 'corps', 'Ton abonnement ' || p_formule || ' se termine aujourd’hui (' || f || '). Renouvelle-le maintenant pour continuer à vendre sans coupure.', 'bouton', 'Renouveler mon abonnement') end;
  end if;
  return case l
    when 'en' then jsonb_build_object('sujet', 'Your subscription ends in ' || p_jours || ' day(s)', 'corps', 'Your ' || p_formule || ' subscription ends on ' || f || '. Renew it before that date so your shop stays open.', 'bouton', 'Renew my subscription')
    when 'es' then jsonb_build_object('sujet', 'Tu suscripción termina en ' || p_jours || ' día(s)', 'corps', 'Tu suscripción ' || p_formule || ' termina el ' || f || '. Renuévala antes de esa fecha para que tu tienda siga abierta.', 'bouton', 'Renovar mi suscripción')
    when 'nl' then jsonb_build_object('sujet', 'Je abonnement loopt over ' || p_jours || ' dag(en) af', 'corps', 'Je abonnement ' || p_formule || ' loopt af op ' || f || '. Verleng het vóór die datum zodat je winkel open blijft.', 'bouton', 'Mijn abonnement verlengen')
    else jsonb_build_object('sujet', 'Ton abonnement se termine dans ' || p_jours || ' jour(s)', 'corps', 'Ton abonnement ' || p_formule || ' se termine le ' || f || '. Renouvelle-le avant cette date pour que ta boutique reste ouverte.', 'bouton', 'Renouveler mon abonnement') end;
end $$;

insert into public.versions_base (version) values ('v31') on conflict (version) do nothing;
