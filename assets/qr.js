/* Small QR code generator (byte mode, error correction level M, versions 1 to 10).
   Enough for a shop link of up to about 210 characters. No outside service is called.
   Usage: var q = YQR.make("https://..."); q.size; q.dark(x, y); YQR.svg(text, color); YQR.canvas(text, px, color) */
window.YQR = (function () {
  /* For each version, level M: error correction codewords per block, then [blocks, data codewords] groups */
  var EC = [null, [10, [1, 16]], [16, [1, 28]], [26, [1, 44]], [18, [2, 32]], [24, [2, 43]], [16, [4, 27]], [18, [4, 31]],
    [22, [2, 38], [2, 39]], [22, [3, 36], [2, 37]], [26, [4, 43], [1, 44]]];
  var ALIGN = [null, [], [6, 18], [6, 22], [6, 26], [6, 30], [6, 34], [6, 22, 38], [6, 24, 42], [6, 26, 46], [6, 28, 50]];

  function gmul(x, y) { var z = 0; for (var i = 7; i >= 0; i--) { z = (z << 1) ^ ((z >>> 7) * 0x11D); z ^= ((y >>> i) & 1) * x; } return z & 255; }
  function rsDivisor(deg) {
    var r = []; for (var i = 0; i < deg; i++) r.push(0); r[deg - 1] = 1; var root = 1;
    for (i = 0; i < deg; i++) { for (var j = 0; j < r.length; j++) { r[j] = gmul(r[j], root); if (j + 1 < r.length) r[j] ^= r[j + 1]; } root = gmul(root, 2); }
    return r;
  }
  function rsRemainder(data, div) {
    var r = div.map(function () { return 0; });
    data.forEach(function (b) { var f = b ^ r.shift(); r.push(0); div.forEach(function (c, i) { r[i] ^= gmul(c, f); }); });
    return r;
  }
  function utf8(s) { var u = unescape(encodeURIComponent(s)), a = []; for (var i = 0; i < u.length; i++) a.push(u.charCodeAt(i)); return a; }

  function make(text) {
    var bytes = utf8(text), ver = 0, cap = 0;
    for (var v = 1; v <= 10; v++) {
      var e = EC[v]; cap = e.slice(1).reduce(function (s, g) { return s + g[0] * g[1]; }, 0);
      if (4 + (v < 10 ? 8 : 16) + bytes.length * 8 <= cap * 8) { ver = v; break; }
    }
    if (!ver) throw new Error("Texte trop long pour le QR code.");
    var ec = EC[ver], size = ver * 4 + 17;

    /* Data bits */
    var bits = [];
    function put(val, len) { for (var i = len - 1; i >= 0; i--) bits.push((val >>> i) & 1); }
    put(4, 4); put(bytes.length, ver < 10 ? 8 : 16); bytes.forEach(function (b) { put(b, 8); });
    put(0, Math.min(4, cap * 8 - bits.length));
    while (bits.length % 8) bits.push(0);
    var data = []; for (var i = 0; i < bits.length; i += 8) { var b = 0; for (var k = 0; k < 8; k++) b = (b << 1) | bits[i + k]; data.push(b); }
    for (var pad = 0xEC; data.length < cap; pad ^= 0xEC ^ 0x11) data.push(pad);

    /* Blocks with error correction, then interleaved */
    var blocks = [], pos = 0, div = rsDivisor(ec[0]);
    ec.slice(1).forEach(function (g) { for (var n = 0; n < g[0]; n++) { var d = data.slice(pos, pos + g[1]); pos += g[1]; blocks.push({ d: d, e: rsRemainder(d, div) }); } });
    var maxD = Math.max.apply(null, blocks.map(function (x) { return x.d.length; })), out = [];
    for (i = 0; i < maxD; i++) blocks.forEach(function (x) { if (i < x.d.length) out.push(x.d[i]); });
    for (i = 0; i < ec[0]; i++) blocks.forEach(function (x) { out.push(x.e[i]); });

    /* Matrix */
    var M = [], F = [];
    for (var y = 0; y < size; y++) { M.push([]); F.push([]); for (var x = 0; x < size; x++) { M[y].push(false); F[y].push(false); } }
    function fn(x, y, d) { M[y][x] = d; F[y][x] = true; }
    for (i = 0; i < size; i++) { fn(6, i, i % 2 === 0); fn(i, 6, i % 2 === 0); }
    [[3, 3], [size - 4, 3], [3, size - 4]].forEach(function (c) {
      for (var dy = -4; dy <= 4; dy++) for (var dx = -4; dx <= 4; dx++) {
        var xx = c[0] + dx, yy = c[1] + dy, dist = Math.max(Math.abs(dx), Math.abs(dy));
        if (xx >= 0 && xx < size && yy >= 0 && yy < size) fn(xx, yy, dist !== 2 && dist !== 4);
      }
    });
    var al = ALIGN[ver], na = al.length;
    for (i = 0; i < na; i++) for (var j = 0; j < na; j++) {
      if ((i === 0 && j === 0) || (i === 0 && j === na - 1) || (i === na - 1 && j === 0)) continue;
      for (var dy2 = -2; dy2 <= 2; dy2++) for (var dx2 = -2; dx2 <= 2; dx2++) fn(al[i] + dx2, al[j] + dy2, Math.max(Math.abs(dx2), Math.abs(dy2)) !== 1);
    }
    function format(mask) {
      var d = (0 << 3) | mask, r = d; /* level M = 00 */
      for (var i = 0; i < 10; i++) r = (r << 1) ^ ((r >>> 9) * 0x537);
      var b = ((d << 10) | r) ^ 0x5412;
      function g(i) { return ((b >>> i) & 1) !== 0; }
      for (i = 0; i <= 5; i++) fn(8, i, g(i));
      fn(8, 7, g(6)); fn(8, 8, g(7)); fn(7, 8, g(8));
      for (i = 9; i < 15; i++) fn(14 - i, 8, g(i));
      for (i = 0; i < 8; i++) fn(size - 1 - i, 8, g(i));
      for (i = 8; i < 15; i++) fn(8, size - 15 + i, g(i));
      fn(8, size - 8, true);
    }
    format(0);
    if (ver >= 7) {
      var r = ver; for (i = 0; i < 12; i++) r = (r << 1) ^ ((r >>> 11) * 0x1F25);
      var vb = (ver << 12) | r;
      for (i = 0; i < 18; i++) { var bit = ((vb >>> i) & 1) !== 0, a = size - 11 + i % 3, c = Math.floor(i / 3); fn(a, c, bit); fn(c, a, bit); }
    }
    /* Codewords in the zigzag order */
    var bi = 0;
    for (var right = size - 1; right >= 1; right -= 2) {
      if (right === 6) right = 5;
      for (var vert = 0; vert < size; vert++) for (var jj = 0; jj < 2; jj++) {
        var xx2 = right - jj, up = ((right + 1) & 2) === 0, yy2 = up ? size - 1 - vert : vert;
        if (!F[yy2][xx2] && bi < out.length * 8) { M[yy2][xx2] = ((out[bi >>> 3] >>> (7 - (bi & 7))) & 1) !== 0; bi++; }
      }
    }
    function maskOn(m, x, y) {
      switch (m) {
        case 0: return (x + y) % 2 === 0; case 1: return y % 2 === 0; case 2: return x % 3 === 0; case 3: return (x + y) % 3 === 0;
        case 4: return (Math.floor(x / 3) + Math.floor(y / 2)) % 2 === 0; case 5: return x * y % 2 + x * y % 3 === 0;
        case 6: return (x * y % 2 + x * y % 3) % 2 === 0; default: return ((x + y) % 2 + x * y % 3) % 2 === 0;
      }
    }
    function apply(m) { for (var y = 0; y < size; y++) for (var x = 0; x < size; x++) if (!F[y][x] && maskOn(m, x, y)) M[y][x] = !M[y][x]; }
    function penalty() {
      var p = 0, dark = 0, x, y;
      for (y = 0; y < size; y++) {
        var run = 1, runC = 1;
        for (x = 0; x < size; x++) {
          if (M[y][x]) dark++;
          if (x > 0) { if (M[y][x] === M[y][x - 1]) { run++; if (run === 5) p += 3; else if (run > 5) p++; } else run = 1; }
          if (x > 0) { if (M[x][y] === M[x - 1][y]) { runC++; if (runC === 5) p += 3; else if (runC > 5) p++; } else runC = 1; }
          if (x > 0 && y > 0 && M[y][x] === M[y - 1][x] && M[y][x] === M[y][x - 1] && M[y][x] === M[y - 1][x - 1]) p += 3;
        }
      }
      var k = Math.ceil(Math.abs(dark * 20 - size * size * 10) / (size * size)) - 1;
      return p + Math.max(0, k) * 10;
    }
    var best = 0, bestP = Infinity;
    for (var m = 0; m < 8; m++) { apply(m); format(m); var pp = penalty(); if (pp < bestP) { bestP = pp; best = m; } apply(m); }
    apply(best); format(best);
    return { size: size, dark: function (x, y) { return M[y][x]; } };
  }

  /* SVG with a 4-module quiet zone */
  function svg(text, color) {
    var q = make(text), n = q.size + 8, d = "";
    for (var y = 0; y < q.size; y++) for (var x = 0; x < q.size; x++) if (q.dark(x, y)) d += "M" + (x + 4) + " " + (y + 4) + "h1v1h-1z";
    return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ' + n + " " + n + '" shape-rendering="crispEdges"><rect width="' + n + '" height="' + n + '" fill="#fff"/><path d="' + d + '" fill="' + (color || "#000") + '"/></svg>';
  }
  function canvas(text, px, color) {
    var q = make(text), n = q.size + 8, s = Math.max(1, Math.floor(px / n)), c = document.createElement("canvas");
    c.width = c.height = n * s; var g = c.getContext("2d");
    g.fillStyle = "#fff"; g.fillRect(0, 0, c.width, c.height); g.fillStyle = color || "#000";
    for (var y = 0; y < q.size; y++) for (var x = 0; x < q.size; x++) if (q.dark(x, y)) g.fillRect((x + 4) * s, (y + 4) * s, s, s);
    return c;
  }
  return { make: make, svg: svg, canvas: canvas };
})();
