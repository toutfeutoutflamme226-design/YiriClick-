/* Yiri, the seller assistant (guided onboarding in the seller space, vendeur).
   A scripted guide, no AI: welcome and congratulations, three questions, a tour of the five tabs,
   then a coach card that walks through the shop checklist step by step, and finally marketing tips.
   vendeur calls YGuide.init(ctx) after each load. Progress is kept in this browser (localStorage).
   ctx = { lang, userId, firstName, founder, shopName, checklist(), products(), go(i), tab(name), shareUrl(), enabled, restart } */
window.YGuide = (function () {
  var T = {
    fr: {
      hiTitle: "Félicitations {p} !", hiTitleNo: "Félicitations !",
      hiText: "Bienvenue chez Yiriclick. Ta boutique en ligne commence aujourd’hui.",
      hiFounder: "Tu fais partie du Club des 50 vendeurs fondateurs. Merci de nous faire confiance dès le début.",
      meet: "Rencontrer Yiri", later: "Plus tard",
      meTitle: "Moi, c’est Yiri", meRole: "Ton assistante Yiriclick",
      meText: "Je vais t’aider à installer ta boutique en quelques minutes, puis à la faire connaître. Trois petites questions d’abord ?",
      q1: "Tu vends quoi ?", q1o: ["Mode et beauté", "Alimentation", "Artisanat et maison", "Autre chose"],
      q2: "Tes clients sont où ?", q2o: ["Dans ma ville", "Dans tout le pays", "Aussi à l’étranger"],
      q3: "Tu as déjà des photos de tes produits ?", q3o: ["Oui", "Pas encore"],
      next: "Suivant", skip: "Passer", start: "C’est parti", finish: "Terminer",
      tourIntro: "Je te montre ton espace en 5 étapes.",
      tour: {
        dash: ["Accueil", "Tes visites, tes contacts WhatsApp et ta liste pour lancer ta boutique. Tu commences ici chaque jour."],
        orders: ["Commandes", "Chaque commande arrive ici, complète : produits, client, adresse. Tu la reçois aussi par e-mail, et sur WhatsApp quand le client l’envoie."],
        shop: ["Boutique", "Ton nom, ton logo, ta couverture, ton numéro WhatsApp et ta livraison. C’est la vitrine de ton commerce."],
        prod: ["Produits", "Ajoute tes produits avec photos et prix en FCFA. Chaque client voit le prix dans sa monnaie et sa langue."],
        share: ["Marketing", "Ton lien, ton QR code et des messages prêts pour WhatsApp et Facebook. C’est comme ça que les clients arrivent."]
      },
      coach: "Yiri · ton assistante", progress: "{d} sur {n} étapes", doIt: "Faire maintenant", hide: "Réduire", replay: "Revoir la visite",
      tips: [
        "Choisis un nom simple, facile à dire et à taper. L’adresse de ta boutique se crée toute seule.",
        "Un logo carré et net, sur fond clair. Pas de logo ? Une belle photo de ton produit phare marche aussi.",
        "La couverture est la grande image en haut de ta boutique : montre tes produits ou ton stand.",
        "Une phrase courte qui dit ce que tu vends. Par exemple : « Le karité pur de Bobo, livré chez toi. »",
        "Présente-toi : qui tu es, ce que tu vends, d’où ça vient. On achète plus facilement à quelqu’un qu’on connaît.",
        "C’est sur ce numéro que tes clients t’envoient leurs commandes. Vérifie qu’il est complet.",
        "Dis où tu livres, en combien de temps et à quel prix. C’est la première question des clients.",
        "Ajoute ton Instagram, ta page Facebook ou ton TikTok pour que tes clients te suivent.",
        "Commence par tes 5 meilleures ventes. Tu ajouteras le reste après.",
        "Une photo nette, à la lumière du jour, sur un fond uni : c’est ce qui fait vendre.",
        "Mets ton produit star à la une : il apparaît en premier dans ta boutique."
      ],
      tipAbroad: "Tu vends aussi à l’étranger ? Précise si tu envoies par colis ou par un proche qui voyage.",
      tipNoPhoto: "Pas encore de photos ? Prends-les à la lumière du jour, près d’une fenêtre, sur un drap ou un mur uni.",
      firstProd: "Ton premier produit est en ligne ! Continue comme ça.",
      readyTitle: "Ta boutique est prête !", readyText: "Bravo {p}. Maintenant, fais-la connaître : partage ton lien partout où sont tes clients.",
      share: "Partager ma boutique", copy: "Copier le message", copied: "Message copié",
      shareMsg: "Découvre ma boutique {s} sur Yiriclick : tous mes produits et mes prix au même endroit. Commande directement sur WhatsApp : {u}",
      tipDay: "Conseil du jour",
      market: [
        "Mets ton lien en statut WhatsApp chaque matin, avec un produit et son prix.",
        "Ajoute le lien de ta boutique dans ta bio Instagram, TikTok et Facebook.",
        "Imprime ton QR code (onglet Marketing) et pose-le sur ton stand ou ton comptoir.",
        "Après chaque livraison, demande un avis à ton client : les avis rassurent les nouveaux.",
        "Publie un produit par jour sur Facebook avec le lien de ta boutique."
      ],
      allDone: "Tout est prêt", close: "Fermer", open: "Ouvrir Yiri"
    },
    en: {
      hiTitle: "Congratulations {p}!", hiTitleNo: "Congratulations!",
      hiText: "Welcome to Yiriclick. Your online shop starts today.",
      hiFounder: "You are one of the Club of 50 founding sellers. Thank you for trusting us from the start.",
      meet: "Meet Yiri", later: "Later",
      meTitle: "I’m Yiri", meRole: "Your Yiriclick assistant",
      meText: "I’ll help you set up your shop in a few minutes, then get it known. Three quick questions first?",
      q1: "What do you sell?", q1o: ["Fashion and beauty", "Food", "Crafts and home", "Something else"],
      q2: "Where are your customers?", q2o: ["In my city", "All over the country", "Abroad too"],
      q3: "Do you already have photos of your products?", q3o: ["Yes", "Not yet"],
      next: "Next", skip: "Skip", start: "Let’s go", finish: "Finish",
      tourIntro: "Let me show you your space in 5 steps.",
      tour: {
        dash: ["Home", "Your visits, your WhatsApp contacts and your checklist to launch your shop. Start here every day."],
        orders: ["Orders", "Every order arrives here, complete: products, customer, address. You also get it by e-mail, and on WhatsApp when the customer sends it."],
        shop: ["Shop", "Your name, logo, cover, WhatsApp number and delivery. It is the window of your business."],
        prod: ["Products", "Add your products with photos and prices. Each customer sees the price in their own currency and language."],
        share: ["Marketing", "Your link, your QR code and ready-made messages for WhatsApp and Facebook. That is how customers arrive."]
      },
      coach: "Yiri · your assistant", progress: "{d} of {n} steps", doIt: "Do it now", hide: "Minimise", replay: "Replay the tour",
      tips: [
        "Pick a simple name, easy to say and type. Your shop address is created automatically.",
        "A sharp square logo on a light background. No logo? A nice photo of your best product works too.",
        "The cover is the big picture at the top of your shop: show your products or your stall.",
        "A short sentence that says what you sell. For example: “Pure shea butter from Bobo, delivered to you.”",
        "Introduce yourself: who you are, what you sell, where it comes from. People buy more easily from someone they know.",
        "Customers send their orders to this number. Check that it is complete.",
        "Say where you deliver, how long it takes and how much it costs. It is customers’ first question.",
        "Add your Instagram, Facebook page or TikTok so customers can follow you.",
        "Start with your 5 best sellers. You can add the rest later.",
        "A sharp photo in daylight, on a plain background: that is what sells.",
        "Feature your star product: it shows first in your shop."
      ],
      tipAbroad: "Selling abroad too? Say whether you ship by parcel or through someone travelling.",
      tipNoPhoto: "No photos yet? Take them in daylight, near a window, on a plain sheet or wall.",
      firstProd: "Your first product is online! Keep going.",
      readyTitle: "Your shop is ready!", readyText: "Well done {p}. Now get it known: share your link wherever your customers are.",
      share: "Share my shop", copy: "Copy the message", copied: "Message copied",
      shareMsg: "Discover my shop {s} on Yiriclick: all my products and prices in one place. Order directly on WhatsApp: {u}",
      tipDay: "Tip of the day",
      market: [
        "Post your link in your WhatsApp status every morning, with a product and its price.",
        "Add your shop link to your Instagram, TikTok and Facebook bio.",
        "Print your QR code (Marketing tab) and put it on your stall or counter.",
        "After each delivery, ask your customer for a review: reviews reassure new customers.",
        "Post one product a day on Facebook with your shop link."
      ],
      allDone: "All set", close: "Close", open: "Open Yiri"
    },
    es: {
      hiTitle: "¡Felicidades, {p}!", hiTitleNo: "¡Felicidades!",
      hiText: "Bienvenido a Yiriclick. Tu tienda en línea empieza hoy.",
      hiFounder: "Formas parte del Club de los 50 vendedores fundadores. Gracias por confiar en nosotros desde el principio.",
      meet: "Conocer a Yiri", later: "Más tarde",
      meTitle: "Soy Yiri", meRole: "Tu asistente de Yiriclick",
      meText: "Te ayudo a montar tu tienda en pocos minutos y luego a darla a conocer. ¿Primero tres preguntas rápidas?",
      q1: "¿Qué vendes?", q1o: ["Moda y belleza", "Alimentación", "Artesanía y hogar", "Otra cosa"],
      q2: "¿Dónde están tus clientes?", q2o: ["En mi ciudad", "En todo el país", "También en el extranjero"],
      q3: "¿Ya tienes fotos de tus productos?", q3o: ["Sí", "Todavía no"],
      next: "Siguiente", skip: "Saltar", start: "Vamos", finish: "Terminar",
      tourIntro: "Te enseño tu espacio en 5 pasos.",
      tour: {
        dash: ["Inicio", "Tus visitas, tus contactos de WhatsApp y tu lista para lanzar la tienda. Empieza aquí cada día."],
        orders: ["Pedidos", "Cada pedido llega aquí, completo: productos, cliente, dirección. También lo recibes por correo, y por WhatsApp cuando el cliente lo envía."],
        shop: ["Tienda", "Tu nombre, logo, portada, número de WhatsApp y entrega. Es el escaparate de tu negocio."],
        prod: ["Productos", "Añade tus productos con fotos y precios. Cada cliente ve el precio en su moneda y su idioma."],
        share: ["Marketing", "Tu enlace, tu código QR y mensajes listos para WhatsApp y Facebook. Así llegan los clientes."]
      },
      coach: "Yiri · tu asistente", progress: "{d} de {n} pasos", doIt: "Hacerlo ahora", hide: "Reducir", replay: "Ver la visita otra vez",
      tips: [
        "Elige un nombre sencillo, fácil de decir y de escribir. La dirección de tu tienda se crea sola.",
        "Un logo cuadrado y nítido sobre fondo claro. ¿Sin logo? Una buena foto de tu producto estrella también sirve.",
        "La portada es la imagen grande arriba de tu tienda: muestra tus productos o tu puesto.",
        "Una frase corta que diga lo que vendes. Por ejemplo: «Karité puro de Bobo, a tu puerta».",
        "Preséntate: quién eres, qué vendes, de dónde viene. Se compra más fácil a alguien que se conoce.",
        "Tus clientes te envían sus pedidos a este número. Comprueba que está completo.",
        "Di dónde entregas, en cuánto tiempo y a qué precio. Es la primera pregunta de los clientes.",
        "Añade tu Instagram, tu página de Facebook o tu TikTok para que tus clientes te sigan.",
        "Empieza por tus 5 productos más vendidos. El resto lo añades después.",
        "Una foto nítida, con luz de día, sobre un fondo liso: eso es lo que vende.",
        "Destaca tu producto estrella: aparece primero en tu tienda."
      ],
      tipAbroad: "¿Vendes también al extranjero? Indica si envías por paquete o con alguien que viaja.",
      tipNoPhoto: "¿Todavía sin fotos? Hazlas con luz de día, cerca de una ventana, sobre una sábana o una pared lisa.",
      firstProd: "¡Tu primer producto está en línea! Sigue así.",
      readyTitle: "¡Tu tienda está lista!", readyText: "Bravo, {p}. Ahora dala a conocer: comparte tu enlace donde estén tus clientes.",
      share: "Compartir mi tienda", copy: "Copiar el mensaje", copied: "Mensaje copiado",
      shareMsg: "Descubre mi tienda {s} en Yiriclick: todos mis productos y precios en un solo lugar. Pide directamente por WhatsApp: {u}",
      tipDay: "Consejo del día",
      market: [
        "Pon tu enlace en tu estado de WhatsApp cada mañana, con un producto y su precio.",
        "Añade el enlace de tu tienda a tu bio de Instagram, TikTok y Facebook.",
        "Imprime tu código QR (pestaña Marketing) y ponlo en tu puesto o mostrador.",
        "Después de cada entrega, pide una opinión a tu cliente: las opiniones dan confianza.",
        "Publica un producto al día en Facebook con el enlace de tu tienda."
      ],
      allDone: "Todo listo", close: "Cerrar", open: "Abrir Yiri"
    }, nl: {
      hiTitle: "Gefeliciteerd, {p}!", hiTitleNo: "Gefeliciteerd!",
      hiText: "Welkom bij Yiriclick. Je online winkel begint vandaag.",
      hiFounder: "Je hoort bij de Club van 50 oprichtende verkopers. Bedankt dat je ons vanaf het begin vertrouwt.",
      meet: "Maak kennis met Yiri", later: "Later",
      meTitle: "Ik ben Yiri", meRole: "Je assistent van Yiriclick",
      meText: "Ik help je je winkel in een paar minuten op te zetten en daarna bekend te maken. Eerst drie korte vragen?",
      q1: "Wat verkoop je?", q1o: ["Mode en beauty", "Voeding", "Ambacht en wonen", "Iets anders"],
      q2: "Waar zijn je klanten?", q2o: ["In mijn stad", "In het hele land", "Ook in het buitenland"],
      q3: "Heb je al foto's van je producten?", q3o: ["Ja", "Nog niet"],
      next: "Volgende", skip: "Overslaan", start: "Aan de slag", finish: "Klaar",
      tourIntro: "Ik laat je je ruimte zien in 5 stappen.",
      tour: {
        dash: ["Home", "Je bezoeken, je WhatsApp-contacten en je lijst om je winkel te lanceren. Je begint hier elke dag."],
        orders: ["Bestellingen", "Elke bestelling komt hier binnen, compleet: producten, klant, adres. Je krijgt hem ook per e-mail, en via WhatsApp als de klant hem verstuurt."],
        shop: ["Winkel", "Je naam, logo, omslagfoto, WhatsApp-nummer en levering. Het is de etalage van je zaak."],
        prod: ["Producten", "Voeg je producten toe met foto's en prijzen. Elke klant ziet de prijs in zijn eigen valuta en taal."],
        share: ["Marketing", "Je link, je QR-code en kant-en-klare berichten voor WhatsApp en Facebook. Zo komen de klanten."]
      },
      coach: "Yiri · je assistent", progress: "{d} van {n} stappen", doIt: "Nu doen", hide: "Verkleinen", replay: "Rondleiding opnieuw bekijken",
      tips: [
        "Kies een eenvoudige naam, makkelijk om uit te spreken en te typen. Het adres van je winkel wordt vanzelf gemaakt.",
        "Een vierkant, scherp logo op een lichte achtergrond. Geen logo? Een mooie foto van je topproduct werkt ook.",
        "De omslagfoto is de grote afbeelding bovenaan je winkel: laat je producten of je kraam zien.",
        "Een korte zin die zegt wat je verkoopt. Bijvoorbeeld: “Pure sheaboter uit Bobo, bij jou thuisbezorgd.”",
        "Stel jezelf voor: wie je bent, wat je verkoopt, waar het vandaan komt. Mensen kopen makkelijker bij iemand die ze kennen.",
        "Je klanten sturen hun bestellingen naar dit nummer. Controleer of het volledig is.",
        "Vertel waar je levert, hoe snel en tegen welke prijs. Dat is de eerste vraag van klanten.",
        "Voeg je Instagram, Facebookpagina of TikTok toe zodat je klanten je kunnen volgen.",
        "Begin met je 5 bestverkopende producten. De rest voeg je later toe.",
        "Een scherpe foto, bij daglicht, op een effen achtergrond: dat is wat verkoopt.",
        "Zet je topproduct in de kijker: het verschijnt als eerste in je winkel."
      ],
      tipAbroad: "Verkoop je ook in het buitenland? Vermeld of je per pakket verstuurt of via iemand die reist.",
      tipNoPhoto: "Nog geen foto's? Maak ze bij daglicht, bij een raam, op een effen laken of muur.",
      firstProd: "Je eerste product staat online! Ga zo door.",
      readyTitle: "Je winkel is klaar!", readyText: "Bravo {p}. Maak hem nu bekend: deel je link overal waar je klanten zijn.",
      share: "Mijn winkel delen", copy: "Bericht kopiëren", copied: "Bericht gekopieerd",
      shareMsg: "Ontdek mijn winkel {s} op Yiriclick: al mijn producten en prijzen op één plek. Bestel direct via WhatsApp: {u}",
      tipDay: "Tip van de dag",
      market: [
        "Zet elke ochtend je link in je WhatsApp-status, met een product en de prijs.",
        "Voeg de link van je winkel toe aan je bio op Instagram, TikTok en Facebook.",
        "Print je QR-code (tabblad Marketing) en zet hem op je kraam of toonbank.",
        "Vraag na elke levering een beoordeling aan je klant: beoordelingen geven nieuwe klanten vertrouwen.",
        "Publiceer elke dag een product op Facebook met de link van je winkel."
      ],
      allDone: "Alles klaar", close: "Sluiten", open: "Open Yiri"
    }
  };
  var TOUR = ["dash", "orders", "shop", "prod", "share"];
  var ctx = null, S = null, tx = T.fr, poll = null, coachEl = null, bubbleEl = null;

  /* ---------- small helpers ---------- */
  function el(tag, cls, text) { var e = document.createElement(tag); if (cls) e.className = cls; if (text != null) e.textContent = text; return e; }
  function fmt(s, v) { for (var k in v) s = s.split("{" + k + "}").join(v[k]); return s; }
  function key() { return "yc-guide:" + ctx.userId; }
  function load() { try { return JSON.parse(localStorage.getItem(key()) || "null"); } catch (e) { return null; } }
  function save() { try { localStorage.setItem(key(), JSON.stringify(S)); } catch (e) {} }
  function list() { try { return ctx.checklist() || []; } catch (e) { return []; } }
  function reduced() { try { return window.matchMedia("(prefers-reduced-motion: reduce)").matches; } catch (e) { return false; } }

  var LOGO = '<svg viewBox="0 0 160 160" aria-hidden="true"><path d="M76 146 V92 L34 40" fill="none" stroke="#4FC7CF" stroke-width="22" stroke-linecap="round" stroke-linejoin="round"/><path d="M76 92 L124 34" fill="none" stroke="#FF7A2E" stroke-width="22" stroke-linecap="round"/><path d="M96 30 H128 V62" fill="none" stroke="#FF7A2E" stroke-width="22" stroke-linecap="round" stroke-linejoin="round"/></svg>';
  function avatar(size) { var a = el("span", "yg-av"); a.style.width = a.style.height = size + "px"; a.innerHTML = LOGO; return a; }

  function style() {
    if (document.getElementById("yg-style")) return;
    var s = document.createElement("style"); s.id = "yg-style";
    s.textContent =
      ".yg-av{display:inline-flex;align-items:center;justify-content:center;flex:none;border-radius:50%;background:#10232A;box-shadow:0 0 0 3px #4FC7CF}.yg-av svg{width:62%;height:62%}" +
      ".yg-back{position:fixed;inset:0;z-index:1000;background:rgba(16,35,42,.72);display:flex;align-items:center;justify-content:center;padding:16px}" +
      ".yg-card{background:#fff;color:#10232A;width:min(440px,100%);max-height:calc(100vh - 32px);overflow:auto;padding:26px 22px 20px;box-shadow:0 20px 60px rgba(0,0,0,.35);border-top:6px solid #FF7A2E;text-align:center}" +
      ".yg-card h2{margin:12px 0 8px;font-size:26px;line-height:1.15;letter-spacing:-.5px}.yg-card p{margin:0 0 12px;font-size:16px;line-height:1.45;color:#4A5A5F}" +
      ".yg-role{display:block;font-size:13px;font-weight:800;letter-spacing:.5px;color:#0E6E78;text-transform:uppercase}" +
      ".yg-found{background:#FFF1E8;color:#10232A!important;padding:10px 12px;font-weight:700}" +
      ".yg-btns{display:flex;gap:10px;justify-content:center;flex-wrap:wrap;margin-top:16px}" +
      ".yg-b{border:0;min-height:48px;padding:0 20px;font:inherit;font-weight:800;font-size:16px;cursor:pointer;background:#FF7A2E;color:#fff}" +
      ".yg-b.alt{background:none;color:#4A5A5F;text-decoration:underline}.yg-b.navy{background:#10232A}" +
      ".yg-q{text-align:left;margin:14px 0 4px;font-weight:800;font-size:16px}.yg-opts{display:flex;flex-wrap:wrap;gap:8px}" +
      ".yg-opt{border:2px solid #D5DEE0;background:#fff;color:#10232A;min-height:44px;padding:0 14px;font:inherit;font-weight:700;font-size:15px;cursor:pointer}" +
      ".yg-opt[aria-pressed=true]{border-color:#0E6E78;background:#E6F4F5}" +
      ".yg-hole{position:fixed;z-index:1001;box-shadow:0 0 0 9999px rgba(16,35,42,.72);border-radius:10px;pointer-events:none;transition:all .25s ease}" +
      ".yg-tip{position:fixed;z-index:1002;background:#fff;color:#10232A;width:min(340px,calc(100vw - 24px));padding:16px;box-shadow:0 14px 40px rgba(0,0,0,.35);border-left:5px solid #4FC7CF}" +
      ".yg-tip h3{margin:0 0 6px;font-size:18px}.yg-tip p{margin:0;font-size:15px;line-height:1.4;color:#4A5A5F}.yg-tip .yg-row{display:flex;align-items:center;justify-content:space-between;margin-top:12px;gap:8px}" +
      ".yg-tip .yg-n{font-size:13px;font-weight:700;color:#4A5A5F}.yg-tip .yg-b{min-height:42px;font-size:15px;padding:0 16px}" +
      ".yg-coach{position:fixed;z-index:30;right:12px;bottom:calc(var(--navh,64px) + 84px + env(safe-area-inset-bottom,0px));width:min(360px,calc(100vw - 24px));background:#fff;color:#10232A;box-shadow:0 12px 36px rgba(16,35,42,.28);border-top:5px solid #4FC7CF;padding:14px 14px 12px}" +
      "@media (min-width:960px){.yg-coach{bottom:96px;right:20px}.yg-bub{bottom:96px!important;right:20px!important}}" +
      ".yg-head{display:flex;align-items:center;gap:10px}.yg-head b{display:block;font-size:15px}.yg-head small{font-size:13px;color:#4A5A5F}" +
      ".yg-x{margin-left:auto;border:0;background:none;font:inherit;font-size:13px;font-weight:700;color:#4A5A5F;cursor:pointer;min-height:36px;text-decoration:underline}" +
      ".yg-bar{height:8px;background:#E6F4F5;margin:12px 0 10px}.yg-bar i{display:block;height:100%;background:#FF7A2E;transition:width .4s}" +
      ".yg-step{font-weight:800;font-size:16px;margin:0 0 4px}.yg-text{font-size:14.5px;line-height:1.4;color:#4A5A5F;margin:0}" +
      ".yg-coach .yg-btns{justify-content:flex-start;margin-top:12px}.yg-coach .yg-b{min-height:44px;font-size:15px}" +
      ".yg-bub{position:fixed;z-index:30;right:12px;bottom:calc(var(--navh,64px) + 84px + env(safe-area-inset-bottom,0px));border:0;padding:0;background:none;cursor:pointer}" +
      ".yg-bub .yg-av{box-shadow:0 0 0 3px #4FC7CF,0 8px 22px rgba(16,35,42,.35)}" +
      ".yg-dot{position:absolute;top:-4px;right:-4px;min-width:22px;height:22px;border-radius:11px;background:#FF7A2E;color:#fff;font-size:12px;font-weight:800;display:flex;align-items:center;justify-content:center;padding:0 5px}" +
      ".yg-toast{position:fixed;z-index:1003;left:50%;top:16px;transform:translateX(-50%);background:#10232A;color:#fff;padding:12px 16px;font-weight:800;box-shadow:0 10px 30px rgba(0,0,0,.3);max-width:calc(100vw - 24px)}" +
      ".yg-conf{position:fixed;inset:0;z-index:1004;pointer-events:none}";
    document.head.appendChild(s);
  }

  /* ---------- confetti and toast ---------- */
  function confetti() {
    if (reduced()) return;
    var c = el("canvas", "yg-conf"); document.body.appendChild(c);
    var w = c.width = window.innerWidth, h = c.height = window.innerHeight, g = c.getContext("2d");
    var cols = ["#FF7A2E", "#4FC7CF", "#10232A", "#FFD35C"], P = [];
    for (var i = 0; i < 140; i++) P.push({ x: w / 2 + (Math.random() - .5) * 80, y: h * .35, vx: (Math.random() - .5) * 12, vy: -Math.random() * 13 - 4, r: Math.random() * 6.28, s: 5 + Math.random() * 6, c: cols[i % 4] });
    var t0 = Date.now();
    (function f() {
      var t = Date.now() - t0; g.clearRect(0, 0, w, h);
      P.forEach(function (p) { p.vy += .35; p.x += p.vx; p.y += p.vy; p.r += .2; g.save(); g.translate(p.x, p.y); g.rotate(p.r); g.fillStyle = p.c; g.fillRect(-p.s / 2, -p.s / 4, p.s, p.s / 2); g.restore(); });
      if (t < 2600) requestAnimationFrame(f); else c.remove();
    })();
  }
  function toast(msg) { var d = el("div", "yg-toast", msg); d.setAttribute("role", "status"); document.body.appendChild(d); setTimeout(function () { d.remove(); }, 3500); }

  /* ---------- modal cards ---------- */
  var modal = null;
  function closeModal() { if (modal) { modal.remove(); modal = null; } }
  function card() {
    closeModal(); modal = el("div", "yg-back"); modal.setAttribute("role", "dialog"); modal.setAttribute("aria-modal", "true");
    var c = el("div", "yg-card"); modal.appendChild(c); document.body.appendChild(modal); return c;
  }
  function btn(text, cls, fn) { var b = el("button", "yg-b" + (cls ? " " + cls : ""), text); b.type = "button"; b.addEventListener("click", fn); return b; }

  function welcome() {
    var c = card(); c.appendChild(avatar(84));
    var h = el("h2", null, ctx.firstName ? fmt(tx.hiTitle, { p: ctx.firstName }) : tx.hiTitleNo); h.id = "yg-h"; modal.setAttribute("aria-labelledby", "yg-h"); c.appendChild(h);
    c.appendChild(el("p", null, tx.hiText));
    if (ctx.founder) c.appendChild(el("p", "yg-found", tx.hiFounder));
    var b = el("div", "yg-btns");
    b.appendChild(btn(tx.meet, "", function () { S.stage = "quiz"; save(); quiz(); }));
    b.appendChild(btn(tx.later, "alt", function () { S.stage = "coach"; save(); closeModal(); showCoach(); }));
    c.appendChild(b); confetti(); setTimeout(function () { var f = c.querySelector(".yg-b"); if (f) f.focus(); }, 50);
  }

  function quiz() {
    var c = card(); c.appendChild(avatar(72));
    var h = el("h2", null, tx.meTitle); h.id = "yg-h"; modal.setAttribute("aria-labelledby", "yg-h"); c.appendChild(h);
    c.appendChild(el("span", "yg-role", tx.meRole));
    c.appendChild(el("p", null, tx.meText));
    S.answers = S.answers || {};
    [["q1", "sell"], ["q2", "where"], ["q3", "photos"]].forEach(function (q) {
      c.appendChild(el("div", "yg-q", tx[q[0]]));
      var box = el("div", "yg-opts"); box.setAttribute("role", "group");
      tx[q[0] + "o"].forEach(function (o, i) {
        var b = el("button", "yg-opt", o); b.type = "button"; b.setAttribute("aria-pressed", String(S.answers[q[1]] === i));
        b.addEventListener("click", function () { S.answers[q[1]] = i; save(); box.querySelectorAll(".yg-opt").forEach(function (x, j) { x.setAttribute("aria-pressed", String(j === i)); }); });
        box.appendChild(b);
      });
      c.appendChild(box);
    });
    var b = el("div", "yg-btns");
    b.appendChild(btn(tx.start, "", function () { S.stage = "tour"; S.tourAt = 0; save(); closeModal(); tour(); }));
    b.appendChild(btn(tx.skip, "alt", function () { S.stage = "tour"; S.tourAt = 0; save(); closeModal(); tour(); }));
    c.appendChild(b);
  }

  /* ---------- tour of the five tabs ---------- */
  var hole = null, tip = null;
  function endTour() { if (hole) hole.remove(); if (tip) tip.remove(); hole = tip = null; window.removeEventListener("resize", placeTour); S.stage = "coach"; S.min = false; save(); try { ctx.tab("dash"); } catch (e) {} showCoach(); }
  function tour() {
    hideCoach();
    var i = S.tourAt || 0; if (i >= TOUR.length) { endTour(); return; }
    var name = TOUR[i], target = document.querySelector('.side [data-tab="' + name + '"]');
    if (!target || !target.getBoundingClientRect().width) { S.tourAt = i + 1; save(); tour(); return; }
    try { ctx.tab(name); } catch (e) {}
    if (!hole) { hole = el("div", "yg-hole"); document.body.appendChild(hole); }
    if (!tip) { tip = el("div", "yg-tip"); tip.setAttribute("role", "dialog"); tip.setAttribute("aria-live", "polite"); document.body.appendChild(tip); window.addEventListener("resize", placeTour); }
    tip.textContent = "";
    var head = el("div", "yg-head"); head.appendChild(avatar(36)); var hn = el("div"); hn.appendChild(el("b", null, "Yiri")); hn.appendChild(el("small", null, i === 0 ? tx.tourIntro : tx.coach)); head.appendChild(hn); tip.appendChild(head);
    var h = el("h3", null, tx.tour[name][0]); h.style.marginTop = "10px"; tip.appendChild(h);
    tip.appendChild(el("p", null, tx.tour[name][1]));
    var row = el("div", "yg-row"); row.appendChild(el("span", "yg-n", (i + 1) + " / " + TOUR.length));
    var bs = el("div"); bs.style.display = "flex"; bs.style.gap = "6px";
    bs.appendChild(btn(tx.skip, "alt", endTour));
    bs.appendChild(btn(i === TOUR.length - 1 ? tx.finish : tx.next, "", function () { S.tourAt = i + 1; save(); tour(); }));
    row.appendChild(bs); tip.appendChild(row);
    tip.__target = target; placeTour();
    setTimeout(function () { var f = tip && tip.querySelector(".yg-b:not(.alt)"); if (f) f.focus(); }, 60);
  }
  function placeTour() {
    if (!tip || !tip.__target) return;
    var r = tip.__target.getBoundingClientRect(), pad = 6;
    hole.style.left = (r.left - pad) + "px"; hole.style.top = (r.top - pad) + "px"; hole.style.width = (r.width + pad * 2) + "px"; hole.style.height = (r.height + pad * 2) + "px";
    var tw = tip.offsetWidth, th = tip.offsetHeight, vw = window.innerWidth, vh = window.innerHeight, x, y;
    if (r.top > vh / 2) { y = r.top - th - 16; x = r.left + r.width / 2 - tw / 2; }            // bottom bar: above the tab
    else if (r.right + tw + 24 < vw) { x = r.right + 16; y = r.top; }                           // side bar: to the right
    else { y = r.bottom + 16; x = r.left + r.width / 2 - tw / 2; }
    tip.style.left = Math.max(12, Math.min(vw - tw - 12, x)) + "px"; tip.style.top = Math.max(12, Math.min(vh - th - 12, y)) + "px";
  }

  /* ---------- coach card: next step of the checklist, then marketing tips ---------- */
  function hideCoach() { if (coachEl) coachEl.remove(); if (bubbleEl) bubbleEl.remove(); coachEl = bubbleEl = null; }
  function showCoach() {
    hideCoach(); if (!ctx || S.stage === "welcome" || S.stage === "quiz" || S.stage === "tour") return;
    var L = list(), done = L.filter(function (x) { return x[1]; }).length, n = L.length, next = -1;
    for (var i = 0; i < L.length; i++) if (!L[i][1]) { next = i; break; }
    if (S.min) {
      bubbleEl = el("button", "yg-bub"); bubbleEl.type = "button"; bubbleEl.setAttribute("aria-label", tx.open);
      bubbleEl.appendChild(avatar(54)); if (next >= 0) bubbleEl.appendChild(el("span", "yg-dot", String(n - done)));
      bubbleEl.addEventListener("click", function () { S.min = false; save(); showCoach(); });
      document.body.appendChild(bubbleEl); return;
    }
    coachEl = el("aside", "yg-coach"); coachEl.setAttribute("aria-label", tx.coach);
    var head = el("div", "yg-head"); head.appendChild(avatar(40));
    var hn = el("div"); hn.appendChild(el("b", null, tx.coach)); hn.appendChild(el("small", null, next >= 0 ? fmt(tx.progress, { d: done, n: n }) : tx.allDone)); head.appendChild(hn);
    var x = el("button", "yg-x", tx.hide); x.type = "button"; x.addEventListener("click", function () { S.min = true; save(); showCoach(); }); head.appendChild(x);
    coachEl.appendChild(head);
    var bar = el("div", "yg-bar"), fill = el("i"); fill.style.width = (n ? Math.round(done / n * 100) : 0) + "%"; bar.appendChild(fill); coachEl.appendChild(bar);
    var b = el("div", "yg-btns");
    if (next >= 0) {
      coachEl.appendChild(el("p", "yg-step", L[next][0]));
      var t = tx.tips[next] || "";
      var a = S.answers || {};
      if (next === 6 && a.where === 2) t += " " + tx.tipAbroad;
      if ((next === 8 || next === 9) && a.photos === 1) t += " " + tx.tipNoPhoto;
      coachEl.appendChild(el("p", "yg-text", t));
      b.appendChild(btn(tx.doIt, "", function () { S.min = true; save(); showCoach(); try { ctx.go(next); } catch (e) {} }));
    } else {
      var k = Math.floor(Date.now() / 864e5) % tx.market.length;
      coachEl.appendChild(el("p", "yg-step", tx.tipDay));
      coachEl.appendChild(el("p", "yg-text", tx.market[k]));
      b.appendChild(btn(tx.share, "", function () { try { ctx.tab("share"); } catch (e) {} }));
    }
    b.appendChild(btn(tx.replay, "alt", function () { S.stage = "tour"; S.tourAt = 0; save(); tour(); }));
    coachEl.appendChild(b);
    document.body.appendChild(coachEl);
  }

  function ready() {
    var c = card(); c.appendChild(avatar(84));
    var h = el("h2", null, tx.readyTitle); h.id = "yg-h"; modal.setAttribute("aria-labelledby", "yg-h"); c.appendChild(h);
    c.appendChild(el("p", null, ctx.firstName ? fmt(tx.readyText, { p: ctx.firstName }) : tx.readyText.replace(/,? \{p\}/, "")));
    var u = null; try { u = ctx.shareUrl(); } catch (e) {}
    var msg = u ? fmt(tx.shareMsg, { s: ctx.shopName || "", u: u }) : "";
    var b = el("div", "yg-btns");
    b.appendChild(btn(tx.share, "", function () { closeModal(); try { ctx.tab("share"); } catch (e) {} showCoach(); }));
    if (msg) b.appendChild(btn(tx.copy, "navy", function () {
      var done = function () { toast(tx.copied); };
      try { navigator.clipboard.writeText(msg).then(done, done); } catch (e) { done(); }
    }));
    b.appendChild(btn(tx.close, "alt", function () { closeModal(); showCoach(); }));
    c.appendChild(b); confetti();
  }

  /* ---------- watch progress: first product, shop complete ---------- */
  function watch() {
    if (!ctx) return;
    var L = list(), all = L.length && L.every(function (x) { return x[1]; }), np = 0;
    try { np = ctx.products() || 0; } catch (e) {}
    S.seen = S.seen || {};
    var changed = false;
    if (np > 0 && !S.seen.firstProd && S.seen.prods === 0) { S.seen.firstProd = true; changed = true; toast(tx.firstProd); confetti(); }
    if (S.seen.prods !== np) { S.seen.prods = np; changed = true; }
    if (all && !S.seen.ready && S.stage === "coach") { S.seen.ready = true; changed = true; save(); hideCoach(); ready(); return; }
    var sig = L.map(function (x) { return x[1] ? 1 : 0; }).join("");
    if (sig !== S.sig) {
      var more = S.sig != null && sig.split("1").length > S.sig.split("1").length;   // a step was just completed: open the card on the next one
      S.sig = sig; changed = true; if (more) S.min = false;
      if (S.stage === "coach" && !modal) showCoach();
    }
    if (changed) save();
  }

  function init(c) {
    if (!c || !c.enabled || !c.userId) return;
    ctx = c; tx = T[c.lang] || T.fr; style();
    S = c.restart ? null : load();
    var L = list(), allDone = L.length && L.every(function (x) { return x[1]; });
    /* sellers who already sell (shop + products) are not welcomed again: Yiri waits as a small bubble */
    var known = !c.restart && (allDone || c.existing);
    if (!S) S = { stage: known ? "coach" : "welcome", answers: {}, min: !!(known && !allDone), seen: { ready: allDone && !c.restart, prods: (c.products && c.products()) || 0 } };
    save();
    if (poll) clearInterval(poll); poll = setInterval(watch, 1500);
    if (S.stage === "welcome") welcome();
    else if (S.stage === "quiz") quiz();
    else if (S.stage === "tour") tour();
    else showCoach();
  }

  return { init: init, refresh: function () { if (ctx && S && S.stage === "coach" && !modal) showCoach(); } };
})();
