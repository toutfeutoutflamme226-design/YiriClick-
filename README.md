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
