// Builds the published site into _site/:
//  - copies the repository files,
//  - writes a share page per shop (b/<slug>/) and per product (p/<id>/) with link-preview tags
//    (WhatsApp, Facebook, X) and structured data, which then send visitors to the live page,
//  - writes sitemap.xml and robots.txt.
// Run by .github/workflows/publier.yml every hour and on each push. Only public data is read.
import { mkdir, readdir, copyFile, writeFile, readFile, stat } from "node:fs/promises";
import { join, dirname } from "node:path";

const ROOT = process.cwd();
const OUT = join(ROOT, "_site");
const OLD_SITE = "https://toutfeutoutflamme226-design.github.io/YiriClick-/";
const SITE = (process.env.SITE_URL || OLD_SITE).replace(/\/?$/, "/");
const SB = (process.env.SUPABASE_URL || "https://vtiakxfnechkoomagddl.supabase.co").replace(/\/$/, "");
const KEY = process.env.SUPABASE_KEY || "sb_publishable_415c2KQSDRx0SMofnkHKQA_PJ2IrzBA";
const SKIP = new Set([".git", ".github", "_site", "node_modules", "scripts"]);
const CUR = { XOF: "FCFA", EUR: "€", USD: "$" };

const esc = (s) => String(s ?? "").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
const clip = (s, n) => { s = String(s ?? "").replace(/\s+/g, " ").trim(); return s.length > n ? s.slice(0, n - 1).trimEnd() + "…" : s; };
const pub = (p) => (p ? SB + "/storage/v1/object/public/boutiques/" + p.split("/").map(encodeURIComponent).join("/") : "");
const price = (v, d) => { const n = Number(v); const t = d === "XOF" ? Math.round(n).toLocaleString("fr-FR") : n.toLocaleString("fr-FR", { minimumFractionDigits: 2, maximumFractionDigits: 2 }); return d === "USD" ? "$" + t : t + " " + (CUR[d] || d); };

async function copyTree(src, dst) {
  await mkdir(dst, { recursive: true });
  for (const e of await readdir(src, { withFileTypes: true })) {
    if (SKIP.has(e.name)) continue;
    const s = join(src, e.name), d = join(dst, e.name);
    if (e.isDirectory()) await copyTree(s, d);
    else if (/\.(html|webmanifest|txt|xml|js|css)$/.test(e.name) && SITE !== OLD_SITE) {
      // after a domain change, absolute links in the pages follow SITE_URL
      await writeFile(d, (await readFile(s, "utf8")).split(OLD_SITE).join(SITE));
    } else await copyFile(s, d);
  }
}

async function rest(path) {
  const r = await fetch(SB + "/rest/v1/" + path, { headers: { apikey: KEY, Accept: "application/json" } });
  if (!r.ok) throw new Error(path.split("?")[0] + " : HTTP " + r.status + " " + (await r.text()).slice(0, 200));
  return r.json();
}

/* Share page: tags for link previews; people are sent to the live page straight away */
function sharePage({ title, desc, image, url, target, jsonld }) {
  return `<!doctype html>
<html lang="fr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${esc(title)}</title>
<meta name="description" content="${esc(desc)}">
<link rel="canonical" href="${esc(target)}">
<meta property="og:type" content="website">
<meta property="og:site_name" content="Yiriclick">
<meta property="og:title" content="${esc(title)}">
<meta property="og:description" content="${esc(desc)}">
<meta property="og:url" content="${esc(url)}">
<meta property="og:image" content="${esc(image)}">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="${esc(title)}">
<meta name="twitter:description" content="${esc(desc)}">
<meta name="twitter:image" content="${esc(image)}">
<script type="application/ld+json">${JSON.stringify(jsonld).replace(/</g, "\\u003c")}</script>
<script>location.replace(${JSON.stringify(target)});</script>
<style>body{font-family:Arial,sans-serif;background:#10232A;color:#fff;display:flex;align-items:center;justify-content:center;min-height:100vh;margin:0;text-align:center;padding:20px}a{color:#4FC7CF;font-weight:bold}</style>
</head>
<body><p>${esc(title)}<br><br><a href="${esc(target)}">Ouvrir sur Yiriclick</a></p></body>
</html>
`;
}

