/* Order tracking for buyers (suivi.html, base v33).
   The buyer types the order number and their phone; works from any device, no account needed.
   They see the status, the items, can write to the seller, and report a problem. The seller answers within 48 h;
   after that (or if the answer is not enough) the buyer can ask Yiriclick to step in. */
(function () {
  var Y = window.YC, el = Y.el, t;
  Y.extend({
    fr: { svT: "Suivre ma commande", svLead: "Retrouve ta commande depuis n’importe quel téléphone : il suffit de son numéro et de ton téléphone.",
      svNum: "Numéro de commande", svNumHint: "Il commence par YC- (par exemple YC-7F3A21). Tu l’as reçu en commandant.", svTel: "Ton téléphone", svTelHint: "Le numéro donné lors de la commande.",
      svFind: "Retrouver ma commande", svFinding: "Recherche…", svReq: "Ce champ est obligatoire.", svNone: "Aucune commande ne correspond. Vérifie le numéro et le téléphone.",
      svErr: "Connexion impossible. Vérifie ton réseau et réessaie.", svOther: "Chercher une autre commande", svOrder: "Commande {n}", svOn: "passée le {d}",
      svS1: "Envoyée", svS2: "Confirmée", svS3: "Expédiée", svS4: "Livrée", svCancel: "Cette commande a été annulée par le vendeur.", svWaitConf: "Le vendeur doit confirmer ta commande. En général, il le fait dans la journée.",
      svTotal: "Total", svWa: "Écrire au vendeur (WhatsApp)", svShop: "Voir la boutique", svReview: "Donner mon avis", svReviewed: "✓ Merci pour ton avis.",
      svPbT: "Un problème avec cette commande ?", svPbLead: "Signale-le : le vendeur est prévenu tout de suite et doit te répondre sous 48 heures. Sans solution, l’équipe Yiriclick t’aide.",
      svPbBtn: "Signaler un problème", svPbMotif: "Quel est le problème ?", svPbMsg: "Explique en quelques mots", svPbMsgHint: "Ce qui s’est passé, et ce que tu attends (un échange, un remboursement, une date de livraison…).",
      svPbSend: "Envoyer au vendeur", svPbCancel: "Annuler",
      m_pas_recu: "Je n’ai pas reçu ma commande", m_retard: "La livraison est en retard", m_abime: "Un article est abîmé", m_different: "L’article ne correspond pas à la description", m_incomplet: "Il manque un article", m_autre: "Autre problème",
      svPbYou: "Ton signalement", svPbSeller: "Réponse du vendeur", svPbWaiting: "Le vendeur a été prévenu. Il doit te répondre sous 48 heures (avant le {d}).",
      svPbEsc: "Demander l’aide de Yiriclick", svPbEscQ: "L’équipe Yiriclick va examiner ta commande et contacter le vendeur. Continuer ?",
      svPbEscDone: "L’équipe Yiriclick s’occupe de ton dossier. Elle te contacte sur ton téléphone, en général sous 2 jours ouvrés.",
      svPbSolved: "Mon problème est réglé", svPbSolvedQ: "Confirmer que ton problème est réglé ?", svPbClosed: "Problème réglé. Merci de ta confiance !", svPbAgain: "Signaler un autre problème",
      svPbStOuverte: "En attente du vendeur", svPbStRepondue: "Le vendeur a répondu", svPbStEscaladee: "Médiation Yiriclick en cours", svPbStResolue: "Réglé",
      svE1: "Commande introuvable : vérifie le numéro et le téléphone.", svE2: "Le vendeur a 24 heures pour confirmer ta commande. Écris-lui sur WhatsApp en attendant.", svE3: "Un signalement est déjà en cours pour cette commande.", svE4: "Le vendeur a 48 heures pour te répondre. Tu pourras ensuite demander l’aide de Yiriclick.", svE5: "Cette commande est annulée.", svTooMany: "Trop d’essais pour ce numéro. Réessaie dans une heure." },
    en: { svT: "Track my order", svLead: "Find your order from any phone: all you need is its number and your phone.",
      svNum: "Order number", svNumHint: "It starts with YC- (for example YC-7F3A21). You received it when ordering.", svTel: "Your phone", svTelHint: "The number given with the order.",
      svFind: "Find my order", svFinding: "Searching…", svReq: "This field is required.", svNone: "No order matches. Check the number and the phone.",
      svErr: "Cannot connect. Check your network and try again.", svOther: "Look up another order", svOrder: "Order {n}", svOn: "placed on {d}",
      svS1: "Sent", svS2: "Confirmed", svS3: "Shipped", svS4: "Delivered", svCancel: "This order was cancelled by the seller.", svWaitConf: "The seller must confirm your order. They usually do so within the day.",
      svTotal: "Total", svWa: "Write to the seller (WhatsApp)", svShop: "See the shop", svReview: "Leave a review", svReviewed: "✓ Thank you for your review.",
      svPbT: "A problem with this order?", svPbLead: "Report it: the seller is told straight away and must answer within 48 hours. If there is no solution, the Yiriclick team helps you.",
      svPbBtn: "Report a problem", svPbMotif: "What is the problem?", svPbMsg: "Explain in a few words", svPbMsgHint: "What happened, and what you expect (an exchange, a refund, a delivery date…).",
      svPbSend: "Send to the seller", svPbCancel: "Cancel",
      m_pas_recu: "I have not received my order", m_retard: "The delivery is late", m_abime: "An item is damaged", m_different: "The item does not match the description", m_incomplet: "An item is missing", m_autre: "Other problem",
      svPbYou: "Your report", svPbSeller: "Seller’s answer", svPbWaiting: "The seller has been told. They must answer within 48 hours (before {d}).",
      svPbEsc: "Ask Yiriclick for help", svPbEscQ: "The Yiriclick team will look into your order and contact the seller. Continue?",
      svPbEscDone: "The Yiriclick team is handling your case. They will contact you by phone, usually within 2 working days.",
      svPbSolved: "My problem is solved", svPbSolvedQ: "Confirm that your problem is solved?", svPbClosed: "Problem solved. Thank you for your trust!", svPbAgain: "Report another problem",
      svPbStOuverte: "Waiting for the seller", svPbStRepondue: "The seller answered", svPbStEscaladee: "Yiriclick mediation in progress", svPbStResolue: "Solved",
      svE1: "Order not found: check the number and the phone.", svE2: "The seller has 24 hours to confirm your order. Write to them on WhatsApp in the meantime.", svE3: "A report is already open for this order.", svE4: "The seller has 48 hours to answer you. After that, you can ask Yiriclick for help.", svE5: "This order is cancelled.", svTooMany: "Too many attempts for this number. Try again in an hour." },
    es: { svT: "Seguir mi pedido", svLead: "Encuentra tu pedido desde cualquier teléfono: solo necesitas su número y tu teléfono.",
      svNum: "Número de pedido", svNumHint: "Empieza por YC- (por ejemplo YC-7F3A21). Lo recibiste al hacer el pedido.", svTel: "Tu teléfono", svTelHint: "El número indicado en el pedido.",
      svFind: "Encontrar mi pedido", svFinding: "Buscando…", svReq: "Este campo es obligatorio.", svNone: "Ningún pedido coincide. Comprueba el número y el teléfono.",
      svErr: "No se puede conectar. Comprueba tu red e inténtalo de nuevo.", svOther: "Buscar otro pedido", svOrder: "Pedido {n}", svOn: "hecho el {d}",
      svS1: "Enviado", svS2: "Confirmado", svS3: "En camino", svS4: "Entregado", svCancel: "El vendedor ha cancelado este pedido.", svWaitConf: "El vendedor debe confirmar tu pedido. Suele hacerlo en el día.",
      svTotal: "Total", svWa: "Escribir al vendedor (WhatsApp)", svShop: "Ver la tienda", svReview: "Dar mi opinión", svReviewed: "✓ Gracias por tu opinión.",
      svPbT: "¿Un problema con este pedido?", svPbLead: "Infórmalo: el vendedor recibe un aviso enseguida y debe responderte en 48 horas. Si no hay solución, el equipo de Yiriclick te ayuda.",
      svPbBtn: "Informar de un problema", svPbMotif: "¿Cuál es el problema?", svPbMsg: "Explícalo en pocas palabras", svPbMsgHint: "Lo que pasó y lo que esperas (un cambio, un reembolso, una fecha de entrega…).",
      svPbSend: "Enviar al vendedor", svPbCancel: "Cancelar",
      m_pas_recu: "No he recibido mi pedido", m_retard: "La entrega se retrasa", m_abime: "Un artículo está dañado", m_different: "El artículo no corresponde a la descripción", m_incomplet: "Falta un artículo", m_autre: "Otro problema",
      svPbYou: "Tu aviso", svPbSeller: "Respuesta del vendedor", svPbWaiting: "El vendedor ha sido avisado. Debe responderte en 48 horas (antes del {d}).",
      svPbEsc: "Pedir ayuda a Yiriclick", svPbEscQ: "El equipo de Yiriclick revisará tu pedido y contactará con el vendedor. ¿Continuar?",
      svPbEscDone: "El equipo de Yiriclick se ocupa de tu caso. Te contactará por teléfono, normalmente en 2 días laborables.",
      svPbSolved: "Mi problema está resuelto", svPbSolvedQ: "¿Confirmas que tu problema está resuelto?", svPbClosed: "Problema resuelto. ¡Gracias por tu confianza!", svPbAgain: "Informar de otro problema",
      svPbStOuverte: "Esperando al vendedor", svPbStRepondue: "El vendedor ha respondido", svPbStEscaladee: "Mediación de Yiriclick en curso", svPbStResolue: "Resuelto",
      svE1: "Pedido no encontrado: comprueba el número y el teléfono.", svE2: "El vendedor tiene 24 horas para confirmar tu pedido. Mientras tanto, escríbele por WhatsApp.", svE3: "Ya hay un aviso abierto para este pedido.", svE4: "El vendedor tiene 48 horas para responderte. Después podrás pedir ayuda a Yiriclick.", svE5: "Este pedido está cancelado.", svTooMany: "Demasiados intentos para este número. Inténtalo dentro de una hora." },
    nl: { svT: "Mijn bestelling volgen", svLead: "Vind je bestelling terug vanaf elke telefoon: je hebt alleen het nummer en je telefoonnummer nodig.",
      svNum: "Bestelnummer", svNumHint: "Het begint met YC- (bijvoorbeeld YC-7F3A21). Je kreeg het bij het bestellen.", svTel: "Je telefoonnummer", svTelHint: "Het nummer dat je bij de bestelling opgaf.",
      svFind: "Mijn bestelling zoeken", svFinding: "Zoeken…", svReq: "Dit veld is verplicht.", svNone: "Geen bestelling gevonden. Controleer het nummer en de telefoon.",
      svErr: "Geen verbinding. Controleer je netwerk en probeer het opnieuw.", svOther: "Een andere bestelling zoeken", svOrder: "Bestelling {n}", svOn: "geplaatst op {d}",
      svS1: "Verstuurd", svS2: "Bevestigd", svS3: "Onderweg", svS4: "Geleverd", svCancel: "Deze bestelling is door de verkoper geannuleerd.", svWaitConf: "De verkoper moet je bestelling bevestigen. Meestal gebeurt dat dezelfde dag.",
      svTotal: "Totaal", svWa: "De verkoper schrijven (WhatsApp)", svShop: "Bekijk de winkel", svReview: "Mijn mening geven", svReviewed: "✓ Bedankt voor je beoordeling.",
      svPbT: "Een probleem met deze bestelling?", svPbLead: "Meld het: de verkoper krijgt meteen bericht en moet binnen 48 uur antwoorden. Zonder oplossing helpt het Yiriclick-team je.",
      svPbBtn: "Een probleem melden", svPbMotif: "Wat is het probleem?", svPbMsg: "Leg het in een paar woorden uit", svPbMsgHint: "Wat er gebeurde en wat je verwacht (een ruil, een terugbetaling, een leverdatum…).",
      svPbSend: "Naar de verkoper sturen", svPbCancel: "Annuleren",
      m_pas_recu: "Ik heb mijn bestelling niet ontvangen", m_retard: "De levering is te laat", m_abime: "Een artikel is beschadigd", m_different: "Het artikel komt niet overeen met de beschrijving", m_incomplet: "Er ontbreekt een artikel", m_autre: "Ander probleem",
      svPbYou: "Je melding", svPbSeller: "Antwoord van de verkoper", svPbWaiting: "De verkoper is op de hoogte. Hij moet binnen 48 uur antwoorden (vóór {d}).",
      svPbEsc: "Yiriclick om hulp vragen", svPbEscQ: "Het Yiriclick-team bekijkt je bestelling en neemt contact op met de verkoper. Doorgaan?",
      svPbEscDone: "Het Yiriclick-team behandelt je zaak. Ze nemen telefonisch contact met je op, meestal binnen 2 werkdagen.",
      svPbSolved: "Mijn probleem is opgelost", svPbSolvedQ: "Bevestigen dat je probleem is opgelost?", svPbClosed: "Probleem opgelost. Bedankt voor je vertrouwen!", svPbAgain: "Nog een probleem melden",
      svPbStOuverte: "Wacht op de verkoper", svPbStRepondue: "De verkoper heeft geantwoord", svPbStEscaladee: "Bemiddeling door Yiriclick bezig", svPbStResolue: "Opgelost",
      svE1: "Bestelling niet gevonden: controleer het nummer en de telefoon.", svE2: "De verkoper heeft 24 uur om je bestelling te bevestigen. Schrijf hem intussen via WhatsApp.", svE3: "Er loopt al een melding voor deze bestelling.", svE4: "De verkoper heeft 48 uur om je te antwoorden. Daarna kun je Yiriclick om hulp vragen.", svE5: "Deze bestelling is geannuleerd.", svTooMany: "Te veel pogingen voor dit nummer. Probeer het over een uur opnieuw." }
  });
  t = Y.t;
  var box = document.getElementById("sv"), QS = new URLSearchParams(location.search);
  var S = { num: QS.get("n") || "", tel: "", o: null, form: false, err: "" };
  try { var b = JSON.parse(localStorage.getItem("yc-buyer") || "{}"); S.tel = b.cPhone || ""; } catch (e) {}
  try { var k = JSON.parse(sessionStorage.getItem("yc-suivi") || "null"); if (k && (!S.num || k.num === S.num)) { S.num = k.num; S.tel = k.tel; S.auto = true; } } catch (e) {}
  var MOTIFS = ["pas_recu", "retard", "abime", "different", "incomplet", "autre"];
  function locale() { return { fr: "fr-FR", en: "en-GB", es: "es-ES", nl: "nl-NL" }[Y.prefs.lang] || "fr-FR"; }
  function dt(d, time) { return new Date(d).toLocaleDateString(locale(), time ? { day: "numeric", month: "long", hour: "2-digit", minute: "2-digit" } : { day: "numeric", month: "long", year: "numeric" }); }
  function errTxt(e) { var m = (e && e.message) || ""; if (/Failed to fetch|NetworkError/i.test(m)) return t("svErr"); if (/Trop d’essais/.test(m)) return t("svTooMany");
    var F = ["Commande introuvable", "24 heures", "déjà en cours", "48 heures", "est annulée"]; for (var i = 0; i < F.length; i++) if (m.indexOf(F[i]) >= 0) return t("svE" + (i + 1));
    return m || t("svErr"); }
  function field(id, label, input, hint) {
    var f = el("div", "sv-f"), l = el("label", null, label); l.setAttribute("for", id); f.appendChild(l); input.id = id; f.appendChild(input);
    if (hint) f.appendChild(el("span", "sv-hint", hint)); var e = el("p", "sv-err"); e.id = id + "-err"; f.appendChild(e); return f;
  }
  async function find(btn) {
    if (btn) { btn.disabled = true; btn.textContent = t("svFinding"); }
    var r = await Y.sb.rpc("retrouver_commande", { p_numero: S.num, p_tel: S.tel });
    if (btn) { btn.disabled = false; btn.textContent = t("svFind"); }
    if (r.error) { S.err = errTxt(r.error); S.o = null; }
    else if (!r.data) { S.err = t("svNone"); S.o = null; }
    else { S.err = ""; S.o = r.data; try { sessionStorage.setItem("yc-suivi", JSON.stringify({ num: S.num, tel: S.tel })); } catch (e) {} }
    render();
  }
  function render() {
    Y.labels(); document.title = t("svT") + " · Yiriclick"; box.textContent = "";
    box.appendChild(el("h1", null, t("svT")));
    if (!S.o) return renderForm();
    renderOrder();
  }
  function renderForm() {
    box.appendChild(el("p", "sv-lead", t("svLead")));
    var f = el("form", "sv-card"); f.noValidate = true;
    var n = el("input"); n.maxLength = 30; n.autocapitalize = "characters"; n.autocomplete = "off"; n.placeholder = "YC-7F3A21"; n.value = S.num;
    var p = el("input"); p.type = "tel"; p.maxLength = 25; p.autocomplete = "tel"; p.inputMode = "tel"; p.value = S.tel;
    f.appendChild(field("svNum", t("svNum"), n, t("svNumHint"))); f.appendChild(field("svTel", t("svTel"), p, t("svTelHint")));
    var er = el("p", "sv-err", S.err); er.setAttribute("role", "alert"); f.appendChild(er);
    var go = el("button", "btn btn-wa", t("svFind")); go.type = "submit"; f.appendChild(go);
    f.addEventListener("submit", function (e) {
      e.preventDefault(); var ok = true;
      [[n, n.value.trim()], [p, p.value.replace(/\D/g, "").length >= 8 ? p.value : ""]].forEach(function (x) { var m = x[1] ? "" : t("svReq"); document.getElementById(x[0].id + "-err").textContent = m; if (m) { x[0].setAttribute("aria-invalid", "true"); ok = false; } else x[0].removeAttribute("aria-invalid"); });
      if (!ok) return; S.num = n.value.trim(); S.tel = p.value.trim(); find(go);
    });
    box.appendChild(f);
  }
  function renderOrder() {
    var o = S.o, c = el("div", "sv-card"), top = el("div", "sv-top"), sh = el("a", null, o.boutique.nom);
    sh.href = "boutique?b=" + encodeURIComponent(o.boutique.slug); top.appendChild(sh);
    top.appendChild(el("span", "ostat ostat-" + o.statut, t("st_" + o.statut))); c.appendChild(top);
    c.appendChild(el("p", "sv-hint", t("svOrder", { n: o.numero }) + " · " + t("svOn", { d: dt(o.created_at) })));
    if (o.statut === "annulee") c.appendChild(el("p", "sv-err", t("svCancel")));
    else {
      var steps = el("div", "steps"), lvl = { nouvelle: 0, confirmee: 1, expediee: 2, livree: 3 }[o.statut];
      ["svS1", "svS2", "svS3", "svS4"].forEach(function (k, i) { var d = el("div", i <= lvl ? "on" : ""); d.appendChild(el("i")); d.appendChild(el("span", null, t(k))); steps.appendChild(d); });
      c.appendChild(steps);
      if (o.statut === "nouvelle") c.appendChild(el("p", "sv-hint", t("svWaitConf")));
    }
    var lines = el("div", "lines");
    (o.articles || []).forEach(function (a) { var d = el("div"); d.appendChild(el("span", null, a.qty + " × " + a.nom + (a.v && a.v.length ? " (" + a.v.join(" / ") + ")" : ""))); d.appendChild(el("span", null, Y.money(Number(a.prix) * Number(a.qty), a.devise || o.devise))); lines.appendChild(d); });
    if (o.total != null) { var tt = el("div", "tot"); tt.appendChild(el("span", null, t("svTotal"))); tt.appendChild(el("span", null, Y.money(o.total, o.devise))); lines.appendChild(tt); }
    c.appendChild(lines);
    var acts = el("div", "acts"), wa = String(o.boutique.whatsapp || "").replace(/\D/g, "");
    if (wa) { var w = el("a", "btn btn-wa", t("svWa")); w.href = "https://wa.me/" + wa + "?text=" + encodeURIComponent(t("svOrder", { n: o.numero }) + " – "); w.target = "_blank"; w.rel = "noopener"; acts.appendChild(w); }
    if (o.statut === "livree" && !o.a_avis) { var rv = el("a", "btn btn-navy", t("svReview")); rv.href = "noter?c=" + encodeURIComponent(o.id); acts.appendChild(rv); }
    c.appendChild(acts);
    if (o.a_avis) c.appendChild(el("p", "sv-hint", t("svReviewed")));
    box.appendChild(c);
    renderProblem();
    var other = el("button", "btn btn-ghost", t("svOther")); other.type = "button"; other.style.alignSelf = "flex-start";
    other.addEventListener("click", function () { S.o = null; S.num = ""; S.form = false; try { sessionStorage.removeItem("yc-suivi"); } catch (e) {} render(); });
    box.appendChild(other);
  }
  async function act(fn, args, btn) {
    btn.disabled = true; var r = await Y.sb.rpc(fn, args); btn.disabled = false;
    if (r.error) { var e = box.querySelector("#pbErr"); if (e) e.textContent = errTxt(r.error); return; }
    S.o = r.data; S.form = false; render();
  }
  function renderProblem() {
    var o = S.o, pb = o.probleme, c = el("div", "sv-card pb" + (pb && pb.statut === "resolue" ? " ok" : pb && pb.statut === "escaladee" ? " med" : ""));
    var er = el("p", "sv-err"); er.id = "pbErr"; er.setAttribute("role", "alert");
    if (!pb || (pb.statut === "resolue" && S.form)) {
      if (o.statut === "annulee") return;
      c.appendChild(el("h2", null, t("svPbT")));
      if (!S.form) {
        c.appendChild(el("p", "sv-hint", t("svPbLead")));
        var open = el("button", "btn btn-navy", t("svPbBtn")); open.type = "button"; open.style.alignSelf = "flex-start";
        open.addEventListener("click", function () { S.form = true; render(); setTimeout(function () { var m = document.getElementById("pbMotif"); if (m) m.focus(); }, 30); });
        c.appendChild(open); box.appendChild(c); return;
      }
      var sel = el("select"); MOTIFS.forEach(function (m) { var op = el("option", null, t("m_" + m)); op.value = m; sel.appendChild(op); });
      if (o.statut === "livree") sel.value = "abime";
      var msg = el("textarea"); msg.maxLength = 1500;
      c.appendChild(field("pbMotif", t("svPbMotif"), sel)); c.appendChild(field("pbMsg", t("svPbMsg"), msg, t("svPbMsgHint")));
      c.appendChild(er);
      var a = el("div", "acts"), send = el("button", "btn btn-wa", t("svPbSend")), cancel = el("button", "btn btn-ghost", t("svPbCancel")); send.type = cancel.type = "button";
      send.addEventListener("click", function () { if (msg.value.trim().length < 5) { document.getElementById("pbMsg-err").textContent = t("svReq"); msg.focus(); return; }
        act("signaler_probleme", { p_numero: S.num, p_tel: S.tel, p_motif: sel.value, p_message: msg.value.trim(), p_langue: Y.dbLang(Y.prefs.lang) }, send); });
      cancel.addEventListener("click", function () { S.form = false; render(); });
      a.appendChild(send); a.appendChild(cancel); c.appendChild(a); box.appendChild(c); return;
    }
    var st = { ouverte: "svPbStOuverte", repondue: "svPbStRepondue", escaladee: "svPbStEscaladee", resolue: "svPbStResolue" }[pb.statut];
    var h = el("div", "sv-top"); h.appendChild(el("h2", null, t("m_" + pb.motif))); h.appendChild(el("span", "ostat ostat-" + (pb.statut === "resolue" ? "livree" : pb.statut === "escaladee" ? "nouvelle" : "confirmee"), t(st))); c.appendChild(h);
    c.appendChild(el("b", null, t("svPbYou") + " · " + dt(pb.created_at, true))); c.appendChild(el("p", "quote", pb.message));
    if (pb.reponse) { c.appendChild(el("b", null, t("svPbSeller") + (pb.repondu_le ? " · " + dt(pb.repondu_le, true) : ""))); c.appendChild(el("p", "quote", pb.reponse)); }
    if (pb.statut === "ouverte") c.appendChild(el("p", "sv-hint", t("svPbWaiting", { d: dt(new Date(new Date(pb.created_at).getTime() + 48 * 3600e3), true) })));
    if (pb.statut === "escaladee") c.appendChild(el("p", null, t("svPbEscDone")));
    if (pb.statut === "resolue") c.appendChild(el("p", null, t("svPbClosed")));
    c.appendChild(er);
    var a2 = el("div", "acts");
    if (pb.statut !== "resolue") {
      var ok = el("button", "btn btn-wa", t("svPbSolved")); ok.type = "button";
      ok.addEventListener("click", function () { if (window.confirm(t("svPbSolvedQ"))) act("reclamation_client", { p_numero: S.num, p_tel: S.tel, p_action: "resolue" }, ok); }); a2.appendChild(ok);
      if (pb.peut_escalader) { var esc = el("button", "btn btn-navy", t("svPbEsc")); esc.type = "button";
        esc.addEventListener("click", function () { if (window.confirm(t("svPbEscQ"))) act("reclamation_client", { p_numero: S.num, p_tel: S.tel, p_action: "escalader" }, esc); }); a2.appendChild(esc); }
    } else if (o.statut !== "annulee") {
      var again = el("button", "btn btn-ghost", t("svPbAgain")); again.type = "button"; again.addEventListener("click", function () { S.form = true; render(); }); a2.appendChild(again);
    }
    if (a2.children.length) c.appendChild(a2);
    box.appendChild(c);
  }
  Y.wirePrefs(render);
  if (S.num && S.tel && S.auto) find(); else render();
})();
