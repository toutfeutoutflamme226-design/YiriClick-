/* Product import for the seller space.
   Accepts a spreadsheet (CSV or Excel), alone or with its photos, or a ZIP holding both.
   Reads the Yiriclick template and exports from Shopify, WooCommerce or any table with a name and a price.
   Products are created one by one with the same rules as the product editor: plan limits,
   photos resized before upload, database checks. Nothing is created before the seller confirms. */
window.YImport = (function () {
  var lang = (window.YCV && YCV.lang) || "fr";
  var D = {
    "Importer des produits": ["Import products", "Importar productos"],
    "Importer": ["Import", "Importar"],
    "Tu as déjà une boutique ailleurs ? Ramène tes produits en une fois : un tableur (CSV ou Excel) avec tes photos, ou un dossier ZIP qui contient les deux. Formats reconnus : modèle Yiriclick, export Shopify, export WooCommerce.": ["Already selling elsewhere? Bring your products in one go: a spreadsheet (CSV or Excel) with your photos, or a ZIP file holding both. Accepted: Yiriclick template, Shopify export, WooCommerce export.", "¿Ya vendes en otro sitio? Trae tus productos de una vez: una hoja de cálculo (CSV o Excel) con tus fotos, o un ZIP que contenga ambos. Formatos: plantilla Yiriclick, exportación Shopify, exportación WooCommerce."],
    "Choisir les fichiers": ["Choose files", "Elegir archivos"],
    "Télécharger le modèle": ["Download the template", "Descargar la plantilla"],
    "Fermer": ["Close", "Cerrar"],
    "Lecture des fichiers…": ["Reading files…", "Leyendo archivos…"],
    "Aucun tableur trouvé. Ajoute un fichier CSV ou Excel (ou un ZIP qui en contient un).": ["No spreadsheet found. Add a CSV or Excel file (or a ZIP containing one).", "No se encontró ninguna hoja de cálculo. Añade un archivo CSV o Excel (o un ZIP que lo contenga)."],
    "Le tableur doit avoir une colonne pour le nom et une pour le prix.": ["The spreadsheet needs a column for the name and one for the price.", "La hoja necesita una columna para el nombre y otra para el precio."],
    "Fichier illisible : ": ["Unreadable file: ", "Archivo ilegible: "],
    "Format reconnu : ": ["Format detected: ", "Formato detectado: "],
    "modèle Yiriclick ou tableur simple": ["Yiriclick template or simple table", "plantilla Yiriclick o tabla simple"],
    " produits trouvés": [" products found", " productos encontrados"],
    " photos jointes": [" photos attached", " fotos adjuntas"],
    "Monnaie si le tableur ne la précise pas": ["Currency if the file does not say", "Moneda si el archivo no la indica"],
    "Visibles dans ma boutique tout de suite": ["Visible in my shop straight away", "Visibles en mi tienda enseguida"],
    "Vérifie chaque produit, corrige la catégorie si besoin, puis importe.": ["Check each product, fix the category if needed, then import.", "Revisa cada producto, corrige la categoría si hace falta y luego importa."],
    "Importer ": ["Import ", "Importar "], " produit": [" product", " producto"], " produits": [" products", " productos"],
    "Catégorie de ": ["Category of ", "Categoría de "],
    "Inclure ": ["Include ", "Incluir "],
    "Prix manquant : produit ignoré.": ["Missing price: product skipped.", "Falta el precio: producto omitido."],
    "Nom manquant : produit ignoré.": ["Missing name: product skipped.", "Falta el nombre: producto omitido."],
    "Déjà dans ta boutique (même nom).": ["Already in your shop (same name).", "Ya está en tu tienda (mismo nombre)."],
    "Photo introuvable : ": ["Photo not found: ", "Foto no encontrada: "],
    " photos gardées sur ": [" photos kept out of ", " fotos conservadas de "],
    " (limite de ta formule).": [" (your plan’s limit).", " (límite de tu plan)."],
    "Deuxième option ignorée : taille et couleur ensemble avec les formules Pro et Entreprise.": ["Second option skipped: size and colour together with the Pro and Business plans.", "Segunda opción omitida: talla y color juntos con los planes Pro y Empresa."],
    "Prix différents selon la variante : le plus élevé est utilisé. Un prix par variante avec les formules Pro et Entreprise.": ["Prices differ by variant: the highest is used. One price per variant with the Pro and Business plans.", "Precios distintos según la variante: se usa el más alto. Un precio por variante con los planes Pro y Empresa."],
    "Ta formule permet encore ": ["Your plan still allows ", "Tu plan aún permite "],
    " produits. Les suivants sont décochés.": [" products. The next ones are unticked.", " productos. Los siguientes están desmarcados."],
    "Limite de ta formule atteinte.": ["Your plan’s limit is reached.", "Límite de tu plan alcanzado."],
    "Sans photo": ["No photo", "Sin foto"], " photo": [" photo", " foto"], " photos": [" photos", " fotos"],
    "Stock : ": ["Stock: ", "Stock: "], "rupture": ["out of stock", "agotado"],
    "Import en cours, garde cette page ouverte… ": ["Importing, keep this page open… ", "Importando, mantén esta página abierta… "],
    " importé": [" imported", " importado"], " importés": [" imported", " importados"],
    "Non importé : ": ["Not imported: ", "No importado: "],
    "Photo non récupérée pour « ": ["Photo not retrieved for “", "Foto no recuperada para «"],
    "» (le site d’origine la bloque, ajoute-la à la main).": ["” (the original site blocks it, add it by hand).", "» (el sitio de origen la bloquea, añádela a mano)."],
    "Importer d’autres produits": ["Import more products", "Importar más productos"],
    "Tes produits sont dans l’onglet Produits. Vérifie les photos et les prix avant de partager ta boutique.": ["Your products are in the Products tab. Check photos and prices before sharing your shop.", "Tus productos están en la pestaña Productos. Revisa fotos y precios antes de compartir tu tienda."],
    "Choix": ["Choice", "Opción"], "Taille": ["Size", "Talla"], "Pointure": ["Shoe size", "Número"], "Couleur": ["Colour", "Color"]
  };
  function t(fr) { if (lang === "fr") return fr; var e = D[fr]; return e ? e[lang === "en" ? 0 : 1] : fr; }

  /* ---------- small helpers ---------- */
  function el(tag, cls, text) { var e = document.createElement(tag); if (cls) e.className = cls; if (text != null) e.textContent = text; return e; }
  function norm(s) { return String(s == null ? "" : s).normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase().replace(/[^a-z0-9]+/g, " ").trim(); }
  function base(p) { var s = String(p || "").trim(); try { s = decodeURIComponent(s); } catch (e) {} return s.split(/[\\/]/).pop().toLowerCase(); }
  function noExt(n) { return n.replace(/\.[a-z0-9]{2,5}$/, ""); }
  function slug(s) { return norm(s).replace(/ /g, "-"); }
  function isImg(n) { return /\.(jpe?g|png|webp|gif|avif|heic|heif)$/i.test(n); }
  var scripts = {};
  function loadScript(url, name) {
    if (window[name]) return Promise.resolve(window[name]);
    if (!scripts[url]) scripts[url] = new Promise(function (res, rej) { var s = document.createElement("script"); s.src = url; s.onload = function () { res(window[name]); }; s.onerror = function () { delete scripts[url]; rej(new Error("Script " + name)); }; document.head.appendChild(s); });
    return scripts[url];
  }
  var JSZIP = "https://cdnjs.cloudflare.com/ajax/libs/jszip/3.10.1/jszip.min.js";
  var SHEETJS = "https://cdnjs.cloudflare.com/ajax/libs/xlsx/0.18.5/xlsx.full.min.js";

  function decode(buf) {
    try { return new TextDecoder("utf-8", { fatal: true }).decode(buf); } catch (e) { return new TextDecoder("windows-1252").decode(buf); }
  }
  /* CSV with ; , or tab, quoted cells and line breaks inside quotes */
  function parseCSV(text) {
    text = String(text).replace(/^﻿/, "");
    var first = text.split(/\r?\n/)[0] || "", sep = ";", best = -1;
    [";", ",", "\t"].forEach(function (s) { var n = first.split(s).length; if (n > best) { best = n; sep = s; } });
    var rows = [], row = [], cell = "", q = false;
    for (var i = 0; i < text.length; i++) {
      var c = text[i];
      if (q) { if (c === '"') { if (text[i + 1] === '"') { cell += '"'; i++; } else q = false; } else cell += c; }
      else if (c === '"' && cell === "") q = true;
      else if (c === sep) { row.push(cell); cell = ""; }
      else if (c === "\n" || c === "\r") { if (c === "\r" && text[i + 1] === "\n") i++; row.push(cell); rows.push(row); row = []; cell = ""; }
      else cell += c;
    }
    if (cell !== "" || row.length) { row.push(cell); rows.push(row); }
    return rows.filter(function (r) { return r.some(function (x) { return String(x).trim() !== ""; }); });
  }
  async function parseSheet(buf) {
    var X = await loadScript(SHEETJS, "XLSX");
    var wb = X.read(buf, { type: "array" }), sh = wb.Sheets[wb.SheetNames[0]];
    return X.utils.sheet_to_json(sh, { header: 1, raw: true, defval: "" }).map(function (r) { return r.map(function (x) { return x == null ? "" : x; }); })
      .filter(function (r) { return r.some(function (x) { return String(x).trim() !== ""; }); });
  }

  /* Prices like "85 000", "85.000 FCFA", "12,50 €", "1,299.00" */
  function price(v, dev) {
    if (typeof v === "number") return isFinite(v) && v >= 0 ? v : null;
    var s = String(v || "").replace(/[\s  ']/g, "").replace(/[^\d,.]/g, "");
    if (!s || !/\d/.test(s)) return null;
    var c = s.lastIndexOf(","), d = s.lastIndexOf(".");
    if (c >= 0 && d >= 0) s = c > d ? s.replace(/\./g, "").replace(",", ".") : s.replace(/,/g, "");
    else if (c >= 0) s = (s.split(",").length > 2 || (dev === "XOF" && /,\d{3}$/.test(s))) ? s.replace(/,/g, "") : s.replace(",", ".");
    else if (d >= 0 && (s.split(".").length > 2 || (dev === "XOF" && /\.\d{3}$/.test(s)))) s = s.replace(/\./g, "");
    var n = parseFloat(s); return isFinite(n) && n >= 0 ? Math.round(n * 100) / 100 : null;
  }
  function devOf(s) {
    s = String(s || "").toLowerCase();
    if (/fcfa|f cfa|cfa|xof/.test(s)) return "XOF";
    if (/€|eur/.test(s)) return "EUR";
    if (/\$|usd|dollar/.test(s)) return "USD";
    return null;
  }
  function stockOf(v) {
    if (typeof v === "number") return v >= 0 ? Math.floor(v) : null;
    var s = norm(v); if (!s) return null;
    if (/^(non|no|false|rupture|epuise|out of stock|outofstock|indisponible|0)$/.test(s) || /rupture|epuise|indisponible/.test(s)) return 0;
    var n = parseInt(s, 10); return isFinite(n) && n >= 0 ? n : null;
  }
  function splitList(v) { return String(v || "").split(/\s*[,|;]\s*/).map(function (x) { return x.trim(); }).filter(Boolean); }
  function htmlText(s) {
    s = String(s || "");
    if (!/<[a-z!\/]/i.test(s)) return s.trim();
    s = s.replace(/<\s*br\s*\/?>/gi, "\n").replace(/<\/(p|div|li|h\d)>/gi, "\n");
    var txt = new DOMParser().parseFromString(s, "text/html").body.textContent || "";
    return txt.replace(/[ \t]+/g, " ").replace(/\n\s*\n+/g, "\n").trim();
  }

  /* Column names in French, English and from Shopify / WooCommerce exports (after norm()) */
  var F = {
    handle: ["handle"],
    nom: ["nom", "name", "title", "titre", "produit", "product", "nom du produit", "product name", "article", "designation", "libelle"],
    description: ["description", "body html", "body", "desc", "short description", "description courte", "details"],
    prix: ["prix", "price", "variant price", "regular price", "prix de vente", "tarif", "prix unitaire"],
    promo: ["sale price", "prix promo", "prix solde"],
    avant: ["prix avant", "prix barre", "ancien prix", "compare at price", "variant compare at price", "prix avant reduction"],
    devise: ["devise", "currency", "monnaie"],
    categorie: ["categorie", "category", "categories", "product category", "product type", "rayon", "collection", "type de produit"],
    stock: ["stock", "quantite", "quantity", "qty", "variant inventory qty", "inventory", "stock quantity", "inventaire"],
    instock: ["disponible", "en stock", "in stock"],
    o1n: ["option", "option1 name", "attribute 1 name", "nom option", "option 1", "nom option 1"],
    o1v: ["valeurs", "choix", "choix proposes", "option1 value", "attribute 1 value s", "attribute 1 values", "valeurs option 1", "variantes", "tailles", "pointures", "sizes", "size", "taille", "pointure"],
    o2n: ["option2 name", "attribute 2 name", "option 2", "nom option 2"],
    o2v: ["option2 value", "attribute 2 value s", "attribute 2 values", "valeurs option 2", "couleurs", "colors", "colours", "couleur", "color"],
    photos: ["photos", "photo", "images", "image", "image src", "image url", "images url", "photo url", "fichier photo", "variant image"],
    wtype: [],
    shtype: ["type"]
  };
  function columns(head) {
    var h = head.map(norm), used = {}, col = {};
    var woo = h.indexOf("regular price") >= 0 || h.indexOf("attribute 1 name") >= 0;
    if (woo) { F.wtype = ["type"]; F.shtype = []; } else { F.wtype = []; F.shtype = ["type"]; }
    Object.keys(F).forEach(function (k) {
      for (var i = 0; i < F[k].length; i++) { var j = h.indexOf(F[k][i]); if (j >= 0 && !used[j]) { col[k] = j; used[j] = 1; return; } }
    });
    /* "Prix (FCFA)", "Price EUR"… */
    if (col.prix == null) h.forEach(function (x, j) { if (col.prix == null && !used[j] && /^(prix|price)\b/.test(x)) { col.prix = j; used[j] = 1; } });
    if (col.photos == null) h.forEach(function (x, j) { if (col.photos == null && !used[j] && /^(photo|image)/.test(x)) { col.photos = j; used[j] = 1; } });
    return { col: col, head: head, h: h, woo: woo, shopify: h.indexOf("handle") >= 0 && h.indexOf("variant price") >= 0 };
  }
  function optName(headerNorm, given) {
    if (given && String(given).trim()) return String(given).trim().slice(0, 30);
    if (/pointure/.test(headerNorm)) return t("Pointure");
    if (/couleur|colou?r/.test(headerNorm)) return t("Couleur");
    if (/taille|size/.test(headerNorm)) return t("Taille");
    return t("Choix");
  }

  /* Category: our code, our label, or keywords in the category text and then in the product name */
  var KW = [
    ["textile", /\b(tissus?|pagnes?|fabrics?|textiles?|wax|bazin|faso dan fani|kente|bogolan|kita|lepi)\b/],
    ["mode", /\b(boubous?|robes?|chemises?|vetements?|habits?|mode|tenues?|pantalons?|jupes?|t ?shirts?|dress(es)?|shirts?|cloth(es|ing)?|apparel|fashion|vestes?|jackets?|hoodies?|sweats?|abayas?|kaftans?|caftans?|complets?|pagnes? cousus?)\b/],
    ["chaussures", /\b(chaussures?|sandales?|baskets?|shoes?|sneakers?|sacs?|bags?|maroquinerie|ceintures?|cuir|leather|babouches?)\b/],
    ["bijoux", /\b(bijoux?|colliers?|bracelets?|bagues?|boucles?|perles?|jewel(le)?ry|necklaces?|rings?|earrings?|accessoires?|accessories|montres?|watch(es)?)\b/],
    ["beaute", /\b(beaute|cosmetiques?|savons?|cremes?|karite|parfums?|beauty|soaps?|creams?|cheveux|hair|perruques?|maquillage|makeup|huiles?)\b/],
    ["boissons", /\b(boissons?|jus|bissap|gingembre|drinks?|juices?|vins?|bieres?)\b/],
    ["alim", /\b(alimentation|epices?|farines?|riz|miel|food|grocery|snacks?|cafe|the|tea|confitures?|soumbala|beignets?)\b/],
    ["artisanat", /\b(artisanat|sculptures?|tableaux?|crafts?|vannerie|poteries?|masques?|bronzes?|statuettes?)\b/],
    ["deco", /\b(decoration|deco|maison|home|coussins?|nappes?|rideaux?|bougies?)\b/],
    ["tech", /\b(telephones?|phones?|smartphones?|electroniques?|ecouteurs?|chargeurs?|cables?)\b/],
    ["info", /\b(ordinateurs?|laptops?|computers?|informatique)\b/],
    ["bebe", /\b(bebes?|baby|babies|enfants?|kids?|layette)\b/],
    ["jouets", /\b(jouets?|toys?|jeux|games?)\b/],
    ["sport", /\b(sports?|fitness|football|ballons?)\b/],
    ["livres", /\b(livres?|books?|cahiers?|fournitures?)\b/],
    ["sante", /\b(sante|health|bien etre|wellness|tisanes?)\b/],
    ["animaux", /\b(animaux|animals?|chiens?|chats?|pets?)\b/],
    ["meubles", /\b(meubles?|chaises?|furniture|canapes?)\b/],
    ["services", /\b(services?|cours|formations?|reparations?)\b/]
  ];
  function category(value, name, CATS) {
    var v = norm(value);
    if (v) {
      for (var i = 0; i < CATS.length; i++) if (v === CATS[i][0] || v === norm(CATS[i][1])) return CATS[i][0];
      var parts = String(value).split(/[>,|\/]/).map(norm).filter(Boolean);
      for (var p = parts.length - 1; p >= 0; p--) for (var k = 0; k < KW.length; k++) if (KW[k][1].test(parts[p])) return KW[k][0];
    }
    var n = norm(name);
    for (var j = 0; j < KW.length; j++) if (KW[j][1].test(n)) return KW[j][0];
    return null;
  }

  /* ---------- rows → products ---------- */
  function cell(r, c, k) { return c.col[k] == null ? "" : r[c.col[k]]; }
  function build(rows, defDev, CATS) {
    var c = columns(rows[0]), body = rows.slice(1), items = [];
    if (c.col.nom == null || c.col.prix == null) return { error: t("Le tableur doit avoir une colonne pour le nom et une pour le prix."), cols: c };
    var headDev = devOf(c.head[c.col.prix]);
    function dev(r, pcell) { return ({ xof: "XOF", fcfa: "XOF", cfa: "XOF", eur: "EUR", euro: "EUR", usd: "USD" })[norm(cell(r, c, "devise"))] || devOf(cell(r, c, "devise")) || devOf(pcell) || headDev || defDev; }

    if (c.shopify) {
      var groups = {}, order = [];
      body.forEach(function (r) { var hd = String(cell(r, c, "handle")).trim(); if (!hd) return; if (!groups[hd]) { groups[hd] = []; order.push(hd); } groups[hd].push(r); });
      order.forEach(function (hd) {
        var rs = groups[hd], f = rs.filter(function (r) { return String(cell(r, c, "nom")).trim(); })[0] || rs[0];
        var it = newItem(); it.nom = String(cell(f, c, "nom")).trim(); it.description = htmlText(cell(f, c, "description"));
        it.catText = cell(f, c, "categorie") || cell(f, c, "shtype");
        var n1 = String(cell(f, c, "o1n")).trim(), n2 = String(cell(f, c, "o2n")).trim();
        var v1 = [], v2 = [], vars = [];
        rs.forEach(function (r) {
          splitList(cell(r, c, "photos")).forEach(function (u) { if (it.photoRefs.indexOf(u) < 0) it.photoRefs.push(u); });
          var a = String(cell(r, c, "o1v")).trim(), b = String(cell(r, c, "o2v")).trim(), p = price(cell(r, c, "prix"), dev(r));
          if (p == null) return;
          if (a && v1.indexOf(a) < 0) v1.push(a); if (b && v2.indexOf(b) < 0) v2.push(b);
          vars.push({ v: [a, b].filter(Boolean), prix: p, avant: price(cell(r, c, "avant"), dev(r)), stock: cell(r, c, "stock") === "" ? null : stockOf(cell(r, c, "stock")) });
        });
        it.devise = dev(f, cell(f, c, "prix"));
        if (!vars.length) { it.prix = null; items.push(it); return; }
        var noVar = !n1 || (/^title$/i.test(n1) && /^default title$/i.test(v1[0] || ""));
        it.prix = Math.min.apply(null, vars.map(function (x) { return x.prix; }));
        it.avant = vars[0].avant;
        if (noVar) { it.stock = vars[0].stock; }
        else {
          it.options.push({ nom: n1.slice(0, 30), valeurs: v1 }); if (n2 && v2.length) it.options.push({ nom: n2.slice(0, 30), valeurs: v2 });
          vars.forEach(function (x) { var k = JSON.stringify(x.v); it.vprix[k] = x.prix; it.vstock[k] = x.stock; });
          var known = vars.filter(function (x) { return x.stock != null; });
          it.stock = known.length === vars.length ? known.reduce(function (s, x) { return s + x.stock; }, 0) : null;
        }
        items.push(it);
      });
      return { items: items, format: "Shopify", cols: c };
    }

    var lastVar = null;
    body.forEach(function (r) {
      if (c.woo && /variation/i.test(String(cell(r, c, "wtype")))) {
        // WooCommerce: one row per variation after its parent; keep its price and stock for that combination
        if (!lastVar) return;
        var d0 = lastVar.devise, rg = price(cell(r, c, "prix"), d0), pm = price(cell(r, c, "promo"), d0), vp = pm != null && rg != null && pm < rg ? pm : rg;
        var key = JSON.stringify([String(cell(r, c, "o1v")).trim(), String(cell(r, c, "o2v")).trim()].filter(Boolean));
        if (vp != null) lastVar.vprix[key] = vp;
        var vs = cell(r, c, "stock") === "" ? null : stockOf(cell(r, c, "stock"));
        if (c.col.instock != null && stockOf(cell(r, c, "instock")) === 0) vs = 0;
        lastVar.vstock[key] = vs;
        return;
      }
      var it = newItem();
      it.nom = String(cell(r, c, "nom")).trim();
      it.description = htmlText(cell(r, c, "description"));
      it.devise = dev(r, cell(r, c, "prix"));
      var reg = price(cell(r, c, "prix"), it.devise), promo = price(cell(r, c, "promo"), it.devise), avant = price(cell(r, c, "avant"), it.devise);
      if (promo != null && reg != null && promo < reg) { it.prix = promo; it.avant = reg; } else { it.prix = reg; it.avant = avant; }
      it.catText = cell(r, c, "categorie");
      it.stock = stockOf(cell(r, c, "stock"));
      if (c.col.instock != null && stockOf(cell(r, c, "instock")) === 0) it.stock = 0; // yes / no column
      var vals1 = splitList(cell(r, c, "o1v")), vals2 = splitList(cell(r, c, "o2v"));
      if (vals1.length) it.options.push({ nom: optName(c.col.o1v != null ? c.h[c.col.o1v] : "", cell(r, c, "o1n")), valeurs: vals1 });
      if (vals2.length) it.options.push({ nom: optName(c.col.o2v != null ? c.h[c.col.o2v] : "", cell(r, c, "o2n")), valeurs: vals2 });
      it.photoRefs = splitList(cell(r, c, "photos"));
      if (!it.nom && it.prix == null && !it.description) return;
      lastVar = c.woo && /variable/i.test(String(cell(r, c, "wtype"))) ? it : null;
      items.push(it);
    });
    items.forEach(function (it) {
      var ps = Object.keys(it.vprix).map(function (k) { return it.vprix[k]; });
      if (it.prix == null && ps.length) it.prix = Math.min.apply(null, ps);
    });
    return { items: items, format: c.woo ? "WooCommerce" : t("modèle Yiriclick ou tableur simple"), cols: c };
  }
  function newItem() { return { nom: "", description: "", prix: null, avant: null, devise: "XOF", catText: "", stock: null, options: [], vprix: {}, vstock: {}, photoRefs: [], photos: [], warn: [], ok: true, on: true }; }

  /* ---------- the import panel ---------- */
  function init(ctx) {
    var box = ctx.box, btn = ctx.button, state = null;
    btn.addEventListener("click", function () { box.hidden = !box.hidden; if (!box.hidden) { if (!state) start(); box.scrollIntoView({ behavior: "smooth", block: "start" }); } });

    function start() {
      state = { items: [], pool: {}, nPhotos: 0 };
      box.textContent = "";
      var hd = el("div", "imp-head"); hd.appendChild(el("h2", null, t("Importer des produits")));
      var x = el("button", "link", t("Fermer")); x.type = "button"; x.addEventListener("click", function () { box.hidden = true; }); hd.appendChild(x); box.appendChild(hd);
      box.appendChild(el("p", "hint", t("Tu as déjà une boutique ailleurs ? Ramène tes produits en une fois : un tableur (CSV ou Excel) avec tes photos, ou un dossier ZIP qui contient les deux. Formats reconnus : modèle Yiriclick, export Shopify, export WooCommerce.")));
      var row = el("div", "imp-actions");
      var lab = el("label", "filebtn"), inp = el("input", "vh"); inp.type = "file"; inp.multiple = true; inp.accept = ".csv,.txt,.tsv,.xlsx,.xls,.ods,.zip,image/*";
      lab.appendChild(inp); lab.appendChild(document.createTextNode(t("Choisir les fichiers"))); row.appendChild(lab);
      var tpl = el("button", "btn btn-ghost btn-sm", t("Télécharger le modèle")); tpl.type = "button"; tpl.addEventListener("click", template); row.appendChild(tpl);
      box.appendChild(row);
      state.msg = el("p", "hint"); state.err = el("p", "err"); state.out = el("div", "imp-out");
      box.appendChild(state.msg); box.appendChild(state.err); box.appendChild(state.out);
      inp.addEventListener("change", function () { if (inp.files.length) read(Array.prototype.slice.call(inp.files)); inp.value = ""; });
    }

    function template() {
      var rows = [["nom", "description", "prix", "prix_avant", "devise", "categorie", "stock", "option", "valeurs", "photos"],
        ["Boubou brodé", "Coton tissé, broderie au col", "45000", "", "FCFA", "mode", "", "Taille", "S, M, L, XL", "boubou-1.jpg, boubou-2.jpg"],
        ["Pagne tissé bleu", "Prix pour un pagne", "15000", "18000", "FCFA", "textile", "12", "", "", "pagne-bleu.jpg"]];
      var csv = "﻿" + rows.map(function (r) { return r.map(function (v) { return /[;"\n]/.test(v) ? '"' + v.replace(/"/g, '""') + '"' : v; }).join(";"); }).join("\r\n");
      var a = document.createElement("a"); a.href = URL.createObjectURL(new Blob([csv], { type: "text/csv;charset=utf-8" })); a.download = "modele-import-yiriclick.csv";
      document.body.appendChild(a); a.click(); setTimeout(function () { URL.revokeObjectURL(a.href); a.remove(); }, 500);
    }

    async function read(files) {
      state.err.textContent = ""; state.out.textContent = ""; state.msg.textContent = t("Lecture des fichiers…");
      var sheets = [];
      try {
        for (var i = 0; i < files.length; i++) {
          var f = files[i], n = f.name.toLowerCase();
          if (/\.zip$/.test(n)) {
            var Z = await loadScript(JSZIP, "JSZip"), zip = await Z.loadAsync(await f.arrayBuffer()), names = Object.keys(zip.files);
            for (var j = 0; j < names.length; j++) {
              var e = zip.files[names[j]], bn = base(names[j]);
              if (e.dir || /^__macosx\//i.test(names[j]) || bn.charAt(0) === ".") continue;
              if (isImg(bn)) addPhoto(bn, await e.async("blob"));
              else if (/\.(csv|txt|tsv)$/.test(bn)) sheets.push({ name: bn, rows: parseCSV(decode(await e.async("uint8array"))) });
              else if (/\.(xlsx|xls|ods)$/.test(bn)) sheets.push({ name: bn, rows: await parseSheet(await e.async("arraybuffer")) });
            }
          } else if (isImg(n) || /^image\//.test(f.type)) addPhoto(base(f.name), f);
          else if (/\.(csv|txt|tsv)$/.test(n)) sheets.push({ name: n, rows: parseCSV(decode(new Uint8Array(await f.arrayBuffer()))) });
          else if (/\.(xlsx|xls|ods)$/.test(n)) sheets.push({ name: n, rows: await parseSheet(await f.arrayBuffer()) });
        }
      } catch (e) { state.msg.textContent = ""; state.err.textContent = t("Fichier illisible : ") + (e.message || e); return; }
      if (!sheets.length) {
        state.msg.textContent = "";
        if (state.items.length && state.nPhotos) { resolvePhotos(); render(); return; } // photos added after the spreadsheet
        state.err.textContent = t("Aucun tableur trouvé. Ajoute un fichier CSV ou Excel (ou un ZIP qui en contient un).");
        return;
      }
      var res = build(sheets[0].rows, ctx.shopDevise(), ctx.CATS);
      if (res.error) { state.msg.textContent = ""; state.err.textContent = res.error; return; }
      state.items = res.items; state.format = res.format;
      resolvePhotos(); render();
    }
    function addPhoto(name, blob) { if (!state.pool[name]) state.nPhotos++; state.pool[name] = blob; state.pool[noExt(name)] = state.pool[noExt(name)] || blob; }

    function resolvePhotos() {
      var P = ctx.plan(), maxPh = P[2], existing = {};
      ctx.products().forEach(function (p) { existing[norm(p.nom)] = 1; });
      var left = P[1] == null ? Infinity : P[1] - ctx.products().length, n = 0;
      state.items.forEach(function (it) {
        it.warn = []; it.photos = []; it.ok = true;
        if (it.nom.length > 120) it.nom = it.nom.slice(0, 120);
        if (it.description.length > 3000) it.description = it.description.slice(0, 3000);
        if (it.nom.length < 2) { it.ok = false; it.warn.push(t("Nom manquant : produit ignoré.")); }
        else if (it.prix == null) { it.ok = false; it.warn.push(t("Prix manquant : produit ignoré.")); }
        if (it.cat === undefined) it.cat = category(it.catText, it.nom + " " + it.description, ctx.CATS) || "autre";
        var refs = it.photoRefs.slice();
        if (!refs.length && state.pool[slug(it.nom)]) refs = [slug(it.nom)];
        refs.forEach(function (r) {
          if (/^https?:\/\//i.test(r)) it.photos.push({ url: r });
          else { var b = state.pool[base(r)] || state.pool[noExt(base(r))]; if (b) it.photos.push({ blob: b, name: base(r) }); else it.warn.push(t("Photo introuvable : ") + r); }
        });
        if (it.photos.length > maxPh) { it.warn.push(maxPh + t(" photos gardées sur ") + it.photos.length + t(" (limite de ta formule).")); it.photos = it.photos.slice(0, maxPh); }
        if (it.options.length > ctx.maxOpts()) it.warn.push(t("Deuxième option ignorée : taille et couleur ensemble avec les formules Pro et Entreprise."));
        if (!ctx.isPro()) {
          var ps = Object.keys(it.vprix).map(function (k) { return it.vprix[k]; });
          if (ps.length && Math.max.apply(null, ps) !== Math.min.apply(null, ps)) { it.prix = Math.max.apply(null, ps); it.warn.push(t("Prix différents selon la variante : le plus élevé est utilisé. Un prix par variante avec les formules Pro et Entreprise.")); }
        }
        var dup = existing[norm(it.nom)]; if (dup && it.ok) it.warn.push(t("Déjà dans ta boutique (même nom)."));
        it.on = it.ok && !dup && n < left; if (it.on) n++;
      });
      state.left = left;
    }

    function fmt(v, d) { return ctx.money(v, d); }
    function render() {
      var out = state.out; out.textContent = "";
      var valid = state.items.filter(function (i) { return i.ok; }).length;
      state.msg.textContent = t("Format reconnu : ") + state.format + " · " + state.items.length + t(" produits trouvés") + (state.nPhotos ? " · " + state.nPhotos + t(" photos jointes") : "");
      if (valid > state.left) out.appendChild(el("p", "notice", state.left > 0 ? t("Ta formule permet encore ") + state.left + t(" produits. Les suivants sont décochés.") : t("Limite de ta formule atteinte.")));
      var set = el("div", "imp-set");
      var f1 = el("label", "imp-vis"), vis = el("input"); vis.type = "checkbox"; vis.checked = true; f1.appendChild(vis); f1.appendChild(document.createTextNode(" " + t("Visibles dans ma boutique tout de suite"))); set.appendChild(f1);
      out.appendChild(set);
      out.appendChild(el("p", "hint", t("Vérifie chaque produit, corrige la catégorie si besoin, puis importe.")));
      var list = el("div", "imp-list"); out.appendChild(list);
      var go = el("button", "btn btn-orange", ""); go.type = "button";
      function count() { var k = state.items.filter(function (i) { return i.on; }).length; go.textContent = t("Importer ") + k + (k > 1 ? t(" produits") : t(" produit")); go.disabled = !k; }
      state.items.forEach(function (it, idx) {
        var r = el("div", "imp-row" + (it.ok ? "" : " off"));
        var cb = el("input"); cb.type = "checkbox"; cb.checked = it.on; cb.disabled = !it.ok; cb.setAttribute("aria-label", t("Inclure ") + (it.nom || "#" + (idx + 1)));
        cb.addEventListener("change", function () {
          var k = state.items.filter(function (i) { return i.on; }).length;
          if (cb.checked && k >= state.left) { cb.checked = false; return; }
          it.on = cb.checked; count();
        });
        r.appendChild(cb);
        var th = el("div", "imp-th"), ph = it.photos[0];
        if (ph) { var im = el("img"); im.alt = ""; im.loading = "lazy"; im.src = ph.url || (ph.preview = ph.preview || URL.createObjectURL(ph.blob)); th.appendChild(im); } else th.appendChild(el("span", null, t("Sans photo")));
        r.appendChild(th);
        var info = el("div", "imp-info");
        info.appendChild(el("b", null, it.nom || "—"));
        var meta = [];
        if (it.prix != null) meta.push(fmt(it.prix, it.devise) + (it.avant && it.avant > it.prix ? " (" + fmt(it.avant, it.devise) + ")" : ""));
        it.options.slice(0, ctx.maxOpts()).forEach(function (o) { meta.push(o.nom + " : " + o.valeurs.join(", ")); });
        if (it.stock === 0) meta.push(t("Stock : ") + t("rupture")); else if (it.stock != null) meta.push(t("Stock : ") + it.stock);
        meta.push(it.photos.length ? it.photos.length + (it.photos.length > 1 ? t(" photos") : t(" photo")) : t("Sans photo"));
        info.appendChild(el("span", "hint", meta.join(" · ")));
        it.warn.forEach(function (w) { info.appendChild(el("span", "imp-warn", w)); });
        if (it.ok) {
          var sel = el("select"); sel.setAttribute("aria-label", t("Catégorie de ") + it.nom);
          ctx.CATS.forEach(function (c) { var o = el("option", null, c[1]); o.value = c[0]; sel.appendChild(o); });
          sel.value = it.cat; sel.addEventListener("change", function () { it.cat = sel.value; });
          info.appendChild(sel);
        }
        r.appendChild(info); list.appendChild(r);
      });
      count();
      var res = el("div", "imp-res");
      go.addEventListener("click", function () { run(vis.checked, go, res); });
      out.appendChild(go); out.appendChild(res);
    }

    function cartesian(opts) { return opts.reduce(function (acc, o) { var r = []; acc.forEach(function (a) { o.valeurs.forEach(function (v) { r.push(a.concat([v])); }); }); return r; }, [[]]); }
    function clean(vals) { var seen = {}; return vals.map(function (v) { return String(v).trim().slice(0, 30); }).filter(function (v) { var k = v.toLowerCase(); if (!v || seen[k]) return false; seen[k] = 1; return true; }).slice(0, 30); }
    async function getBlob(ph) {
      if (ph.blob) return ph.blob;
      var r = await fetch(ph.url, { mode: "cors" }); if (!r.ok) throw new Error("HTTP " + r.status); return r.blob();
    }

    async function run(visible, go, res) {
      var todo = state.items.filter(function (i) { return i.on; });
      if (!todo.length) return;
      go.disabled = true; res.textContent = "";
      state.out.querySelectorAll("input,select").forEach(function (x) { x.disabled = true; });
      var done = 0, failed = [], lost = [], prog = el("p", "ok"); res.appendChild(prog);
      var pro = ctx.isPro();
      for (var i = 0; i < todo.length; i++) {
        var it = todo[i], id = ctx.uid(), fresh = [];
        prog.textContent = t("Import en cours, garde cette page ouverte… ") + (i + 1) + " / " + todo.length;
        try {
          for (var k = 0; k < it.photos.length; k++) {
            try { fresh.push(await ctx.upload(await ctx.compress(await getBlob(it.photos[k]), 1600, .82), "produits/" + id)); }
            catch (e) { if (e && /row-level|permission|quota|Payload|exceeded/i.test(e.message || "")) throw e; lost.push(it.nom); }
          }
          var row = { id: id, boutique_id: ctx.shop().id, nom: it.nom, description: it.description || null, prix: it.prix, devise: it.devise,
            categorie: it.cat, stock: it.stock, photos: fresh, visible: visible };
          if (it.avant != null && it.avant > it.prix) row.prix_avant = it.avant;
          var opts = it.options.slice(0, ctx.maxOpts()).map(function (o) { return { nom: o.nom.slice(0, 30), valeurs: clean(o.valeurs) }; }).filter(function (o) { return o.nom && o.valeurs.length; });
          if (opts.length && ctx.hasVariants()) {
            var listed = Object.keys(it.vprix).length > 0 && opts.length === it.options.length;
            var combis = cartesian(opts).slice(0, 200).map(function (v) {
              var key = JSON.stringify(v), s = it.vstock[key], p = it.vprix[key];
              if (listed && !(key in it.vprix)) s = 0; // a combination the original shop did not sell
              return { v: v, stock: s != null ? s : (it.stock === 0 ? 0 : null), prix: pro && p != null && p !== it.prix ? p : null };
            });
            row.variantes = { options: opts, combis: combis }; row.stock = null;
          }
          var r = await ctx.sb.from("produits").insert(row).select().single();
          if (r.error && row.variantes && ctx.missingCol(r.error)) { delete row.variantes; r = await ctx.sb.from("produits").insert(row).select().single(); }
          if (r.error) throw r.error;
          ctx.added(r.data); done++;
        } catch (e) {
          if (fresh.length) { try { await ctx.removeFiles(fresh); } catch (x) {} }
          failed.push(it.nom + " : " + ctx.niceErr(e));
          if (/limite|limit/i.test((e && e.message) || "")) break;
        }
      }
      ctx.refresh();
      prog.textContent = done + (done > 1 ? t(" importés") : t(" importé")) + " / " + todo.length;
      if (done) res.appendChild(el("p", "hint", t("Tes produits sont dans l’onglet Produits. Vérifie les photos et les prix avant de partager ta boutique.")));
      lost.filter(function (v, j, a) { return a.indexOf(v) === j; }).forEach(function (n) { res.appendChild(el("p", "imp-warn", t("Photo non récupérée pour « ") + n + t("» (le site d’origine la bloque, ajoute-la à la main)."))); });
      failed.forEach(function (f) { res.appendChild(el("p", "err", t("Non importé : ") + f)); });
      var again = el("button", "btn btn-ghost btn-sm", t("Importer d’autres produits")); again.type = "button"; again.addEventListener("click", start); res.appendChild(again);
    }
  }

  return { init: init, _test: { parseCSV: parseCSV, price: price, build: build, category: category, norm: norm } };
})();
