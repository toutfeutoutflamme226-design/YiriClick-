/* Shared logic for the showcase (index), boutique and catalogue: Supabase client, languages, currencies, product cards and product detail */
window.YC = (function () {
  var URL_SB = "https://vtiakxfnechkoomagddl.supabase.co";
  var KEY_SB = "sb_publishable_415c2KQSDRx0SMofnkHKQA_PJ2IrzBA";
  var sb = window.supabase.createClient(URL_SB, KEY_SB, { auth: { persistSession: false } });
  /* "langue" columns accept Dutch once base v25 is installed; until then a Dutch visitor is stored as "en" */
  var NL_DB = false;
  try { sb.rpc("langues_acceptees").then(function (r) { NL_DB = !r.error && Array.isArray(r.data) && r.data.indexOf("nl") >= 0; }, function () {}); } catch (e) {}
  function dbLang(l) { return l === "nl" && !NL_DB ? "en" : l; }

  /* ECB reference rates of 23 October 2026 (1 EUR = x). The CFA franc is pegged: 1 EUR = 655.957 FCFA. */
  var RATES = { EUR: 1, XOF: 655.957, USD: 1.1193 }, RATES_DATE = new Date("2026-10-23T16:00:00Z");
  /* Daily rates from the database (base v12); the values above are only a fallback */
  sb.from("taux").select("devise,par_eur,maj").then(function (r) {
    if (r.error || !r.data || !r.data.length) return;
    r.data.forEach(function (x) { if (Number(x.par_eur) > 0) RATES[x.devise] = Number(x.par_eur); if (x.devise === "USD" && x.maj) RATES_DATE = new Date(x.maj); });
    prefsListeners.forEach(function (f) { try { f(); } catch (e) {} });
  }, function () {});
  var LOCALE = { fr: "fr-FR", en: "en-GB", es: "es-ES", nl: "nl-NL" };
  /* Shop brand colours chosen by the seller: [background, text on it] */
  var THEMES = { teal: ["#0E6E78", "#FFFFFF"], navy: ["#10232A", "#FFFFFF"], orange: ["#FF7A2E", "#10232A"], rouge: ["#C62828", "#FFFFFF"], vert: ["#1E7F4F", "#FFFFFF"],
    violet: ["#6A3FB5", "#FFFFFF"], or: ["#E0A526", "#10232A"], rose: ["#C2185B", "#FFFFFF"], noir: ["#111111", "#FFFFFF"] };

  var T = {
    fr: { lang: "Langue", cur: "Monnaie", showcase: "Vitrine", sellers: "Espace vendeur", search: "Rechercher un produit…", allCats: "Toutes les catégories",
      noProducts: "Aucun produit pour l’instant.", noMatch: "Aucun produit ne correspond à ta recherche.", stock: "En stock : {n}", outStock: "Rupture de stock",
      order: "Commander sur WhatsApp", noWa: "Ce vendeur n’a pas encore indiqué de numéro WhatsApp.", waMsg: "Bonjour, je suis intéressé(e) par « {p} » ({x}) vu sur votre boutique Yiriclick : {u}",
      approx: "≈ {v} au taux du {d}", close: "Fermer", verified: "Vendeur vérifié par Yiriclick", notFound: "Boutique introuvable", notFoundP: "Cette boutique n’existe pas ou n’est pas visible pour le moment.",
      back: "Voir la vitrine Yiriclick", loading: "Chargement…", latest: "Les derniers produits des vendeurs Yiriclick", vitrineT: "La vitrine Yiriclick", see: "Voir la boutique", by: "Par {s}", foot: "Boutique propulsée par Yiriclick", openShop: "Ouvrir ma boutique sur Yiriclick", buy: "Commander", details: "Détails",
      add: "Ajouter", addLong: "Ajouter au panier", added: "Ajouté au panier", viewCart: "Voir le panier", cart: "Panier", cartTitle: "Mon panier",
      cartEmpty: "Ton panier est vide. Ajoute des produits depuis la vitrine ou une boutique.", keepShopping: "Continuer mes achats",
      qty: "Quantité", less: "Retirer un", more: "Ajouter un", remove: "Retirer", subtotal: "Sous-total", total: "Total estimé", maxStock: "Stock maximum atteint",
      gone: "Certains produits ne sont plus disponibles et ont été retirés de ton panier.", checkout: "Valider ma commande",
      yourInfo: "Tes coordonnées", cName: "Nom complet", cPhone: "Téléphone (WhatsApp)", cAddr: "Adresse de livraison", cNote: "Message pour le vendeur (facultatif)",
      eReq: "Ce champ est obligatoire.", ePhone: "Choisis ton pays, puis entre ton numéro WhatsApp.", ePhoneN: "Ce numéro doit avoir {n} chiffres, sans l’indicatif. Vérifie qu’il est complet.",
      sendTitle: "Envoie ta commande à chaque vendeur", sendHelp: "Ton panier contient des produits de plusieurs vendeurs : envoie la commande à chacun. Le vendeur te confirme la disponibilité, la livraison et le paiement.",
      sendTo: "Envoyer à {s} sur WhatsApp", sent: "Envoyé à {s}", noWaShop: "{s} n’a pas indiqué de numéro WhatsApp : sa commande ne peut pas être envoyée pour l’instant.",
      sentTitle: "Commandes envoyées", sentLine: "{s} · {n} article(s) · {h}", restore: "Remettre dans le panier", doneTitle: "Commande envoyée", doneText: "Ton panier a été vidé. Le vendeur te répond sur WhatsApp pour confirmer la disponibilité, la livraison et le paiement. Si le message n’est pas parti, touche « Remettre dans le panier ».", editInfo: "Modifier mes coordonnées", orderDirect: "Commander directement sur WhatsApp",
      waCart: "Bonjour {s}, je souhaite commander sur Yiriclick :", waTotal: "Total", waName: "Nom", waPhone: "Téléphone", waAddr: "Adresse de livraison", waNote: "Message",
      waEnd: "Merci de me confirmer la disponibilité, les frais de livraison et le mode de paiement.", approxSign: "≈ ", crumbs: "Fil d’Ariane" },
    en: { lang: "Language", cur: "Currency", showcase: "Showcase", sellers: "Seller space", search: "Search for a product…", allCats: "All categories",
      noProducts: "No products yet.", noMatch: "No product matches your search.", stock: "In stock: {n}", outStock: "Out of stock",
      order: "Order on WhatsApp", noWa: "This seller has not added a WhatsApp number yet.", waMsg: "Hello, I am interested in “{p}” ({x}) seen on your Yiriclick shop: {u}",
      approx: "≈ {v} at the {d} rate", close: "Close", verified: "Seller verified by Yiriclick", notFound: "Shop not found", notFoundP: "This shop does not exist or is not visible right now.",
      back: "See the Yiriclick showcase", loading: "Loading…", latest: "The latest products from Yiriclick sellers", vitrineT: "The Yiriclick showcase", see: "See the shop", by: "By {s}", foot: "Shop powered by Yiriclick", openShop: "Open my shop on Yiriclick", buy: "Order", details: "Details",
      add: "Add", addLong: "Add to cart", added: "Added to cart", viewCart: "View cart", cart: "Cart", cartTitle: "My cart",
      cartEmpty: "Your cart is empty. Add products from the showcase or a shop.", keepShopping: "Continue shopping",
      qty: "Quantity", less: "Remove one", more: "Add one", remove: "Remove", subtotal: "Subtotal", total: "Estimated total", maxStock: "Maximum stock reached",
      gone: "Some products are no longer available and were removed from your cart.", checkout: "Place my order",
      yourInfo: "Your details", cName: "Full name", cPhone: "Phone (WhatsApp)", cAddr: "Delivery address", cNote: "Message for the seller (optional)",
      eReq: "This field is required.", ePhone: "Choose your country, then enter your WhatsApp number.", ePhoneN: "This number must have {n} digits, without the country code. Check it is complete.",
      sendTitle: "Send your order to each seller", sendHelp: "Your cart has products from several sellers: send the order to each one. The seller confirms availability, delivery and payment with you.",
      sendTo: "Send to {s} on WhatsApp", sent: "Sent to {s}", noWaShop: "{s} has not added a WhatsApp number: this order cannot be sent yet.",
      sentTitle: "Orders sent", sentLine: "{s} · {n} item(s) · {h}", restore: "Put back in the cart", doneTitle: "Order sent", doneText: "Your cart has been emptied. The seller will reply on WhatsApp to confirm availability, delivery and payment. If the message did not go through, tap “Put back in the cart”.", editInfo: "Edit my details", orderDirect: "Order directly on WhatsApp",
      waCart: "Hello {s}, I would like to order on Yiriclick:", waTotal: "Total", waName: "Name", waPhone: "Phone", waAddr: "Delivery address", waNote: "Message",
      waEnd: "Please confirm availability, delivery costs and payment method.", approxSign: "≈ ", crumbs: "Breadcrumb" },
    es: { lang: "Idioma", cur: "Moneda", showcase: "Escaparate", sellers: "Espacio vendedor", search: "Buscar un producto…", allCats: "Todas las categorías",
      noProducts: "Todavía no hay productos.", noMatch: "Ningún producto coincide con tu búsqueda.", stock: "En stock: {n}", outStock: "Agotado",
      order: "Pedir por WhatsApp", noWa: "Este vendedor aún no ha indicado un número de WhatsApp.", waMsg: "Hola, me interesa «{p}» ({x}) visto en su tienda Yiriclick: {u}",
      approx: "≈ {v} al cambio del {d}", close: "Cerrar", verified: "Vendedor verificado por Yiriclick", notFound: "Tienda no encontrada", notFoundP: "Esta tienda no existe o no está visible por ahora.",
      back: "Ver el escaparate de Yiriclick", loading: "Cargando…", latest: "Los últimos productos de los vendedores de Yiriclick", vitrineT: "El escaparate de Yiriclick", see: "Ver la tienda", by: "Por {s}", foot: "Tienda impulsada por Yiriclick", openShop: "Abrir mi tienda en Yiriclick", buy: "Pedir", details: "Detalles",
      add: "Añadir", addLong: "Añadir al carrito", added: "Añadido al carrito", viewCart: "Ver el carrito", cart: "Carrito", cartTitle: "Mi carrito",
      cartEmpty: "Tu carrito está vacío. Añade productos desde el escaparate o una tienda.", keepShopping: "Seguir comprando",
      qty: "Cantidad", less: "Quitar uno", more: "Añadir uno", remove: "Quitar", subtotal: "Subtotal", total: "Total estimado", maxStock: "Stock máximo alcanzado",
      gone: "Algunos productos ya no están disponibles y se han quitado de tu carrito.", checkout: "Confirmar mi pedido",
      yourInfo: "Tus datos", cName: "Nombre completo", cPhone: "Teléfono (WhatsApp)", cAddr: "Dirección de entrega", cNote: "Mensaje para el vendedor (opcional)",
      eReq: "Este campo es obligatorio.", ePhone: "Elige tu país y luego escribe tu número de WhatsApp.", ePhoneN: "Este número debe tener {n} cifras, sin el prefijo. Comprueba que está completo.",
      sendTitle: "Envía tu pedido a cada vendedor", sendHelp: "Tu carrito tiene productos de varios vendedores: envía el pedido a cada uno. El vendedor te confirma disponibilidad, entrega y pago.",
      sendTo: "Enviar a {s} por WhatsApp", sent: "Enviado a {s}", noWaShop: "{s} no ha indicado un número de WhatsApp: este pedido aún no se puede enviar.",
      sentTitle: "Pedidos enviados", sentLine: "{s} · {n} artículo(s) · {h}", restore: "Volver a poner en el carrito", doneTitle: "Pedido enviado", doneText: "Tu carrito se ha vaciado. El vendedor te responderá por WhatsApp para confirmar disponibilidad, entrega y pago. Si el mensaje no se envió, toca «Volver a poner en el carrito».", editInfo: "Modificar mis datos", orderDirect: "Pedir directamente por WhatsApp",
      waCart: "Hola {s}, quiero hacer un pedido en Yiriclick:", waTotal: "Total", waName: "Nombre", waPhone: "Teléfono", waAddr: "Dirección de entrega", waNote: "Mensaje",
      waEnd: "Por favor, confírmame disponibilidad, gastos de envío y forma de pago.", approxSign: "≈ ", crumbs: "Ruta de navegación" }, nl: { lang: "Taal", cur: "Valuta", showcase: "Etalage", sellers: "Verkopersruimte", search: "Zoek een product…", allCats: "Alle categorieën",
      noProducts: "Nog geen producten.", noMatch: "Geen product komt overeen met je zoekopdracht.", stock: "Op voorraad: {n}", outStock: "Uitverkocht",
      order: "Bestellen via WhatsApp", noWa: "Deze verkoper heeft nog geen WhatsApp-nummer opgegeven.", waMsg: "Hallo, ik ben geïnteresseerd in “{p}” ({x}), gezien in je Yiriclick-winkel: {u}",
      approx: "≈ {v} tegen de koers van {d}", close: "Sluiten", verified: "Verkoper geverifieerd door Yiriclick", notFound: "Winkel niet gevonden", notFoundP: "Deze winkel bestaat niet of is op dit moment niet zichtbaar.",
      back: "Bekijk de Yiriclick-etalage", loading: "Laden…", latest: "De nieuwste producten van de Yiriclick-verkopers", vitrineT: "De Yiriclick-etalage", see: "Bekijk de winkel", by: "Door {s}", foot: "Winkel mogelijk gemaakt door Yiriclick", openShop: "Open mijn winkel op Yiriclick", buy: "Bestellen", details: "Details",
      add: "Toevoegen", addLong: "In winkelwagen", added: "Toegevoegd aan winkelwagen", viewCart: "Bekijk winkelwagen", cart: "Winkelwagen", cartTitle: "Mijn winkelwagen",
      cartEmpty: "Je winkelwagen is leeg. Voeg producten toe vanuit de etalage of een winkel.", keepShopping: "Verder winkelen",
      qty: "Aantal", less: "Eén minder", more: "Eén meer", remove: "Verwijderen", subtotal: "Subtotaal", total: "Geschat totaal", maxStock: "Maximale voorraad bereikt",
      gone: "Sommige producten zijn niet meer beschikbaar en zijn uit je winkelwagen gehaald.", checkout: "Mijn bestelling bevestigen",
      yourInfo: "Je gegevens", cName: "Volledige naam", cPhone: "Telefoon (WhatsApp)", cAddr: "Afleveradres", cNote: "Bericht voor de verkoper (optioneel)",
      eReq: "Dit veld is verplicht.", ePhone: "Kies je land en vul daarna je WhatsApp-nummer in.", ePhoneN: "Dit nummer moet {n} cijfers hebben, zonder landcode. Controleer of het volledig is.",
      sendTitle: "Stuur je bestelling naar elke verkoper", sendHelp: "Je winkelwagen bevat producten van meerdere verkopers: stuur de bestelling naar elk van hen. De verkoper bevestigt beschikbaarheid, levering en betaling.",
      sendTo: "Naar {s} sturen via WhatsApp", sent: "Verstuurd naar {s}", noWaShop: "{s} heeft geen WhatsApp-nummer opgegeven: deze bestelling kan nog niet worden verstuurd.",
      sentTitle: "Verstuurde bestellingen", sentLine: "{s} · {n} artikel(en) · {h}", restore: "Terug in winkelwagen", doneTitle: "Bestelling verstuurd", doneText: "Je winkelwagen is geleegd. De verkoper antwoordt je via WhatsApp om beschikbaarheid, levering en betaling te bevestigen. Is het bericht niet verstuurd? Tik dan op “Terug in winkelwagen”.", editInfo: "Mijn gegevens wijzigen", orderDirect: "Direct bestellen via WhatsApp",
      waCart: "Hallo {s}, ik wil graag bestellen op Yiriclick:", waTotal: "Totaal", waName: "Naam", waPhone: "Telefoon", waAddr: "Afleveradres", waNote: "Bericht",
      waEnd: "Wil je de beschikbaarheid, de verzendkosten en de betaalwijze bevestigen?", approxSign: "≈ ", crumbs: "Kruimelpad" }
  };
  var CATS = {
    fr: { mode: "Mode et vêtements", chaussures: "Chaussures et maroquinerie", bijoux: "Bijoux et accessoires", textile: "Tissus et pagnes", beaute: "Beauté et cosmétiques", sante: "Santé et bien-être", alim: "Alimentation et épicerie", boissons: "Boissons", agri: "Produits agricoles et élevage", artisanat: "Artisanat et art", deco: "Décoration et maison", meubles: "Meubles", electromenager: "Électroménager", tech: "Téléphones et électronique", info: "Informatique", auto: "Auto et moto", btp: "Bâtiment et matériaux", bebe: "Bébé et enfants", jouets: "Jouets et jeux", sport: "Sport et loisirs", livres: "Livres et fournitures scolaires", musique: "Musique et instruments", animaux: "Animaux", numerique: "Produits numériques", services: "Services", autre: "Autre" },
    en: { mode: "Fashion and clothing", chaussures: "Shoes and leather goods", bijoux: "Jewellery and accessories", textile: "Fabrics and wax prints", beaute: "Beauty and cosmetics", sante: "Health and wellness", alim: "Food and groceries", boissons: "Drinks", agri: "Farm products and livestock", artisanat: "Crafts and art", deco: "Home and decor", meubles: "Furniture", electromenager: "Home appliances", tech: "Phones and electronics", info: "Computers", auto: "Cars and motorbikes", btp: "Building and materials", bebe: "Baby and kids", jouets: "Toys and games", sport: "Sports and leisure", livres: "Books and school supplies", musique: "Music and instruments", animaux: "Pets and animals", numerique: "Digital products", services: "Services", autre: "Other" },
    es: { mode: "Moda y ropa", chaussures: "Calzado y marroquinería", bijoux: "Joyas y accesorios", textile: "Telas y wax", beaute: "Belleza y cosmética", sante: "Salud y bienestar", alim: "Alimentación y supermercado", boissons: "Bebidas", agri: "Productos agrícolas y ganadería", artisanat: "Artesanía y arte", deco: "Hogar y decoración", meubles: "Muebles", electromenager: "Electrodomésticos", tech: "Teléfonos y electrónica", info: "Informática", auto: "Coches y motos", btp: "Construcción y materiales", bebe: "Bebés y niños", jouets: "Juguetes y juegos", sport: "Deporte y ocio", livres: "Libros y material escolar", musique: "Música e instrumentos", animaux: "Animales", numerique: "Productos digitales", services: "Servicios", autre: "Otro" }, nl: { mode: "Mode en kleding", chaussures: "Schoenen en lederwaren", bijoux: "Sieraden en accessoires", textile: "Stoffen en wax", beaute: "Beauty en cosmetica", sante: "Gezondheid en welzijn", alim: "Voeding en supermarkt", boissons: "Dranken", agri: "Landbouw en veeteelt", artisanat: "Ambacht en kunst", deco: "Wonen en decoratie", meubles: "Meubels", electromenager: "Huishoudelijke apparaten", tech: "Telefoons en elektronica", info: "Computers", auto: "Auto's en motoren", btp: "Bouw en materialen", bebe: "Baby's en kinderen", jouets: "Speelgoed en spellen", sport: "Sport en vrije tijd", livres: "Boeken en schoolspullen", musique: "Muziek en instrumenten", animaux: "Dieren", numerique: "Digitale producten", services: "Diensten", autre: "Overig" }
  };

  /* Showcase, favourites and promotion texts */
  var T2 = {
    fr: { searchBig: "Que cherches-tu ?", voice: "Recherche vocale", voiceOn: "Je t’écoute…", doSearch: "Rechercher", menu: "Menu", login: "Se connecter", favs: "Favoris", favTitle: "Mes favoris",
      favEmpty: "Touche le cœur d’un produit pour le retrouver ici.", favAdd: "Ajouter aux favoris", favDel: "Retirer des favoris",
      sale: "à prix réduit", usually: "En général {p}", off: "-{n} %", newB: "Nouveau", lowB: "Stock limité", trends: "Tendances du moment", deals: "Petits prix",
      near: "Près de chez toi", nearIn: "Vendeurs : {c}", shops: "Boutiques à découvrir", seeAll: "Tout voir", dealDay: "Offre du jour", endsIn: "Se termine dans",
      discover: "Découvrez tout Yiriclick", results: "{n} résultat(s)", resultsFor: "Résultats pour « {q} »", filters: "Filtres", sort: "Trier", sNew: "Plus récents", sAsc: "Prix croissant", sDesc: "Prix décroissant",
      pMin: "Prix min", pMax: "Prix max", inStock: "En stock uniquement", reset: "Effacer les filtres", more: "Voir plus", backHome: "Retour à l’accueil", suggest: "Suggestions",
      welcome: "Bienvenue sur Yiriclick", choose: "Choisis ton pays et ta langue", country: "Pays", language: "Langue", welcomeP: "Les prix s’affichent dans la monnaie de ton pays. Tu peux changer à tout moment dans le menu.", go: "Continuer",
      service: "Service et contact", sv1T: "Commander simplement", sv1: "Ajoute au panier, puis envoie ta commande au vendeur sur WhatsApp.", sv2T: "Besoin d’aide ?", sv2: "Écris à l’équipe Yiriclick avec le formulaire de contact. Pour une commande, écris directement au vendeur depuis sa boutique.", svcBtn: "Nous contacter",
      fHelp: "Aide", fHelp1: "Comment commander", fHelp2: "Paiement et livraison", fHelp3: "Vendeurs vérifiés", fSell: "Vendre sur Yiriclick", fSell1: "Nos formules", fSell2: "Espace vendeur", fSell3: "Ouvrir ma boutique",
      fAbout: "À propos", fAbout1: "Qui sommes-nous", fAbout2: "Conditions", fAbout3: "Confidentialité", tagline: "la place de marché des petits vendeurs, partout dans le monde",
      install: "Ajoute Yiriclick à ton écran d’accueil", installP: "Comme une appli, en un geste.", installBtn: "Ajouter", installIos: "Sur iPhone : touche Partager, puis « Sur l’écran d’accueil ».",
      settings: "Pays, langue et monnaie", catTitle: "Catégories", allProducts: "Tous les produits", seeShop: "Voir la boutique", home: "Accueil",
      fam_mode: "Mode et beauté", fam_maison: "Maison et jardin", fam_tech: "Électronique", fam_alim: "Alimentation et agriculture", fam_famille: "Famille et loisirs", fam_pro: "Auto, bâtiment et services" },
    en: { searchBig: "What are you looking for?", voice: "Voice search", voiceOn: "Listening…", doSearch: "Search", menu: "Menu", login: "Sign in", favs: "Favourites", favTitle: "My favourites",
      favEmpty: "Tap the heart on a product to find it here.", favAdd: "Add to favourites", favDel: "Remove from favourites",
      sale: "reduced price", usually: "Usually {p}", off: "-{n}%", newB: "New", lowB: "Limited stock", trends: "Trending now", deals: "Low prices",
      near: "Near you", nearIn: "Sellers: {c}", shops: "Shops to discover", seeAll: "See all", dealDay: "Deal of the day", endsIn: "Ends in",
      discover: "Discover all of Yiriclick", results: "{n} result(s)", resultsFor: "Results for “{q}”", filters: "Filters", sort: "Sort", sNew: "Newest", sAsc: "Price: low to high", sDesc: "Price: high to low",
      pMin: "Min price", pMax: "Max price", inStock: "In stock only", reset: "Clear filters", more: "Show more", backHome: "Back to home", suggest: "Suggestions",
      welcome: "Welcome to Yiriclick", choose: "Choose your country and language", country: "Country", language: "Language", welcomeP: "Prices are shown in your country’s currency. You can change this any time in the menu.", go: "Continue",
      service: "Service and contact", sv1T: "Ordering made simple", sv1: "Add to cart, then send your order to the seller on WhatsApp.", sv2T: "Need help?", sv2: "Write to the Yiriclick team with the contact form. For an order, write to the seller directly from their shop.", svcBtn: "Contact us",
      fHelp: "Help", fHelp1: "How to order", fHelp2: "Payment and delivery", fHelp3: "Verified sellers", fSell: "Sell on Yiriclick", fSell1: "Our plans", fSell2: "Seller space", fSell3: "Open my shop",
      fAbout: "About", fAbout1: "About us", fAbout2: "Terms", fAbout3: "Privacy", tagline: "the marketplace for small sellers, everywhere in the world",
      install: "Add Yiriclick to your home screen", installP: "Just like an app, in one tap.", installBtn: "Add", installIos: "On iPhone: tap Share, then “Add to Home Screen”.",
      settings: "Country, language and currency", catTitle: "Categories", allProducts: "All products", seeShop: "See the shop", home: "Home",
      fam_mode: "Fashion and beauty", fam_maison: "Home and garden", fam_tech: "Electronics", fam_alim: "Food and farming", fam_famille: "Family and leisure", fam_pro: "Cars, building and services" },
    es: { searchBig: "¿Qué estás buscando?", voice: "Búsqueda por voz", voiceOn: "Te escucho…", doSearch: "Buscar", menu: "Menú", login: "Iniciar sesión", favs: "Favoritos", favTitle: "Mis favoritos",
      favEmpty: "Toca el corazón de un producto para encontrarlo aquí.", favAdd: "Añadir a favoritos", favDel: "Quitar de favoritos",
      sale: "precio rebajado", usually: "Normalmente {p}", off: "-{n} %", newB: "Nuevo", lowB: "Pocas unidades", trends: "Tendencias del momento", deals: "Precios bajos",
      near: "Cerca de ti", nearIn: "Vendedores: {c}", shops: "Tiendas para descubrir", seeAll: "Ver todo", dealDay: "Oferta del día", endsIn: "Termina en",
      discover: "Descubre todo Yiriclick", results: "{n} resultado(s)", resultsFor: "Resultados para «{q}»", filters: "Filtros", sort: "Ordenar", sNew: "Más recientes", sAsc: "Precio ascendente", sDesc: "Precio descendente",
      pMin: "Precio mín.", pMax: "Precio máx.", inStock: "Solo con stock", reset: "Borrar filtros", more: "Ver más", backHome: "Volver al inicio", suggest: "Sugerencias",
      welcome: "Bienvenido a Yiriclick", choose: "Elige tu país y tu idioma", country: "País", language: "Idioma", welcomeP: "Los precios se muestran en la moneda de tu país. Puedes cambiarlo cuando quieras en el menú.", go: "Continuar",
      service: "Servicio y contacto", sv1T: "Pedir es sencillo", sv1: "Añade al carrito y envía tu pedido al vendedor por WhatsApp.", sv2T: "¿Necesitas ayuda?", sv2: "Escribe al equipo de Yiriclick con el formulario de contacto. Para un pedido, escribe directamente al vendedor desde su tienda.", svcBtn: "Contáctanos",
      fHelp: "Ayuda", fHelp1: "Cómo pedir", fHelp2: "Pago y entrega", fHelp3: "Vendedores verificados", fSell: "Vender en Yiriclick", fSell1: "Nuestros planes", fSell2: "Espacio vendedor", fSell3: "Abrir mi tienda",
      fAbout: "Acerca de", fAbout1: "Quiénes somos", fAbout2: "Condiciones", fAbout3: "Privacidad", tagline: "el mercado de los pequeños vendedores, en todo el mundo",
      install: "Añade Yiriclick a tu pantalla de inicio", installP: "Como una app, en un gesto.", installBtn: "Añadir", installIos: "En iPhone: toca Compartir y luego «Añadir a pantalla de inicio».",
      settings: "País, idioma y moneda", catTitle: "Categorías", allProducts: "Todos los productos", seeShop: "Ver la tienda", home: "Inicio",
      fam_mode: "Moda y belleza", fam_maison: "Hogar y jardín", fam_tech: "Electrónica", fam_alim: "Alimentación y agricultura", fam_famille: "Familia y ocio", fam_pro: "Motor, construcción y servicios" }, nl: { searchBig: "Wat zoek je?", voice: "Zoeken met je stem", voiceOn: "Ik luister…", doSearch: "Zoeken", menu: "Menu", login: "Inloggen", favs: "Favorieten", favTitle: "Mijn favorieten",
      favEmpty: "Tik op het hartje van een product om het hier terug te vinden.", favAdd: "Toevoegen aan favorieten", favDel: "Verwijderen uit favorieten",
      sale: "afgeprijsd", usually: "Normaal {p}", off: "-{n} %", newB: "Nieuw", lowB: "Bijna op", trends: "Populair op dit moment", deals: "Lage prijzen",
      near: "Bij jou in de buurt", nearIn: "Verkopers: {c}", shops: "Winkels om te ontdekken", seeAll: "Alles bekijken", dealDay: "Deal van de dag", endsIn: "Eindigt over",
      discover: "Ontdek heel Yiriclick", results: "{n} resultaat/resultaten", resultsFor: "Resultaten voor “{q}”", filters: "Filters", sort: "Sorteren", sNew: "Nieuwste", sAsc: "Prijs oplopend", sDesc: "Prijs aflopend",
      pMin: "Min. prijs", pMax: "Max. prijs", inStock: "Alleen op voorraad", reset: "Filters wissen", more: "Meer bekijken", backHome: "Terug naar boven", suggest: "Suggesties",
      welcome: "Welkom bij Yiriclick", choose: "Kies je land en je taal", country: "Land", language: "Taal", welcomeP: "Prijzen worden getoond in de valuta van je land. Je kunt dit altijd wijzigen in het menu.", go: "Doorgaan",
      service: "Service en contact", sv1T: "Bestellen is eenvoudig", sv1: "Voeg toe aan je winkelwagen en stuur je bestelling via WhatsApp naar de verkoper.", sv2T: "Hulp nodig?", sv2: "Schrijf het Yiriclick-team via het contactformulier. Voor een bestelling schrijf je de verkoper direct vanuit zijn winkel.", svcBtn: "Neem contact op",
      fHelp: "Hulp", fHelp1: "Hoe bestellen", fHelp2: "Betaling en levering", fHelp3: "Geverifieerde verkopers", fSell: "Verkopen op Yiriclick", fSell1: "Onze formules", fSell2: "Verkopersruimte", fSell3: "Open mijn winkel",
      fAbout: "Over ons", fAbout1: "Wie zijn wij", fAbout2: "Voorwaarden", fAbout3: "Privacy", tagline: "de markt van kleine verkopers, wereldwijd",
      install: "Zet Yiriclick op je beginscherm", installP: "Net als een app, met één tik.", installBtn: "Toevoegen", installIos: "Op iPhone: tik op Delen en daarna op “Zet op beginscherm”.",
      settings: "Land, taal en valuta", catTitle: "Categorieën", allProducts: "Alle producten", seeShop: "Bekijk de winkel", home: "Home",
      fam_mode: "Mode en beauty", fam_maison: "Huis en tuin", fam_tech: "Elektronica", fam_alim: "Voeding en landbouw", fam_famille: "Gezin en vrije tijd", fam_pro: "Auto, bouw en diensten" }
  };
  Object.keys(T2).forEach(function (L) { Object.keys(T2[L]).forEach(function (k) { T[L][k] = T2[L][k]; }); });
  var FAMILIES = [["fam_mode", ["mode", "chaussures", "bijoux", "textile", "beaute", "sante"]], ["fam_maison", ["deco", "meubles", "electromenager", "animaux"]],
    ["fam_tech", ["tech", "info", "numerique"]], ["fam_alim", ["alim", "boissons", "agri"]], ["fam_famille", ["bebe", "jouets", "sport", "livres", "musique", "artisanat"]],
    ["fam_pro", ["auto", "btp", "services", "autre"]]];

  function extendT(d) { Object.keys(d).forEach(function (L) { T[L] = T[L] || {}; Object.keys(d[L]).forEach(function (k) { T[L][k] = d[L][k]; }); }); }
  /* Orders and variants */
  extendT({
    fr: { cc: "Indicatif du pays", sizeGuide: "Guide des tailles", sizeNote: "Mesures indicatives en cm : elles varient selon les marques. En cas de doute, demande au vendeur.", gEU: "Europe", gFoot: "Pied (cm)", gSize: "Taille", gFR: "Taille FR", gChest: "Poitrine (cm)", gWaist: "Tour de taille (cm)", chooseVar: "Choisir", pickOpt: "Choisis : {o}", placeOrder: "Envoyer ma commande", placing: "Envoi en cours…", placeHelp: "Ta commande est enregistrée chez chaque vendeur avec un numéro. Tu pourras ensuite la lui envoyer sur WhatsApp.",
      orderErr: "La commande n’a pas pu être enregistrée. Réessaie.", orderNo: "Commande n° {n}", orderedTitle: "Commande enregistrée", orderedHelp: "Merci ! Le vendeur a reçu ta commande. Envoie-la-lui aussi sur WhatsApp pour aller plus vite : il te confirme la disponibilité, la livraison et le paiement.",
      noWaRec: "{s} a bien reçu ta commande sur Yiriclick et te contactera.", myOrders: "Mes commandes", ordersHelp: "Les commandes passées depuis ce téléphone ou cet ordinateur, avec leur suivi.",
      st_nouvelle: "En attente", st_confirmee: "Confirmée", st_expediee: "Expédiée", st_livree: "Livrée", st_annulee: "Annulée",
      soldes: "Soldes", saleEndsH: "fin dans {n} h", saleEndsD: "fin dans {n} j", promoHave: "J’ai un code promo", promoCode: "Code", promoPh: "EX. BIENVENUE10", promoApply: "Appliquer",
      promoBad: "Ce code n’est pas valable pour cette boutique.", promoMin: "dès {m} d’achat", afterPromo: "Après réduction", promoRemove: "Retirer le code",
      revTitle: "Ton avis sur {s}", revNote: "Note sur 5", revPh: "Qu’as-tu pensé du produit et du vendeur ? (facultatif)", revSend: "Publier mon avis", revPick: "Choisis une note de 1 à 5 étoiles.", revThanks: "Merci pour ton avis !",
      reviews: "Avis clients", nReviews: "{n} avis", noReviews: "Pas encore d’avis.", sellerReply: "Réponse du vendeur" },
    en: { cc: "Country code", sizeGuide: "Size guide", sizeNote: "Indicative measurements in cm: they vary by brand. If in doubt, ask the seller.", gEU: "EU", gFoot: "Foot (cm)", gSize: "Size", gFR: "FR size", gChest: "Chest (cm)", gWaist: "Waist (cm)", chooseVar: "Choose", pickOpt: "Choose: {o}", placeOrder: "Send my order", placing: "Sending…", placeHelp: "Your order is recorded with each seller with a number. You can then send it to them on WhatsApp.",
      orderErr: "The order could not be recorded. Please try again.", orderNo: "Order no. {n}", orderedTitle: "Order recorded", orderedHelp: "Thank you! The seller has received your order. Send it on WhatsApp too to speed things up: they will confirm availability, delivery and payment.",
      noWaRec: "{s} has received your order on Yiriclick and will contact you.", myOrders: "My orders", ordersHelp: "Orders placed from this phone or computer, with their status.",
      st_nouvelle: "Pending", st_confirmee: "Confirmed", st_expediee: "Shipped", st_livree: "Delivered", st_annulee: "Cancelled",
      soldes: "Sale", saleEndsH: "ends in {n} h", saleEndsD: "ends in {n} d", promoHave: "I have a promo code", promoCode: "Code", promoPh: "E.G. WELCOME10", promoApply: "Apply",
      promoBad: "This code is not valid for this shop.", promoMin: "from {m} spent", afterPromo: "After discount", promoRemove: "Remove code",
      revTitle: "Your review of {s}", revNote: "Rating out of 5", revPh: "What did you think of the product and the seller? (optional)", revSend: "Post my review", revPick: "Choose a rating from 1 to 5 stars.", revThanks: "Thank you for your review!",
      reviews: "Customer reviews", nReviews: "{n} reviews", noReviews: "No reviews yet.", sellerReply: "Seller’s reply" },
    es: { cc: "Prefijo del país", sizeGuide: "Guía de tallas", sizeNote: "Medidas orientativas en cm: varían según la marca. Si tienes dudas, pregunta al vendedor.", gEU: "Europa", gFoot: "Pie (cm)", gSize: "Talla", gFR: "Talla FR", gChest: "Pecho (cm)", gWaist: "Cintura (cm)", chooseVar: "Elegir", pickOpt: "Elige: {o}", placeOrder: "Enviar mi pedido", placing: "Enviando…", placeHelp: "Tu pedido queda registrado en cada vendedor con un número. Después podrás enviárselo por WhatsApp.",
      orderErr: "No se pudo registrar el pedido. Inténtalo de nuevo.", orderNo: "Pedido n.º {n}", orderedTitle: "Pedido registrado", orderedHelp: "¡Gracias! El vendedor ha recibido tu pedido. Envíaselo también por WhatsApp para ir más rápido: te confirmará disponibilidad, entrega y pago.",
      noWaRec: "{s} ha recibido tu pedido en Yiriclick y se pondrá en contacto contigo.", myOrders: "Mis pedidos", ordersHelp: "Los pedidos hechos desde este teléfono u ordenador, con su seguimiento.",
      st_nouvelle: "Pendiente", st_confirmee: "Confirmado", st_expediee: "Enviado", st_livree: "Entregado", st_annulee: "Cancelado",
      soldes: "Rebajas", saleEndsH: "termina en {n} h", saleEndsD: "termina en {n} d", promoHave: "Tengo un código promocional", promoCode: "Código", promoPh: "EJ. BIENVENIDA10", promoApply: "Aplicar",
      promoBad: "Este código no es válido para esta tienda.", promoMin: "a partir de {m}", afterPromo: "Tras el descuento", promoRemove: "Quitar el código",
      revTitle: "Tu opinión sobre {s}", revNote: "Nota sobre 5", revPh: "¿Qué te parecieron el producto y el vendedor? (opcional)", revSend: "Publicar mi opinión", revPick: "Elige una nota de 1 a 5 estrellas.", revThanks: "¡Gracias por tu opinión!",
      reviews: "Opiniones de clientes", nReviews: "{n} opiniones", noReviews: "Todavía no hay opiniones.", sellerReply: "Respuesta del vendedor" }, nl: { cc: "Landcode", sizeGuide: "Maattabel", sizeNote: "Indicatieve maten in cm: ze verschillen per merk. Twijfel je? Vraag het de verkoper.", gEU: "Europa", gFoot: "Voet (cm)", gSize: "Maat", gFR: "Maat FR", gChest: "Borst (cm)", gWaist: "Taille (cm)", chooseVar: "Kiezen", pickOpt: "Kies: {o}", placeOrder: "Mijn bestelling versturen", placing: "Bezig met versturen…", placeHelp: "Je bestelling wordt bij elke verkoper geregistreerd met een nummer. Daarna kun je hem via WhatsApp versturen.",
      orderErr: "De bestelling kon niet worden geregistreerd. Probeer het opnieuw.", orderNo: "Bestelling nr. {n}", orderedTitle: "Bestelling geregistreerd", orderedHelp: "Bedankt! De verkoper heeft je bestelling ontvangen. Stuur hem ook via WhatsApp voor een snellere afhandeling: hij bevestigt beschikbaarheid, levering en betaling.",
      noWaRec: "{s} heeft je bestelling op Yiriclick ontvangen en neemt contact met je op.", myOrders: "Mijn bestellingen", ordersHelp: "Bestellingen vanaf deze telefoon of computer, met de status.",
      st_nouvelle: "In behandeling", st_confirmee: "Bevestigd", st_expediee: "Verzonden", st_livree: "Geleverd", st_annulee: "Geannuleerd",
      soldes: "Uitverkoop", saleEndsH: "eindigt over {n} u", saleEndsD: "eindigt over {n} d", promoHave: "Ik heb een kortingscode", promoCode: "Code", promoPh: "BV. WELKOM10", promoApply: "Toepassen",
      promoBad: "Deze code is niet geldig voor deze winkel.", promoMin: "vanaf {m}", afterPromo: "Na korting", promoRemove: "Code verwijderen",
      revTitle: "Jouw beoordeling van {s}", revNote: "Score op 5", revPh: "Wat vond je van het product en de verkoper? (optioneel)", revSend: "Mijn beoordeling plaatsen", revPick: "Kies een score van 1 tot 5 sterren.", revThanks: "Bedankt voor je beoordeling!",
      reviews: "Klantbeoordelingen", nReviews: "{n} beoordelingen", noReviews: "Nog geen beoordelingen.", sellerReply: "Antwoord van de verkoper" }
  });
  function load(k, d) { try { return localStorage.getItem(k) || d; } catch (e) { return d; } }
  function save(k, v) { try { localStorage.setItem(k, v); } catch (e) {} }
  var navLang = (navigator.language || "fr").slice(0, 2);
  var prefs = { lang: load("yc-lang", T[navLang] ? navLang : "fr"), cur: load("yc-cur", "") };
  if (!T[prefs.lang]) prefs.lang = "fr";

  function t(key, vars) { var s = (T[prefs.lang] || T.fr)[key] || key; for (var k in vars || {}) s = s.split("{" + k + "}").join(vars[k]); return s; }
  function cat(c) { return (CATS[prefs.lang] || CATS.fr)[c] || ""; }
  function el(tag, cls, text) { var e = document.createElement(tag); if (cls) e.className = cls; if (text != null) e.textContent = text; return e; }
  function pub(path) { return path ? URL_SB + "/storage/v1/object/public/boutiques/" + path.split("/").map(encodeURIComponent).join("/") : ""; }
  function money(v, d) {
    var whole = d === "XOF";
    /* CFA franc: always "2 500 FCFA" (locale grouping, even for 4 digits), never the code "XOF" or "FCFA 2.500" */
    if (whole) { try { return new Intl.NumberFormat(LOCALE[prefs.lang], { maximumFractionDigits: 0, useGrouping: "always" }).format(v) + "\u00A0FCFA"; } catch (e) { try { return new Intl.NumberFormat(LOCALE[prefs.lang], { maximumFractionDigits: 0 }).format(v) + "\u00A0FCFA"; } catch (x) {} } }
    try { return new Intl.NumberFormat(LOCALE[prefs.lang], { style: "currency", currency: d, minimumFractionDigits: whole ? 0 : 2, maximumFractionDigits: whole ? 0 : 2 }).format(v); }
    catch (e) { return Number(v).toFixed(whole ? 0 : 2) + " " + d; }
  }
  function convert(v, from, to) { return Number(v) / RATES[from] * RATES[to]; }
  /* Second line under a price: the amount in the visitor's chosen currency, when it differs */
  function approx(p) {
    var to = prefs.cur; if (!to || to === p.devise) return "";
    var exact = (to === "XOF" && p.devise === "EUR") || (to === "EUR" && p.devise === "XOF");
    var v = money(convert(p.prix, p.devise, to), to);
    return exact ? "= " + v : t("approx", { v: v, d: RATES_DATE.toLocaleDateString(LOCALE[prefs.lang], { day: "2-digit", month: "2-digit", year: "numeric" }) });
  }
  /* Anonymous statistics for sellers (no personal data). Views are counted once per browser session,
     and a seller's own visits are skipped (vendeur remembers which shop is theirs). */
  var SRC = /(\/|index\.html|vitrine(\.html)?)$/.test(location.pathname) ? "vitrine" : "boutique";
  function track(type, boutiqueId, produitId) {
    try {
      if (!boutiqueId) return;
      if (String(localStorage.getItem("yc-own-shop") || "") === String(boutiqueId)) return;
      if (/^vue_/.test(type)) { var k = "yc-seen-" + type + (produitId || boutiqueId); if (sessionStorage.getItem(k)) return; sessionStorage.setItem(k, "1"); }
      var row = { type: type, boutique_id: boutiqueId, source: SRC }; if (produitId) row.produit_id = produitId;
      var q = sb.from("evenements").insert(row); if (q && q.then) q.then(function () {}, function () {});
    } catch (e) {}
  }
  function shopIdOf(p, shop) { return (p && p.boutique_id) || (shop && shop.id) || null; }
  function waLink(shop, p) {
    var d = String(shop.whatsapp || "").replace(/\D/g, ""); if (d.length < 8) return "";
    var u = location.origin + location.pathname.replace(/[^/]*$/, "") + "boutique?b=" + encodeURIComponent(shop.slug) + "&p=" + p.id;
    return "https://wa.me/" + d + "?text=" + encodeURIComponent(t("waMsg", { p: p.nom, x: money(p.prix, p.devise), u: u }));
  }

  /* Header preferences: language and currency selects */
  var prefsListeners = [];
  function wirePrefs(onChange) {
    if (onChange) prefsListeners.push(onChange);
    var ls = document.getElementById("prefLang"), cs = document.getElementById("prefCur");
    if (ls) { ls.value = prefs.lang; ls.addEventListener("change", function () { setPrefs(ls.value, null); }); }
    if (cs) { cs.value = prefs.cur; cs.addEventListener("change", function () { setPrefs(null, cs.value); }); }
    document.documentElement.lang = prefs.lang;
  }
  function setPrefs(lang, cur) {
    if (lang && T[lang]) { prefs.lang = lang; save("yc-lang", lang); document.documentElement.lang = lang; }
    if (cur != null) { prefs.cur = cur; save("yc-cur", cur); }
    var ls = document.getElementById("prefLang"), cs = document.getElementById("prefCur");
    if (ls) ls.value = prefs.lang; if (cs) cs.value = prefs.cur;
    prefsListeners.forEach(function (f) { f(); });
  }
  function labels() {
    document.querySelectorAll("[data-t]").forEach(function (n) { n.textContent = t(n.getAttribute("data-t")); });
    document.querySelectorAll("[data-tp]").forEach(function (n) { n.placeholder = t(n.getAttribute("data-tp")); });
    document.querySelectorAll("[data-ta]").forEach(function (n) { n.setAttribute("aria-label", t(n.getAttribute("data-ta"))); });
    var cs = document.getElementById("prefCur"); if (cs && cs.options[0]) cs.options[0].textContent = cs.closest(".ch-f") ? "—" : t("cur") + " : —";
    cartBadge();
    var cw = document.getElementById("cartWrap"); if (cw && !cw.hidden) renderCart();
  }

  /* Favourites: kept in this visitor's browser */
  var favs = [];
  try { favs = JSON.parse(localStorage.getItem("yc-favs") || "[]"); if (!Array.isArray(favs)) favs = []; } catch (e) { favs = []; }
  var favListeners = [];
  function isFav(id) { return favs.indexOf(id) >= 0; }
  function toggleFav(id, p) {
    if (isFav(id)) favs = favs.filter(function (x) { return x !== id; }); else { favs.unshift(id); if (p) track("favori", p.boutique_id, id); }
    try { localStorage.setItem("yc-favs", JSON.stringify(favs.slice(0, 200))); } catch (e) {}
    document.querySelectorAll('[data-fav="' + id + '"]').forEach(function (b) { favPaint(b, id); });
    favListeners.forEach(function (f) { f(); });
  }
  var HEART = '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round" aria-hidden="true"><path d="M12 20s-7-4.4-9-8.6C1.6 8.3 3.6 5 6.8 5c2 0 3.4 1.1 4.2 2.4h2C13.8 6.1 15.2 5 17.2 5c3.2 0 5.2 3.3 3.8 6.4C19 15.6 12 20 12 20z"/></svg>';
  function favPaint(b, id) { var on = isFav(id); b.classList.toggle("on", on); b.setAttribute("aria-pressed", String(on)); b.setAttribute("aria-label", on ? t("favDel") : t("favAdd")); }
  function favButton(p) {
    var b = el("button", "fav"); b.type = "button"; b.setAttribute("data-fav", p.id); b.innerHTML = HEART; favPaint(b, p.id);
    b.addEventListener("click", function (e) { e.stopPropagation(); toggleFav(p.id, p); if (b.animate && isFav(p.id)) b.animate([{ transform: "scale(1)" }, { transform: "scale(1.3)" }, { transform: "scale(1)" }], { duration: 300 }); });
    return b;
  }
  function discount(p) { return p.prix_avant && Number(p.prix_avant) > Number(p.prix) ? Math.round((1 - Number(p.prix) / Number(p.prix_avant)) * 100) : 0; }
  /* Scheduled sales: during the period the sale price becomes the price, the normal price is shown crossed out */
  function saleOn(p) {
    if (p.solde_prix == null || !(Number(p.solde_prix) < Number(p.prix))) return false;
    var n = Date.now();
    return (!p.solde_debut || new Date(p.solde_debut).getTime() <= n) && (!p.solde_fin || new Date(p.solde_fin).getTime() > n);
  }
  function prep(list) {
    (list || []).forEach(function (p) {
      if (p._prep) return; p._prep = true;
      if (saleOn(p)) { var base = Number(p.prix); p.solde_ratio = Number(p.solde_prix) / base; p.prix_avant = Math.max(Number(p.prix_avant) || 0, base); p.prix = Number(p.solde_prix); p.en_solde = true; }
    });
    return list;
  }
  function endsIn(p) {
    if (!p.en_solde || !p.solde_fin) return "";
    var h = Math.max(1, Math.round((new Date(p.solde_fin).getTime() - Date.now()) / 3600e3));
    return h < 48 ? t("saleEndsH", { n: h }) : t("saleEndsD", { n: Math.round(h / 24) });
  }
  function isNew(p) { return p.created_at && (Date.now() - new Date(p.created_at).getTime()) < 7 * 24 * 3600 * 1000; }
  function priceBlock(p, big) {
    var w = el("div", "pblock" + (big ? " big" : "")), d = discount(p);
    var pr = el("span", d ? "pr pr-sale" : "pr", money(p.prix, p.devise)); w.appendChild(pr);
    if (d) {
      w.appendChild(el("span", "sale-l", t("sale") + " · " + t("off", { n: d })));
      var u = el("span", "usual"); u.appendChild(document.createTextNode(t("usually", { p: "" }).replace(/\s*$/, "") + " "));
      u.appendChild(el("s", null, money(p.prix_avant, p.devise))); w.appendChild(u);
    }
    var a = approx(p); if (a) w.appendChild(el("span", "cv", a));
    return w;
  }

  /* Product card: photo and title open the details; "Commander" goes straight to WhatsApp with a ready message */
  function card(p, shop, showShop, onOpen) {
    var c = el("article", "item");
    var media = el("div", "media");
    var open = el("button", "item-open"); open.type = "button";
    if (p.photos && p.photos[0]) { var im = el("img", "im"); im.src = pub(p.photos[0]); im.alt = ""; im.loading = "lazy"; media.appendChild(im); }
    else media.appendChild(el("div", "noim"));
    var badges = el("div", "badges"), d = discount(p);
    if (d) badges.appendChild(el("span", "bdg bdg-sale", t("off", { n: d })));
    if (p.en_solde) badges.appendChild(el("span", "bdg bdg-solde", t("soldes")));
    if (isNew(p)) badges.appendChild(el("span", "bdg bdg-new", t("newB")));
    if (p.stock != null && p.stock > 0 && p.stock <= 3) badges.appendChild(el("span", "bdg bdg-low", t("lowB")));
    if (badges.children.length) media.appendChild(badges);
    open.appendChild(media);
    var ib = el("div", "ib");
    if (showShop && shop) ib.appendChild(el("span", "shopname", shop.nom));
    ib.appendChild(el("h3", null, p.nom));
    ib.appendChild(priceBlock(p));
    if (endsIn(p)) ib.appendChild(el("span", "ends", "⏱ " + t("soldes") + " · " + endsIn(p)));
    if (hasVar(p)) { var o0 = p.variantes.options[0], vs = o0.valeurs; ib.appendChild(el("span", "sizes", o0.nom + " : " + vs.slice(0, 6).join(" · ") + (vs.length > 6 ? " …" : ""))); }
    open.appendChild(ib);
    open.addEventListener("click", function () { onOpen(p, shop); });
    c.appendChild(open);
    c.appendChild(favButton(p));
    var acts = el("div", "item-acts");
    var out = p.stock === 0, vr = hasVar(p), lbl = out ? t("outStock") : vr ? t("chooseVar") : t("addLong");
    var buy = el("button", "btn btn-wa btn-buy"); buy.type = "button";
    if (out) buy.disabled = true; else buy.addEventListener("click", function () { if (vr) onOpen(p, shop); else cartAdd(p, shop, 1, buy); });
    buy.innerHTML = CART_SVG;
    buy.appendChild(document.createTextNode(lbl));
    buy.setAttribute("aria-label", lbl + " : " + p.nom);
    var det = el("button", "btn btn-ghost btn-det", t("details")); det.type = "button";
    det.setAttribute("aria-label", t("details") + " : " + p.nom);
    det.addEventListener("click", function () { onOpen(p, shop); });
    acts.appendChild(buy); acts.appendChild(det); c.appendChild(acts);
    return c;
  }

  /* ===================== Variants =====================
     p.variantes = { options: [{ nom, valeurs: [] }], combis: [{ v: [], stock, prix }] } */
  function hasVar(p) { return !!(p && p.variantes && Array.isArray(p.variantes.options) && p.variantes.options.length); }
  function combiOf(p, v) {
    if (!hasVar(p) || !v) return null;
    var cs = p.variantes.combis || [], k = JSON.stringify(v);
    for (var i = 0; i < cs.length; i++) if (JSON.stringify(cs[i].v) === k) return cs[i];
    return null;
  }
  function varPrice(p, v) { var c = combiOf(p, v); return c && typeof c.prix === "number" ? Math.round(c.prix * (p.solde_ratio || 1) * 100) / 100 : Number(p.prix); }
  function varStock(p, v) {
    if (!hasVar(p)) return p.stock;
    var cs = p.variantes.combis || []; if (!cs.length) return p.stock;
    var c = combiOf(p, v); if (!c) return 0;
    return typeof c.stock === "number" ? c.stock : null;
  }
  /* Indicative size guides (vary by brand) */
  function guideKind(o, p) {
    if (/pointure|shoe|calzado/i.test(o.nom) || (p.categorie === "chaussures" && /taille|size|talla/i.test(o.nom))) return o.valeurs.some(function (v) { return Number(v) >= 36; }) ? "shoes" : null;
    if (/taille|size|talla/i.test(o.nom) && o.valeurs.some(function (v) { return /^(XS|S|M|L|XL|XXL)$/i.test(v); })) return "clothes";
    return null;
  }
  function guideTable(kind) {
    var rows = kind === "shoes"
      ? [[t("gEU"), "UK", "US", t("gFoot")], ["36", "3,5", "4,5", "23"], ["37", "4", "5", "23,5"], ["38", "5", "6", "24"], ["39", "6", "7", "25"], ["40", "6,5", "7,5", "25,5"], ["41", "7,5", "8,5", "26"], ["42", "8", "9", "26,5"], ["43", "9", "10", "27,5"], ["44", "9,5", "10,5", "28"], ["45", "10,5", "11,5", "29"], ["46", "11", "12", "29,5"]]
      : [[t("gSize"), t("gFR"), t("gChest"), t("gWaist")], ["XS", "34", "80–84", "64–68"], ["S", "36", "84–90", "68–74"], ["M", "38–40", "90–98", "74–82"], ["L", "42", "98–106", "82–90"], ["XL", "44", "106–114", "90–98"], ["XXL", "46", "114–122", "98–106"]];
    var tb = el("table", "gtable");
    rows.forEach(function (r, i) { var tr = el("tr"); r.forEach(function (c) { tr.appendChild(el(i ? "td" : "th", null, c)); }); tb.appendChild(tr); });
    return tb;
  }
  function vLabel(v) { return v && v.length ? v.join(" / ") : ""; }

  /* ===================== Cart =====================
     Kept in this visitor's browser. Checkout records one order per seller in Yiriclick
     (prices and stock are checked by the database), then the visitor sends it on WhatsApp.
     Online payment is not connected yet. */
  var CART_SVG = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M4 5h2l2 10h10l2-7H7"/><circle cx="10" cy="19" r="1.4"/><circle cx="17" cy="19" r="1.4"/></svg>';
  function readJSON(k, d) { try { var v = JSON.parse(localStorage.getItem(k) || "null"); return v == null ? d : v; } catch (e) { return d; } }
  var cart = readJSON("yc-cart", []); if (!Array.isArray(cart)) cart = [];
  cart.forEach(function (i) { if (!i.key) i.key = i.id; });
  var buyer = readJSON("yc-buyer", {}) || {};
  var cartView = "list", cartNotice = "", cartBusy = false;
  var sentLog = readJSON("yc-sent", []); if (!Array.isArray(sentLog)) sentLog = [];
  var myOrders = readJSON("yc-orders", []); if (!Array.isArray(myOrders)) myOrders = [];
  var justOrdered = [];
  function sentSave() {
    var day = Date.now() - 24 * 3600 * 1000;
    sentLog = sentLog.filter(function (x) { return x.at > day; }).slice(-10);
    try { localStorage.setItem("yc-sent", JSON.stringify(sentLog)); } catch (e) {}
  }
  sentSave();
  function ordersSave() {
    var old = Date.now() - 60 * 24 * 3600 * 1000;
    myOrders = myOrders.filter(function (o) { return o.at > old; }).slice(-30);
    try { localStorage.setItem("yc-orders", JSON.stringify(myOrders)); } catch (e) {}
  }
  /* Fallback (database not updated): tapping "Envoyer à … sur WhatsApp" takes those products out of the cart */
  function markSent(g) {
    sentLog.push({ at: Date.now(), shop: g.shop, items: g.items.map(function (i) { return JSON.parse(JSON.stringify(i)); }) });
    var keys = g.items.map(function (i) { return i.key; });
    cart = cart.filter(function (i) { return keys.indexOf(i.key) < 0; });
    sentSave(); cartSave();
  }
  function restoreSent(entry) {
    entry.items.forEach(function (it) { if (!it.key) it.key = it.id; var ex = cart.filter(function (i) { return i.key === it.key; })[0]; if (ex) ex.qty += it.qty; else cart.push(it); });
    sentLog = sentLog.filter(function (x) { return x !== entry; }); sentSave(); cartSave();
  }
  function sentBlock(p, recentOnly) {
    var list = sentLog.slice().reverse().filter(function (x) { return !recentOnly || x.at > Date.now() - 2 * 3600 * 1000; });
    if (!list.length) return;
    var box = el("div", "sent-box"); box.appendChild(el("h3", null, t("sentTitle")));
    list.forEach(function (x) {
      var r = el("div", "sent-row");
      var tm = new Date(x.at).toLocaleTimeString(LOCALE[prefs.lang], { hour: "2-digit", minute: "2-digit" });
      r.appendChild(el("span", null, "✓ " + t("sentLine", { s: x.shop.nom, h: tm, n: x.items.reduce(function (n, i) { return n + i.qty; }, 0) })));
      var b = el("button", "cart-rm", t("restore")); b.type = "button";
      b.addEventListener("click", function () { restoreSent(x); cartView = "list"; renderCart(); });
      r.appendChild(b); box.appendChild(r);
    });
    p.appendChild(box);
  }
  function cartSave() { try { localStorage.setItem("yc-cart", JSON.stringify(cart)); } catch (e) {} cartBadge(); }
  function cartCount() { return cart.reduce(function (n, i) { return n + i.qty; }, 0); }
  function cartAdd(p, shop, q, fromBtn, v) {
    if (!shop) return;
    if (hasVar(p) && !v) { openProduct(p, shop, { showShop: !!fromBtn && fromBtn.closest && !!fromBtn.closest(".vitrine") }); return; }
    var stock = varStock(p, v), max = stock == null ? 99 : stock, key = p.id + (v ? "|" + v.join("|") : "");
    if (max <= 0) return;
    var it = cart.filter(function (i) { return i.key === key; })[0], price = varPrice(p, v);
    if (it) { it.qty = Math.min(max, it.qty + q); it.prix = price; it.devise = p.devise; it.stock = stock; }
    else cart.push({ key: key, id: p.id, v: v || null, qty: Math.min(max, q), nom: p.nom, prix: price, devise: p.devise, stock: stock, photo: p.photos && p.photos[0] || null, shop: { id: shopIdOf(p, shop), slug: shop.slug, nom: shop.nom, whatsapp: shop.whatsapp || "" } });
    cartSave(); toast(t("added"), fromBtn); track("ajout_panier", shopIdOf(p, shop), p.id);
    var b = document.getElementById("cartBtn");
    if (b && b.animate && !matchMedia("(prefers-reduced-motion: reduce)").matches) b.animate([{ transform: "scale(1)" }, { transform: "scale(1.18)" }, { transform: "scale(1)" }], { duration: 380 });
  }
  function cartBadge() {
    var n = cartCount(), b = document.getElementById("cartN"), btn = document.getElementById("cartBtn");
    if (!b) return; b.textContent = n; b.hidden = !n;
    btn.setAttribute("aria-label", t("cart") + (n ? " (" + n + ")" : ""));
  }
  function exactPair(a, b) { return a === b || (a === "XOF" && b === "EUR") || (a === "EUR" && b === "XOF"); }
  function sumIn(items, to) {
    var approxF = false, v = items.reduce(function (s, i) { if (!exactPair(i.devise, to)) approxF = true; return s + convert(i.prix * i.qty, i.devise, to); }, 0);
    return { v: v, approx: approxF };
  }
  function groups() {
    var g = {}, order = [];
    cart.forEach(function (i) { var k = i.shop.slug; if (!g[k]) { g[k] = { shop: i.shop, items: [] }; order.push(k); } g[k].items.push(i); });
    return order.map(function (k) { return g[k]; });
  }

  var toastTimer = null;
  function toast(msg) {
    var tb = document.getElementById("ycToast");
    tb.querySelector(".tmsg").textContent = msg;
    tb.querySelector("button").textContent = t("viewCart");
    tb.hidden = false; clearTimeout(toastTimer); toastTimer = setTimeout(function () { tb.hidden = true; }, 3200);
  }

  function setupCart() {
    var prefsBox = document.querySelector(".prefs"); if (!prefsBox) return;
    var b = el("button", "cart-btn"); b.type = "button"; b.id = "cartBtn";
    b.innerHTML = CART_SVG.replace('width="16" height="16"', 'width="22" height="22"');
    var n = el("span", "cart-n", "0"); n.id = "cartN"; b.appendChild(n);
    b.addEventListener("click", function () { openCart(); });
    prefsBox.appendChild(b);
    var tb = el("div", "yc-toast"); tb.id = "ycToast"; tb.hidden = true; tb.setAttribute("role", "status");
    tb.appendChild(el("span", "tmsg")); var vb = el("button", null, ""); vb.type = "button"; vb.addEventListener("click", function () { tb.hidden = true; openCart(); }); tb.appendChild(vb);
    document.body.appendChild(tb);
    var d = el("div", "cart-wrap"); d.id = "cartWrap"; d.hidden = true;
    var bg = el("div", "cart-bg"); bg.addEventListener("click", closeCart); d.appendChild(bg);
    var p = el("div", "cart-panel"); p.id = "cartPanel"; p.setAttribute("role", "dialog"); p.setAttribute("aria-modal", "true"); p.setAttribute("aria-labelledby", "cartTitle");
    d.appendChild(p); document.body.appendChild(d);
    document.addEventListener("keydown", function (e) { if (e.key === "Escape" && !d.hidden) closeCart(); });
    cartBadge();
  }
  var cartLast = null;
  async function openCart(view, fromNav) {
    cartLast = document.activeElement; cartView = view || "list";
    var d = document.getElementById("cartWrap"); d.hidden = false; document.body.style.overflow = "hidden";
    if (!fromNav && window.YNav) YNav.opened("cart", cartView);
    renderCart(); var x = document.querySelector("#cartPanel .mclose"); if (x) x.focus();
    await refreshCart(); await refreshOrders(); renderCart();
  }
  function hideCart() { var d = document.getElementById("cartWrap"); if (!d || d.hidden) return; d.hidden = true; document.body.style.overflow = document.getElementById("pmodal") && !document.getElementById("pmodal").hidden ? "hidden" : ""; if (cartLast && cartLast.focus) cartLast.focus(); }
  function closeCart() { if (!(window.YNav && YNav.close("cart"))) hideCart(); }
  if (window.YNav) YNav.layer("cart", { open: function (v) { openCart(v, true); }, close: hideCart });
  /* Refresh prices, stock and availability from the database before ordering */
  async function refreshCart() {
    if (!cart.length) return;
    var base = "id,nom,prix,devise,stock,photos,boutique_id,boutiques(nom,slug,whatsapp)", ids = cart.map(function (i) { return i.id; });
    var r = await sb.from("produits").select("variantes,solde_prix,solde_debut,solde_fin," + base).in("id", ids);
    if (r.error) r = await sb.from("produits").select("variantes," + base).in("id", ids);
    if (r.error) r = await sb.from("produits").select(base).in("id", ids);
    if (r.error || !r.data) return;
    prep(r.data);
    var map = {}; r.data.forEach(function (p) { map[p.id] = p; });
    var before = cart.length;
    cart = cart.filter(function (i) {
      var p = map[i.id]; if (!p || !p.boutiques) return false;
      if (hasVar(p) && (!i.v || (p.variantes.combis || []).length && !combiOf(p, i.v))) return false;
      return varStock(p, i.v) !== 0;
    }).map(function (i) {
      var p = map[i.id], stock = varStock(p, i.v), max = stock == null ? 99 : stock;
      return { key: i.key, id: i.id, v: i.v || null, qty: Math.min(i.qty, max), nom: p.nom, prix: varPrice(p, i.v), devise: p.devise, stock: stock, photo: p.photos && p.photos[0] || null,
        shop: { id: p.boutique_id, slug: p.boutiques.slug, nom: p.boutiques.nom, whatsapp: p.boutiques.whatsapp || "" } };
    });
    if (cart.length < before) cartNotice = t("gone");
    cartSave();
  }
  /* Order status, for the orders placed from this browser */
  async function refreshOrders() {
    var ids = myOrders.slice(-20).map(function (o) { return o.id; });
    if (!ids.length) return;
    var r = await sb.rpc("suivi_commandes", { ids: ids });
    if (r.error || !r.data) return;
    r.data.forEach(function (s) { myOrders.forEach(function (o) { if (o.id === s.id) { o.statut = s.statut; if (s.a_avis != null) o.a_avis = s.a_avis; } }); });
    ordersSave();
  }
  function head(p, title) {
    var h = el("div", "cart-head"), ti = el("h2", null, title); ti.id = "cartTitle"; h.appendChild(ti);
    var x = el("button", "mclose", "×"); x.type = "button"; x.setAttribute("aria-label", t("close")); x.addEventListener("click", closeCart); h.appendChild(x);
    p.appendChild(h);
  }
  function renderCart() {
    var p = document.getElementById("cartPanel"); if (!p) return; p.textContent = "";
    if (cartView === "info") return renderInfo(p);
    if (cartView === "send") return renderSend(p);
    if (cartView === "orders") return renderOrders(p);
    head(p, t("cartTitle") + (cartCount() ? " (" + cartCount() + ")" : ""));
    if (cartNotice) { p.appendChild(el("p", "cart-notice", cartNotice)); cartNotice = ""; }
    if (!cart.length) {
      sentBlock(p, false);
      p.appendChild(el("p", "cart-empty", t("cartEmpty")));
      var k = el("a", "btn btn-navy", t("keepShopping")); k.href = "./"; p.appendChild(k);
      ordersLink(p);
      return;
    }
    groups().forEach(function (g) {
      var sec = el("section", "cart-group");
      var sh = el("a", "cart-shop", g.shop.nom); sh.href = "boutique?b=" + encodeURIComponent(g.shop.slug); sec.appendChild(sh);
      g.items.forEach(function (i) {
        var row = el("div", "cart-row");
        if (i.photo) { var im = el("img"); im.src = pub(i.photo); im.alt = ""; row.appendChild(im); } else row.appendChild(el("div", "cart-noim"));
        var info = el("div", "cart-info"); info.appendChild(el("b", null, i.nom));
        if (i.v) info.appendChild(el("span", "cart-var", vLabel(i.v)));
        info.appendChild(el("span", "cart-unit", money(i.prix, i.devise)));
        var ctl = el("div", "cart-ctl"), stp = el("div", "stepper"), max = i.stock == null ? 99 : i.stock;
        var mi = el("button", null, "−"), qv = el("span", "qv", String(i.qty)), pl = el("button", null, "+");
        mi.type = pl.type = "button"; mi.setAttribute("aria-label", t("less") + " : " + i.nom); pl.setAttribute("aria-label", t("more") + " : " + i.nom);
        mi.disabled = i.qty <= 1; pl.disabled = i.qty >= max; if (pl.disabled) pl.title = t("maxStock");
        mi.addEventListener("click", function () { i.qty = Math.max(1, i.qty - 1); cartSave(); renderCart(); });
        pl.addEventListener("click", function () { i.qty = Math.min(max, i.qty + 1); cartSave(); renderCart(); });
        stp.appendChild(mi); stp.appendChild(qv); stp.appendChild(pl); ctl.appendChild(stp);
        var rm = el("button", "cart-rm", t("remove")); rm.type = "button"; rm.setAttribute("aria-label", t("remove") + " : " + i.nom);
        rm.addEventListener("click", function () { cart = cart.filter(function (x) { return x.key !== i.key; }); cartSave(); renderCart(); });
        ctl.appendChild(rm); info.appendChild(ctl); row.appendChild(info);
        row.appendChild(el("span", "cart-line", money(i.prix * i.qty, i.devise)));
        sec.appendChild(row);
      });
      var to = g.items[0].devise, st = sumIn(g.items, to);
      var sub = el("div", "cart-sub"); sub.appendChild(el("span", null, t("subtotal"))); sub.appendChild(el("b", null, (st.approx ? t("approxSign") : "") + money(st.v, to)));
      sec.appendChild(sub);
      promoBlock(sec, g, st, to);
      p.appendChild(sec);
    });
    var cur = prefs.cur || cart[0].devise, tot = sumIn(cart, cur);
    groups().forEach(function (g) { var to = g.items[0].devise, amt = promoAmount(g, sumIn(g.items, to)); if (amt) tot.v -= convert(amt, to, cur); });
    var tr = el("div", "cart-total"); tr.appendChild(el("span", null, t("total"))); tr.appendChild(el("b", null, (tot.approx ? t("approxSign") : "") + money(tot.v, cur)));
    p.appendChild(tr);
    var go = el("button", "btn btn-wa cart-go", t("checkout")); go.type = "button"; go.addEventListener("click", function () { cartView = "info"; renderCart(); var f = document.getElementById("cName"); if (f) f.focus(); });
    p.appendChild(go);
    var k2 = el("button", "cart-rm", t("keepShopping")); k2.type = "button"; k2.style.alignSelf = "center"; k2.addEventListener("click", closeCart); p.appendChild(k2);
    ordersLink(p);
  }
  /* Promo code per seller: checked by the database, applied again when the order is recorded */
  var promos = {}, promoOff = false;
  function promoAmount(g, st) {
    var c = promos[g.shop.id]; if (!c) return 0;
    if (st.v < Number(c.min_achat)) return 0;
    return c.type === "pct" ? Math.round(st.v * Number(c.valeur)) / 100 : Math.min(Number(c.valeur), st.v);
  }
  function promoBlock(sec, g, st, to) {
    if (promoOff || !g.shop.id) return;
    var c = promos[g.shop.id];
    if (c) {
      var r = el("div", "cart-sub promo-on"), amt = promoAmount(g, st);
      var l = el("span", null, t("promoCode") + " " + c.code); r.appendChild(l);
      if (amt) r.appendChild(el("b", null, "− " + money(amt, to)));
      else r.appendChild(el("span", "cart-help", t("promoMin", { m: money(c.min_achat, to) })));
      sec.appendChild(r);
      if (amt) { var nt = el("div", "cart-sub"); nt.appendChild(el("span", null, t("afterPromo"))); nt.appendChild(el("b", null, money(st.v - amt, to))); sec.appendChild(nt); }
      var x = el("button", "cart-rm", t("promoRemove")); x.type = "button"; x.addEventListener("click", function () { delete promos[g.shop.id]; renderCart(); }); sec.appendChild(x);
      return;
    }
    var d = el("details", "promo-box"), sm = el("summary", null, t("promoHave")); d.appendChild(sm);
    var f = el("form", "promo-form"); f.noValidate = true;
    var lab = el("label", "vh", t("promoCode")), inp = el("input"); inp.id = "pc-" + g.shop.id; lab.setAttribute("for", inp.id); inp.autocapitalize = "characters"; inp.maxLength = 20; inp.placeholder = t("promoPh");
    var b = el("button", "btn btn-navy", t("promoApply")); b.type = "submit";
    var err = el("p", "wa-note"); err.setAttribute("role", "status");
    f.appendChild(lab); f.appendChild(inp); f.appendChild(b); d.appendChild(f); d.appendChild(err);
    f.addEventListener("submit", async function (e) {
      e.preventDefault(); var code = inp.value.trim().toUpperCase(); if (!code) return;
      b.disabled = true; var r = await sb.rpc("verifier_code", { p_boutique: g.shop.id, p_code: code }); b.disabled = false;
      if (r.error) { if (/function|schema cache|not found/i.test(r.error.message || "")) { promoOff = true; renderCart(); return; } err.textContent = t("orderErr"); return; }
      var row = Array.isArray(r.data) ? r.data[0] : r.data;
      if (!row) { err.textContent = t("promoBad"); return; }
      promos[g.shop.id] = row; renderCart();
    });
    sec.appendChild(d);
  }
  function ordersLink(p) {
    if (!myOrders.length) return;
    var b = el("button", "cart-rm", t("myOrders") + " (" + myOrders.length + ")"); b.type = "button"; b.style.alignSelf = "center";
    b.addEventListener("click", function () { cartView = "orders"; renderCart(); }); p.appendChild(b);
  }
  function renderInfo(p) {
    head(p, t("yourInfo"));
    if (cartNotice) { p.appendChild(el("p", "cart-notice", cartNotice)); cartNotice = ""; }
    var f = el("form", "cart-form"); f.noValidate = true;
    function fld(id, key, type, area) {
      var w = el("div", "cfield"), l = el("label", null, t(key)); l.setAttribute("for", id); w.appendChild(l);
      var i = el(area ? "textarea" : "input"); i.id = id; if (!area) i.type = type || "text"; else i.rows = 3; i.value = buyer[id] || "";
      if (type === "tel") { i.inputMode = "tel"; i.autocomplete = "tel"; } if (id === "cName") i.autocomplete = "name"; if (id === "cAddr") i.autocomplete = "street-address";
      w.appendChild(i); var e = el("span", "cerr"); e.id = id + "-err"; w.appendChild(e); f.appendChild(w); return i;
    }
    var n = fld("cName", "cName"), ph = fld("cPhone", "cPhone", "tel"), ad = fld("cAddr", "cAddr", "text", true), no = fld("cNote", "cNote", "text", true);
    ph.placeholder = "70 00 00 00"; n.maxLength = 80;
    if (window.YPhone) YPhone.attach(ph, { label: t("cc") }); ad.maxLength = 300; no.maxLength = 600;
    var go = el("button", "btn btn-wa cart-go", t("placeOrder")); go.type = "submit"; f.appendChild(go);
    f.appendChild(el("p", "cart-help", t("placeHelp")));
    var bk = el("button", "cart-rm", t("cartTitle")); bk.type = "button"; bk.style.alignSelf = "center"; bk.addEventListener("click", function () { cartView = "list"; renderCart(); }); f.appendChild(bk);
    f.addEventListener("submit", async function (e) {
      e.preventDefault(); if (cartBusy) return; var ok = true, first = null;
      function err(i, m) { document.getElementById(i.id + "-err").textContent = m || ""; if (m) { i.setAttribute("aria-invalid", "true"); ok = false; first = first || i; } else i.removeAttribute("aria-invalid"); }
      err(n, n.value.trim().length >= 2 ? "" : t("eReq"));
      var pv = window.YPhone ? YPhone.value(ph) : ph.value.trim();
      err(ph, !ph.value.trim() ? t("eReq") : (window.YPhone ? YPhone.valid(ph) : /^\+?[0-9 ().-]{8,20}$/.test(pv) && pv.replace(/\D/g, "").length >= 8) ? "" : (window.YPhone && YPhone.expected(ph) ? t("ePhoneN", { n: YPhone.expected(ph) }) : t("ePhone")));
      err(ad, ad.value.trim().length >= 3 ? "" : t("eReq"));
      if (!ok) { first.focus(); return; }
      buyer = { cName: n.value.trim(), cPhone: pv, cAddr: ad.value.trim(), cNote: no.value.trim() };
      try { localStorage.setItem("yc-buyer", JSON.stringify(buyer)); } catch (x) {}
      cartBusy = true; go.disabled = true; go.textContent = t("placing");
      await placeOrders();
      cartBusy = false;
      renderCart();
    });
    p.appendChild(f);
  }
  /* Records one order per seller. If the database is not updated yet, falls back to WhatsApp only. */
  async function placeOrders() {
    justOrdered = [];
    var gs = groups(), failed = null;
    for (var k = 0; k < gs.length; k++) {
      var g = gs[k]; if (!g.shop.id) continue;
      var args = { p_boutique: g.shop.id, p_nom: buyer.cName, p_tel: buyer.cPhone, p_adresse: buyer.cAddr, p_note: buyer.cNote || "",
        p_articles: g.items.map(function (i) { var a = { id: i.id, qty: i.qty }; if (i.v) a.v = i.v; return a; }), p_langue: prefs.lang };
      if (promos[g.shop.id]) args.p_code = promos[g.shop.id].code;
      var r = await sb.rpc("passer_commande", args);
      if (r.error) {
        if (/function|schema cache|does not exist|not found/i.test(r.error.message || "")) break; /* old database: WhatsApp only */
        failed = r.error.message || t("orderErr"); break;
      }
      var row = Array.isArray(r.data) ? r.data[0] : r.data;
      var st = sumIn(g.items, g.items[0].devise);
      var tot = row.total != null ? money(row.total, g.items[0].devise) : (st.approx ? t("approxSign") : "") + money(st.v, g.items[0].devise);
      if (row.remise && Number(row.remise) > 0) tot += " (" + t("promoCode") + " " + promos[g.shop.id].code + " : − " + money(row.remise, g.items[0].devise) + ")";
      delete promos[g.shop.id];
      var o = { id: row.id, numero: row.numero, at: Date.now(), statut: "nouvelle", shop: g.shop, total: tot,
        items: g.items.map(function (i) { return { nom: i.nom, v: i.v || null, qty: i.qty, prix: i.prix, devise: i.devise }; }) };
      myOrders.push(o); justOrdered.push(o);
      var keys = g.items.map(function (i) { return i.key; });
      cart = cart.filter(function (i) { return keys.indexOf(i.key) < 0; });
    }
    ordersSave(); cartSave();
    if (failed && !justOrdered.length) { cartNotice = failed; cartView = "info"; return; }
    if (failed) cartNotice = failed;
    cartView = "send";
  }
  function orderText(o) {
    var lines = [t("waCart", { s: o.shop.nom })];
    if (o.numero) lines.push(t("orderNo", { n: o.numero }));
    lines.push("");
    o.items.forEach(function (i) { lines.push("• " + i.qty + " × " + i.nom + (i.v ? " (" + vLabel(i.v) + ")" : "") + " – " + money(i.prix, i.devise) + " = " + money(i.prix * i.qty, i.devise)); });
    lines.push("", t("waTotal") + " : " + o.total, "");
    lines.push(t("waName") + " : " + buyer.cName, t("waPhone") + " : " + buyer.cPhone, t("waAddr") + " : " + buyer.cAddr);
    if (buyer.cNote) lines.push(t("waNote") + " : " + buyer.cNote);
    lines.push("", t("waEnd"));
    return lines.join("\n");
  }
  function waButton(sec, o, onClick) {
    var d = String(o.shop.whatsapp || "").replace(/\D/g, "");
    if (d.length < 8) { sec.appendChild(el("p", "wa-note", o.numero ? t("noWaRec", { s: o.shop.nom }) : t("noWaShop", { s: o.shop.nom }))); return; }
    var a = el("a", "btn btn-wa cart-go", o.numero ? t("sendTo", { s: o.shop.nom }) : t("sendTo", { s: o.shop.nom }));
    a.href = "https://wa.me/" + d + "?text=" + encodeURIComponent(orderText(o)); a.target = "_blank"; a.rel = "noopener";
    a.addEventListener("click", onClick); sec.appendChild(a);
  }
  function renderSend(p) {
    var gs = groups().filter(function (g) { return !g.shop.id || !justOrdered.length; });
    head(p, justOrdered.length ? t("orderedTitle") : t("sendTitle"));
    if (cartNotice) { p.appendChild(el("p", "cart-notice", cartNotice)); cartNotice = ""; }
    if (justOrdered.length) {
      var ok = el("div", "cart-done"); ok.appendChild(el("span", "cart-done-ic", "✓")); ok.appendChild(el("p", "cart-help", t("orderedHelp"))); p.appendChild(ok);
      justOrdered.forEach(function (o) {
        var sec = el("section", "cart-group");
        sec.appendChild(el("b", "cart-shop", o.shop.nom));
        sec.appendChild(el("p", "order-no", t("orderNo", { n: o.numero })));
        sec.appendChild(el("p", "cart-help", o.items.reduce(function (n, i) { return n + i.qty; }, 0) + " × · " + o.total));
        waButton(sec, o, function () {});
        p.appendChild(sec);
      });
    }
    if (!justOrdered.length && !gs.length) {
      var dn = el("div", "cart-done");
      dn.appendChild(el("span", "cart-done-ic", "✓")); dn.appendChild(el("h3", null, t("doneTitle"))); dn.appendChild(el("p", "cart-help", t("doneText")));
      p.appendChild(dn); sentBlock(p, true);
    } else if (gs.length) {
      if (gs.length > 1) p.appendChild(el("p", "cart-help", t("sendHelp")));
      gs.forEach(function (g) {
        var sec = el("section", "cart-group"); sec.appendChild(el("b", "cart-shop", g.shop.nom));
        var st = sumIn(g.items, g.items[0].devise), o = { shop: g.shop, items: g.items, total: (st.approx ? t("approxSign") : "") + money(st.v, g.items[0].devise) };
        sec.appendChild(el("p", "cart-help", g.items.reduce(function (n, i) { return n + i.qty; }, 0) + " × · " + o.total));
        waButton(sec, o, function () { track("commande_envoyee", g.shop.id); markSent(g); setTimeout(renderCart, 300); });
        p.appendChild(sec);
      });
      sentBlock(p, true);
    }
    var k = el("a", "btn btn-navy cart-go", t("keepShopping")); k.href = "./"; p.appendChild(k);
    if (!justOrdered.length && gs.length) { var ed = el("button", "cart-rm", t("editInfo")); ed.type = "button"; ed.style.alignSelf = "center"; ed.addEventListener("click", function () { cartView = "info"; renderCart(); }); p.appendChild(ed); }
    ordersLink(p);
  }
  function renderOrders(p) {
    head(p, t("myOrders"));
    p.appendChild(el("p", "cart-help", t("ordersHelp")));
    myOrders.slice().reverse().forEach(function (o) {
      var sec = el("section", "cart-group order-card");
      var top = el("div", "order-top"); top.appendChild(el("b", null, o.shop.nom)); top.appendChild(el("span", "ostat ostat-" + (o.statut || "nouvelle"), t("st_" + (o.statut || "nouvelle")))); sec.appendChild(top);
      sec.appendChild(el("p", "order-no", t("orderNo", { n: o.numero }) + " · " + new Date(o.at).toLocaleDateString(LOCALE[prefs.lang], { day: "numeric", month: "short" })));
      o.items.forEach(function (i) { sec.appendChild(el("p", "cart-help", i.qty + " × " + i.nom + (i.v ? " (" + vLabel(i.v) + ")" : ""))); });
      sec.appendChild(el("p", "cart-help", t("waTotal") + " : " + o.total));
      if (o.statut !== "livree" && o.statut !== "annulee") waButton(sec, o, function () {});
      if (o.statut === "livree" && o.a_avis === false) reviewForm(sec, o);
      if (o.a_avis) sec.appendChild(el("p", "cart-help", "✓ " + t("revThanks")));
      p.appendChild(sec);
    });
    var bk = el("button", "cart-rm", t("cartTitle")); bk.type = "button"; bk.style.alignSelf = "center"; bk.addEventListener("click", function () { cartView = "list"; renderCart(); }); p.appendChild(bk);
  }
  /* Review form (base v14): overall rating, ratings per criterion, causes when something went wrong,
     call-back request, and a short optional part about Yiriclick itself. Falls back to the v7 form if the base is older. */
  var REV_CRIT = ["produit", "qualite", "livraison", "emballage", "vendeur", "prix"], YC_CRIT = ["facilite", "confiance", "suivi"];
  var REV_CAUSES = ["abime", "non_conforme", "qualite", "taille", "manquant", "retard", "vendeur_injoignable", "vendeur_impoli", "prix", "emballage", "paiement", "autre"];
  function starRow(label, size, onPick) {
    var row = el("div", "rv-row" + (size === "s" ? " rv-small" : "")), val = 0;
    if (label) row.appendChild(el("span", "rv-lbl", label));
    var g = el("div", "rev-stars"); g.setAttribute("role", "radiogroup"); g.setAttribute("aria-label", label || t("revNote"));
    for (var i = 1; i <= 5; i++) (function (n) {
      var b = el("button", null, "★"); b.type = "button"; b.setAttribute("role", "radio"); b.setAttribute("aria-checked", "false"); b.setAttribute("aria-label", n + " / 5");
      b.addEventListener("click", function () {
        val = val === n && size === "s" ? 0 : n;
        Array.prototype.forEach.call(g.children, function (x, k) { x.classList.toggle("on", k < val); x.setAttribute("aria-checked", String(k === val - 1)); });
        onPick(val);
      });
      g.appendChild(b);
    })(i);
    row.appendChild(g); return row;
  }
  /* done: called after a successful review (noter); by default the cart's order list is updated */
  function reviewForm(sec, o, done) {
    var f = el("form", "rev-form"); f.noValidate = true;
    var d = { note: 0, criteres: {}, causes: [], recontact: false, yc: { note: 0, criteres: {}, recommande: null } };
    f.appendChild(el("b", "rv-h", t("revTitle", { s: o.shop.nom })));
    f.appendChild(starRow(null, "l", function (v) { d.note = v; update(); }));
    var hint = el("p", "rv-hint", t("rvHint")); f.appendChild(hint);

    var crit = el("div", "rv-crit"); crit.appendChild(el("span", "rv-sub", t("rvDetail")));
    REV_CRIT.forEach(function (k) { crit.appendChild(starRow(t("rvc_" + k), "s", function (v) { if (v) d.criteres[k] = v; else delete d.criteres[k]; update(); })); });
    f.appendChild(crit);

    var cz = el("fieldset", "rv-causes"); cz.hidden = true;
    cz.appendChild(el("legend", null, t("rvWhat")));
    var chips = el("div", "rv-chips");
    REV_CAUSES.forEach(function (k) {
      var lb = el("label", "rv-chip"), cb = el("input"); cb.type = "checkbox"; cb.value = k;
      cb.addEventListener("change", function () { var i = d.causes.indexOf(k); if (cb.checked && i < 0) d.causes.push(k); if (!cb.checked && i >= 0) d.causes.splice(i, 1); lb.classList.toggle("on", cb.checked); });
      lb.appendChild(cb); lb.appendChild(el("span", null, t("rvk_" + k))); chips.appendChild(lb);
    });
    cz.appendChild(chips); f.appendChild(cz);

    var tl = el("label", "rv-sub"); var ta = el("textarea"); ta.rows = 3; ta.maxLength = 1000; ta.id = "rvTxt" + o.id.slice(0, 8);
    tl.htmlFor = ta.id; f.appendChild(tl); f.appendChild(ta);

    var rc = el("label", "rv-check"); rc.hidden = true; var rcb = el("input"); rcb.type = "checkbox";
    rcb.addEventListener("change", function () { d.recontact = rcb.checked; });
    rc.appendChild(rcb); rc.appendChild(el("span", null, t("rvCall"))); f.appendChild(rc);

    /* Yiriclick part: one tap for the recommendation, the rest folded */
    var y = el("fieldset", "rv-yc"); y.appendChild(el("legend", null, t("rvReco")));
    var nps = el("div", "rv-nps"); nps.setAttribute("role", "radiogroup"); nps.setAttribute("aria-label", t("rvReco"));
    for (var i = 0; i <= 10; i++) (function (n) {
      var b = el("button", null, String(n)); b.type = "button"; b.setAttribute("role", "radio"); b.setAttribute("aria-checked", "false");
      b.addEventListener("click", function () {
        d.yc.recommande = d.yc.recommande === n ? null : n;
        Array.prototype.forEach.call(nps.children, function (x, k) { x.classList.toggle("on", k === d.yc.recommande); x.setAttribute("aria-checked", String(k === d.yc.recommande)); });
      });
      nps.appendChild(b);
    })(i);
    y.appendChild(nps);
    var ends = el("div", "rv-ends"); ends.appendChild(el("span", null, t("rvNo"))); ends.appendChild(el("span", null, t("rvYes"))); y.appendChild(ends);
    var more = el("details", "rv-more"); more.appendChild(el("summary", null, t("rvYcMore")));
    more.appendChild(starRow(t("rvYcNote"), "s", function (v) { d.yc.note = v; }));
    YC_CRIT.forEach(function (k) { more.appendChild(starRow(t("rvc_" + k), "s", function (v) { if (v) d.yc.criteres[k] = v; else delete d.yc.criteres[k]; })); });
    var yl = el("label", "rv-sub", t("rvYcIdea")), yta = el("textarea"); yta.rows = 2; yta.maxLength = 1000; yta.id = "rvYc" + o.id.slice(0, 8); yl.htmlFor = yta.id;
    more.appendChild(yl); more.appendChild(yta); y.appendChild(more); f.appendChild(y);

    f.appendChild(el("p", "rv-legal", t("rvLegal")));
    var err = el("p", "wa-note"); err.setAttribute("role", "status"); f.appendChild(err);
    var go = el("button", "btn btn-navy", t("revSend")); go.type = "submit"; f.appendChild(go);

    function bad() { if (d.note && d.note <= 3) return true; for (var k in d.criteres) if (d.criteres[k] <= 2) return true; return false; }
    function update() {
      var b = bad(); cz.hidden = !b; rc.hidden = !b;
      tl.textContent = b ? t("rvTxtBad") : t("rvTxtGood"); ta.placeholder = b ? t("rvPhBad") : t("rvPhGood");
      hint.hidden = !!d.note;
    }
    update();
    f.addEventListener("submit", async function (e) {
      e.preventDefault(); if (!d.note) { err.textContent = t("revPick"); f.querySelector(".rev-stars button").focus(); return; }
      if (bad() && !d.causes.length && ta.value.trim().length < 10) { err.textContent = t("rvNeedWhy"); cz.querySelector("input").focus(); return; }
      var payload = { note: d.note, commentaire: ta.value.trim(), criteres: d.criteres, causes: bad() ? d.causes : [], recontact: bad() && d.recontact, langue: dbLang(prefs.lang),
        yc: { note: d.yc.note || null, commentaire: yta.value.trim(), criteres: d.yc.criteres, recommande: d.yc.recommande } };
      go.disabled = true; err.textContent = "";
      var r = await sb.rpc("laisser_avis_v2", { p_commande: o.id, p_data: payload });
      if (r.error && (r.error.code === "PGRST202" || /laisser_avis_v2/.test(r.error.message || ""))) r = await sb.rpc("laisser_avis", { p_commande: o.id, p_note: d.note, p_commentaire: ta.value.trim() });
      go.disabled = false;
      if (r.error) { err.textContent = r.error.message || t("orderErr"); return; }
      o.a_avis = true;
      if (done) { done(); return; }
      ordersSave(); renderCart();
    });
    sec.appendChild(f);
  }

  /* Public list of reviews with summary, sorting and "show more". Used by boutique and avis. */
  function reviewsUI(box, list, opts) {
    opts = opts || {}; box.textContent = "";
    var n = list.length; if (!n) { box.appendChild(el("p", "rv-empty", t("noReviews"))); return; }
    var loc = LOCALE[prefs.lang], fmt = function (x) { return x.toLocaleString(loc, { maximumFractionDigits: 1, minimumFractionDigits: 1 }); };
    function stars(v) { var r = Math.round(v); return "★★★★★".slice(0, r) + "☆☆☆☆☆".slice(0, 5 - r); }
    var avg = list.reduce(function (s, r) { return s + r.note; }, 0) / n;
    var top = el("div", "rv-top"), sum = el("div", "rev-sum");
    sum.appendChild(el("span", "big", fmt(avg))); var w = el("div"); var s1 = el("div", "stars", stars(avg)); s1.setAttribute("aria-hidden", "true"); w.appendChild(s1); w.appendChild(el("div", "who", t("nReviews", { n: n }))); sum.appendChild(w);
    top.appendChild(sum);
    var dist = el("div", "rv-dist");
    for (var k = 5; k >= 1; k--) {
      var c = list.filter(function (r) { return r.note === k; }).length, row = el("div", "rv-drow");
      row.appendChild(el("span", null, k + " ★")); var bar = el("span", "rv-bar"), fill = el("i"); fill.style.width = Math.round(c / n * 100) + "%"; bar.appendChild(fill); row.appendChild(bar);
      row.appendChild(el("span", "rv-dn", String(c))); row.setAttribute("aria-label", t("rvDist", { k: k, c: c })); dist.appendChild(row);
    }
    top.appendChild(dist);
    /* criteria averages, only those rated at least 3 times */
    var keys = opts.cible === "yiriclick" ? YC_CRIT : REV_CRIT, cr = el("div", "rv-cavg");
    keys.forEach(function (k) {
      var v = list.map(function (r) { return r.criteres && r.criteres[k]; }).filter(function (x) { return x >= 1; });
      if (v.length >= 3) { var a = v.reduce(function (s, x) { return s + x; }, 0) / v.length, it = el("span"); it.appendChild(el("b", null, fmt(a))); it.appendChild(document.createTextNode(" " + t("rvc_" + k))); cr.appendChild(it); }
    });
    if (cr.children.length) top.appendChild(cr);
    box.appendChild(top);

    var tools = el("div", "rv-tools"), lab = el("label", null, t("rvSort")), sel = el("select"); sel.id = "rvSort" + (opts.cible || "b"); lab.htmlFor = sel.id;
    ["pert", "recent", "best", "worst"].forEach(function (v) { var op = el("option", null, t("rvs_" + v)); op.value = v; sel.appendChild(op); });
    tools.appendChild(lab); tools.appendChild(sel); box.appendChild(tools);
    var ul = el("div", "revs"), shown = 10, mb = el("button", "btn btn-ghost rv-moreb"); mb.type = "button";
    box.appendChild(ul); box.appendChild(mb);
    box.appendChild(el("p", "rv-legal", t("rvHow")));
    function sorted() {
      var a = list.slice(), v = sel.value, d = function (r) { return new Date(r.created_at).getTime(); };
      if (v === "recent") a.sort(function (x, y) { return d(y) - d(x); });
      else if (v === "best") a.sort(function (x, y) { return y.note - x.note || d(y) - d(x); });
      else if (v === "worst") a.sort(function (x, y) { return x.note - y.note || d(y) - d(x); });
      else a.sort(function (x, y) { return (y.mis_en_avant ? 1 : 0) - (x.mis_en_avant ? 1 : 0) || ((y.commentaire ? 1 : 0) - (x.commentaire ? 1 : 0)) || d(y) - d(x); });
      return a;
    }
    function draw() {
      ul.textContent = "";
      sorted().slice(0, shown).forEach(function (r) {
        var c = el("article", "rev" + (r.mis_en_avant && sel.value === "pert" ? " rev-star" : "")), hd = el("div", "rv-hd");
        var s2 = el("span", "stars", stars(r.note)); s2.setAttribute("aria-label", r.note + " / 5"); hd.appendChild(s2);
        if (r.mis_en_avant) hd.appendChild(el("span", "rv-badge", t("rvPicked")));
        hd.appendChild(el("span", "rv-ok", "✓ " + t("rvVerified"))); c.appendChild(hd);
        c.appendChild(el("span", "who", r.nom + " · " + new Date(r.created_at).toLocaleDateString(loc, { day: "numeric", month: "long", year: "numeric" })));
        if (r.commentaire) c.appendChild(el("p", null, r.commentaire));
        if (r.reponse) { var rp = el("div", "reply"); rp.appendChild(el("b", null, t(opts.cible === "yiriclick" ? "rvYcReply" : "sellerReply") + " : ")); rp.appendChild(document.createTextNode(r.reponse)); c.appendChild(rp); }
        ul.appendChild(c);
      });
      mb.hidden = shown >= n; mb.textContent = t("rvMore", { n: Math.min(10, n - shown) });
    }
    sel.addEventListener("change", function () { shown = 10; draw(); });
    mb.addEventListener("click", function () { shown += 10; draw(); });
    draw();
  }
  window.addEventListener("storage", function (e) { if (e.key === "yc-sent") { try { sentLog = JSON.parse(e.newValue || "[]"); } catch (x) { sentLog = []; } } if (e.key === "yc-cart") { try { cart = JSON.parse(e.newValue || "[]"); } catch (x) { cart = []; } cart.forEach(function (i) { if (!i.key) i.key = i.id; }); cartBadge(); } if (e.key === "yc-orders") { myOrders = readJSON("yc-orders", []); } });

  var lastFocus = null;
  /* Product sheet. opts: showShop, list (the products around it, for Previous / Next), url (its own address),
     fromNav (opened by the browser's Forward button: no new history step) */
  var shown = null, prodCache = {}, productListeners = [];
  function openProduct(p, shop, opts) {
    opts = opts || {};
    var m = document.getElementById("pmodal"); var box = m.querySelector(".mbox"); box.textContent = "";
    var wasOpen = !m.hidden;
    shown = { p: p, shop: shop, opts: opts }; prodCache[p.id] = shown;
    var x = el("button", "mclose", "×"); x.type = "button"; x.setAttribute("aria-label", t("close")); x.addEventListener("click", closeProduct); box.appendChild(x);
    /* top bar: back, and previous / next product of the list it was opened from */
    var bar = el("div", "mnav"), bk = el("button", "mback", "← " + t("goBack")); bk.type = "button"; bk.addEventListener("click", closeProduct); bar.appendChild(bk);
    var list = opts.list || [], at = -1;
    list.forEach(function (x2, i) { if (x2[0].id === p.id) at = i; });
    if (at >= 0 && list.length > 1) {
      var pn = el("div", "mpn");
      var pv = el("button", "mpv", "‹"); pv.type = "button"; pv.setAttribute("aria-label", t("prevP")); pv.title = t("prevP"); pv.disabled = at === 0;
      var nx = el("button", "mpv", "›"); nx.type = "button"; nx.setAttribute("aria-label", t("nextP")); nx.title = t("nextP"); nx.disabled = at === list.length - 1;
      pv.addEventListener("click", function () { if (at > 0) openProduct(list[at - 1][0], list[at - 1][1], Object.assign({}, opts, { fromNav: false, focusNav: "prev" })); });
      nx.addEventListener("click", function () { if (at < list.length - 1) openProduct(list[at + 1][0], list[at + 1][1], Object.assign({}, opts, { fromNav: false, focusNav: "next" })); });
      pn.appendChild(pv); pn.appendChild(el("span", "mpos", (at + 1) + " / " + list.length)); pn.appendChild(nx); bar.appendChild(pn);
    }
    box.appendChild(bar);
    var gal = el("div", "gal"), sl = el("div", "slides"), photos = (p.photos || []).length ? p.photos : [null];
    photos.forEach(function (ph, i) { if (!ph) { var d = el("div", "noim"); d.style.aspectRatio = "1"; sl.appendChild(d); return; } var im = el("img"); im.src = pub(ph); im.alt = p.nom + " – " + (i + 1); sl.appendChild(im); });
    gal.appendChild(sl);
    if (photos.length > 1) {
      /* arrows for mouse users; the keyboard ← → do the same */
      [["‹", -1, "prevPh"], ["›", 1, "nextPh"]].forEach(function (a) {
        var b = el("button", "gnav " + (a[1] < 0 ? "gprev" : "gnext"), a[0]); b.type = "button"; b.setAttribute("aria-label", t(a[2]));
        b.addEventListener("click", function () { slide(sl, a[1]); }); gal.appendChild(b);
      });
      var dots = el("div", "dots"); photos.forEach(function (_, i) { dots.appendChild(el("span", i ? "" : "on")); }); gal.appendChild(dots);
      sl.addEventListener("scroll", function () { var i = Math.round(sl.scrollLeft / sl.clientWidth); Array.prototype.forEach.call(dots.children, function (d, k) { d.className = k === i ? "on" : ""; }); }, { passive: true });
    }
    box.appendChild(gal);
    var bd = el("div", "mbody");
    if (opts.showShop && shop) { var sa = el("a", null, t("by", { s: shop.nom })); sa.href = "boutique?b=" + encodeURIComponent(shop.slug); sa.style.color = "var(--teal-deep)"; sa.style.fontWeight = "700"; bd.appendChild(sa); }
    var h = el("h2", null, p.nom); h.id = "pmTitle"; bd.appendChild(h);
    track("vue_produit", shopIdOf(p, shop), p.id);
    var vr = hasVar(p), sel = vr ? p.variantes.options.map(function () { return null; }) : null;
    var hr = el("div", "m-pricerow"), pbox = el("div"); pbox.appendChild(priceBlock(p, true)); hr.appendChild(pbox); hr.appendChild(favButton(p)); bd.appendChild(hr);
    var metaEl = el("div", "meta"); bd.appendChild(metaEl);
    var vbox = null, row = null, q = 1, max = 99, ad = null, qv = null, mi = null, pl = null;
    function chosen() { return sel && sel.every(function (x) { return x != null; }) ? sel.slice() : null; }
    function curStock() { return vr ? (chosen() ? varStock(p, chosen()) : null) : p.stock; }
    function update() {
      var v = vr ? chosen() : null, s = curStock();
      var meta = [cat(p.categorie)];
      if (!vr || v) { if (s != null) meta.push(s > 0 ? t("stock", { n: s }) : t("outStock")); }
      metaEl.textContent = meta.filter(Boolean).join(" · ");
      if (vr) { pbox.textContent = ""; var pp = Object.assign({}, p); if (v) { pp.prix = varPrice(p, v); if (pp.prix_avant && Number(pp.prix_avant) <= pp.prix) pp.prix_avant = null; } pbox.appendChild(priceBlock(pp, true)); }
      if (vbox) Array.prototype.forEach.call(vbox.querySelectorAll("[data-opt]"), function (b) {
        var k = +b.getAttribute("data-opt"), val = b.getAttribute("data-val"), on = sel[k] === val;
        b.setAttribute("aria-pressed", String(on));
        var test = sel.slice(); test[k] = val;
        var cs = p.variantes.combis || [], possible = !cs.length || cs.some(function (c) { return c.v.every(function (x, j) { return test[j] == null || x === test[j]; }) && c.stock !== 0; });
        b.classList.toggle("na", !possible);
      });
      max = s == null ? 99 : s; if (q > max) q = Math.max(1, max); if (qv) qv.textContent = q;
      if (ad) {
        var need = vr && !v ? p.variantes.options[sel.indexOf(null)].nom : "";
        ad.disabled = !!need || s === 0;
        ad.lastChild.textContent = need ? t("pickOpt", { o: need }) : s === 0 ? t("outStock") : t("addLong");
        mi.disabled = q <= 1; pl.disabled = q >= max;
      }
    }
    if (vr) {
      vbox = el("div", "vpick");
      p.variantes.options.forEach(function (o, k) {
        var g = el("div", "vgroup"), lab = el("span", "vlab", o.nom); lab.id = "vl" + k; g.appendChild(lab);
        var list = el("div", "vvals"); list.setAttribute("role", "group"); list.setAttribute("aria-labelledby", "vl" + k);
        o.valeurs.forEach(function (val) {
          var b = el("button", "vval", val); b.type = "button"; b.setAttribute("data-opt", k); b.setAttribute("data-val", val);
          b.addEventListener("click", function () { sel[k] = sel[k] === val ? null : val; q = 1; update(); });
          list.appendChild(b);
        });
        g.appendChild(list);
        var kind = guideKind(o, p);
        if (kind) {
          var gd = el("details", "sguide"), gs = el("summary", null, t("sizeGuide")); gd.appendChild(gs);
          gd.appendChild(guideTable(kind)); gd.appendChild(el("p", "wa-note", t("sizeNote"))); g.appendChild(gd);
        }
        vbox.appendChild(g);
      });
      bd.appendChild(vbox);
    }
    if (p.description) bd.appendChild(el("p", "desc", p.description));
    if (p.stock !== 0) {
      row = el("div", "m-buy");
      var stp = el("div", "stepper"); mi = el("button", null, "−"); qv = el("span", "qv", "1"); pl = el("button", null, "+");
      mi.type = pl.type = "button"; mi.setAttribute("aria-label", t("less")); pl.setAttribute("aria-label", t("more")); qv.setAttribute("aria-live", "polite");
      mi.addEventListener("click", function () { q = Math.max(1, q - 1); update(); });
      pl.addEventListener("click", function () { q = Math.min(max, q + 1); update(); });
      stp.appendChild(mi); stp.appendChild(qv); stp.appendChild(pl); row.appendChild(stp);
      ad = el("button", "btn btn-wa"); ad.type = "button"; ad.innerHTML = CART_SVG; ad.appendChild(document.createTextNode(t("addLong")));
      ad.addEventListener("click", function () { cartAdd(p, shop, q, ad, vr ? chosen() : null); });
      row.appendChild(ad); bd.appendChild(row);
    }
    update();
    var wa = shop ? waLink(shop, p) : "";
    if (wa && p.stock !== 0) { var w = el("a", "direct", t("orderDirect")); w.href = wa; w.target = "_blank"; w.rel = "noopener"; w.addEventListener("click", function () { track("clic_whatsapp", shopIdOf(p, shop), p.id); }); bd.appendChild(w); }
    else if (!wa) bd.appendChild(el("p", "wa-note", t("noWa")));
    var rp = el("a", "report-link", "⚑ " + t("report"));
    rp.href = "contact?sujet=signalement&produit=" + encodeURIComponent(String(p.id || "")) + "&nom=" + encodeURIComponent(String(p.nom || "").slice(0, 80)) + (shop && shop.nom ? "&boutique=" + encodeURIComponent(String(shop.nom).slice(0, 80)) : "");
    bd.appendChild(rp);
    box.appendChild(bd);
    box.setAttribute("aria-labelledby", "pmTitle");
    if (!wasOpen) lastFocus = document.activeElement;
    m.hidden = false; document.body.style.overflow = "hidden"; box.scrollTop = 0;
    var f = opts.focusNav && box.querySelector(".mpv:not([disabled])" + (opts.focusNav === "next" ? ":last-of-type" : ""));
    (f && !f.disabled ? f : bk).focus({ preventScroll: true });
    if (!opts.fromNav && window.YNav) YNav.opened("product", p.id, opts.url ? opts.url(p, shop) : undefined);
    productListeners.forEach(function (fn) { fn(p, shop); });
  }
  function slide(sl, dir) { sl.scrollBy({ left: dir * sl.clientWidth, behavior: "smooth" }); }
  function hideProduct() {
    var m = document.getElementById("pmodal"); if (!m || m.hidden) return;
    m.hidden = true; shown = null; document.body.style.overflow = "";
    if (lastFocus && lastFocus.focus) lastFocus.focus();
    productListeners.forEach(function (fn) { fn(null); });
  }
  function closeProduct() { if (!(window.YNav && YNav.close("product"))) hideProduct(); }
  if (window.YNav) YNav.layer("product", {
    open: function (id) { var c = prodCache[id]; if (!c) return false; openProduct(c.p, c.shop, Object.assign({}, c.opts, { fromNav: true, focusNav: null })); },
    close: hideProduct
  });
  document.addEventListener("keydown", function (e) {
    var m = document.getElementById("pmodal"); if (!m || m.hidden) return;
    var cw = document.getElementById("cartWrap"); if (cw && !cw.hidden) return;
    if (e.key === "Escape") { closeProduct(); return; }
    if ((e.key === "ArrowLeft" || e.key === "ArrowRight") && !e.altKey && !e.ctrlKey && !e.metaKey && !/^(INPUT|TEXTAREA|SELECT)$/.test((e.target && e.target.nodeName) || "")) {
      var sl = m.querySelector(".slides"); if (sl && sl.children.length > 1) { e.preventDefault(); slide(sl, e.key === "ArrowLeft" ? -1 : 1); }
    }
  });
  document.addEventListener("click", function (e) { if (e.target.classList && e.target.classList.contains("modal-bg")) closeProduct(); });

  function catOptions(select, present) {
    var v = select.value; select.textContent = "";
    var o = el("option", null, t("allCats")); o.value = ""; select.appendChild(o);
    Object.keys(CATS.fr).filter(function (c) { return !present || present.indexOf(c) >= 0; }).forEach(function (c) { var op = el("option", null, cat(c)); op.value = c; select.appendChild(op); });
    select.value = v;
  }
  function norm(x) { return String(x || "").normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase(); }

  extend({
    fr: { goBack: "Retour", prevP: "Produit précédent", nextP: "Produit suivant", prevPh: "Photo précédente", nextPh: "Photo suivante" },
    en: { goBack: "Back", prevP: "Previous product", nextP: "Next product", prevPh: "Previous photo", nextPh: "Next photo" },
    es: { goBack: "Volver", prevP: "Producto anterior", nextP: "Producto siguiente", prevPh: "Foto anterior", nextPh: "Foto siguiente" }, nl: { goBack: "Terug", prevP: "Vorig product", nextP: "Volgend product", prevPh: "Vorige foto", nextPh: "Volgende foto" }
  });
  /* Review form and review list (base v14) */
  extend({
    fr: { fReviews: "Avis clients", fLegal: "Informations légales", fBuy: "Acheter", fdTag: "Club des 50 vendeurs fondateurs", fdTitle: "Tu vends sur Facebook ou WhatsApp ? Ta boutique en ligne t’attend.", fd1: "On t’aide à créer ta boutique, à distance", fd2: "Un lien à partager sur Facebook et WhatsApp", fd3: "14 jours d’essai, puis 4 mois offerts après le lancement*", fd4: "Ton avis compte pour améliorer Yiriclick", fdLeft: "places restantes sur {n}", fdGo: "Je deviens fondateur", fdNote: "*Selon les conditions du programme. Pour l’instant, les commandes passent par WhatsApp ; le paiement en ligne arrive plus tard.", ptMain: "Partenaire principal", ptBand: "Ils soutiennent les petits vendeurs", founderB: "Vendeur fondateur", fSellH: "Vendre", fOrders: "Mes commandes", fReport: "Signaler un problème", fFounders: "Vendeurs fondateurs", fPartners: "Devenir partenaire", fYiri: "Yiriclick", fTerms: "Conditions", fPrivacy: "Confidentialité", fOpen: "Ouvrir ma boutique", chGuess: "On a choisi pour toi, d’après ton appareil. Tu peux changer quand tu veux.", chYouAre: "Ton pays", chPrices: "Prix affichés en", chOk: "C’est bon, continuer", chOther: "Choisir un autre pays", chSearch: "Rechercher un pays", regAf: "Afrique", regEu: "Europe", regAm: "Amérique et autres", pendingShop: "Boutique en cours de vérification par Yiriclick. En attendant, ne paie qu’après avoir confirmé la commande avec le vendeur.", fContact: "Contact", report: "Signaler ce produit", rvHint: "Touche une étoile pour noter.", rvDetail: "Détaille ta note (facultatif)", rvWhat: "Qu’est-ce qui n’a pas été ? Coche tout ce qui s’applique.",
      rvc_produit: "Conforme à la description", rvc_qualite: "Qualité", rvc_livraison: "Délai de livraison", rvc_emballage: "Emballage", rvc_vendeur: "Réponses du vendeur", rvc_prix: "Rapport qualité-prix",
      rvc_facilite: "Facilité de commande", rvc_confiance: "Confiance", rvc_suivi: "Suivi de commande",
      rvk_abime: "Produit abîmé", rvk_non_conforme: "Différent de la photo ou de la description", rvk_qualite: "Qualité décevante", rvk_taille: "Mauvaise taille", rvk_manquant: "Article manquant",
      rvk_retard: "Livraison en retard", rvk_vendeur_injoignable: "Vendeur difficile à joindre", rvk_vendeur_impoli: "Vendeur peu aimable", rvk_prix: "Trop cher", rvk_emballage: "Emballage insuffisant",
      rvk_paiement: "Problème de paiement ou de remboursement", rvk_autre: "Autre",
      rvTxtGood: "Ton commentaire (facultatif)", rvTxtBad: "Raconte ce qui s’est passé", rvPhGood: "Qu’as-tu aimé ? Le produit, la livraison, le vendeur…", rvPhBad: "Plus tu donnes de détails, plus nous pouvons agir vite.",
      rvCall: "Je souhaite que Yiriclick me recontacte sur WhatsApp pour trouver une solution.", rvNeedWhy: "Coche au moins une cause ou décris le problème en quelques mots.",
      rvReco: "Recommanderais-tu Yiriclick à un proche ? (facultatif)", rvNo: "Pas du tout", rvYes: "Certainement", rvYcMore: "Donner aussi mon avis sur Yiriclick (30 secondes)",
      rvYcNote: "Ta note pour Yiriclick", rvYcIdea: "Une idée pour améliorer Yiriclick ?",
      rvLegal: "Ton prénom et l’initiale de ton nom s’affichent avec ton avis. Ton téléphone n’est jamais publié.",
      rvSort: "Trier", rvs_pert: "Les plus pertinents", rvs_recent: "Les plus récents", rvs_best: "Meilleures notes", rvs_worst: "Notes les plus basses",
      rvPicked: "Mis en avant par Yiriclick", rvVerified: "Achat vérifié", rvMore: "Voir {n} avis de plus", rvDist: "{c} avis à {k} étoiles", rvYcReply: "Réponse de Yiriclick",
      rvHow: "Comment fonctionnent les avis : seuls les clients dont la commande a été livrée peuvent donner leur avis, une fois par commande. Les avis ne sont ni achetés ni triés selon leur note. Yiriclick masque un avis seulement s’il est injurieux, faux, hors sujet ou s’il contient des données personnelles. « Mis en avant » signale un avis choisi par Yiriclick pour sa précision." },
    en: { fReviews: "Customer reviews", fLegal: "Legal information", fBuy: "Buy", fdTag: "Club of 50 founding sellers", fdTitle: "Selling on Facebook or WhatsApp? Your online shop is waiting.", fd1: "We help you set up your shop, remotely", fd2: "A link to share on Facebook and WhatsApp", fd3: "14-day trial, then 4 months free after launch*", fd4: "Your feedback shapes Yiriclick", fdLeft: "places left out of {n}", fdGo: "Become a founder", fdNote: "*Subject to the programme terms. For now, orders go through WhatsApp; online payment comes later.", ptMain: "Main partner", ptBand: "They support small sellers", founderB: "Founding seller", fSellH: "Sell", fOrders: "My orders", fReport: "Report a problem", fFounders: "Founding sellers", fPartners: "Become a partner", fYiri: "Yiriclick", fTerms: "Terms", fPrivacy: "Privacy", fOpen: "Open my shop", chGuess: "We picked these for you, based on your device. You can change them any time.", chYouAre: "Your country", chPrices: "Prices shown in", chOk: "Looks good, continue", chOther: "Choose another country", chSearch: "Search for a country", regAf: "Africa", regEu: "Europe", regAm: "Americas and other", pendingShop: "This shop is being checked by Yiriclick. Until then, only pay after confirming the order with the seller.", fContact: "Contact", report: "Report this product", rvHint: "Tap a star to rate.", rvDetail: "Rate the details (optional)", rvWhat: "What went wrong? Tick everything that applies.",
      rvc_produit: "As described", rvc_qualite: "Quality", rvc_livraison: "Delivery time", rvc_emballage: "Packaging", rvc_vendeur: "Seller communication", rvc_prix: "Value for money",
      rvc_facilite: "Ease of ordering", rvc_confiance: "Trust", rvc_suivi: "Order tracking",
      rvk_abime: "Damaged item", rvk_non_conforme: "Not as pictured or described", rvk_qualite: "Disappointing quality", rvk_taille: "Wrong size", rvk_manquant: "Missing item",
      rvk_retard: "Late delivery", rvk_vendeur_injoignable: "Seller hard to reach", rvk_vendeur_impoli: "Unfriendly seller", rvk_prix: "Too expensive", rvk_emballage: "Poor packaging",
      rvk_paiement: "Payment or refund problem", rvk_autre: "Other",
      rvTxtGood: "Your comment (optional)", rvTxtBad: "Tell us what happened", rvPhGood: "What did you like? The product, the delivery, the seller…", rvPhBad: "The more details you give, the faster we can act.",
      rvCall: "I would like Yiriclick to contact me on WhatsApp to find a solution.", rvNeedWhy: "Tick at least one cause or describe the problem in a few words.",
      rvReco: "Would you recommend Yiriclick to a friend? (optional)", rvNo: "Not at all", rvYes: "Definitely", rvYcMore: "Also review Yiriclick (30 seconds)",
      rvYcNote: "Your rating for Yiriclick", rvYcIdea: "An idea to improve Yiriclick?",
      rvLegal: "Your first name and the initial of your last name are shown with your review. Your phone number is never published.",
      rvSort: "Sort", rvs_pert: "Most relevant", rvs_recent: "Most recent", rvs_best: "Highest rated", rvs_worst: "Lowest rated",
      rvPicked: "Highlighted by Yiriclick", rvVerified: "Verified purchase", rvMore: "Show {n} more reviews", rvDist: "{c} reviews with {k} stars", rvYcReply: "Yiriclick’s reply",
      rvHow: "How reviews work: only customers whose order was delivered can leave a review, once per order. Reviews are never bought or filtered by rating. Yiriclick hides a review only if it is abusive, fake, off-topic or contains personal data. “Highlighted” marks a review chosen by Yiriclick for its detail." },
    es: { fReviews: "Opiniones de clientes", fLegal: "Información legal", fBuy: "Comprar", fdTag: "Club de los 50 vendedores fundadores", fdTitle: "¿Vendes en Facebook o WhatsApp? Tu tienda en línea te espera.", fd1: "Te ayudamos a crear tu tienda, a distancia", fd2: "Un enlace para compartir en Facebook y WhatsApp", fd3: "14 días de prueba y luego 4 meses gratis tras el lanzamiento*", fd4: "Tu opinión mejora Yiriclick", fdLeft: "plazas libres de {n}", fdGo: "Quiero ser fundador", fdNote: "*Según las condiciones del programa. Por ahora, los pedidos pasan por WhatsApp; el pago en línea llegará más adelante.", ptMain: "Socio principal", ptBand: "Apoyan a los pequeños vendedores", founderB: "Vendedor fundador", fSellH: "Vender", fOrders: "Mis pedidos", fReport: "Informar de un problema", fFounders: "Vendedores fundadores", fPartners: "Hazte socio", fYiri: "Yiriclick", fTerms: "Condiciones", fPrivacy: "Privacidad", fOpen: "Abrir mi tienda", chGuess: "Lo elegimos por ti, según tu dispositivo. Puedes cambiarlo cuando quieras.", chYouAre: "Tu país", chPrices: "Precios en", chOk: "Perfecto, continuar", chOther: "Elegir otro país", chSearch: "Buscar un país", regAf: "África", regEu: "Europa", regAm: "América y otros", pendingShop: "Tienda en proceso de verificación por Yiriclick. Mientras tanto, paga solo después de confirmar el pedido con el vendedor.", fContact: "Contacto", report: "Denunciar este producto", rvHint: "Toca una estrella para valorar.", rvDetail: "Detalla tu valoración (opcional)", rvWhat: "¿Qué salió mal? Marca todo lo que corresponda.",
      rvc_produit: "Conforme a la descripción", rvc_qualite: "Calidad", rvc_livraison: "Plazo de entrega", rvc_emballage: "Embalaje", rvc_vendeur: "Comunicación del vendedor", rvc_prix: "Relación calidad-precio",
      rvc_facilite: "Facilidad para pedir", rvc_confiance: "Confianza", rvc_suivi: "Seguimiento del pedido",
      rvk_abime: "Producto dañado", rvk_non_conforme: "Diferente de la foto o la descripción", rvk_qualite: "Calidad decepcionante", rvk_taille: "Talla incorrecta", rvk_manquant: "Falta un artículo",
      rvk_retard: "Entrega con retraso", rvk_vendeur_injoignable: "Vendedor difícil de contactar", rvk_vendeur_impoli: "Vendedor poco amable", rvk_prix: "Demasiado caro", rvk_emballage: "Embalaje insuficiente",
      rvk_paiement: "Problema de pago o reembolso", rvk_autre: "Otro",
      rvTxtGood: "Tu comentario (opcional)", rvTxtBad: "Cuéntanos qué pasó", rvPhGood: "¿Qué te gustó? El producto, la entrega, el vendedor…", rvPhBad: "Cuantos más detalles des, más rápido podremos actuar.",
      rvCall: "Quiero que Yiriclick me contacte por WhatsApp para encontrar una solución.", rvNeedWhy: "Marca al menos una causa o describe el problema en pocas palabras.",
      rvReco: "¿Recomendarías Yiriclick a un amigo? (opcional)", rvNo: "Para nada", rvYes: "Seguro que sí", rvYcMore: "Opinar también sobre Yiriclick (30 segundos)",
      rvYcNote: "Tu nota para Yiriclick", rvYcIdea: "¿Una idea para mejorar Yiriclick?",
      rvLegal: "Tu nombre y la inicial de tu apellido aparecen con tu opinión. Tu teléfono nunca se publica.",
      rvSort: "Ordenar", rvs_pert: "Más relevantes", rvs_recent: "Más recientes", rvs_best: "Mejor valoradas", rvs_worst: "Peor valoradas",
      rvPicked: "Destacada por Yiriclick", rvVerified: "Compra verificada", rvMore: "Ver {n} opiniones más", rvDist: "{c} opiniones de {k} estrellas", rvYcReply: "Respuesta de Yiriclick",
      rvHow: "Cómo funcionan las opiniones: solo los clientes cuyo pedido fue entregado pueden opinar, una vez por pedido. Las opiniones no se compran ni se filtran según su nota. Yiriclick oculta una opinión solo si es ofensiva, falsa, ajena al tema o contiene datos personales. «Destacada» indica una opinión elegida por Yiriclick por su precisión." }, nl: { fReviews: "Klantbeoordelingen", fLegal: "Juridische informatie", fBuy: "Kopen", fdTag: "Club van 50 oprichtende verkopers", fdTitle: "Verkoop je via Facebook of WhatsApp? Je online winkel wacht op je.", fd1: "We helpen je op afstand je winkel op te zetten", fd2: "Eén link om te delen op Facebook en WhatsApp", fd3: "14 dagen proef, daarna 4 maanden gratis na de lancering*", fd4: "Jouw mening maakt Yiriclick beter", fdLeft: "plaatsen vrij van de {n}", fdGo: "Ik word oprichter", fdNote: "*Volgens de voorwaarden van het programma. Bestellingen gaan voorlopig via WhatsApp; online betalen volgt later.", ptMain: "Hoofdpartner", ptBand: "Zij steunen kleine verkopers", founderB: "Oprichtende verkoper", fSellH: "Verkopen", fOrders: "Mijn bestellingen", fReport: "Een probleem melden", fFounders: "Oprichtende verkopers", fPartners: "Word partner", fYiri: "Yiriclick", fTerms: "Voorwaarden", fPrivacy: "Privacy", fOpen: "Open mijn winkel", chGuess: "We hebben dit voor je gekozen op basis van je toestel. Je kunt het altijd wijzigen.", chYouAre: "Jouw land", chPrices: "Prijzen in", chOk: "Prima, doorgaan", chOther: "Een ander land kiezen", chSearch: "Zoek een land", regAf: "Afrika", regEu: "Europa", regAm: "Amerika en overige", pendingShop: "Winkel wordt gecontroleerd door Yiriclick. Betaal intussen pas nadat je de bestelling met de verkoper hebt bevestigd.", fContact: "Contact", report: "Dit product melden", rvHint: "Tik op een ster om te beoordelen.", rvDetail: "Licht je beoordeling toe (optioneel)", rvWhat: "Wat ging er mis? Vink alles aan wat van toepassing is.",
      rvc_produit: "Volgens de beschrijving", rvc_qualite: "Kwaliteit", rvc_livraison: "Levertijd", rvc_emballage: "Verpakking", rvc_vendeur: "Communicatie van de verkoper", rvc_prix: "Prijs-kwaliteitverhouding",
      rvc_facilite: "Gemak van bestellen", rvc_confiance: "Vertrouwen", rvc_suivi: "Opvolging van de bestelling",
      rvk_abime: "Product beschadigd", rvk_non_conforme: "Anders dan op de foto of in de beschrijving", rvk_qualite: "Teleurstellende kwaliteit", rvk_taille: "Verkeerde maat", rvk_manquant: "Er ontbreekt een artikel",
      rvk_retard: "Te late levering", rvk_vendeur_injoignable: "Verkoper moeilijk bereikbaar", rvk_vendeur_impoli: "Onvriendelijke verkoper", rvk_prix: "Te duur", rvk_emballage: "Onvoldoende verpakking",
      rvk_paiement: "Probleem met betaling of terugbetaling", rvk_autre: "Overig",
      rvTxtGood: "Je opmerking (optioneel)", rvTxtBad: "Vertel ons wat er is gebeurd", rvPhGood: "Wat vond je goed? Het product, de levering, de verkoper…", rvPhBad: "Hoe meer details je geeft, hoe sneller we kunnen handelen.",
      rvCall: "Ik wil dat Yiriclick contact met me opneemt via WhatsApp om een oplossing te vinden.", rvNeedWhy: "Vink minstens één oorzaak aan of beschrijf het probleem in een paar woorden.",
      rvReco: "Zou je Yiriclick aanraden aan een vriend? (optioneel)", rvNo: "Zeker niet", rvYes: "Zeker wel", rvYcMore: "Geef ook je mening over Yiriclick (30 seconden)",
      rvYcNote: "Jouw score voor Yiriclick", rvYcIdea: "Een idee om Yiriclick te verbeteren?",
      rvLegal: "Je voornaam en de eerste letter van je achternaam staan bij je beoordeling. Je telefoonnummer wordt nooit gepubliceerd.",
      rvSort: "Sorteren", rvs_pert: "Meest relevant", rvs_recent: "Nieuwste", rvs_best: "Best beoordeeld", rvs_worst: "Slechtst beoordeeld",
      rvPicked: "Uitgelicht door Yiriclick", rvVerified: "Geverifieerde aankoop", rvMore: "Nog {n} beoordelingen bekijken", rvDist: "{c} beoordelingen met {k} sterren", rvYcReply: "Antwoord van Yiriclick",
      rvHow: "Hoe beoordelingen werken: alleen klanten van wie de bestelling is geleverd, kunnen een beoordeling geven, één keer per bestelling. Beoordelingen worden niet gekocht en niet gefilterd op score. Yiriclick verbergt een beoordeling alleen als die beledigend, onjuist of niet ter zake is, of persoonsgegevens bevat. “Uitgelicht” betekent een beoordeling die Yiriclick heeft gekozen omdat ze zo precies is." }
  });
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", setupCart); else setupCart();

  /* Shared site footer: any <footer class="site-foot"> is filled the same way on every page (phone: 2 columns, computer: 4) */
  function footer() {
    document.querySelectorAll("footer.site-foot").forEach(function (f) {
      if (f.getAttribute("data-built")) return; f.setAttribute("data-built", "1");
      var w = el("div", "wrap sf"), top = el("div", "sf-top"), brand = el("div", "sf-brand");
      brand.innerHTML = '<span class="word"><span class="a">yiri</span><span class="b">click</span></span>';
      var tg = el("p", null, t("tagline")); tg.setAttribute("data-t", "tagline"); brand.appendChild(tg);
      var op = el("a", "sf-cta", t("fOpen")); op.href = "vendre"; op.setAttribute("data-t", "fOpen"); brand.appendChild(op);
      top.appendChild(brand);
      var cols = el("div", "sf-cols");
      [["fBuy", [["fHelp1", "vendre#comment"], ["fOrders", "#orders"], ["fReviews", "avis"]]],
       ["fSellH", [["fSell1", "vendre#tarifs"], ["fSell2", "vendeur"], ["fFounders", "vendre#fondateurs"]]],
       ["fHelp", [["svcBtn", "contact"], ["fReport", "contact?sujet=signalement"]]],
       ["fYiri", [["fAbout1", "vendre"], ["fPartners", "contact?sujet=partenariat"]]]].forEach(function (c) {
        var col = el("div", "sf-col"), h = el("h2", null, t(c[0])); h.setAttribute("data-t", c[0]); col.appendChild(h);
        c[1].forEach(function (l) {
          var a = el("a", null, t(l[0])); a.href = l[1]; a.setAttribute("data-t", l[0]);
          if (l[1] === "#orders") a.addEventListener("click", function (e) { e.preventDefault(); openCart("orders"); });
          col.appendChild(a);
        });
        cols.appendChild(col);
      });
      top.appendChild(cols); w.appendChild(top);
      var extra = f.querySelector("[data-foot-extra]"); if (extra) w.appendChild(extra);
      var bot = el("div", "sf-bot"), legal = el("div", "sf-legal");
      [["fLegal", "juridique#mentions"], ["fTerms", "juridique#conditions"], ["fPrivacy", "juridique#confidentialite"]].forEach(function (l) { var a = el("a", null, t(l[0])); a.href = l[1]; a.setAttribute("data-t", l[0]); legal.appendChild(a); });
      var kvk = (window.YLEGAL && window.YLEGAL.kvk) ? " · KvK " + window.YLEGAL.kvk : "";
      bot.appendChild(el("span", null, "© 2026 Yiriclick" + kvk)); bot.appendChild(legal); w.appendChild(bot);
      f.textContent = ""; f.appendChild(w);
    });
  }
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", footer); else footer();

  /* Pages can add their own texts: YC.extend({ fr: {...}, en: {...}, es: {...} }) */
  function extend(d) { Object.keys(d).forEach(function (L) { T[L] = T[L] || {}; Object.keys(d[L]).forEach(function (k) { T[L][k] = d[L][k]; }); }); }

  return { dbLang: function (l) { return dbLang(l || prefs.lang); }, extend: extend, track: track, hasVar: hasVar, prep: prep, cartAdd: function (p, shop, q, b, v) { cartAdd(p, shop, q || 1, b, v); }, openOrders: function () { openCart("orders"); }, sb: sb, t: t, cat: cat, el: el, pub: pub, money: money, card: card, openProduct: openProduct, closeProduct: closeProduct, reviewsUI: reviewsUI, reviewForm: function (box, o, done) { reviewForm(box, o, done || function () {}); }, onProduct: function (f) { productListeners.push(f); }, wirePrefs: wirePrefs, setPrefs: setPrefs, labels: labels, catOptions: catOptions, norm: norm, prefs: prefs,
    convert: convert, discount: discount, priceBlock: priceBlock, favButton: favButton, isFav: isFav, favs: function () { return favs.slice(); }, onFavs: function (f) { favListeners.push(f); },
    openCart: function () { openCart(); }, CATS: CATS, FAMILIES: FAMILIES, THEMES: THEMES, LOCALE: LOCALE, URL_SB: URL_SB, HEART: HEART, CART_SVG: CART_SVG };
})();
