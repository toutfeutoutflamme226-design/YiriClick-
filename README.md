# Yiriclick – site vitrine

La place de marché mondiale des petits vendeurs.
Site en français, anglais et espagnol, avec tarifs par région (FCFA, €, $).

## Contenu du dossier

```
yiriclick-site/
├── index.html      Le site complet (HTML, CSS et JavaScript dans un seul fichier)
├── logos/          Logos officiels des moyens de paiement (voir logos/LISEZMOI.md)
└── README.md       Ce fichier
```

## Mettre le site en ligne avec GitHub Pages (gratuit)

1. Crée un dépôt sur GitHub, par exemple `yiriclick`.
2. Envoie le contenu de ce dossier dans le dépôt (bouton **Add file › Upload files**).
3. Dans le dépôt : **Settings › Pages**, choisis la branche `main` et le dossier `/ (root)`, puis **Save**.
4. Après une minute, le site est en ligne à l'adresse indiquée par GitHub.
5. Pour utiliser ton nom de domaine (ex. `yiriclick.com`) : **Settings › Pages › Custom domain**,
   puis suis les instructions DNS de ton fournisseur de domaine.

## Et Supabase ?

Supabase n'est pas nécessaire pour afficher ce site vitrine. Il servira à l'étape suivante,
pour la vraie plateforme :

- comptes vendeurs et connexion,
- base de données des boutiques, produits et commandes,
- stockage des photos de produits,
- abonnements (Essai, Basique, Pro, Entreprise).

## Activer l'enregistrement des inscriptions (Supabase)

Les boutons « Démarrer », « Essai gratuit », « Essayer » et « Choisir » ouvrent le formulaire
d'inscription. Pour que les inscriptions soient enregistrées :

1. Crée un projet gratuit sur supabase.com.
2. Ouvre **SQL Editor › New query**, colle le contenu de `supabase/inscriptions.sql`, puis **Run**.
3. Ouvre **Project Settings › API** et copie la **Project URL** et la clé **anon public**.
4. Dans `index.html`, cherche `var SUPABASE = { url: "", anonKey: "" };`
   et colle-les entre les guillemets.
5. Republie le site sur GitHub. Les inscriptions apparaissent dans **Table Editor › inscriptions**.

La clé « anon public » peut être visible dans le site : la sécurité est assurée par la règle
du script SQL, qui autorise uniquement l'ajout d'inscriptions. Ne mets **jamais** la clé
« service_role » dans le site.

Tant que ces deux valeurs sont vides, le formulaire affiche « Formulaire prêt » et n'envoie rien.

## À modifier avant le lancement

- Remplacer `[ADRESSE E-MAIL]` (et ses traductions) par ton adresse de contact,
  dans `index.html` (chercher `contact:`).
- Mettre à jour les taux de change : objet `RATES` dans `index.html`
  (taux de référence BCE du 23 octobre 2026). Sur la plateforme finale,
  ils pourront être récupérés automatiquement chaque jour.
- Ajouter les logos officiels dans `logos/`.
- Relier le formulaire d'inscription à Supabase (voir la section ci-dessus).
- Liste des villes : le site contient les principales villes de chaque pays (objet `CITIES` dans `index.html`).
  Pour la plateforme finale, importer une base complète (par exemple GeoNames, gratuite) dans Supabase.
- Textes juridiques (conditions générales, confidentialité, attestation, engagement) : version provisoire
  dans l'objet `DOCS` de `index.html`. Les faire valider par un juriste et compléter les éléments entre crochets.
