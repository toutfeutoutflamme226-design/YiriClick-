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
      back: "Voir la vitrine Yiriclick", loading: "Chargement…", latest: "Les derniers produits des vendeurs Yiriclick", vitrineT: "La vitrine Yiriclick", see: "Voir la boutique", by: "Par {s}", foot: "Boutique propulsée par Yiriclick", openShop: "Ouvrir ma boutique sur Yiriclick" },
    en: { lang: "Language", cur: "Currency", showcase: "Showcase", sellers: "Seller space", search: "Search for a product…", allCats: "All categories",
      noProducts: "No products yet.", noMatch: "No product matches your search.", stock: "In stock: {n}", outStock: "Out of stock",
      order: "Order on WhatsApp", noWa: "This seller has not added a WhatsApp number yet.", waMsg: "Hello, I am interested in “{p}” ({x}) seen on your Yiriclick shop: {u}",
      approx: "≈ {v} at the 23/10/2026 rate", close: "Close", verified: "Seller verified by Yiriclick", notFound: "Shop not found", notFoundP: "This shop does not exist or is not visible right now.",
      back: "See the Yiriclick showcase", loading: "Loading…", latest: "The latest products from Yiriclick sellers", vitrineT: "The Yiriclick showcase", see: "See the shop", by: "By {s}", foot: "Shop powered by Yiriclick", openShop: "Open my shop on Yiriclick" },
    es: { lang: "Idioma", cur: "Moneda", showcase: "Escaparate", sellers: "Espacio vendedor", search: "Buscar un producto…", allCats: "Todas las categorías",
      noProducts: "Todavía no hay productos.", noMatch: "Ningún producto coincide con tu búsqueda.", stock: "En stock: {n}", outStock: "Agotado",
      order: "Pedir por WhatsApp", noWa: "Este vendedor aún no ha indicado un número de WhatsApp.", waMsg: "Hola, me interesa «{p}» ({x}) visto en su tienda Yiriclick: {u}",
      approx: "≈ {v} al cambio del 23/10/2026", close: "Cerrar", verified: "Vendedor verificado por Yiriclick", notFound: "Tienda no encontrada", notFoundP: "Esta tienda no existe o no está visible por ahora.",
      back: "Ver el escaparate de Yiriclick", loading: "Cargando…", latest: "Los últimos productos de los vendedores de Yiriclick", vitrineT: "El escaparate de Yiriclick", see: "Ver la tienda", by: "Por {s}", foot: "Tienda impulsada por Yiriclick", openShop: "Abrir mi tienda en Yiriclick" }
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
  }

  function card(p, shop, showShop, onOpen) {
    var b = el("button", "item"); b.type = "button";
    if (p.photos && p.photos[0]) { var im = el("img", "im"); im.src = pub(p.photos[0]); im.alt = ""; im.loading = "lazy"; b.appendChild(im); }
    else b.appendChild(el("div", "noim"));
    var ib = el("div", "ib");
    if (showShop && shop) ib.appendChild(el("span", "shopname", shop.nom));
    ib.appendChild(el("h3", null, p.nom));
    ib.appendChild(el("span", "pr", money(p.prix, p.devise)));
    var a = approx(p); if (a) ib.appendChild(el("span", "cv", a));
    b.appendChild(ib);
    b.addEventListener("click", function () { onOpen(p, shop); });
    return b;
  }

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
    var wa = shop ? waLink(shop, p) : "";
    if (wa) { var w = el("a", "btn btn-wa", t("order")); w.href = wa; w.target = "_blank"; w.rel = "noopener"; bd.appendChild(w); }
    else bd.appendChild(el("p", "wa-note", t("noWa")));
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

  return { sb: sb, t: t, cat: cat, el: el, pub: pub, money: money, card: card, openProduct: openProduct, wirePrefs: wirePrefs, labels: labels, catOptions: catOptions, norm: norm, prefs: prefs };
})();
