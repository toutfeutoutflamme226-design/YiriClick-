/* Anti-robot check (Cloudflare Turnstile) for logins, sign-ups and password resets.
   YCaptcha.get() resolves with a one-time token, or null if the check could not run
   (then the request is sent without a token: it works as long as Supabase does not require one).
   Most visitors see nothing; a small box only appears when Cloudflare needs a click. */
(function () {
  var SITEKEY = "0x4AAAAAAFrszsGvXYG798IG";
  var loading = null, box = null, wid = null, waiting = null;

  function load() {
    if (loading) return loading;
    loading = new Promise(function (resolve) {
      if (window.turnstile) return resolve(true);
      window.__ycTurnstileReady = function () { resolve(true); };
      var s = document.createElement("script");
      s.src = "https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit&onload=__ycTurnstileReady";
      s.async = true; s.defer = true;
      s.onerror = function () { resolve(false); };
      document.head.appendChild(s);
      setTimeout(function () { resolve(!!window.turnstile); }, 15000);
    });
    return loading;
  }
  function done(token) { var w = waiting; waiting = null; if (w) w(token || null); }

  function get() {
    return load().then(function (ok) {
      if (!ok || !window.turnstile) return null;
      return new Promise(function (resolve) {
        waiting = resolve;
        try {
          if (wid === null) {
            box = document.createElement("div");
            box.style.cssText = "position:fixed;left:50%;bottom:16px;transform:translateX(-50%);z-index:9999";
            document.body.appendChild(box);
            wid = window.turnstile.render(box, {
              sitekey: SITEKEY, appearance: "interaction-only", execution: "execute",
              language: (document.documentElement.lang || "fr").slice(0, 2),
              callback: function (t) { done(t); },
              "error-callback": function () { done(null); },
              "expired-callback": function () { done(null); },
              "timeout-callback": function () { done(null); }
            });
          } else {
            window.turnstile.reset(wid);
          }
          window.turnstile.execute(wid);
        } catch (e) { done(null); }
        setTimeout(function () { done(null); }, 30000);
      });
    });
  }
  window.YCaptcha = { get: get, preload: load };
})();
