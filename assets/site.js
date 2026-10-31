/* Site settings managed from the admin (base v27): prices, contact details, announcement bar, edited texts.
   - YSITE.get("prix") returns the settings (from the browser's copy first, then the fresh copy from the database).
   - Texts changed in « mode édition » replace the text of any element with data-t (or data-edit) on the page,
     in the language of the page. Elements that contain other elements are never replaced.
   - An admin who is signed in sees a « Modifier » button: click a dotted text, write, save. */
(function () {
  var URL_SB = "https://vtiakxfnechkoomagddl.supabase.co", KEY = "sb_publishable_415c2KQSDRx0SMofnkHKQA_PJ2IrzBA";
  var CACHE = "yc-site", data = {}, ready = false, subs = [];
  try { data = JSON.parse(localStorage.getItem(CACHE) || "{}") || {}; } catch (e) { data = {}; }

  var PAGE = (location.pathname.split("/").pop() || "index").replace(/\.html$/, "") || "index";
  function lang() { var l = (document.documentElement.lang || "fr").slice(0, 2); return ["fr", "en", "es", "nl"].indexOf(l) >= 0 ? l : "fr"; }
  function keyOf(n) { var k = n.getAttribute("data-edit") || n.getAttribute("data-t"); return k ? PAGE + "|" + k : null; }
  function leaf(n) { return !n.firstElementChild; }

  /* ---------- contact details: the legal identity follows the admin settings ---------- */
  function applyContact() {
    var c = data.contact || {};
    if (window.YLEGAL && c.email) window.YLEGAL.email = c.email;
  }
  applyContact();

  /* ---------- edited texts ---------- */
  var applying = false;
  function applyTexts() {
    var T = data.textes || {}, l = lang(); if (applying) return; applying = true;
    try {
      document.querySelectorAll("[data-t],[data-edit]").forEach(function (n) {
        if (!leaf(n)) return;
        if (n._ycv === undefined || n.textContent !== n._ycv) { n._ycorig = n.textContent; n._ycv = undefined; }   // the page wrote its own text
        var k = keyOf(n), v = k && T[k] && T[k][l];
        if (v) { if (n.textContent !== v) n.textContent = v; n._ycv = v; }
        else if (n._ycv !== undefined) { n.textContent = n._ycorig; n._ycv = undefined; }
      });
    } finally { applying = false; }
  }
  var timer = null;
  function later() { if (timer) return; timer = setTimeout(function () { timer = null; applyTexts(); if (editing) mark(); }, 40); }
  function observe() {
    try { new MutationObserver(function (m) { if (applying) return; for (var i = 0; i < m.length; i++) { if (m[i].type === "childList" || m[i].attributeName === "lang") { later(); return; } } })
      .observe(document.documentElement, { childList: true, subtree: true, attributes: true, attributeFilter: ["lang"] }); } catch (e) {}
  }

  /* ---------- announcement bar ---------- */
  function applyAnnonce() {
    var a = data.annonce || {}, old = document.getElementById("ycAnnonce");
    var txt = a.actif && a.texte ? (a.texte[lang()] || a.texte.fr || "") : "";
    var over = a.fin && new Date(a.fin + "T23:59:59") < new Date();
    var closed = false; try { closed = sessionStorage.getItem("yc-annonce-off") === txt; } catch (e) {}
    if (!txt || over || closed || /admin/.test(PAGE)) { if (old) old.remove(); return; }
    var bar = old || document.createElement("div");
    bar.id = "ycAnnonce"; bar.setAttribute("role", "region"); bar.setAttribute("aria-label", "Annonce");
    bar.style.cssText = "position:relative;z-index:50;background:#FF7A2E;color:#10232A;font:700 14px/1.35 Archivo,Arial,sans-serif;padding:10px 48px 10px 16px;text-align:center";
    bar.textContent = "";
    var t = document.createElement("a");
    t.textContent = txt; if (a.lien && /^(https:\/\/|[a-z0-9#?\/._=&-]+$)/i.test(a.lien)) { t.href = a.lien; t.style.color = "inherit"; t.style.textDecoration = "underline"; }
    var x = document.createElement("button"); x.type = "button"; x.textContent = "×"; x.setAttribute("aria-label", "Fermer");
    x.style.cssText = "position:absolute;right:4px;top:50%;transform:translateY(-50%);width:40px;height:40px;border:0;background:none;color:inherit;font-size:22px;cursor:pointer";
    x.addEventListener("click", function () { try { sessionStorage.setItem("yc-annonce-off", txt); } catch (e) {} bar.remove(); });
    bar.appendChild(t); bar.appendChild(x);
    if (!old) document.body.insertBefore(bar, document.body.firstChild);
  }

  /* ---------- load fresh settings ---------- */
  function load() {
    return fetch(URL_SB + "/rest/v1/site_reglages?select=cle,valeur", { headers: { apikey: KEY, Authorization: "Bearer " + KEY } })
      .then(function (r) { if (!r.ok) throw new Error(r.status); return r.json(); })
      .then(function (rows) {
        var d = {}; rows.forEach(function (r) { d[r.cle] = r.valeur; });
        data = d; ready = true; try { localStorage.setItem(CACHE, JSON.stringify(d)); } catch (e) {}
        applyContact(); applyTexts(); applyAnnonce(); subs.forEach(function (f) { try { f(data); } catch (e) {} });
        return data;
      }).catch(function () { ready = true; subs.forEach(function (f) { try { f(data); } catch (e) {} }); return data; });
  }

  /* ---------- « mode édition » for the admin ---------- */
  var editing = false;
  function session() {
    try {
      for (var i = 0; i < localStorage.length; i++) { var k = localStorage.key(i);
        if (/^sb-.*-auth-token$/.test(k)) { var s = JSON.parse(localStorage.getItem(k)); return s && (s.access_token ? s : s.currentSession); } }
    } catch (e) {}
    return null;
  }
  function isAdminHere() { try { return localStorage.getItem("yc-admin") === "1"; } catch (e) { return false; } }
  var css = null;
  function mark() {
    document.querySelectorAll("[data-t],[data-edit]").forEach(function (n) { if (leaf(n) && n.textContent.trim() && !n.closest("#ycEdit")) n.classList.add("yc-ed"); });
  }
  function toggleEdit(on) {
    editing = on;
    if (!css) { css = document.createElement("style"); css.textContent = ".yc-edit-on .yc-ed{outline:2px dashed #FF7A2E!important;outline-offset:2px;cursor:text!important}.yc-edit-on .yc-ed:hover{background:rgba(255,122,46,.15)!important}"; document.head.appendChild(css); }
    document.documentElement.classList.toggle("yc-edit-on", on); if (on) mark();
    var b = document.getElementById("ycEditBtn"); if (b) b.textContent = on ? "✓ Terminer" : "✏️";
  }
  function editBtn() {
    if (!isAdminHere() || document.getElementById("ycEditBtn")) return;
    var b = document.createElement("button"); b.id = "ycEditBtn"; b.type = "button"; b.textContent = "✏️"; b.title = "Modifier les textes"; b.setAttribute("aria-label", "Modifier les textes");
    b.style.cssText = "position:fixed;right:0;top:45%;z-index:9997;background:#10232A;color:#fff;border:2px solid #FF7A2E;border-right:0;font:800 14px Archivo,Arial,sans-serif;padding:10px 12px;cursor:pointer;min-height:44px;border-radius:12px 0 0 12px;box-shadow:0 4px 14px rgba(0,0,0,.25)";
    b.addEventListener("click", function () { toggleEdit(!editing); });
    document.body.appendChild(b);
    document.addEventListener("click", function (e) {
      if (!editing) return; var n = e.target.closest && e.target.closest(".yc-ed"); if (!n || e.target.closest("#ycEdit,#ycEditBtn")) return;
      e.preventDefault(); e.stopPropagation(); openEditor(n);
    }, true);
  }
  function openEditor(n) {
    var k = keyOf(n), l = lang(), T = data.textes || {}, cur = (T[k] && T[k][l]) || n.textContent;
    var old = document.getElementById("ycEdit"); if (old) old.remove();
    var w = document.createElement("div"); w.id = "ycEdit";
    w.style.cssText = "position:fixed;inset:0;z-index:9999;background:rgba(16,35,42,.55);display:flex;align-items:flex-end;justify-content:center;padding:12px;font-family:Archivo,Arial,sans-serif";
    var box = document.createElement("div"); box.setAttribute("role", "dialog"); box.setAttribute("aria-modal", "true");
    box.style.cssText = "background:#fff;color:#10232A;width:100%;max-width:560px;padding:18px;display:flex;flex-direction:column;gap:10px;margin-bottom:max(0px,env(safe-area-inset-bottom))";
    var h = document.createElement("b"); h.textContent = "Modifier ce texte (" + l.toUpperCase() + ")"; h.style.fontSize = "18px";
    var info = document.createElement("small"); info.textContent = "Page « " + PAGE + " » · repère " + k.split("|")[1] + ". Laisse vide pour revenir au texte d’origine."; info.style.color = "#4A5A5F";
    var ta = document.createElement("textarea"); ta.value = cur; ta.rows = Math.min(8, Math.max(2, Math.ceil(cur.length / 50))); ta.maxLength = 2000;
    ta.style.cssText = "width:100%;padding:10px;border:2px solid #D5DEE0;font:16px Archivo,Arial,sans-serif;box-sizing:border-box";
    var orig = document.createElement("small"); orig.textContent = "Texte d’origine : " + (n._ycorig || n.textContent); orig.style.color = "#4A5A5F";
    var err = document.createElement("p"); err.style.cssText = "margin:0;color:#B3261E;font-size:14px";
    var row = document.createElement("div"); row.style.cssText = "display:flex;gap:8px;flex-wrap:wrap";
    function btn(t, bg, fg) { var b = document.createElement("button"); b.type = "button"; b.textContent = t; b.style.cssText = "min-height:44px;padding:0 16px;border:2px solid " + bg + ";background:" + bg + ";color:" + fg + ";font:800 15px Archivo,Arial,sans-serif;cursor:pointer"; return b; }
    var save = btn("Enregistrer", "#FF7A2E", "#10232A"), reset = btn("Texte d’origine", "#fff", "#10232A"), cancel = btn("Annuler", "#fff", "#10232A");
    reset.style.borderColor = cancel.style.borderColor = "#D5DEE0";
    function send(txt) {
      var s = session(); if (!s || !s.access_token) { err.textContent = "Connecte-toi d’abord dans l’espace admin (même navigateur), puis reviens ici."; return; }
      save.disabled = reset.disabled = true; err.textContent = "";
      fetch(URL_SB + "/rest/v1/rpc/admin_texte", { method: "POST", headers: { apikey: KEY, Authorization: "Bearer " + s.access_token, "Content-Type": "application/json" },
        body: JSON.stringify({ p_cle: k, p_lang: l, p_texte: txt }) })
        .then(function (r) { return r.ok ? null : r.json().then(function (j) { throw new Error(j.message || r.status); }); })
        .then(function () { w.remove(); return load(); })
        .catch(function (e) { save.disabled = reset.disabled = false; err.textContent = /JWT|expired|401/i.test(e.message) ? "Ta session admin a expiré : ouvre l’espace admin pour la renouveler, puis réessaie." : e.message; });
    }
    save.addEventListener("click", function () { send(ta.value.trim()); });
    reset.addEventListener("click", function () { send(""); });
    cancel.addEventListener("click", function () { w.remove(); });
    w.addEventListener("click", function (e) { if (e.target === w) w.remove(); });
    row.appendChild(save); row.appendChild(reset); row.appendChild(cancel);
    [h, info, ta, orig, err, row].forEach(function (x) { box.appendChild(x); }); w.appendChild(box); document.body.appendChild(w); ta.focus();
  }

  function start() { applyTexts(); applyAnnonce(); observe(); editBtn(); load(); }
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", start); else start();

  window.YSITE = {
    get: function (k) { return data[k]; },
    ready: function (f) { subs.push(f); if (ready) f(data); else if (data.prix) f(data); },
    reload: load
  };
})();