async function main() {
  await copyTree(ROOT, OUT);
  const now = new Date().toISOString();
  const urls = [{ loc: SITE, lastmod: now, pr: "1.0" }, { loc: SITE + "vendre.html", lastmod: now, pr: "0.8" }];
  let shops = [], products = [], reviews = [];
  try {
    shops = await rest("boutiques?select=id,slug,nom,description,slogan,ville,pays,logo,couverture,updated_at&visible=eq.true&masque_admin=eq.false&limit=5000");
    products = await rest("produits?select=id,nom,description,prix,prix_avant,devise,stock,photos,updated_at,boutique_id&visible=eq.true&masque_admin=eq.false&order=updated_at.desc&limit=5000");
    try { reviews = await rest("avis?select=boutique_id,note&limit=20000"); } catch { reviews = []; }
  } catch (e) {
    console.warn("Données Supabase indisponibles, publication sans pages de partage :", e.message);
  }
  const shopById = new Map(shops.map((s) => [s.id, s]));
  const rating = new Map();
  for (const r of reviews) { const x = rating.get(r.boutique_id) || { n: 0, sum: 0 }; x.n++; x.sum += r.note; rating.set(r.boutique_id, x); }

  for (const s of shops) {
    if (!/^[a-z0-9-]{3,40}$/.test(s.slug)) continue;
    const target = SITE + "boutique.html?b=" + s.slug, url = SITE + "b/" + s.slug + "/";
    const n = products.filter((p) => p.boutique_id === s.id).length;
    const place = [s.ville, s.pays].filter(Boolean).join(", ");
    const desc = clip([s.slogan, s.description, place && "Boutique à " + place, n ? n + " produits à commander sur WhatsApp" : ""].filter(Boolean).join(" · "), 200);
    const r = rating.get(s.id);
    const jsonld = { "@context": "https://schema.org", "@type": "Store", name: s.nom, url: target, description: desc,
      image: pub(s.couverture) || pub(s.logo) || SITE + "assets/og.png", logo: pub(s.logo) || undefined,
      address: place ? { "@type": "PostalAddress", addressLocality: s.ville || undefined, addressCountry: s.pays || undefined } : undefined,
      aggregateRating: r ? { "@type": "AggregateRating", ratingValue: (r.sum / r.n).toFixed(1), reviewCount: r.n } : undefined };
    await mkdir(join(OUT, "b", s.slug), { recursive: true });
    await writeFile(join(OUT, "b", s.slug, "index.html"), sharePage({ title: s.nom + " · Yiriclick", desc, image: jsonld.image, url, target, jsonld }));
    urls.push({ loc: target, lastmod: s.updated_at || now, pr: "0.9" });
  }
  for (const p of products) {
    const s = shopById.get(p.boutique_id); if (!s || !/^[0-9a-f-]{36}$/.test(p.id)) continue;
    const target = SITE + "boutique.html?b=" + s.slug + "&p=" + p.id, url = SITE + "p/" + p.id + "/";
    const old = p.prix_avant && Number(p.prix_avant) > Number(p.prix) ? " (au lieu de " + price(p.prix_avant, p.devise) + ")" : "";
    const title = p.nom + " · " + price(p.prix, p.devise);
    const desc = clip(price(p.prix, p.devise) + old + " chez " + s.nom + ". " + (p.description || "") , 200);
    const image = p.photos && p.photos[0] ? pub(p.photos[0]) : pub(s.couverture) || SITE + "assets/og.png";
    const jsonld = { "@context": "https://schema.org", "@type": "Product", name: p.nom, description: clip(p.description || p.nom, 500), image: (p.photos || []).map(pub),
      url: target, brand: { "@type": "Brand", name: s.nom },
      offers: { "@type": "Offer", price: Number(p.prix).toFixed(p.devise === "XOF" ? 0 : 2), priceCurrency: p.devise, url: target,
        availability: p.stock === 0 ? "https://schema.org/OutOfStock" : "https://schema.org/InStock", seller: { "@type": "Organization", name: s.nom } } };
    await mkdir(join(OUT, "p", p.id), { recursive: true });
    await writeFile(join(OUT, "p", p.id, "index.html"), sharePage({ title, desc, image, url, target, jsonld }));
    urls.push({ loc: target, lastmod: p.updated_at || now, pr: "0.7" });
  }
  const xml = '<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n' +
    urls.map((u) => `  <url><loc>${esc(u.loc)}</loc><lastmod>${String(u.lastmod).slice(0, 10)}</lastmod><priority>${u.pr}</priority></url>`).join("\n") + "\n</urlset>\n";
  await writeFile(join(OUT, "sitemap.xml"), xml);
  await writeFile(join(OUT, "robots.txt"), "User-agent: *\nAllow: /\nDisallow: /admin.html\nDisallow: /vendeur.html\nSitemap: " + SITE + "sitemap.xml\n");
  console.log(`Site : ${SITE} · ${shops.length} boutiques · ${products.length} produits · ${urls.length} adresses dans le plan du site`);
}

main().catch((e) => { console.error(e); process.exit(1); });
