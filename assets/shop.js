/* Shared logic for boutique.html and vitrine.html: Supabase client, languages, currencies, product cards and product detail */
window.YC = (function () {
  var URL_SB = "https://vtiakxfnechkoomagddl.supabase.co";
  var KEY_SB = "sb_publishable_415c2KQSDRx0SMofnkHKQA_PJ2IrzBA";
  var sb = window.supabase.createClient(URL_SB, KEY_SB, { auth: { persistSession: false } });

  /* ECB reference rates of 23 October 2026 (1 EUR = x). The CFA franc is pegged: 1 EUR = 655.957 FCFA. */
  var RATES = { EUR: 1, XOF: 655.957, USD: 1.1193 };
  var LOCALE = { fr: "fr-FR", en: "en-GB", es: "es-ES" };

  var T = {
    fr: { lang: "Langue", cur: "Monnaie", showcase: "Vitrine", sellers: "Espace vendeur", search: "Rechercher un produit…", allCats: "Toutes les catégories",
      noProducts: "Aucun produit pour l’instant.", noMatch: "Aucun produit ne correspond à ta recherche.", stock: "En stock : {n}", outStock: "Rupture de stock",
      order: "Commander sur WhatsApp", noWa: "Ce vendeur n’a pas encore indiqué de numéro WhatsApp.", waMsg: "Bonjour, je suis intéressé(e) par « {p} » ({x}) vu sur votre boutique Yiriclick : {u}",
      approx: "≈ {v} au taux du 23/10/2026", close: "Fermer", verified: "Vendeur vérifié par Yiriclick", notFound: "Boutique introuvable", notFoundP: "Cette boutique n’existe pas ou n’est pas visible pour le moment.",
      back: "Voir la vitrine Yiriclick", loading: "Chargement…", latest: "Les derniers produits des vendeurs Yiriclick", vitrineT: "La vitrine Yiriclick", see: "Voir la boutique", by: "Par {s}", foot: "Boutique propulsée par Yiriclick", openShop: "Ouvrir ma boutique sur Yiriclick", buy: "Commander", details: "Détails",
      add: "Ajouter", addLong: "Ajouter au panier", added: "Ajouté au panier", viewCart: "Voir le panier", cart: "Panier", cartTitle: "Mon panier",
      cartEmpty: "Ton panier est vide. Ajoute des produits depuis la vitrine ou une boutique.", keepShopping: "Continuer mes achats",
      qty: "Quantité", less: "Retirer un", more: "Ajouter un", remove: "Retirer", subtotal: "Sous-total", total: "Total estimé", maxStock: "Stock maximum atteint",
      gone: "Certains produits ne sont plus disponibles et ont été retirés de ton panier.", checkout: "Valider ma commande",
      yourInfo: "Tes coordonnées", cName: "Nom complet", cPhone: "Téléphone (WhatsApp)", cAddr: "Adresse de livraison", cNote: "Message pour le vendeur (facultatif)",
      eReq: "Ce champ est obligatoire.", ePhone: "Entre ton numéro avec l’indicatif du pays, par exemple +226 70 00 00 00.",
      sendTitle: "Envoie ta commande à chaque vendeur", sendHelp: "Ton panier contient des produits de plusieurs vendeurs : envoie la commande à chacun. Le vendeur te confirme la disponibilité, la livraison et le paiement.",
      sendTo: "Envoyer à {s} sur WhatsApp", sent: "Envoyé à {s}", noWaShop: "{s} n’a pas indiqué de numéro WhatsApp : sa commande ne peut pas être envoyée pour l’instant.",
      clearSent: "Retirer les produits envoyés du panier", editInfo: "Modifier mes coordonnées", orderDirect: "Commander directement sur WhatsApp",
      waCart: "Bonjour {s}, je souhaite commander sur Yiriclick :", waTotal: "Total", waName: "Nom", waPhone: "Téléphone", waAddr: "Adresse de livraison", waNote: "Message",
      waEnd: "Merci de me confirmer la disponibilité, les frais de livraison et le mode de paiement.", approxSign: "≈ " },
    en: { lang: "Language", cur: "Currency", showcase: "Showcase", sellers: "Seller space", search: "Search for a product…", allCats: "All categories",
      noProducts: "No products yet.", noMatch: "No product matches your search.", stock: "In stock: {n}", outStock: "Out of stock",
      order: "Order on WhatsApp", noWa: "This seller has not added a WhatsApp number yet.", waMsg: "Hello, I am interested in “{p}” ({x}) seen on your Yiriclick shop: {u}",
      approx: "≈ {v} at the 23/10/2026 rate", close: "Close", verified: "Seller verified by Yiriclick", notFound: "Shop not found", notFoundP: "This shop does not exist or is not visible right now.",
      back: "See the Yiriclick showcase", loading: "Loading…", latest: "The latest products from Yiriclick sellers", vitrineT: "The Yiriclick showcase", see: "See the shop", by: "By {s}", foot: "Shop powered by Yiriclick", openShop: "Open my shop on Yiriclick", buy: "Order", details: "Details",
      add: "Add", addLong: "Add to cart", added: "Added to cart", viewCart: "View cart", cart: "Cart", cartTitle: "My cart",
      cartEmpty: "Your cart is empty. Add products from the showcase or a shop.", keepShopping: "Continue shopping",
      qty: "Quantity", less: "Remove one", more: "Add one", remove: "Remove", subtotal: "Subtotal", total: "Estimated total", maxStock: "Maximum stock reached",
      gone: "Some products are no longer available and were removed from your cart.", checkout: "Place my order",
      yourInfo: "Your details", cName: "Full name", cPhone: "Phone (WhatsApp)", cAddr: "Delivery address", cNote: "Message for the seller (optional)",
      eReq: "This field is required.", ePhone: "Enter your number with the country code, for example +226 70 00 00 00.",
      sendTitle: "Send your order to each seller", sendHelp: "Your cart has products from several sellers: send the order to each one. The seller confirms availability, delivery and payment with you.",
      sendTo: "Send to {s} on WhatsApp", sent: "Sent to {s}", noWaShop: "{s} has not added a WhatsApp number: this order cannot be sent yet.",
      clearSent: "Remove sent products from the cart", editInfo: "Edit my details", orderDirect: "Order directly on WhatsApp",
      waCart: "Hello {s}, I would like to order on Yiriclick:", waTotal: "Total", waName: "Name", waPhone: "Phone", waAddr: "Delivery address", waNote: "Message",
      waEnd: "Please confirm availability, delivery costs and payment method.", approxSign: "≈ " },
    es: { lang: "Idioma", cur: "Moneda", showcase: "Escaparate", sellers: "Espacio vendedor", search: "Buscar un producto…", allCats: "Todas las categorías",
      noProducts: "Todavía no hay productos.", noMatch: "Ningún producto coincide con tu búsqueda.", stock: "En stock: {n}", outStock: "Agotado",
      order: "Pedir por WhatsApp", noWa: "Este vendedor aún no ha indicado un número de WhatsApp.", waMsg: "Hola, me interesa «{p}» ({x}) visto en su tienda Yiriclick: {u}",
      approx: "≈ {v} al cambio del 23/10/2026", close: "Cerrar", verified: "Vendedor verificado por Yiriclick", notFound: "Tienda no encontrada", notFoundP: "Esta tienda no existe o no está visible por ahora.",
      back: "Ver el escaparate de Yiriclick", loading: "Cargando…", latest: "Los últimos productos de los vendedores de Yiriclick", vitrineT: "El escaparate de Yiriclick", see: "Ver la tienda", by: "Por {s}", foot: "Tienda impulsada por Yiriclick", openShop: "Abrir mi tienda en Yiriclick", buy: "Pedir", details: "Detalles",
      add: "Añadir", addLong: "Añadir al carrito", added: "Añadido al carrito", viewCart: "Ver el carrito", cart: "Carrito", cartTitle: "Mi carrito",
      cartEmpty: "Tu carrito está vacío. Añade productos desde el escaparate o una tienda.", keepShopping: "Seguir comprando",
      qty: "Cantidad", less: "Quitar uno", more: "Añadir uno", remove: "Quitar", subtotal: "Subtotal", total: "Total estimado", maxStock: "Stock máximo alcanzado",
      gone: "Algunos productos ya no están disponibles y se han quitado de tu carrito.", checkout: "Confirmar mi pedido",
      yourInfo: "Tus datos", cName: "Nombre completo", cPhone: "Teléfono (WhatsApp)", cAddr: "Dirección de entrega", cNote: "Mensaje para el vendedor (opcional)",
      eReq: "Este campo es obligatorio.", ePhone: "Introduce tu número con el prefijo del país, por ejemplo +226 70 00 00 00.",
      sendTitle: "Envía tu pedido a cada vendedor", sendHelp: "Tu carrito tiene productos de varios vendedores: envía el pedido a cada uno. El vendedor te confirma disponibilidad, entrega y pago.",
      sendTo: "Enviar a {s} por WhatsApp", sent: "Enviado a {s}", noWaShop: "{s} no ha indicado un número de WhatsApp: este pedido aún no se puede enviar.",
      clearSent: "Quitar del carrito los productos enviados", editInfo: "Modificar mis datos", orderDirect: "Pedir directamente por WhatsApp",
      waCart: "Hola {s}, quiero hacer un pedido en Yiriclick:", waTotal: "Total", waName: "Nombre", waPhone: "Teléfono", waAddr: "Dirección de entrega", waNote: "Mensaje",
      waEnd: "Por favor, confírmame disponibilidad, gastos de envío y forma de pago.", approxSign: "≈ " }
  };
  var CATS = {
    fr: { mode: "Mode et vêtements", chaussures: "Chaussures et maroquinerie", bijoux: "Bijoux et accessoires", textile: "Tissus et pagnes", beaute: "Beauté et cosmétiques", sante: "Santé et bien-être", alim: "Alimentation et épicerie", boissons: "Boissons", agri: "Produits agricoles et élevage", artisanat: "Artisanat et art", deco: "Décoration et maison", meubles: "Meubles", electromenager: "Électroménager", tech: "Téléphones et électronique", info: "Informatique", auto: "Auto et moto", btp: "Bâtiment et matériaux", bebe: "Bébé et enfants", jouets: "Jouets et jeux", sport: "Sport et loisirs", livres: "Livres et fournitures scolaires", musique: "Musique et instruments", animaux: "Animaux", numerique: "Produits numériques", services: "Services", autre: "Autre" },
    en: { mode: "Fashion and clothing", chaussures: "Shoes and leather goods", bijoux: "Jewellery and accessories", textile: "Fabrics and wax prints", beaute: "Beauty and cosmetics", sante: "Health and wellness", alim: "Food and groceries", boissons: "Drinks", agri: "Farm products and livestock", artisanat: "Crafts and art", deco: "Home and decor", meubles: "Furniture", electromenager: "Home appliances", tech: "Phones and electronics", info: "Computers", auto: "Cars and motorbikes", btp: "Building and materials", bebe: "Baby and kids", jouets: "Toys and games", sport: "Sports and leisure", livres: "Books and school supplies", musique: "Music and instruments", animaux: "Pets and animals", numerique: "Digital products", services: "Services", autre: "Other" },
    es: { mode: "Moda y ropa", chaussures: "Calzado y marroquinería", bijoux: "Joyas y accesorios", textile: "Telas y wax", beaute: "Belleza y cosmética", sante: "Salud y bienestar", alim: "Alimentación y supermercado", boissons: "Bebidas", agri: "Productos agrícolas y ganadería", artisanat: "Artesanía y arte", deco: "Hogar y decoración", meubles: "Muebles", electromenager: "Electrodomésticos", tech: "Teléfonos y electrónica", info: "Informática", auto: "Coches y motos", btp: "Construcción y materiales", bebe: "Bebés y niños", jouets: "Juguetes y juegos", sport: "Deporte y ocio", livres: "Libros y material escolar", musique: "Música e instrumentos", animaux: "Animales", numerique: "Productos digitales", services: "Servicios", autre: "Otro" }
  };

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
    try { return new Intl.NumberFormat(LOCALE[prefs.lang], { style: "currency", currency: d, minimumFractionDigits: whole ? 0 : 2, maximumFractionDigits: whole ? 0 : 2 }).format(v); }
    catch (e) { return Number(v).toFixed(whole ? 0 : 2) + " " + d; }
  }
  function convert(v, from, to) { return Number(v) / RATES[from] * RATES[to]; }
  /* Second line under a price: the amount in the visitor's chosen currency, when it differs */
  function approx(p) {
    var to = prefs.cur; if (!to || to === p.devise) return "";
    var exact = (to === "XOF" && p.devise === "EUR") || (to === "EUR" && p.devise === "XOF");
    var v = money(convert(p.prix, p.devise, to), to);
    return exact ? "= " + v : t("approx", { v: v });
  }
  function waLink(shop, p) {
    var d = String(shop.whatsapp || "").replace(/\D/g, ""); if (d.length < 8) return "";
    var u = location.origin + location.pathname.replace(/[^/]*$/, "") + "boutique.html?b=" + encodeURIComponent(shop.slug) + "&p=" + p.id;
    return "https://wa.me/" + d + "?text=" + encodeURIComponent(t("waMsg", { p: p.nom, x: money(p.prix, p.devise), u: u }));
  }

  /* Header preferences: language and currency selects */
  function wirePrefs(onChange) {
    var ls = document.getElementById("prefLang"), cs = document.getElementById("prefCur");
    ls.value = prefs.lang; cs.value = prefs.cur;
    ls.addEventListener("change", function () { prefs.lang = ls.value; save("yc-lang", prefs.lang); document.documentElement.lang = prefs.lang; onChange(); });
    cs.addEventListener("change", function () { prefs.cur = cs.value; save("yc-cur", prefs.cur); onChange(); });
    document.documentElement.lang = prefs.lang;
  }
  function labels() {
    document.querySelectorAll("[data-t]").forEach(function (n) { n.textContent = t(n.getAttribute("data-t")); });
    document.querySelectorAll("[data-tp]").forEach(function (n) { n.placeholder = t(n.getAttribute("data-tp")); });
    document.querySelectorAll("[data-ta]").forEach(function (n) { n.setAttribute("aria-label", t(n.getAttribute("data-ta"))); });
    var cs = document.getElementById("prefCur"); if (cs && cs.options[0]) cs.options[0].textContent = t("cur") + " : —";
    cartBadge();
    var cw = document.getElementById("cartWrap"); if (cw && !cw.hidden) renderCart();
  }

  /* Product card: photo and title open the details; "Commander" goes straight to WhatsApp with a ready message */
  function card(p, shop, showShop, onOpen) {
    var c = el("article", "item");
    var open = el("button", "item-open"); open.type = "button";
    if (p.photos && p.photos[0]) { var im = el("img", "im"); im.src = pub(p.photos[0]); im.alt = ""; im.loading = "lazy"; open.appendChild(im); }
    else open.appendChild(el("div", "noim"));
    var ib = el("div", "ib");
    if (showShop && shop) ib.appendChild(el("span", "shopname", shop.nom));
    ib.appendChild(el("h3", null, p.nom));
    ib.appendChild(el("span", "pr", money(p.prix, p.devise)));
    var a = approx(p); if (a) ib.appendChild(el("span", "cv", a));
    open.appendChild(ib);
    open.addEventListener("click", function () { onOpen(p, shop); });
    c.appendChild(open);
    var acts = el("div", "item-acts");
    var out = p.stock === 0;
    var buy = el("button", "btn btn-wa btn-buy"); buy.type = "button";
    if (out) buy.disabled = true; else buy.addEventListener("click", function () { cartAdd(p, shop, 1, buy); });
    buy.innerHTML = CART_SVG;
    buy.appendChild(document.createTextNode(out ? t("outStock") : t("addLong")));
    buy.setAttribute("aria-label", (out ? t("outStock") : t("addLong")) + " : " + p.nom);
    var det = el("button", "btn btn-ghost btn-det", t("details")); det.type = "button";
    det.setAttribute("aria-label", t("details") + " : " + p.nom);
    det.addEventListener("click", function () { onOpen(p, shop); });
    acts.appendChild(buy); acts.appendChild(det); c.appendChild(acts);
    return c;
  }

  /* ===================== Cart =====================
     Kept in this visitor's browser only. Checkout sends one WhatsApp order per seller,
     since online payment is not connected yet. */
  var CART_SVG = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M4 5h2l2 10h10l2-7H7"/><circle cx="10" cy="19" r="1.4"/><circle cx="17" cy="19" r="1.4"/></svg>';
  var cart = [];
  try { cart = JSON.parse(localStorage.getItem("yc-cart") || "[]"); if (!Array.isArray(cart)) cart = []; } catch (e) { cart = []; }
  var buyer = {};
  try { buyer = JSON.parse(localStorage.getItem("yc-buyer") || "{}") || {}; } catch (e) { buyer = {}; }
  var cartView = "list", sentShops = {}, cartNotice = "";
  function cartSave() { try { localStorage.setItem("yc-cart", JSON.stringify(cart)); } catch (e) {} cartBadge(); }
  function cartCount() { return cart.reduce(function (n, i) { return n + i.qty; }, 0); }
  function cartAdd(p, shop, q, fromBtn) {
    if (!shop) return;
    var max = p.stock == null ? 99 : p.stock;
    var it = cart.filter(function (i) { return i.id === p.id; })[0];
    if (it) { it.qty = Math.min(max, it.qty + q); it.prix = p.prix; it.devise = p.devise; it.stock = p.stock; }
    else cart.push({ id: p.id, qty: Math.min(max, q), nom: p.nom, prix: Number(p.prix), devise: p.devise, stock: p.stock, photo: p.photos && p.photos[0] || null, shop: { slug: shop.slug, nom: shop.nom, whatsapp: shop.whatsapp || "" } });
    cartSave(); toast(t("added"), fromBtn);
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

  var toastTimer = null, toastReturn = null;
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
  async function openCart() {
    cartLast = document.activeElement; cartView = "list"; sentShops = {};
    var d = document.getElementById("cartWrap"); d.hidden = false; document.body.style.overflow = "hidden";
    renderCart(); document.querySelector("#cartPanel .mclose").focus();
    await refreshCart(); renderCart();
  }
  function closeCart() { document.getElementById("cartWrap").hidden = true; document.body.style.overflow = ""; if (cartLast && cartLast.focus) cartLast.focus(); }
  /* Refresh prices, stock and availability from the database before ordering */
  async function refreshCart() {
    if (!cart.length) return;
    var r = await sb.from("produits").select("id,nom,prix,devise,stock,photos,boutiques(nom,slug,whatsapp)").in("id", cart.map(function (i) { return i.id; }));
    if (r.error || !r.data) return;
    var map = {}; r.data.forEach(function (p) { map[p.id] = p; });
    var before = cart.length;
    cart = cart.filter(function (i) { var p = map[i.id]; return p && p.boutiques && p.stock !== 0; }).map(function (i) {
      var p = map[i.id]; var max = p.stock == null ? 99 : p.stock;
      return { id: i.id, qty: Math.min(i.qty, max), nom: p.nom, prix: Number(p.prix), devise: p.devise, stock: p.stock, photo: p.photos && p.photos[0] || null, shop: { slug: p.boutiques.slug, nom: p.boutiques.nom, whatsapp: p.boutiques.whatsapp || "" } };
    });
    if (cart.length < before) cartNotice = t("gone");
    cartSave();
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
    head(p, t("cartTitle") + (cartCount() ? " (" + cartCount() + ")" : ""));
    if (cartNotice) { p.appendChild(el("p", "cart-notice", cartNotice)); cartNotice = ""; }
    if (!cart.length) {
      p.appendChild(el("p", "cart-empty", t("cartEmpty")));
      var k = el("a", "btn btn-navy", t("keepShopping")); k.href = "vitrine.html"; p.appendChild(k); return;
    }
    groups().forEach(function (g) {
      var sec = el("section", "cart-group");
      var sh = el("a", "cart-shop", g.shop.nom); sh.href = "boutique.html?b=" + encodeURIComponent(g.shop.slug); sec.appendChild(sh);
      g.items.forEach(function (i) {
        var row = el("div", "cart-row");
        if (i.photo) { var im = el("img"); im.src = pub(i.photo); im.alt = ""; row.appendChild(im); } else row.appendChild(el("div", "cart-noim"));
        var info = el("div", "cart-info"); info.appendChild(el("b", null, i.nom)); info.appendChild(el("span", "cart-unit", money(i.prix, i.devise)));
        var ctl = el("div", "cart-ctl"), stp = el("div", "stepper"), max = i.stock == null ? 99 : i.stock;
        var mi = el("button", null, "−"), qv = el("span", "qv", String(i.qty)), pl = el("button", null, "+");
        mi.type = pl.type = "button"; mi.setAttribute("aria-label", t("less") + " : " + i.nom); pl.setAttribute("aria-label", t("more") + " : " + i.nom);
        mi.disabled = i.qty <= 1; pl.disabled = i.qty >= max; if (pl.disabled) pl.title = t("maxStock");
        mi.addEventListener("click", function () { i.qty = Math.max(1, i.qty - 1); cartSave(); renderCart(); });
        pl.addEventListener("click", function () { i.qty = Math.min(max, i.qty + 1); cartSave(); renderCart(); });
        stp.appendChild(mi); stp.appendChild(qv); stp.appendChild(pl); ctl.appendChild(stp);
        var rm = el("button", "cart-rm", t("remove")); rm.type = "button"; rm.setAttribute("aria-label", t("remove") + " : " + i.nom);
        rm.addEventListener("click", function () { cart = cart.filter(function (x) { return x.id !== i.id; }); cartSave(); renderCart(); });
        ctl.appendChild(rm); info.appendChild(ctl); row.appendChild(info);
        row.appendChild(el("span", "cart-line", money(i.prix * i.qty, i.devise)));
        sec.appendChild(row);
      });
      var to = g.items[0].devise, st = sumIn(g.items, to);
      var sub = el("div", "cart-sub"); sub.appendChild(el("span", null, t("subtotal"))); sub.appendChild(el("b", null, (st.approx ? t("approxSign") : "") + money(st.v, to)));
      sec.appendChild(sub); p.appendChild(sec);
    });
    var cur = prefs.cur || cart[0].devise, tot = sumIn(cart, cur);
    var tr = el("div", "cart-total"); tr.appendChild(el("span", null, t("total"))); tr.appendChild(el("b", null, (tot.approx ? t("approxSign") : "") + money(tot.v, cur)));
    p.appendChild(tr);
    var go = el("button", "btn btn-wa cart-go", t("checkout")); go.type = "button"; go.addEventListener("click", function () { cartView = "info"; renderCart(); var f = document.getElementById("cName"); if (f) f.focus(); });
    p.appendChild(go);
    var k2 = el("button", "cart-rm", t("keepShopping")); k2.type = "button"; k2.style.alignSelf = "center"; k2.addEventListener("click", closeCart); p.appendChild(k2);
  }
  function renderInfo(p) {
    head(p, t("yourInfo"));
    var f = el("form", "cart-form"); f.noValidate = true;
    function fld(id, key, type, area, opt) {
      var w = el("div", "cfield"), l = el("label", null, t(key)); l.setAttribute("for", id); w.appendChild(l);
      var i = el(area ? "textarea" : "input"); i.id = id; if (!area) i.type = type || "text"; else i.rows = 3; i.value = buyer[id] || "";
      if (type === "tel") { i.inputMode = "tel"; i.autocomplete = "tel"; } if (id === "cName") i.autocomplete = "name"; if (id === "cAddr") i.autocomplete = "street-address";
      w.appendChild(i); var e = el("span", "cerr"); e.id = id + "-err"; w.appendChild(e); f.appendChild(w); return i;
    }
    var n = fld("cName", "cName"), ph = fld("cPhone", "cPhone", "tel"), ad = fld("cAddr", "cAddr", "text", true), no = fld("cNote", "cNote", "text", true);
    ph.placeholder = "+226 70 00 00 00";
    var go = el("button", "btn btn-wa cart-go", t("checkout")); go.type = "submit"; f.appendChild(go);
    var bk = el("button", "cart-rm", t("cartTitle")); bk.type = "button"; bk.style.alignSelf = "center"; bk.addEventListener("click", function () { cartView = "list"; renderCart(); }); f.appendChild(bk);
    f.addEventListener("submit", function (e) {
      e.preventDefault(); var ok = true, first = null;
      function err(i, m) { document.getElementById(i.id + "-err").textContent = m || ""; if (m) { i.setAttribute("aria-invalid", "true"); ok = false; first = first || i; } else i.removeAttribute("aria-invalid"); }
      err(n, n.value.trim() ? "" : t("eReq"));
      var pv = ph.value.trim(); err(ph, !pv ? t("eReq") : (/^\+?[0-9 ().-]{8,20}$/.test(pv) && pv.replace(/\D/g, "").length >= 8 ? "" : t("ePhone")));
      err(ad, ad.value.trim() ? "" : t("eReq"));
      if (!ok) { first.focus(); return; }
      buyer = { cName: n.value.trim(), cPhone: pv, cAddr: ad.value.trim(), cNote: no.value.trim() };
      try { localStorage.setItem("yc-buyer", JSON.stringify(buyer)); } catch (x) {}
      cartView = "send"; renderCart();
    });
    p.appendChild(f);
  }
  function orderText(g) {
    var lines = [t("waCart", { s: g.shop.nom }), ""];
    g.items.forEach(function (i) { lines.push("• " + i.qty + " × " + i.nom + " – " + money(i.prix, i.devise) + " = " + money(i.prix * i.qty, i.devise)); });
    var to = g.items[0].devise, st = sumIn(g.items, to);
    lines.push("", t("waTotal") + " : " + (st.approx ? t("approxSign") : "") + money(st.v, to), "");
    lines.push(t("waName") + " : " + buyer.cName, t("waPhone") + " : " + buyer.cPhone, t("waAddr") + " : " + buyer.cAddr);
    if (buyer.cNote) lines.push(t("waNote") + " : " + buyer.cNote);
    lines.push("", t("waEnd"));
    return lines.join("\n");
  }
  function renderSend(p) {
    head(p, t("sendTitle"));
    var gs = groups();
    if (gs.length > 1) p.appendChild(el("p", "cart-help", t("sendHelp")));
    gs.forEach(function (g) {
      var sec = el("section", "cart-group");
      sec.appendChild(el("b", "cart-shop", g.shop.nom));
      var to = g.items[0].devise, st = sumIn(g.items, to);
      sec.appendChild(el("p", "cart-help", g.items.reduce(function (n, i) { return n + i.qty; }, 0) + " × · " + (st.approx ? t("approxSign") : "") + money(st.v, to)));
      var d = String(g.shop.whatsapp || "").replace(/\D/g, "");
      if (d.length < 8) { sec.appendChild(el("p", "wa-note", t("noWaShop", { s: g.shop.nom }))); }
      else if (sentShops[g.shop.slug]) { sec.appendChild(el("p", "cart-sent", "✓ " + t("sent", { s: g.shop.nom }))); }
      else {
        var a = el("a", "btn btn-wa cart-go", t("sendTo", { s: g.shop.nom }));
        a.href = "https://wa.me/" + d + "?text=" + encodeURIComponent(orderText(g)); a.target = "_blank"; a.rel = "noopener";
        a.addEventListener("click", function () { sentShops[g.shop.slug] = true; setTimeout(renderCart, 300); });
        sec.appendChild(a);
      }
      p.appendChild(sec);
    });
    if (Object.keys(sentShops).length) {
      var cl = el("button", "btn btn-navy cart-go", t("clearSent")); cl.type = "button";
      cl.addEventListener("click", function () { cart = cart.filter(function (i) { return !sentShops[i.shop.slug]; }); sentShops = {}; cartSave(); cartView = cart.length ? "send" : "list"; renderCart(); });
      p.appendChild(cl);
    }
    var ed = el("button", "cart-rm", t("editInfo")); ed.type = "button"; ed.style.alignSelf = "center"; ed.addEventListener("click", function () { cartView = "info"; renderCart(); }); p.appendChild(ed);
  }
  window.addEventListener("storage", function (e) { if (e.key === "yc-cart") { try { cart = JSON.parse(e.newValue || "[]"); } catch (x) { cart = []; } cartBadge(); } });

  var lastFocus = null;
  function openProduct(p, shop, opts) {
    opts = opts || {};
    var m = document.getElementById("pmodal"); var box = m.querySelector(".mbox"); box.textContent = "";
    var x = el("button", "mclose", "×"); x.type = "button"; x.setAttribute("aria-label", t("close")); x.addEventListener("click", closeProduct); box.appendChild(x);
    var gal = el("div", "gal"), sl = el("div", "slides"), photos = (p.photos || []).length ? p.photos : [null];
    photos.forEach(function (ph, i) { if (!ph) { var d = el("div", "noim"); d.style.aspectRatio = "1"; sl.appendChild(d); return; } var im = el("img"); im.src = pub(ph); im.alt = p.nom + " – " + (i + 1); sl.appendChild(im); });
    gal.appendChild(sl);
    if (photos.length > 1) {
      var dots = el("div", "dots"); photos.forEach(function (_, i) { dots.appendChild(el("span", i ? "" : "on")); }); gal.appendChild(dots);
      sl.addEventListener("scroll", function () { var i = Math.round(sl.scrollLeft / sl.clientWidth); Array.prototype.forEach.call(dots.children, function (d, k) { d.className = k === i ? "on" : ""; }); }, { passive: true });
    }
    box.appendChild(gal);
    var bd = el("div", "mbody");
    if (opts.showShop && shop) { var sa = el("a", null, t("by", { s: shop.nom })); sa.href = "boutique.html?b=" + encodeURIComponent(shop.slug); sa.style.color = "var(--teal-deep)"; sa.style.fontWeight = "700"; bd.appendChild(sa); }
    var h = el("h2", null, p.nom); h.id = "pmTitle"; bd.appendChild(h);
    bd.appendChild(el("div", "pr", money(p.prix, p.devise)));
    var a = approx(p); if (a) bd.appendChild(el("div", "cv", a));
    var meta = [cat(p.categorie)]; if (p.stock != null) meta.push(p.stock > 0 ? t("stock", { n: p.stock }) : t("outStock"));
    bd.appendChild(el("div", "meta", meta.filter(Boolean).join(" · ")));
    if (p.description) bd.appendChild(el("p", "desc", p.description));
    if (p.stock !== 0) {
      var row = el("div", "m-buy"), q = 1, max = p.stock == null ? 99 : p.stock;
      var stp = el("div", "stepper"), mi = el("button", null, "−"), qv = el("span", "qv", "1"), pl = el("button", null, "+");
      mi.type = pl.type = "button"; mi.setAttribute("aria-label", t("less")); pl.setAttribute("aria-label", t("more")); qv.setAttribute("aria-live", "polite");
      mi.addEventListener("click", function () { q = Math.max(1, q - 1); qv.textContent = q; });
      pl.addEventListener("click", function () { q = Math.min(max, q + 1); qv.textContent = q; });
      stp.appendChild(mi); stp.appendChild(qv); stp.appendChild(pl); row.appendChild(stp);
      var ad = el("button", "btn btn-wa"); ad.type = "button"; ad.innerHTML = CART_SVG; ad.appendChild(document.createTextNode(t("addLong")));
      ad.addEventListener("click", function () { cartAdd(p, shop, q, ad); });
      row.appendChild(ad); bd.appendChild(row);
    }
    var wa = shop ? waLink(shop, p) : "";
    if (wa && p.stock !== 0) { var w = el("a", "direct", t("orderDirect")); w.href = wa; w.target = "_blank"; w.rel = "noopener"; bd.appendChild(w); }
    else if (!wa) bd.appendChild(el("p", "wa-note", t("noWa")));
    box.appendChild(bd);
    box.setAttribute("aria-labelledby", "pmTitle");
    lastFocus = document.activeElement;
    m.hidden = false; document.body.style.overflow = "hidden"; x.focus();
  }
  function closeProduct() { var m = document.getElementById("pmodal"); m.hidden = true; document.body.style.overflow = ""; if (lastFocus && lastFocus.focus) lastFocus.focus(); }
  document.addEventListener("keydown", function (e) { var m = document.getElementById("pmodal"); if (e.key === "Escape" && m && !m.hidden) closeProduct(); });
  document.addEventListener("click", function (e) { if (e.target.classList && e.target.classList.contains("modal-bg")) closeProduct(); });

  function catOptions(select, present) {
    var v = select.value; select.textContent = "";
    var o = el("option", null, t("allCats")); o.value = ""; select.appendChild(o);
    Object.keys(CATS.fr).filter(function (c) { return !present || present.indexOf(c) >= 0; }).forEach(function (c) { var op = el("option", null, cat(c)); op.value = c; select.appendChild(op); });
    select.value = v;
  }
  function norm(x) { return String(x || "").normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase(); }

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", setupCart); else setupCart();

  return { sb: sb, t: t, cat: cat, el: el, pub: pub, money: money, card: card, openProduct: openProduct, wirePrefs: wirePrefs, labels: labels, catOptions: catOptions, norm: norm, prefs: prefs };
})();
