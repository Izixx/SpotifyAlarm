# ⏰ Spotify Alarm — Application iOS Native (SwiftUI)

**Spotify Alarm** est une application iOS native moderne développée en **Swift 5.9+ / SwiftUI**, permettant de créer des alarmes musicales qui lancent des morceaux, albums ou playlists Spotify à l'heure programmée.

L'application est conçue pour être compilée localement avec **Xcode** et installée sur un véritable iPhone par **sideloading avec Sideloadly**, sans aucun abonnement Apple Developer payant ni serveur tiers propriétaire.

---

## 📱 Aperçu des Fonctionnalités

* **Connexion Spotify sécurisée (PKCE) :** Protocole OAuth 2.0 *Authorization Code avec PKCE* (RFC 7636). Aucun secret client n'est embarqué dans l'application.
* **Sélection musicale :** Moteur de recherche officiel Spotify (titres, albums, playlists) et accès instantané à vos playlists personnelles.
* **Gestion complète des alarmes :**
  * Heure précise (07:00, 08:30...).
  * Jours de répétition personnalisables (En semaine, Week-end, Tous les jours...).
  * Titre de l'alarme personnalisé.
  * Réglage du volume avec fondu sonore progressif (*fade-in*).
  * Interrupteur ON/OFF individuel persistant.
* **Déclenchement fiable & Notifications Time-Sensitive :** Utilisation du framework `UserNotifications` avec niveau d'interruption *Time-Sensitive* pour sonner à travers les modes de concentration et Ne Pas Déranger.
* **Action sur écran verrouillé :** Bouton direct *"🎵 Lancer Spotify"* sur la bannière de notification.
* **Secours audio local :** Carillon d'alarme haute fidélité intégré (`alarm_sound.wav`), configuré en catégorie `AVAudioSessionCategoryPlayback` (sonne même si le commutateur silencieux physique de l'iPhone est activé).
* **Mode Chevet (Nightstand Mode) :** Horloge nocturne OLED plein écran (écran tamisé basse consommation). En laissant l'iPhone sur sa table de nuit, la musique Spotify se lance de façon 100 % directe au réveil !
* **Bouton "Tester l'alarme" :** Vérification immédiate du son, de la notification (programmée à 3 secondes) et de la connexion Spotify.

---

## 🔍 Comprendre les Règles iOS & Limitations Techniques

Avant d'utiliser l'application, il est essentiel de comprendre comment fonctionne le système d'exploitation d'Apple :

### 1. Le Bac à Sable iOS (Sandbox)
Pour préserver la batterie et la sécurité de l'iPhone, **iOS interdit formellement à toute application tierce suspendue ou fermée de réveiller arbitrairement la puce audio à une heure précise dans le futur sans intervention de l'utilisateur**. Les tâches d'arrière-plan `BGAppRefreshTask` ne garantissent aucun horaire précis (retards de plusieurs heures possibles décidés par l'OS).

### 2. La Solution Optimale et Légale Implémentée
Spotify Alarm adopte la meilleure architecture technique conforme aux règles Apple :
1. **Notification Locale Time-Sensitive (`UNUserNotificationCenter`) :** L'alarme est programmée auprès du processeur d'iOS. À 07h00 tapante, une notification prioritaire s'affiche avec la sonnerie d'alarme dédiée `alarm_sound.wav`.
2. **Action Immédiate :** En touchant la notification ou le bouton *"🎵 Lancer Spotify"*, l'iPhone ouvre l'application, appelle l'API Spotify de reprise de lecture (`PUT /v1/me/player/play`) et ouvre directement Spotify via son *Deep Link* (`spotify:track:...`).
3. **Le Mode Chevet (Nightstand Mode) :** Si vous posez votre iPhone sur son chargeur la nuit avec l'écran Chevet ouvert, l'application reste au premier plan sans s'éteindre : **la musique se lance alors de façon 100 % automatique sans que vous n'ayez à toucher l'écran**.
4. **Secours Hors-Ligne :** Si vous êtes en mode avion ou sans réseau, le carillon local sonne immédiatement pour que vous ne ratiez jamais votre réveil.

> [!NOTE]
> La commande à distance de lecture via l'API Web Spotify nécessite un compte **Spotify Premium** et un appareil actif (Spotify Connect). Pour les utilisateurs Spotify Gratuit, l'application effectue un deep link direct vers l'application Spotify native.

