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

## Formules payantes, espace admin et suivi des visites (base v2)

1. Dans Supabase, **SQL Editor › New query** : colle `supabase/schema-v2.sql`, puis **Run**.
2. **Authentication › Users › Add user › Create new user** : ton e-mail et un mot de passe solide,
   coche « Auto Confirm User ».
3. Dans `schema-v2.sql`, la dernière partie (« Te nommer administrateur ») : remplace
   `TON_EMAIL@exemple.com` par ton e-mail, colle ces lignes dans une nouvelle requête et **Run**.
4. Ouvre `admin.html` sur ton site (ex. `https://…github.io/YiriClick-/admin.html`) et connecte-toi.

Ce que fait la base v2 :
- **dossiers** : les dossiers vendeurs (Basique, Pro, Entreprise), statut « en attente » à la réception ;
- **pieces-identite** : espace privé pour les pièces d'identité. Les visiteurs peuvent seulement déposer
  un fichier ; seul un administrateur connecté peut l'ouvrir, via un lien valable 5 minutes ;
- **visites** : compteur anonyme (visites, formulaires ouverts, inscriptions), sans nom, sans cookie ;
- **admins** : la liste des comptes autorisés à ouvrir l'espace admin.

Le paiement des abonnements n'est pas encore branché : il le sera avec ton prestataire de paiement.

## Espace vendeur, boutiques et vitrine (base v3)

1. Dans Supabase, **SQL Editor › New query** : colle `supabase/schema-v3.sql`, puis **Run**.
2. **Authentication › URL Configuration** :
   - **Site URL** : `https://toutfeutoutflamme226-design.github.io/YiriClick-/vendeur.html`
   - **Redirect URLs** : ajoute la même adresse.
3. **Authentication › Sign In / Providers › Email** : laisse « Confirm email » activé (obligatoire pour la sécurité).

Fonctionnement :
- Dans l'admin, passe un dossier en **Actif** (ou un essai en **Client actif**).
- Le vendeur ouvre `vendeur.html`, crée son mot de passe avec **le même e-mail** que son inscription,
  confirme son e-mail, puis crée sa boutique et ses produits.
- Page publique de chaque boutique : `boutique.html?b=nom-de-la-boutique`. Vitrine de tous les produits : `vitrine.html`.
- Limites appliquées par la base : Essai 15 produits / 4 photos, Basique 100 / 4, Pro 500 / 6, Entreprise illimité / 10.
- Les e-mails de confirmation partent du service d'e-mail intégré de Supabase, limité à un petit nombre
  d'e-mails par heure : avant le vrai lancement, configure ton propre service d'envoi (Authentication › Emails › SMTP).

## Vitrine façon grand magasin et promotions (base v4)

1. Dans Supabase, **SQL Editor › New query** : colle `supabase/schema-v4.sql`, puis **Run**.
2. Dans l'admin, section **Promotions de la vitrine** : ajoute des bannières, des tuiles et une offre du jour.
3. Dans l'espace vendeur, le champ **Prix avant réduction** affiche un prix barré et le pourcentage de réduction.

La vitrine (`vitrine.html`) propose : choix du pays et de la langue à la première visite, recherche avec
suggestions et recherche vocale, favoris, bannières, tuiles, offre du jour, petits prix, tendances,
« Près de chez toi », boutiques, catégories, filtres et tri. Les liens des réseaux sociaux se renseignent
en haut du script de `vitrine.html` (objet `SOCIAL`).

## Espace vendeur professionnel (base v5)

1. Dans Supabase, **SQL Editor › New query** : colle `supabase/schema-v5.sql`, puis **Run**.
2. L'espace vendeur (`vendeur.html`) contient :
   - **Accueil** : boutique complète à X %, chiffres des 7 derniers jours, alertes de stock ;
     pour Pro et Entreprise, la courbe sur 30 jours et les produits les plus regardés ;
   - **Boutique** : identité, couleur de marque, sections, infos pratiques, réseaux sociaux, FAQ, avec un aperçu en direct ;
   - **Produits** : recherche, filtres, produits à la une, réordonner les photos, calcul de marge (le coût reste dans le navigateur) ;
   - **Partager** : lien, message prêt à envoyer, WhatsApp et Facebook ; QR code et affiche à imprimer (Pro et Entreprise).
3. Les statistiques sont anonymes (table `evenements`) : visites, vues, ajouts au panier, favoris et contacts WhatsApp.

## Commandes et variantes (base v6)

