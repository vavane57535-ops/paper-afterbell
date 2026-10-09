# Paper Afterbell 0.14 — OM

## Jouer maintenant

**Windows :** décompresser entièrement le ZIP. Ouvrir `Launcher/PaperAfterbellLauncher.exe`, puis **Jouer**. Le jeu peut aussi être lancé directement avec `PaperAfterbell.exe`. Garder le fichier `.pck` à côté de l'exécutable.

**Nouveau dans la 0.14 :** toutes les animations sont reparties de zéro (chaque capacité de chaque personnage a son propre geste), beaucoup plus d'effets visuels façon bande dessinée (éclats, onomatopées, traînées, lignes de vitesse, encre sur l'écran), tous les films refaits avec les vraies capacités, et le survol des boutons du menu corrigé. Voir `CHANGEMENTS-0.14.md`.

**Rappel des versions précédentes :** voix des personnages retirées (0.13.1) ; nouvelles musiques et ambiances sonores, menu illustré et animé, trois cartes redessinées façon Outcome Memories (0.13). Voir `CHANGEMENTS-0.13.1.md`, `CHANGEMENTS-0.13.md` et `CHANGEMENTS-0.12.md`.

**Réglages conseillés :** tout est dans **Réglages → Graphismes** : qualité (Élevée / Équilibrée / Performance), plein écran (ou F11), synchronisation verticale, limite d'images par seconde et échelle de rendu 3D. Sur un petit PC, commence par « Équilibrée ».

**Effets visuels :** ils se règlent dans **Réglages → Jeu** : « Secousses de caméra », « Onomatopées » et « Effets d'écran ». Si les éclairs et les flashs te gênent, active « Réduire les flashs » dans **Réglages → Accessibilité**.

**Android :** cette livraison ne contient que la version Windows. L'APK 0.11 reste jouable seul, mais ne peut pas rejoindre une partie PC 0.14 (protocole réseau différent).

Le mode normal est désormais **OM uniquement**, avec trois cartes. Les anciens choix Forsaken sont retirés. Le terrain d'essai permet de changer de personnage et de tester les capacités, l'aura LMS et la True Form sans terminer une vraie partie. La cinémathèque permet de revoir les 77 films : intros, évasions et fins.

## Commandes

- ZQSD / WASD : déplacement ; souris : caméra ; Maj : course ; Espace : saut.
- 1 à 6 : capacités ; E : interagir, réanimer ou attraper un allié avec Simon pendant son boost ; R : annuler la visée.
- Maintenir 2 avec Simon ou Ashura pour charger, puis relâcher. Moins d'une seconde annule ; 1–2 secondes donnent 3 secondes de boost ; 2–3 donnent 4 secondes ; au moins 3 donnent 6 secondes. Le personnage reste immobile pendant la charge.
- 3 avec Simon ou Ashura : changer le mode de flashbang ou de drone. La flashbang lancée s'arme avec 1 et se confirme avec 1 ou le clic d'attaque.
- G : émotes ; F2 : réglages du terrain d'essai ; Échap : pause.
- Manette : stick gauche déplacement, stick droit caméra, A/Croix saut, X/Carré interaction, RT/R2 capacité 1, LT/L2 charge, LB/L1 changement de mode, RB/R1 capacité 4, croix haut capacité 5, croix bas True Form. Clic du stick gauche : course.

Les commandes se changent dans **Réglages → Commandes → Personnaliser clavier / manette**. Les touches affichées dans le jeu suivent la disposition de ton clavier (ZQSD sur AZERTY). Les manettes Xbox, PlayStation, Switch Pro et les commandes Steam Deck passent par les entrées standard du moteur ; les périphériques physiques n'ont pas tous été testés. Sur Steam Deck, la livraison actuelle est l'EXE Windows à utiliser avec Proton, pas un paquet Linux natif.

Sur Android, le même menu ouvre l'éditeur tactile : déplacer le joystick et les boutons, y compris **Saut**, puis enregistrer. Le profil **Fluide** réduit le coût du rendu sans changer les règles.

## Partie et victoire

Une manche commence à **5:20** par défaut. À **1:20**, l'issue s'ouvre : il faut l'atteindre pour s'échapper. Attendre la fin du temps dans la carte ne donne plus de victoire. Si aucun élève ne sort, Alice gagne.

Chaque LMS dure la longueur réelle de sa musique. Si le LMS commence après l'ouverture de la sortie, une aura pleine conserve l'ouverture et accorde les bonus. Sans aura pleine, la sortie se ferme et le LMS commence sans bonus ; elle se rouvre dans ses 80 dernières secondes.

La **True Form** se débloque après 15 étourdissements reçus, une seule utilisation par partie. Elle dure 30 secondes, suspend le chronomètre et ferme la sortie. Son bond remplace la téléportation et inflige 40 dégâts. Après un étourdissement, Alice porte une aura rouge : elle résiste aux nouveaux étourdissements pendant 5 secondes après sa récupération.

## Jouer entre amis

Le protocole réseau est celui de la **0.14** : tous les joueurs doivent avoir la 0.14 (PC). Une 0.13 ou une 0.13.1 ne peut pas rejoindre une partie 0.14.

**Disponible sans compte :** le salon Internet par code conserve une connexion entre joueurs avec relais de secours. Un joueur héberge toujours la simulation dans ce mode ; ce n'est pas un serveur régional. Sa connexion et son ordinateur influencent donc la partie. Le relais public expérimental peut être indisponible.

**Comptes, amis, groupes privés et serveurs dédiés :** le launcher et le menu en jeu sont prêts, ainsi que le service dans les sources. **Aucun hébergement public n'est déployé ni inclus.** L'adresse d'un vrai service HTTPS devra être configurée pour activer ces fonctions entre tous les joueurs. Les essais ont utilisé un service et un serveur dédiés locaux, sans abonnement ni achat.

Le launcher peut télécharger et vérifier les mises à jour lorsqu'un service les publie. Il conserve la version précédente pour revenir en arrière. Aucun serveur de mise à jour public n'est encore configuré ; ce premier ZIP reste nécessaire. Le launcher ne se met pas lui-même à jour automatiquement.

## Modèles, école et limites de cette alpha

Les sept nouvelles archives de personnages sont intégrées, avec le modèle Simon fourni précédemment. Les textures sont conservées, les proportions distinctes, les squelettes enrichis et les poses/expressions animées dans le moteur. Le rendu ajoute aplats d'ombre et contours noirs aux personnages et décors.

Les animations sont écrites à la main, pose clé par pose clé, puis jouées par le moteur du jeu ; ce n'est pas de la capture de mouvement. La True Form conserve la silhouette du nouveau fichier fourni, humanoïde en robe ; elle n'est pas une nouvelle sculpture quadrupède.

Aucun fichier 3D de carte n'était présent dans les pièces jointes. L'école existante a donc été retravaillée avec le plan et les références FPE : cour/fontaine, gymnase, bassin vidé, salles de classe et pièce d'Alice. Les références trouvées sur Internet n'ont pas fourni une école complète directement réutilisable. Les trois cartes gardent leurs collisions, chemins et sorties.

Voir `CHANGEMENTS-0.14.md` (et les fichiers des versions précédentes), les crédits audio, `UI-LICENSES` (polices OFL et icônes game-icons.net sous CC BY 3.0) et les licences jointes pour les détails.
