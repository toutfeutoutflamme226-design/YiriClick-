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

## Formulaires pré-remplis et mots de passe (base v13)

1. Supabase › **SQL Editor** : colle `supabase/schema-v13.sql`, puis **Run**.
2. Fonction `mon_profil()` : le vendeur connecté (adresse e-mail confirmée) récupère ses propres informations
   (inscription, boutique, dernier dossier sans pièce d'identité, sans numéro de pièce ni IBAN).
3. Utilisée pour pré-remplir la création de boutique (`vendeur.html`) et le dossier des formules payantes (`vendre.html`).
   Le vendeur vérifie, corrige si besoin et continue. Ce qu'il tape n'est jamais remplacé.
4. Sans ce script, le pré-remplissage utilise ce que le navigateur connaît déjà (inscription, boutique, dernière commande).
   Ce navigateur ne garde que les coordonnées (`yc-profil`), effacées à la déconnexion.
5. Un vendeur connecté qui choisit une formule payante dans les tarifs arrive directement sur son dossier, pas sur un nouvel essai.
6. Mots de passe (`assets/pass.js`) : bouton pour afficher ou masquer, et vérification en direct que la confirmation est identique
   (création d'accès, nouveau mot de passe, administration).

## Navigation précédent / suivant (`assets/nav.js`)

- Les flèches ← → du navigateur (et les boutons latéraux de la souris, Alt + flèches, le glissement à deux doigts)
  marchent à l'intérieur des pages : fiche produit, panier, menu, choix du pays (vitrine), fiche produit (boutique),
  onglets et éditeur de produit (espace vendeur, avec confirmation si des changements ne sont pas enregistrés),
  formulaire et étapes du dossier (`vendre.html`), onglets et détail (administration).
- Fiche produit : bouton « ← Retour », produit précédent / suivant de la liste d'origine, flèches sur les photos ;
  au clavier, Échap ferme et ← → font défiler les photos.
- Boutique : lien « ← Vitrine » en haut, qui revient à la vitrine telle qu'on l'a laissée.

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

## Avis clients complets et analyse automatique (base v14)

Ce que ça ajoute :
- **Formulaire d’avis détaillé** (dans « Mes commandes », après livraison) : note globale, notes par critère
  (conformité, qualité, livraison, emballage, vendeur, prix), causes d’insatisfaction à cocher quand la note est basse,
  demande de rappel sur WhatsApp, recommandation de 0 à 10, et un avis facultatif sur Yiriclick lui-même.
- **Avis sur Yiriclick** : nouvelle page publique `avis.html` (lien « Avis clients » en bas de l’accueil).
- **Tri des avis** sur les boutiques et sur `avis.html` : les plus pertinents, les plus récents, meilleures notes, notes les plus basses.
  Les avis mis en avant portent le badge « Mis en avant par Yiriclick ». Une phrase explique comment les avis sont vérifiés (obligation légale).
- **Page admin `avis-admin.html`** (bouton « Avis clients » dans l’admin) :
  compte rendu écrit de la période, causes d’insatisfaction, notes par critère, note par mois, classement des boutiques,
  liste filtrable des avis et, pour chaque avis, une page d’analyse avec la commande, le compte rendu automatique,
  l’analyse IA, le message proposé au client (copier ou envoyer sur WhatsApp), le suivi, la mise en avant, le masquage avec motif et le journal.
- **Analyse par règles** (gratuite, immédiate) : sentiment, causes (cochées et repérées dans le texte en français, anglais et espagnol),
  cause principale, urgence, responsable probable, actions et message proposé. Les avis positifs sans alerte sont classés « traités » tout seuls.
- **Analyse par IA** (facultative) : cause racine, nuances du texte, actions et message rédigés par Claude (Anthropic).
- **Alerte e-mail** à l’admin pour chaque avis urgent (si les e-mails de la base v9 sont configurés).
- **Masquage encadré** : un avis ne peut être masqué qu’avec un motif autorisé (injurieux, données personnelles, hors sujet,
  faux, spam, sans achat, illégal). Chaque décision est enregistrée, et un bouton prépare le message WhatsApp qui explique le motif au client.

Installation :
1. **Base** : dans Supabase, **SQL Editor › New query**, colle `supabase/schema-v14.sql`, puis **Run**.
   Les avis déjà publiés sont analysés tout de suite.
2. **Site** : envoie sur GitHub les fichiers modifiés (`admin.html`, `boutique.html`, `index.html`, `vendeur.html`,
   `assets/shop.js`, `assets/shop.css`) et les nouveaux (`avis.html`, `avis-admin.html`, `supabase/schema-v14.sql`).
   Fais l’étape 1 avant l’étape 2.
3. **IA (facultatif)** :
   - crée une clé sur **console.anthropic.com › API Keys** (un moyen de paiement est demandé ; tu paies selon l’usage) ;
   - dans Supabase, **SQL Editor › New query**, lance (avec ta clé à la place de `sk-ant-...`) :
     `select vault.create_secret('sk-ant-...', 'anthropic_api_key');`
   - dans `avis-admin.html`, bouton **Analyser avec l’IA** sur un avis, ou coche **Analyse IA automatique** dans les réglages.
   - Le nom du modèle se change dans les réglages de la page si Anthropic en publie un nouveau.
4. **Confidentialité** : ajoute dans ta déclaration de confidentialité que les avis sont analysés automatiquement et,
   si tu actives l’IA, que la note et le commentaire (sans nom ni téléphone) sont envoyés à Anthropic pour analyse.

Tester : passe une commande, mets-la en « livrée » dans l’espace vendeur, ouvre « Mes commandes » sur le site
et laisse un avis avec 2 étoiles ; il apparaît en urgence dans `avis-admin.html`.

## Demander un avis après la livraison (base v15)

1. Dans Supabase, **SQL Editor › New query** : colle `supabase/schema-v15.sql`, puis **Run**.
2. Envoie sur GitHub : `noter.html`, `vendeur.html`, `avis-admin.html` (à la racine), `assets/shop.js` et `assets/vendeur-i18n.js` (dans `assets`).

Fonctionnement :
- Chaque commande a son lien d’avis : `noter.html?c=<numéro interne>`. Le client l’ouvre sur n’importe quel téléphone,
  sans compte : il voit sa commande et le formulaire d’avis. Seuls la boutique, le numéro et les articles sont affichés.
- Espace vendeur, commande « Livrée » : bouton **Demander un avis au client (WhatsApp)** (message prêt dans la langue du client),
  bouton **Copier le lien d’avis**, date de la demande, et « Avis reçu : x/5 » quand le client a répondu.
  Le message WhatsApp habituel « commande livrée » contient aussi le lien.
- Admin (`avis-admin.html`) : tableau **Commandes livrées sans avis** avec un bouton Demander / Relancer pour chacune.
- Les clients n’ont pas d’adresse e-mail dans Yiriclick : la demande passe par WhatsApp. L’envoi automatique de WhatsApp
  demanderait l’API WhatsApp Business (payante) ; ici, un clic ouvre le message prêt.

## Boutiques validées, contact et état du site (base v16)

1. Supabase › **SQL Editor** › New query : colle `supabase/schema-v16.sql`, puis **Run** (après v14 et v15).
2. **Validation des boutiques** : une nouvelle boutique d'essai marche tout de suite par son lien, mais n'entre dans la vitrine
   (recherche, rubriques, suggestions, plan du site) qu'après « Approuver » dans l'admin (carte « Boutiques à valider »).
   Les boutiques déjà en ligne au premier passage du script restent visibles. Un dossier d'identité validé approuve la boutique.
   Le vendeur voit « En cours de vérification » dans son tableau de bord. L'admin reçoit un e-mail si les e-mails (v9) sont réglés.
3. **Contact** : page `contact.html` (formulaire, aucune adresse affichée). Les messages arrivent dans l'admin
   (carte « Messages de contact ») et par e-mail à l'admin. Anti-abus : 3 messages par heure et par contact.
   L’adresse contact@yiriclick.com (transférée par Cloudflare Email Routing) est affichée sous le formulaire (`CONTACT_EMAIL` dans `contact.html`).
4. **État du site** (admin) : scripts installés (inscriptions à v16), taux du jour, tâches planifiées, clé Resend,
   adresse admin, derniers e-mails, boutiques et messages en attente.
5. **Polices** : Archivo est servie par le site (`assets/fonts.css`, `assets/fonts/`), plus aucune requête vers Google.

## Taux de change à 7 h, heure des Pays-Bas (base v17)

Supabase › SQL Editor › New query : colle `supabase/schema-v17.sql`, puis **Run**.
Chaque jour à 07:00 (Amsterdam, été comme hiver), la base récupère les derniers taux publiés par la BCE (la veille vers 16 h).
Si `schema-v12.sql` est relancé un jour, relancer ensuite `schema-v17.sql`.

## Sécurité et données personnelles (base v18)

1. Supabase › SQL Editor › New query : colle `supabase/schema-v18.sql`, puis **Run**.
2. **Code à 6 chiffres pour l'administration** : à la prochaine connexion, `admin.html` propose de l'activer
   (Google Authenticator, Microsoft Authenticator ou l'app Mots de passe de l'iPhone). Une fois activé, les droits
   d'admin exigent le code à chaque nouvelle connexion. Téléphone perdu : dans Supabase › SQL Editor,
   `delete from auth.mfa_factors where user_id = (select id from auth.users where email = 'ton e-mail');`
3. **Suppression de compte** : espace vendeur › Ma boutique › Supprimer mon compte (photos, boutique, produits,
   commandes, avis et accès). Le dossier d'identité est gardé 6 mois (DSA) puis effacé par le ménage mensuel ;
   ses fichiers se suppriment à la main dans Supabase › Storage (Supabase interdit de les effacer en SQL).
4. **Ménage mensuel** (le 1er à 03:00 UTC) : commandes de plus de 2 ans anonymisées, messages de contact de plus d'un an,
   visites de plus de 13 mois et journal des e-mails de plus d'un an supprimés.
5. **Mots de passe** : 10 caractères minimum. Dans Supabase › Authentication › Policies (ou Providers › Email),
   mettre aussi « Minimum password length » à 10.
6. **Sauvegarde chiffrée chaque dimanche** (`.github/workflows/sauvegarde.yml`) : ajouter une fois dans GitHub ›
   Settings › Secrets and variables › Actions les secrets `SUPABASE_DB_URL` (Supabase › Connect › Session pooler,
   avec le mot de passe de la base) et `BACKUP_PASSPHRASE` (une longue phrase gardée dans un gestionnaire de mots de passe).
   Les sauvegardes sont gardées 90 jours dans l'onglet Actions. Ouvrir : `gpg --decrypt fichier.sql.gz.gpg | gunzip > base.sql`.
7. **Anti-usurpation des e-mails** : dans Cloudflare › DNS, enregistrement TXT `_dmarc` =
   `v=DMARC1; p=none; rua=mailto:admin@yiriclick.com` (passer à `p=quarantine` quand Resend est en place).

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

## Informations légales (juridique.html)

- Les textes (mentions légales, conditions d’utilisation, conditions vendeurs, confidentialité) sont dans `assets/legal-texts.js`, en FR/EN/ES. Ils servent aussi dans le formulaire d’inscription vendeur (vendre.html).
- L’identité de l’entreprise est dans `assets/legal.js` : nom, adresse, numéro KvK, numéro de TVA (btw-id), tribunal. Une valeur vide s’affiche « en cours d’enregistrement ».
- **Ajouter le numéro KvK** : sur GitHub, ouvre `assets/legal.js`, clique sur le crayon, remplis `kvk: "12345678"` (et `nom`, `adresse`, `btw`, `tribunal`), puis « Commit changes ». Le site se met à jour en 1 à 2 minutes.
- Chaque fiche produit a un lien « Signaler ce produit » qui ouvre le formulaire de contact pré-rempli (sujet : signalement).
- À faire relire par un juriste (par exemple via le Juridisch Loket ou un avocat) avant de prendre des paiements en ligne.

## Base v19 : protections anti-abus et surveillance

- Colle `supabase/schema-v19.sql` dans Supabase › SQL Editor › New query, puis Run.
- Pièces d'identité : nom de fichier imposé, 40 dépôts par heure, 3 000 fichiers maximum. Dossiers : 20 par heure. Visites : 3 000 par heure.
- État du site : alerte si une tâche automatique n'a pas tourné depuis 26 h (et barre rouge en haut de l'admin). Remède habituel : Supabase › Project Settings › General › Restart project.
- Boutique pas encore approuvée : un bandeau prévient les visiteurs sur sa page.

## Base v20 : partenaires et Club des 50 vendeurs fondateurs

- Colle `supabase/schema-v20.sql` dans Supabase › SQL Editor › New query, puis Run (après v19).
- Admin › **Vendeurs fondateurs** : cherche une boutique et ajoute-la au Club. Badge « Vendeur fondateur » sur sa boutique, compteur de places sur l'accueil (50 maximum, refusé au-delà).
- Admin › **Partenaires** : logo, affiche, lien, dates, emplacement (grande affiche ou bande de logos). Compteur d'affichages et de clics sur 30 jours, bouton « Copier le rapport » à envoyer au partenaire.
- Rien ne s'affiche sur l'accueil tant que v20 n'est pas installée ou qu'aucun partenaire n'est ajouté.

## Base v21 et publication renforcée

- `supabase/schema-v21.sql` : 30 commandes par heure et par boutique (300 au total), 30 inscriptions par heure, statistiques limitées.
- À chaque publication, la bibliothèque Supabase est copiée sur yiriclick.com (plus de dépendance au CDN extérieur) et chaque page refuse d'être affichée dans le cadre d'un autre site.

## Base v23 : horaires des tâches planifiées

- `supabase/schema-v23.sql` : chaque tâche est surveillée selon son rythme (26 h quotidienne, 8 jours hebdomadaire, 32 jours mensuelle). Une tâche qui n'a encore jamais tourné est « en attente », plus « arrêtée ».
- L'admin (État du site) affiche une rubrique **Tâches planifiées** : prochain passage avec compte à rebours (heure des Pays-Bas) et dernier passage.

## Adresses sans « .html »

- Le site s'ouvre partout sans « .html » : `yiriclick.com/vendre`, `/contact`, `/juridique`, `/boutique?b=…`. Les anciens liens en .html marchent toujours ; la barre d'adresse est nettoyée automatiquement.
- Adresse courte pour les vidéos, flyers et publications : **yiriclick.com/rejoindre** (ouvre l'inscription vendeur).
- Les e-mails de connexion reviennent toujours sur `vendeur.html` : c'est l'adresse enregistrée dans Supabase › Authentication › URL Configuration, rien à changer.

## Yiri, l'assistante des nouveaux vendeurs (assets/guide.js)

- Bienvenue et félicitations (message spécial pour les fondateurs), 3 questions, visite des 5 onglets, puis une carte « Yiri » qui guide la liste « lancer ma boutique » étape par étape. Quand la boutique est complète : fête, message de partage prêt à copier et conseil marketing du jour. Français, anglais, espagnol.
- **Activée pour tous les vendeurs** (30 octobre 2026). Les nouveaux vendeurs sont accueillis ; ceux qui vendent déjà voient seulement la petite bulle Yiri. `yiriclick.com/vendeur?guide=1` relance le guide depuis le début sur ce téléphone.
- Pour la couper : dans `vendeur.html`, passe `var GUIDE_ON = true` à `false`.

## Base v24 : relances des nouveaux vendeurs

- `supabase/schema-v24.sql` (après v23) : chaque jour à 11 h 17, un e-mail part aux vendeurs en essai qui en ont besoin : accès pas créé ou aucun produit 48 h après l'inscription, point au 7e jour, fin d'essai au 12e jour (pas aux fondateurs). Un seul e-mail par étape, en français, anglais ou espagnol. À l'installation, les étapes déjà dépassées ne sont pas rattrapées.
- Admin : carte « Nouveaux vendeurs en essai » (entonnoir accès › boutique › produits › boutique complète, et e-mails envoyés à chacun).
- Pour couper les relances : Table Editor › reglages_email › relances_vendeurs = false.

## Base v25 : le néerlandais dans la base

- `supabase/schema-v25.sql` (après v24) : les inscriptions, dossiers, visites et messages acceptent la langue « nl », et les e-mails de relance existent en néerlandais. Avant ce script, le site enregistre un visiteur néerlandophone en anglais (il le détecte tout seul).

## Base v26 : abonnements, visibilité réservée à l'admin, Boost

- `supabase/schema-v26.sql` (après v25), à coller dans Supabase › SQL Editor › New query, puis Run.
- **Abonnements** : chaque dossier actif a une date de début, une date de fin et une période (mois / an). Les abonnements déjà actifs reçoivent une fin dans 30 jours : ajuste-les dans l'admin, vue « Abonnements ».
- **Rappels** : chaque jour à 10 h 37 UTC (tâche `yiriclick-abonnements`), e-mail et message dans l'espace vendeur à J-14, J-7, J-1 et J0, puis boutique masquée après le délai de grâce (7 jours). Elle revient toute seule quand l'admin prolonge. Réglages dans l'admin.
- **Suivi** : fil de messages admin ↔ vendeur (`vendeurs_suivi`), questions rapides, notes privées, relance WhatsApp ou e-mail pré-remplie.
- **Visibilité** : seul l'admin affiche ou masque une boutique. Le vendeur demande une pause ou une réouverture (`demander_visibilite`).
- **Boost** : mise en avant, vedette de l'accueil, boutique de la semaine (colonnes `boost`, `boost_debut`, `boost_fin`, `boost_raison`).
- **Partenaires** : nouvel emplacement « Espace vendeurs », affiché aux vendeurs dont la boutique est complète à 100 %.

## Base v27 : prix et contenu du site depuis l'admin, parrainage, codes promo

- `supabase/schema-v27.sql` (après v26).
- **Prix** : table `site_reglages` (clé `prix`) pour le mensuel, le trimestriel et l'annuel, par région, plus le Boost. Modifiable dans l'admin, vue « Contenu du site ». Grille de départ : 6 000, 12 000 et 18 000 FCFA ; 12,90, 24,90 et 39,90 € ; 14,90, 28,90 et 45,90 $ par mois.
- **Prix verrouillé** : chaque abonnement garde le prix du jour de son activation (`dossiers.prix`), à vie pour les vendeurs fondateurs (`prix_a_vie`).
- **Parrainage** : lien `vendre?parrain=<adresse de la boutique>`. Mois offerts automatiquement au parrain quand le filleul s'abonne (`parrainages`).
- **Codes promo d'abonnement** : `codes_abonnement`, vérifiés par `verifier_code_abonnement`.
- **Mode édition** : `assets/site.js` remplace les textes `data-t` modifiés par l'admin (`admin_texte`), affiche le bandeau d'annonce et le bouton « ✏️ Modifier » pour l'admin connecté.


## Base v30 : prix à jour dans l'e-mail de fin d'essai

- `supabase/schema-v30.sql` (après v29) : l'e-mail du 12e jour d'essai lit le prix mensuel Basique réglé dans l'admin (au lieu de l'ancien 7 500 FCFA / 15 €).
