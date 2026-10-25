/* Phone field with the country dialling code, so customers and sellers can be reached from any country.
   YPhone.attach(input, { country, label, onChange }) adds a country selector in front of the input.
   YPhone.value(input) returns the number in international format, e.g. +31640535171. */
window.YPhone = (function () {
  /* [country, dialling code] – West and Central Africa first, then the rest of the world */
  var C = [["BF", "226"], ["CI", "225"], ["SN", "221"], ["ML", "223"], ["TG", "228"], ["BJ", "229"], ["NE", "227"], ["GN", "224"], ["CM", "237"], ["GA", "241"],
    ["CG", "242"], ["CD", "243"], ["TD", "235"], ["CF", "236"], ["MR", "222"], ["GH", "233"], ["NG", "234"], ["GM", "220"], ["GW", "245"], ["SL", "232"], ["LR", "231"],
    ["CV", "238"], ["MA", "212"], ["DZ", "213"], ["TN", "216"], ["EG", "20"], ["KE", "254"], ["RW", "250"], ["BI", "257"], ["MG", "261"], ["DJ", "253"], ["KM", "269"],
    ["ET", "251"], ["ZA", "27"], ["FR", "33"], ["BE", "32"], ["NL", "31"], ["DE", "49"], ["LU", "352"], ["CH", "41"], ["ES", "34"], ["IT", "39"], ["PT", "351"],
    ["GB", "44"], ["IE", "353"], ["AT", "43"], ["DK", "45"], ["SE", "46"], ["NO", "47"], ["FI", "358"], ["PL", "48"], ["GR", "30"], ["TR", "90"], ["US", "1"],
    ["CA", "1"], ["HT", "509"], ["BR", "55"], ["MX", "52"], ["AR", "54"], ["CO", "57"], ["CN", "86"], ["IN", "91"], ["JP", "81"], ["AE", "971"], ["SA", "966"],
    ["LB", "961"], ["QA", "974"], ["MY", "60"], ["AU", "61"]];
  /* Countries whose national numbers keep their leading 0 after the dialling code */
  var KEEP0 = { "225": 1, "229": 1, "39": 1 };
  function dialOf(c) { for (var i = 0; i < C.length; i++) if (C[i][0] === c) return C[i][1]; return null; }
  function flag(c) { return String.fromCodePoint.apply(null, c.split("").map(function (ch) { return 127397 + ch.charCodeAt(0); })); }
  function lang() { var l = ""; try { l = localStorage.getItem("yc-lang") || ""; } catch (e) {} return l || document.documentElement.lang || "fr"; }
  function cname(c) { try { return new Intl.DisplayNames([lang()], { type: "region" }).of(c); } catch (e) { return c; } }
  function defCountry() {
    try { var c = localStorage.getItem("yc-country"); if (c && dialOf(c)) return c; } catch (e) {}
    var r = (navigator.language || "").split("-")[1]; if (r && dialOf(r.toUpperCase())) return r.toUpperCase();
    return "BF";
  }
  /* "+31 6 40…" or "0031 6 40…" -> { c: "NL", n: "640…" }; anything else -> null */
  function parse(v) {
    var d = String(v || "").trim().replace(/[^\d+]/g, "");
    if (d.indexOf("00") === 0) d = "+" + d.slice(2);
    if (d.charAt(0) !== "+") return null;
    d = d.slice(1); var best = null;
    C.forEach(function (x) { if (d.indexOf(x[1]) === 0 && (!best || x[1].length > best[1].length)) best = x; });
    return best ? { c: best[0], n: d.slice(best[1].length) } : null;
  }
  function build(dial, nat) {
    var n = String(nat || "").replace(/\D/g, ""); if (!n) return "";
    if (n.charAt(0) === "0" && !KEEP0[dial]) n = n.slice(1);
    return "+" + dial + n;
  }
  function international(v) { return /^\s*(\+|00)/.test(String(v || "")); }
  /* Guess the country from an address ("…Amersfoort, Pays-Bas") */
  function guess(text) {
    var t = String(text || "").normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase(), hit = null;
    C.forEach(function (x) { ["fr", "en", "es", "nl"].forEach(function (l) { try { var n = new Intl.DisplayNames([l], { type: "region" }).of(x[0]).normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase(); if (n.length > 3 && t.indexOf(n) >= 0) hit = hit || x[0]; } catch (e) {} }); });
    return hit;
  }
  function options(sel) {
    C.slice().sort(function (a, b) { return cname(a[0]).localeCompare(cname(b[0]), lang()); }).forEach(function (x) {
      var o = document.createElement("option"); o.value = x[0]; o.textContent = flag(x[0]) + " +" + x[1] + "  " + cname(x[0]); sel.appendChild(o);
    });
  }
  var styled = false;
  function style() {
    if (styled) return; styled = true;
    var s = document.createElement("style");
    s.textContent = ".yp-row{display:flex;gap:6px;min-width:0;width:100%}.yp-row>input{flex:1 1 auto;min-width:0}" +
      ".yp-cc{flex:0 0 112px;width:112px;min-width:0;min-height:48px;border:2px solid #D5DEE0;background:#fff;color:#10232A;font:inherit;font-size:16px;padding:0 4px;text-overflow:ellipsis}" +
      ".yp-cc:focus{border-color:#0E6E78;outline:none}";
    document.head.appendChild(s);
  }
  function attach(input, o) {
    o = o || {}; if (!input) return null; if (input.__yp) return input.__yp;
    style();
    var row = document.createElement("div"); row.className = "yp-row";
    var sel = document.createElement("select"); sel.className = "yp-cc"; sel.setAttribute("aria-label", o.label || "Indicatif du pays");
    options(sel);
    input.parentNode.insertBefore(row, input); row.appendChild(sel); row.appendChild(input);
    input.setAttribute("inputmode", "tel"); input.setAttribute("autocomplete", "tel-national");
    var api = {
      select: sel,
      value: function () { var raw = input.value.trim(); if (!raw) return ""; var p = parse(raw); return p ? "+" + dialOf(p.c) + p.n.replace(/\D/g, "") : build(dialOf(sel.value), raw); },
      set: function (v) { var p = parse(v); if (p) { sel.value = p.c; input.value = p.n; } else input.value = v || ""; },
      valid: function () { var v = api.value(), p = parse(v); return !!p && p.n.length >= 6 && p.n.length <= 13; }
    };
    sel.value = o.country && dialOf(o.country) ? o.country : defCountry();
    api.set(input.value);
    function changed() { var p = parse(input.value); if (p) { sel.value = p.c; } if (o.onChange) o.onChange(api.value()); }
    input.addEventListener("input", changed); sel.addEventListener("change", changed);
    input.__yp = api; return api;
  }
  return {
    attach: attach, list: C, flag: flag, cname: cname, parse: parse, build: build, dialOf: dialOf, defCountry: defCountry, guess: guess, international: international, options: options,
    value: function (i) { return i && i.__yp ? i.__yp.value() : (i ? i.value.trim() : ""); },
    set: function (i, v) { if (!i) return; if (i.__yp) i.__yp.set(v); else i.value = v || ""; },
    valid: function (i) { return i && i.__yp ? i.__yp.valid() : false; }
  };
})();