---

## 🛠️ Configuration Préalable : Spotify Developer Dashboard

Pour connecter l'application à Spotify, vous devez générer un `Client ID` officiel gratuit.

### Étape 1 : Créer votre Application Spotify
1. Rendez-vous sur le portail développeur : [https://developer.spotify.com/dashboard](https://developer.spotify.com/dashboard).
2. Connectez-vous avec votre compte Spotify habituel.
3. Cliquez sur le bouton **"Create App"**.
4. Renseignez les informations :
   * **App name :** `Spotify Alarm`
   * **App description :** `Application de réveil musical pour iPhone`
   * **Redirect URIs :** Ajoutez impérativement `spotifyalarm://callback`
   * **Which API/SDKs are you planning to use? :** Cochez **Web API**.
5. Acceptez les conditions d'utilisation et cliquez sur **Save**.

### Étape 2 : Récupérer le Client ID
1. Dans la page de votre application sur le dashboard, cliquez sur **Settings**.
2. Copiez votre **Client ID** (chaîne de 32 caractères hexadécimaux).
3. *(Important)* Vous n'avez **PAS** besoin de copier le *Client Secret*. L'application utilise PKCE.

### Étape 3 : Configurer l'application iOS
Ouvrez le fichier `SpotifyAlarm/Config/SpotifyConfig.swift` et collez votre Client ID :

```swift
public struct SpotifyConfig {
    // Remplacez "YOUR_SPOTIFY_CLIENT_ID" par votre vrai Client ID
    public static let clientID = "votre_client_id_ici"
    
    public static let redirectURI = "spotifyalarm://callback"
    // ...
}
```

---

## 💻 Compilation avec Xcode (Compte Apple Gratuit)

Vous n'avez besoin d'aucun compte Apple Developer payant (99 $/an). Un simple identifiant Apple personnel (Apple ID gratuit) suffit.

### Étape 1 : Ouvrir le projet
1. Ouvrez le dossier dans Xcode : double-cliquez sur `SpotifyAlarm.xcodeproj`.
2. Sélectionnez la cible principale **SpotifyAlarm** dans le navigateur de projet à gauche.

### Étape 2 : Configuration de la signature (Signing)
1. Allez dans l'onglet **"Signing & Capabilities"**.
2. Cochez **"Automatically manage signing"**.
3. Dans **Team**, sélectionnez votre compte Apple personnel (ajoutez votre Apple ID dans *Xcode > Settings > Accounts* si ce n'est pas déjà fait).
4. Dans **Bundle Identifier**, personnalisez l'identifiant pour le rendre unique (ex: `com.votrenom.spotifyalarm`).
5. Xcode génère automatiquement votre profil de provisionnement gratuit (*Personal Provisioning Profile*).

### Étape 3 : Génération du fichier `.ipa`
Deux méthodes simples pour exporter le paquet :

#### Méthode A : Archive Xcode classique
1. Dans le sélecteur de destination (en haut de Xcode), choisissez **Any iOS Device (arm64)**.
2. Allez dans le menu **Product > Archive**.
3. Une fois l'archivage terminé dans l'Organizer, cliquez sur **Distribute App** > **Custom** > **Development** or **Ad-Hoc** > cochez le profil de développement > exportez le dossier contenant le fichier `SpotifyAlarm.ipa`.

#### Méthode C : 100 % automatique depuis Windows avec GitHub Actions (Recommandé si vous n'avez pas de Mac)

Si vous utilisez un PC Windows sans Mac, l'application inclut un workflow d'automatisation GitHub Actions prêt à l'emploi (`.github/workflows/build.yml`) :

1. Créez un dépôt sur votre compte GitHub (public ou privé).
2. Poussez le projet sur GitHub :
   ```bash
   git add .
   git commit -m "Initial commit"
   git remote add origin https://github.com/VOTRE_PSEUDO/SpotifyAlarm.git
   git branch -M main
   git push -u origin main
   ```
3. Rendez-vous sur votre dépôt GitHub dans l'onglet **"Actions"**.
4. Le workflow **"Build & Package IPA"** se lance automatiquement (ou cliquez sur *Run workflow*).
5. En ~2 minutes, une fois la compilation terminée, téléchargez l'artefact **`SpotifyAlarm-ipa`** en bas de la page.
6. Décompressez le ZIP pour obtenir votre fichier **`SpotifyAlarm.ipa`**, prêt à être glissé dans Sideloadly !

---

## 📲 Installation sur iPhone avec Sideloadly

[Sideloadly](https://sideloadly.io/) permet d'installer facilement le fichier `.ipa` sur votre iPhone depuis Windows ou macOS.

1. **Téléchargez et installez Sideloadly** sur votre ordinateur (disponible gratuitement pour Windows et Mac).
2. **Branchez votre iPhone en USB** à votre ordinateur (déverrouillez l'écran et touchez *"Faire confiance à cet ordinateur"* si demandé).
3. Ouvrez **Sideloadly** :
   * Votre iPhone doit apparaître dans le champ **iDevice**.
   * Dans le champ **Apple ID**, entrez l'adresse email de votre compte Apple personnel.
4. **Glissez-déposez le fichier `SpotifyAlarm.ipa`** sur l'icône IPA à gauche dans Sideloadly.
5. Cliquez sur le bouton **Start**.
   * Sideloadly vous demandera le mot de passe de votre Apple ID (utilisé uniquement pour signer l'application auprès d'Apple).
   * Si l'authentification à deux facteurs (2FA) est activée, entrez le code à 6 chiffres reçu sur votre iPhone.
6. Attendez que la barre de progression affiche **"Done"**. L'icône de l'application **Spotify Alarm** apparaît alors sur votre écran d'accueil iPhone !

### Autoriser le Certificat sur l'iPhone (Obligatoire la 1ère fois)
Lors du premier lancement, iOS affiche le message *"Développeur non approuvé"* :
1. Sur votre iPhone, ouvrez **Réglages** > **Général** > **VPN et gestion des appareils**.
2. Sous *App de développeur*, touchez votre adresse email Apple ID.
3. Touchez **"Faire confiance à [Votre email]"** puis confirmez.
4. *(Pour iOS 16 et versions supérieures)* : Allez dans **Réglages** > **Confidentialité et sécurité** > descendez tout en bas sur **Mode Développeur** > Activez-le et redémarrez votre iPhone lorsque demandé.

---

## 🧪 Guide de Test & Vérification sur un Véritable iPhone

Dès l'ouverture de l'application :

1. **Autoriser les Notifications :**
   * Au premier lancement, touchez *"Autoriser"* lorsque l'application demande l'accès aux notifications.
   * Assurez-vous dans *Réglages > Spotify Alarm > Notifications* que l'option **"Notifications urgentes" (Time-Sensitive)** est bien activée.
2. **Connexion Spotify :**
   * Ouvrez l'onglet **Paramètres** (icône d'engrenage en haut à droite).
   * Touchez **"Se connecter avec Spotify"**.
   * Safari ouvre la page officielle Spotify : connectez-vous et acceptez les permissions.
   * L'application affiche votre photo de profil, votre nom et le statut de votre abonnement (Premium ou Gratuit).
   * Touchez **"Tester la connexion Spotify"** pour vérifier la latence en millisecondes.
3. **Tester l'alarme immédiatement :**
   * Sur l'écran d'accueil, touchez le bouton **"Tester l'alarme immédiatement"**.
   * L'application lance immédiatement un extrait sonore de l'alarme pour vérifier le volume.
   * Verrouillez l'écran de votre iPhone : **au bout de 3 secondes**, la notification d'alarme retentit avec son carillon dédié.
   * Sur l'écran verrouillé, touchez la notification ou l'action **"🎵 Lancer Spotify"** : Spotify s'ouvre directement !
4. **Création d'une alarme :**
   * Touchez le bouton **`+`**.
   * Définissez l'heure souhaitée (ex: 07:00).
   * Sélectionnez vos jours de répétition (ex: Lun, Mar, Mer, Jeu, Ven).
   * Touchez **"Choisir sur Spotify"** : recherchez votre artiste favori ou choisissez l'une de vos playlists personnelles.
   * Réglez le curseur de volume (ex: 80 %).
   * Touchez **"Enregistrer"**.

---

## 📂 Architecture du Projet

Le projet respecte scrupuleusement le design pattern **MVVM** et la séparation des responsabilités :

```
SpotifyAlarm/
├── SpotifyAlarm.xcodeproj/              # Projet Xcode prêt à l'emploi
│   └── project.pbxproj                  # Arborescence et build phases complètes
├── SpotifyAlarm/
│   ├── App/
│   │   ├── SpotifyAlarmApp.swift        # Point d'entrée SwiftUI (@main)
│   │   └── AppDelegate.swift            # Délégué UserNotifications & deep links
│   ├── Config/
│   │   └── SpotifyConfig.swift          # Configuration Client ID & Scopes PKCE
│   ├── Models/
│   │   ├── Alarm.swift                  # Modèle d'alarme (persistance JSON)
│   │   ├── SpotifyModels.swift          # DTOs Spotify Web API & TrackItem
│   │   └── RepeatDay.swift              # Enumération des jours de répétition
│   ├── Services/
│   │   ├── KeychainService.swift        # Chiffrement Keychain iOS (jetons OAuth)
│   │   ├── SpotifyAuthService.swift     # Flux PKCE via ASWebAuthenticationSession
│   │   ├── SpotifyAPIService.swift      # Recherche, playlists et lecture Spotify
│   │   ├── AlarmService.swift           # CRUD local persistant dans Documents
│   │   ├── NotificationService.swift    # Gestionnaire UNUserNotificationCenter
│   │   └── AudioPlayerService.swift     # Lecteur AVFoundation & secours sonore
│   ├── ViewModels/
│   │   ├── AlarmListViewModel.swift     # Gestion de la liste & test immédiat
│   │   ├── AlarmEditViewModel.swift     # Création & modification d'alarme
│   │   ├── SpotifyPickerViewModel.swift # Recherche musicale avec debounce
│   │   └── SettingsViewModel.swift      # État du compte & tests de latence
│   ├── Views/
│   │   ├── Main/
│   │   │   ├── AlarmListView.swift      # Vue principale avec switches ON/OFF
│   │   │   └── AlarmRowView.swift       # Ligne d'alarme individuelle
│   │   ├── Edit/
│   │   │   ├── AlarmEditView.swift      # Sélecteur heure, jours, musique, volume
│   │   │   └── DaySelectorView.swift    # Composant de sélection des 7 jours
│   │   ├── Spotify/
│   │   │   ├── SpotifyPickerView.swift  # Explorateur recherche & playlists
│   │   │   └── SpotifyItemRow.swift     # Ligne avec jaquette d'album
│   │   ├── Settings/
│   │   │   ├── SettingsView.swift       # Profil, déconnexion & infos
│   │   │   └── IOSLimitationsView.swift # Guide interactif des règles iOS
│   │   └── Nightstand/
│   │       └── NightstandView.swift     # Mode chevet nocturne plein écran
│   └── Resources/
│       ├── Assets.xcassets/             # AppIcon (1024x1024) et SpotifyGreen
│       ├── Info.plist                   # Schémas URL (spotifyalarm://) & Background Audio
│       └── alarm_sound.wav              # Sonnerie carillon d'alarme embarquée
└── README.md                            # Ce guide exhaustif
```

---

## 🔒 Sécurité & Bonnes Pratiques

* **Zéro mot de passe stocké :** L'authentification s'effectue directement sur le domaine officiel sécurisé de Spotify via `ASWebAuthenticationSession`.
* **PKCE (Proof Key for Code Exchange) :** Aucun `Client Secret` n'est intégré dans le binaire de l'application. La sécurité des échanges repose sur le hachage dynamique SHA256 d'un vérificateur aléatoire à usage unique.
* **Keychain iOS :** Les jetons `access_token` et `refresh_token` sont chiffrés matériellement dans le Keychain avec le niveau de protection `kSecAttrAccessibleAfterFirstUnlock`.
* **Aucun serveur tiers intermédiaire :** Toutes les requêtes sont émises directement depuis l'iPhone vers les serveurs officiels `api.spotify.com`.
* **Respect des DRM Spotify :** L'application ne télécharge aucun fichier MP3/audio protégé. La lecture s'effectue exclusivement via l'écosystème officiel Spotify.

---

## 📄 Licence

Ce projet est distribué sous licence MIT. Libre d'utilisation personnelle et éducative.