1. Dans Supabase, **SQL Editor › New query** : colle `supabase/schema-v6.sql`, puis **Run**.
2. Côté client : « Envoyer ma commande » enregistre une commande par vendeur avec un numéro (YC-XXXXXX).
   Les prix et le stock sont vérifiés par la base, pas par le navigateur. Le client l’envoie ensuite sur WhatsApp
   et suit son statut dans « Mes commandes » (menu de la vitrine ou panier).
3. Côté vendeur, onglet **Commandes** : nouvelles, en cours, livrées, annulées ; confirmer, expédier, livrer,
   annuler ; message WhatsApp prêt pour le client ; note interne ; bon de commande à imprimer ou enregistrer en PDF ;
   vue **Clients** avec l’historique de chacun. Le stock baisse à la confirmation et revient en cas d’annulation.
4. **Variantes** (Pro et Entreprise) : jusqu’à 2 options (ex. taille et couleur), stock et prix par combinaison.

## Marketing et avis (base v7)

1. Dans Supabase, **SQL Editor › New query** : colle `supabase/schema-v7.sql`, puis **Run**.
2. Espace vendeur, onglet **Marketing** :
   - **Codes promo** (Pro et Entreprise) : % ou montant, achat minimum, dates, nombre d’utilisations ; vérifiés par la base ;
   - **Soldes programmées** (Pro et Entreprise) : -X % sur tous les produits ou ceux à la une, avec début et fin ; aussi produit par produit ;
   - **Visuels à partager** : image carrée ou verticale avec photo, prix et couleur de la boutique ;
   - **Catalogue PDF** : `catalogue.html?b=adresse-boutique`, à imprimer ou enregistrer en PDF.
3. **Avis clients** : après une commande livrée, le client note la boutique depuis « Mes commandes ».
   Le vendeur répond ou signale (onglet Commandes › Avis) ; l’admin masque les avis abusifs.

## Tailles pour toutes les formules (base v8)

1. Dans Supabase, **SQL Editor › New query** : colle `supabase/schema-v8.sql`, puis **Run**.
2. Essai et Basique : une option (taille, pointure, âge…) avec un stock par taille.
   Pro et Entreprise : taille **et** couleur, et un prix par variante.
3. Dans la fiche produit, des modèles en un geste : XS → XXL, grandes tailles, 34 → 48, pointures 36 → 46,
   pointures enfant, âges enfant et bébé, couleurs, taille unique. Un rappel apparaît pour les vêtements sans tailles.
4. Côté client : les tailles s’affichent sur les cartes produits, et un guide des tailles indicatif dans la fiche.

## E-mails automatiques (base v9)

Chaque nouvelle commande envoie un e-mail au vendeur, et chaque nouvel essai ou dossier t’envoie une alerte.
Les e-mails partent par Resend (gratuit : 100 par jour, 3 000 par mois).

1. Supabase › **SQL Editor** : colle `supabase/schema-v9.sql`, puis **Run**.
2. Crée un compte sur https://resend.com avec ton adresse e-mail, puis **API Keys › Create API key** (accès « Sending »). Copie la clé `re_…`.
3. Supabase › **SQL Editor**, en remplaçant les deux valeurs :
   ```sql
   select vault.create_secret('re_COLLE_TA_CLE_ICI', 'resend_api_key');
   update public.reglages_email set admin_email = 'ton.adresse@gmail.com';
   ```
4. Test : fais une inscription d’essai sur `vendre.html`. Tu dois recevoir l’alerte en quelques secondes.
   En cas de souci : `select * from net._http_response order by created desc limit 5;`
5. **Tant que le domaine n’est pas vérifié**, Resend n’envoie qu’à ta propre adresse : les alertes admin marchent,
   pas encore les e-mails aux vendeurs. Après l’achat de yiriclick.com : Resend › **Domains › Add domain**,
   ajoute les enregistrements DNS indiqués, puis :
   ```sql
   update public.reglages_email set expediteur = 'Yiriclick <commandes@yiriclick.com>';
   ```
6. Même domaine pour les e-mails de connexion : Supabase › Authentication › Emails › **SMTP Settings** :
   hôte `smtp.resend.com`, port `465`, utilisateur `resend`, mot de passe = la clé Resend, expéditeur `no-reply@yiriclick.com`.

Pour changer la clé : `select vault.update_secret((select id from vault.secrets where name = 'resend_api_key'), 're_NOUVELLE_CLE');`

Le vendeur peut couper les e-mails (« Ma boutique › Contact »). Dans l’espace vendeur ouvert, une alerte sonore
et une notification signalent aussi chaque nouvelle commande (vérification toutes les 30 secondes).

## Inscription simplifiée (base v10)

