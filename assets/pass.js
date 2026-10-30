/* Password fields: a button to show or hide what was typed, and a live check that a confirmation
   field matches. Every input[type=password] on the page gets the button; a field with
   data-match="<id of the first field>" gets the check. Language follows the site (localStorage "yc-lang"). */
window.YPass = (function () {
  var lang = "fr";
  try { lang = localStorage.getItem("yc-lang") || ""; } catch (e) {}
  if (!lang) lang = (navigator.language || "fr").slice(0, 2);
  var TX = {
    fr: ["Afficher le mot de passe", "Masquer le mot de passe", "Les deux mots de passe sont identiques.", "Les deux mots de passe ne sont pas identiques."],
    en: ["Show password", "Hide password", "The two passwords match.", "The two passwords do not match."],
    es: ["Mostrar la contraseña", "Ocultar la contraseña", "Las dos contraseñas coinciden.", "Las dos contraseñas no coinciden."],
    nl: ["Wachtwoord tonen", "Wachtwoord verbergen", "De twee wachtwoorden komen overeen.", "De twee wachtwoorden komen niet overeen."]
  }[lang] || null;
  if (!TX) TX = ["Afficher le mot de passe", "Masquer le mot de passe", "Les deux mots de passe sont identiques.", "Les deux mots de passe ne sont pas identiques."];

  var EYE = '<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M1 12s4-7 11-7 11 7 11 7-4 7-11 7S1 12 1 12z"/><circle cx="12" cy="12" r="3"/></svg>';
  var EYE_OFF = '<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M17.9 17.9A10.8 10.8 0 0 1 12 19C5 19 1 12 1 12a19.6 19.6 0 0 1 5.1-5.9M9.9 5.2A10 10 0 0 1 12 5c7 0 11 7 11 7a19.7 19.7 0 0 1-2.2 3.2M14.1 14.1a3 3 0 1 1-4.2-4.2"/><path d="M1 1l22 22"/></svg>';

  function style() {
    if (document.getElementById("yc-pass-css")) return;
    var s = document.createElement("style"); s.id = "yc-pass-css";
    s.textContent = ".pw-wrap{position:relative;display:block;width:100%}" +
      ".pw-wrap input{width:100%;padding-right:52px !important;box-sizing:border-box}" +
      ".pw-eye{position:absolute;right:2px;top:50%;transform:translateY(-50%);width:46px;height:44px;border:0;background:transparent;color:#4B5D63;cursor:pointer;display:flex;align-items:center;justify-content:center;padding:0}" +
      ".pw-eye:hover{color:#10232A}.pw-eye:focus-visible{outline:3px solid #FF7A2E;outline-offset:-3px}" +
      ".pw-match{margin:4px 0 0;font-size:13px;font-weight:700}.pw-match.ok{color:#1E7F4F}.pw-match.bad{color:#B3261E}";
    document.head.appendChild(s);
  }

  function attach(inp) {
    if (!inp || inp.__pw) return;
    style(); inp.__pw = true;
    var wrap = document.createElement("span"); wrap.className = "pw-wrap";
    inp.parentNode.insertBefore(wrap, inp); wrap.appendChild(inp);
    var b = document.createElement("button"); b.type = "button"; b.className = "pw-eye";
    function paint() { var shown = inp.type === "text"; b.innerHTML = shown ? EYE_OFF : EYE; b.setAttribute("aria-label", shown ? TX[1] : TX[0]); b.title = shown ? TX[1] : TX[0]; b.setAttribute("aria-pressed", shown ? "true" : "false"); }
    b.addEventListener("click", function () {
      var pos = inp.selectionStart;
      inp.type = inp.type === "password" ? "text" : "password"; paint();
      inp.focus(); try { if (pos != null) inp.setSelectionRange(pos, pos); } catch (e) {}
    });
    wrap.appendChild(b); paint();
    // the password is hidden again when the form is sent, so browsers offer to save it as usual
    if (inp.form) inp.form.addEventListener("submit", function () { if (inp.type === "text") { inp.type = "password"; paint(); } });
  }

  function match(first, second) {
    if (!first || !second || second.__pwm) return;
    second.__pwm = true;
    var msg = document.createElement("p"); msg.className = "pw-match"; msg.setAttribute("aria-live", "polite");
    var host = second.closest(".pw-wrap") || second; host.parentNode.insertBefore(msg, host.nextSibling);
    function check() {
      if (!second.value) { msg.textContent = ""; msg.className = "pw-match"; return; }
      var ok = first.value === second.value;
      msg.textContent = ok ? "✓ " + TX[2] : TX[3]; msg.className = "pw-match " + (ok ? "ok" : "bad");
      second.setAttribute("aria-invalid", ok ? "false" : "true");
    }
    first.addEventListener("input", check); second.addEventListener("input", check);
    if (second.form) second.form.addEventListener("reset", function () { setTimeout(check, 0); });
  }

  function all(root) {
    root = root || document;
    root.querySelectorAll('input[type="password"]').forEach(attach);
    root.querySelectorAll("input[data-match]").forEach(function (s) { match(document.getElementById(s.getAttribute("data-match")), s); });
  }
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", function () { all(); }); else all();
  return { attach: attach, match: match, all: all };
})();
