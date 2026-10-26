/* Browser back / forward inside a page.
   Windows that open over the page (product sheet, cart, menu, forms) and in-page tabs become steps
   in the browser history: Back closes the window or returns to the previous tab, Forward opens it again.
   This also covers the mouse side buttons, Alt + arrow keys and the two-finger swipe.

   A page registers each window with YNav.layer(name, { open(data), close(), update?(data) }):
   open/close/update are called on back/forward and must NOT call YNav themselves; close may return
   false to refuse (unsaved changes), and the step is put back.
   When the visitor opens a window: YNav.opened(name, data, url?, { push: true }?).
   When the visitor closes it (button, Escape, backdrop): if (!YNav.close(name)) hide it directly.
   Tabs: YNav.page(name, onChange) once, then YNav.go(name, url) on each tab change;
   onChange(name) runs on back/forward and may return false to refuse. */
window.YNav = (function () {
  var L = {}, cur = [], page = null, pageFn = null, busy = false, after = null;
  function st() { return history.state && typeof history.state === "object" ? history.state : {}; }
  function want(s) { return (s && s.ycL) || []; }
  function same(a, b) { return a.n === b.n && String(a.d == null ? "" : a.d) === String(b.d == null ? "" : b.d); }
  function write(push, extra, url) {
    var s = Object.assign({}, st(), { ycL: cur.map(function (x) { return { n: x.n, d: x.d, k: x.k }; }) }, extra || {});
    try { history[push ? "pushState" : "replaceState"](s, "", url || location.href); } catch (e) {}
  }
  // after a reload, windows that were open are not open any more
  if (want(st()).length) write(false);

  function layer(name, o) { L[name] = o; }
  function opened(name, data, url, o) {
    var top = cur[cur.length - 1];
    if (top && top.n === name) {
      top.d = data;
      if (o && o.push) { top.k = (top.k || 1) + 1; write(true, null, url); } // a new step inside the same window
      else write(false, null, url); // same window, new content
      return;
    }
    cur.push({ n: name, d: data, k: 1 });
    write(true, null, url);
  }
  function isOpen(name) { return cur.some(function (x) { return x.n === name; }); }
  /* The visitor closes a window: go back in history to before it opened (all its steps).
     then() runs once that is done (history moves are not instant): use it for what comes next,
     for example opening another page section from a menu. */
  function close(name, then) {
    var top = cur[cur.length - 1], w = want(st()), wt = w[w.length - 1];
    if (top && top.n === name && wt && wt.n === name) { after = then || null; history.go(-(top.k || 1)); return true; }
    cur = cur.filter(function (x) { return x.n !== name; });
    return false;
  }
  /* One step back inside a window with steps (form pages); false if there is none in history */
  function back(name) {
    var top = cur[cur.length - 1], w = want(st()), wt = w[w.length - 1];
    if (top && top.n === name && (top.k || 1) > 1 && wt && wt.n === name) { history.back(); return true; }
    return false;
  }

  function setPage(name, fn) { page = name; pageFn = fn; write(false, { ycPage: name }); }
  function go(name, url) {
    if (name === page) return;
    page = name; cur = [];
    try { history.pushState({ ycPage: name, ycL: [] }, "", url || location.href); } catch (e) {}
  }

  window.addEventListener("popstate", function (e) {
    if (busy) return;
    var s = e.state && typeof e.state === "object" ? e.state : {}, w = want(s);
    // windows: close the ones no longer wanted (top first), open the missing ones (Forward)
    var keep = 0; while (keep < cur.length && keep < w.length && same(cur[keep], w[keep])) keep++;
    if (keep === cur.length - 1 && keep === w.length - 1 && cur[keep].n === w[keep].n && L[w[keep].n] && L[w[keep].n].update) {
      if (L[w[keep].n].update(w[keep].d) === false) { restore(); return; }
      cur[keep] = w[keep];
    } else {
      for (var i = cur.length - 1; i >= keep; i--) {
        var o = L[cur[i].n];
        if (o && o.close() === false) { restore(); return; }
        cur.pop();
      }
      for (var j = keep; j < w.length; j++) { var o2 = L[w[j].n]; if (o2 && o2.open(w[j].d) !== false) cur.push(w[j]); else break; }
    }
    // tabs
    if (pageFn && s.ycPage && s.ycPage !== page) {
      var prev = page;
      if (pageFn(s.ycPage) === false) { page = prev; try { history.pushState({ ycPage: prev, ycL: [] }, "", location.href.split("#")[0] + "#" + prev); } catch (x) {} return; }
      page = s.ycPage;
    }
    if (after) { var f = after; after = null; f(); }
  });
  /* A refused step: put the current state back on top of the history */
  function restore() { write(true); }

  return { layer: layer, opened: opened, close: close, back: back, isOpen: isOpen, page: setPage, go: go };
})();