1. Supabase › **SQL Editor** : colle `supabase/schema-v10.sql`, puis **Run**.
2. Toute inscription ouvre **tout de suite** un essai gratuit de 14 jours (une seule fois par adresse e-mail).
   Le vendeur crée son mot de passe, confirme son e-mail, et sa boutique est ouverte.
3. La pièce d’identité n’est demandée que pour passer en formule payante : bouton « Passer à une formule »
   dans l’espace vendeur, ou `vendre.html?email=…#dossier-pro`.
4. À la fin de l’essai, l’espace vendeur affiche « Ton essai gratuit est terminé » avec le lien vers le dossier.
   Dans l’admin (onglet Essais), tu peux **prolonger l’essai de 14 jours** ou le refuser.
5. Le badge « Vendeur vérifié » ne s’affiche que pour les vendeurs dont le dossier est validé (Actif).

## Vitrine rapide (base v11)

1. Supabase › **SQL Editor** : colle `supabase/schema-v11.sql`, puis **Run**.
2. La vitrine ne charge plus tous les produits : la base fait la recherche, les filtres, le tri et les pages de 24 produits.
   Recherche sans accents (« karite » trouve « Karité »), plusieurs mots possibles. Testé à 5 000 produits : moins de 0,1 seconde.
3. Sans ce script, la vitrine continue de marcher comme avant (400 produits chargés d’un coup).
4. Taux de change utilisés pour trier par prix : table `taux` (1 EUR = x).

## Taux de change du jour (base v12)

1. Supabase › **SQL Editor** : colle `supabase/schema-v12.sql`, puis **Run**.
2. Chaque jour de semaine à 15 h 30 UTC, la base récupère les taux de la Banque centrale européenne (API Frankfurter, gratuite)
   et met à jour la table `taux`. Le franc CFA reste fixe (1 € = 655,957 FCFA).
3. La vitrine, les boutiques et la démo des monnaies de `vendre.html` utilisent ces taux, avec leur date.
4. Vérifier : `select * from public.taux;` · Voir les tâches : `select * from cron.job;`

## Préparation Google et aperçus de liens

- **Publication automatique** (`.github/workflows/publier.yml`) : à chaque modification et toutes les heures,
  le site est publié avec une page de partage par boutique (`b/nom-de-boutique/`) et par produit (`p/id/`),
  un plan du site `sitemap.xml` et `robots.txt`.
  **À faire une fois** : GitHub › Settings › Pages › Build and deployment › Source = **GitHub Actions**.
- Les liens courts affichent le nom, la description et la photo dans WhatsApp, Facebook et X, puis ouvrent la boutique.
  Ils marchent aussi avant la publication suivante grâce à `404.html`.
- Chaque boutique décrit ses produits, prix, disponibilité et note moyenne aux moteurs de recherche (données structurées schema.org).
- Image d’aperçu par défaut : `assets/og.png`.
- **Après l’achat du domaine** : GitHub › Settings › Secrets and variables › Actions › Variables › `SITE_URL` = `https://yiriclick.com/`.
  Toutes les adresses absolues suivent automatiquement.

## Pages du site

- `index.html` : la vitrine, page d’accueil pour les acheteurs.
- `vendre.html` : la présentation pour les vendeurs (tarifs, inscription).
- `vitrine.html` : redirige vers l’accueil pour que les anciens liens marchent encore.
- Dans l’admin, chaque bannière ou tuile a une destination à choisir : tous les produits, petits prix,
  une catégorie, une boutique, un produit précis, la page vendeurs ou un autre lien.

## Importer des produits (espace vendeur)

Onglet **Produits > Importer** : le vendeur choisit un tableur (CSV ou Excel) avec ses photos,
ou un dossier ZIP qui contient les deux. Le code est dans `assets/import.js`.

- Formats lus : modèle Yiriclick (bouton « Télécharger le modèle »), export Shopify, export WooCommerce,
  ou tout tableau avec au moins une colonne nom et une colonne prix (en français ou en anglais).
- Colonnes du modèle : `nom; description; prix; prix_avant; devise; categorie; stock; option; valeurs; photos`.
  Les photos sont des noms de fichiers joints ou des adresses web.
- Aperçu avant import : chaque produit peut être décoché et sa catégorie corrigée.
- Les règles de la formule s'appliquent (nombre de produits, de photos, d'options ; prix par variante en Pro).
- Les photos venant d'un autre site peuvent être bloquées par celui-ci : le vendeur est prévenu et les ajoute à la main.
- Les bibliothèques ZIP (JSZip) et Excel (SheetJS) ne sont chargées que si un tel fichier est choisi.

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
