/* About page (apropos.html): Yiriclick's story and commitments, in four languages. Text only, no personal photo. */
(function () {
  var Y = window.YC, el = Y.el;
  Y.extend({
    fr: { abTitle: "Qui sommes-nous", abKick: "Qui sommes-nous", abH1a: "Yiriclick relie l’Afrique et l’Europe,", abH1b: "une boutique à la fois.",
      abYiri: "<b>« Yiri »</b> veut dire « chez moi » en mooré. Yiriclick, c’est la maison des petits vendeurs, à un clic du monde.",
      abFromT: "D’où nous venons", abFrom1: "Yiriclick est né entre le Burkina Faso et les Pays-Bas, d’un constat simple.",
      abFrom2: "D’un côté, des vendeurs talentueux, avec de beaux produits, mais un marché trop petit. De l’autre, une diaspora et des clients qui cherchent ces produits sans savoir à qui faire confiance.",
      abDoT: "Ce que nous faisons", abDo: "Nous donnons à chaque petit vendeur une boutique en ligne, simple à créer depuis un téléphone. Elle est visible par des acheteurs sur plusieurs continents, dans leur langue et leur monnaie. La commande passe par WhatsApp, comme les clients en ont l’habitude.",
      abMisT: "Notre mission", abMis: "Que le talent d’un vendeur de Ouagadougou, Bamako ou Abidjan puisse être trouvé à Amsterdam, Paris ou Bruxelles, et que chaque acheteur achète en confiance.",
      abEngT: "Nos engagements",
      abE1t: "0 % de commission", abE1: "Le vendeur garde ce qu’il gagne. Il paie seulement sa formule, à prix fixe.",
      abE2t: "Des vendeurs vérifiés", abE2: "Chaque boutique est contrôlée par notre équipe avant d’apparaître dans la vitrine.",
      abE3t: "4 langues, 3 monnaies", abE3: "Français, anglais, espagnol et néerlandais. Prix en FCFA, en euros ou en dollars.",
      abE4t: "Un vrai suivi", abE4: "Chaque client suit sa commande. En cas de problème, notre équipe intervient.",
      abCtaT: "Rejoins la maison", abCta1: "Ouvrir ma boutique", abCta2: "Découvrir la vitrine",
      abLegal: "Yiriclick est une entreprise enregistrée aux Pays-Bas (KvK{kvk}, Amersfoort), avec ses racines au Burkina Faso." },
    en: { abTitle: "About us", abKick: "About us", abH1a: "Yiriclick connects Africa and Europe,", abH1b: "one shop at a time.",
      abYiri: "<b>“Yiri”</b> means “home” in Mooré. Yiriclick is the home of small sellers, one click from the world.",
      abFromT: "Where we come from", abFrom1: "Yiriclick was born between Burkina Faso and the Netherlands, from a simple observation.",
      abFrom2: "On one side, talented sellers with beautiful products but a market that is too small. On the other, a diaspora and customers looking for these products without knowing whom to trust.",
      abDoT: "What we do", abDo: "We give every small seller an online shop that is easy to create from a phone. It is seen by buyers on several continents, in their own language and currency. Orders go through WhatsApp, as customers are used to.",
      abMisT: "Our mission", abMis: "That the talent of a seller in Ouagadougou, Bamako or Abidjan can be found in Amsterdam, Paris or Brussels, and that every buyer can buy with confidence.",
      abEngT: "Our commitments",
      abE1t: "0% commission", abE1: "Sellers keep what they earn. They only pay their plan, at a fixed price.",
      abE2t: "Verified sellers", abE2: "Every shop is checked by our team before it appears in the showcase.",
      abE3t: "4 languages, 3 currencies", abE3: "French, English, Spanish and Dutch. Prices in CFA francs, euros or dollars.",
      abE4t: "Real follow-up", abE4: "Every customer can track their order. If something goes wrong, our team steps in.",
      abCtaT: "Join the home", abCta1: "Open my shop", abCta2: "Discover the showcase",
      abLegal: "Yiriclick is a company registered in the Netherlands (KvK{kvk}, Amersfoort), with its roots in Burkina Faso." },
    es: { abTitle: "Quiénes somos", abKick: "Quiénes somos", abH1a: "Yiriclick une África y Europa,", abH1b: "una tienda a la vez.",
      abYiri: "<b>«Yiri»</b> significa «mi casa» en mooré. Yiriclick es la casa de los pequeños vendedores, a un clic del mundo.",
      abFromT: "De dónde venimos", abFrom1: "Yiriclick nació entre Burkina Faso y los Países Bajos, de una constatación sencilla.",
      abFrom2: "Por un lado, vendedores con talento y buenos productos, pero un mercado demasiado pequeño. Por otro, una diáspora y clientes que buscan esos productos sin saber en quién confiar.",
      abDoT: "Lo que hacemos", abDo: "Damos a cada pequeño vendedor una tienda en línea, fácil de crear desde un teléfono. La ven compradores de varios continentes, en su idioma y su moneda. El pedido se hace por WhatsApp, como los clientes están acostumbrados.",
      abMisT: "Nuestra misión", abMis: "Que el talento de un vendedor de Uagadugú, Bamako o Abiyán pueda encontrarse en Ámsterdam, París o Bruselas, y que cada comprador compre con confianza.",
      abEngT: "Nuestros compromisos",
      abE1t: "0 % de comisión", abE1: "El vendedor se queda con lo que gana. Solo paga su plan, a precio fijo.",
      abE2t: "Vendedores verificados", abE2: "Nuestro equipo revisa cada tienda antes de que aparezca en el escaparate.",
      abE3t: "4 idiomas, 3 monedas", abE3: "Francés, inglés, español y neerlandés. Precios en francos CFA, euros o dólares.",
      abE4t: "Un seguimiento real", abE4: "Cada cliente sigue su pedido. Si hay un problema, nuestro equipo interviene.",
      abCtaT: "Únete a la casa", abCta1: "Abrir mi tienda", abCta2: "Descubrir el escaparate",
      abLegal: "Yiriclick es una empresa registrada en los Países Bajos (KvK{kvk}, Amersfoort), con sus raíces en Burkina Faso." },
    nl: { abTitle: "Wie zijn wij", abKick: "Wie zijn wij", abH1a: "Yiriclick verbindt Afrika en Europa,", abH1b: "winkel voor winkel.",
      abYiri: "<b>“Yiri”</b> betekent “thuis” in het Mooré. Yiriclick is het thuis van kleine verkopers, op één klik van de wereld.",
      abFromT: "Waar we vandaan komen", abFrom1: "Yiriclick is ontstaan tussen Burkina Faso en Nederland, uit een eenvoudige vaststelling.",
      abFrom2: "Aan de ene kant getalenteerde verkopers met mooie producten, maar een te kleine markt. Aan de andere kant een diaspora en klanten die deze producten zoeken zonder te weten wie ze kunnen vertrouwen.",
      abDoT: "Wat we doen", abDo: "We geven elke kleine verkoper een online winkel die je eenvoudig met je telefoon maakt. Kopers op meerdere continenten zien hem, in hun eigen taal en valuta. Bestellen gaat via WhatsApp, zoals klanten gewend zijn.",
      abMisT: "Onze missie", abMis: "Dat het talent van een verkoper in Ouagadougou, Bamako of Abidjan gevonden wordt in Amsterdam, Parijs of Brussel, en dat elke koper met vertrouwen koopt.",
      abEngT: "Onze beloftes",
      abE1t: "0% commissie", abE1: "De verkoper houdt wat hij verdient. Hij betaalt alleen zijn abonnement, tegen een vaste prijs.",
      abE2t: "Gecontroleerde verkopers", abE2: "Ons team controleert elke winkel voordat die in de etalage verschijnt.",
      abE3t: "4 talen, 3 valuta", abE3: "Frans, Engels, Spaans en Nederlands. Prijzen in CFA-frank, euro of dollar.",
      abE4t: "Echte opvolging", abE4: "Elke klant kan zijn bestelling volgen. Gaat er iets mis, dan grijpt ons team in.",
      abCtaT: "Kom erbij", abCta1: "Open mijn winkel", abCta2: "Ontdek de etalage",
      abLegal: "Yiriclick is een in Nederland geregistreerd bedrijf (KvK{kvk}, Amersfoort), met wortels in Burkina Faso." }
  });
  var t = Y.t, hero = document.getElementById("abHero"), box = document.getElementById("ab");
  var ICONS = [
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="7" cy="7" r="3"/><circle cx="17" cy="17" r="3"/><path d="M19 5L5 19"/></svg>',
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M12 2l8 4v6c0 5-3.5 8.5-8 10-4.5-1.5-8-5-8-10V6z"/><path d="M8.5 12l2.5 2.5 4.5-5"/></svg>',
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="12" cy="12" r="10"/><path d="M2 12h20M12 2a15 15 0 0 1 0 20M12 2a15 15 0 0 0 0 20"/></svg>',
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M21 8l-9-5-9 5 9 5 9-5zM3 8v8l9 5 9-5V8"/><path d="M16 15.5l2 2 3-3.5"/></svg>'];
  function sec(title, paras) { var s = el("section", "ab-sec"), h = el("h2", null, title), d = el("div"); s.appendChild(h); paras.forEach(function (p) { d.appendChild(el("p", null, p)); }); s.appendChild(d); return s; }
  function render() {
    Y.labels(); document.title = t("abTitle") + " · Yiriclick";
    hero.textContent = ""; box.textContent = "";
    hero.appendChild(el("p", "ab-kick", t("abKick")));
    var h1 = el("h1"); h1.appendChild(document.createTextNode(t("abH1a") + " ")); h1.appendChild(el("span", null, t("abH1b"))); hero.appendChild(h1);
    var y = el("p", "ab-yiri"); y.innerHTML = t("abYiri"); hero.appendChild(y); // fixed text from this file only
    box.appendChild(sec(t("abFromT"), [t("abFrom1"), t("abFrom2")]));
    box.appendChild(sec(t("abDoT"), [t("abDo")]));
    var m = el("section", "ab-sec"); m.appendChild(el("h2", null, t("abMisT"))); m.appendChild(el("p", "ab-mission", t("abMis"))); box.appendChild(m);
    var e = el("section"); e.style.cssText = "display:flex;flex-direction:column;gap:14px"; e.appendChild(el("h2", null, t("abEngT"))); e.lastChild.style.cssText = "margin:0;font-size:22px;font-weight:900";
    var g = el("div", "ab-grid");
    [1, 2, 3, 4].forEach(function (i) { var c = el("div", "ab-card"); c.innerHTML = ICONS[i - 1]; c.appendChild(el("h3", null, t("abE" + i + "t"))); c.appendChild(el("p", null, t("abE" + i))); g.appendChild(c); });
    e.appendChild(g); box.appendChild(e);
    var cta = el("section", "ab-cta"); cta.appendChild(el("h2", null, t("abCtaT")));
    var a = el("div", "acts"), b1 = el("a", "btn btn-wa", t("abCta1")), b2 = el("a", "btn btn-navy", t("abCta2")); b1.href = "vendre"; b2.href = "./"; a.appendChild(b1); a.appendChild(b2); cta.appendChild(a); box.appendChild(cta);
    var kvk = window.YLEGAL && window.YLEGAL.kvk ? " " + window.YLEGAL.kvk : "";
    box.appendChild(el("p", "ab-legal", t("abLegal", { kvk: kvk })));
  }
  Y.wirePrefs(render); render();
})();
