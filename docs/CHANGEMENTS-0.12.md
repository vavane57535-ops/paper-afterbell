# Changements 0.12

Version consacrée à la qualité : menus, rendu, fluidité, IA et corrections de bugs. Les règles du mode OM ne changent pas : capacités, recharges, dégâts, durées, chronomètre, sortie à 1:20, LMS calé sur la musique, relevage immédiat avec E.

## Menus et interface

- **Menu principal** entièrement refait :
  - titre et navigation claire ;
  - personnages mis en scène sous des projecteurs ;
  - aperçu de la prochaine manche.
- **Nouvel écran « Préparer la manche »** :
  - choix Survivant / Alice ;
  - fiches des six élèves avec portraits ;
  - dossier du personnage : capacités avec icônes, touches, recharges et passif ;
  - choix de la carte avec vignettes ;
  - modèle 3D que l'on peut faire tourner.
- **Nouveau HUD** :
  - chronomètre et objectif lisibles, liste des élèves compacte ;
  - carte du joueur avec PV et aura (la barre d'endurance inutile a disparu) ;
  - barre de capacités avec icônes, recharge circulaire, état de charge et verrou LMS ;
  - touches affichées selon ton clavier (ZQSD sur AZERTY) ;
  - messages empilés au lieu de se remplacer.
- **Réglages en onglets** (Jeu, Graphismes, Audio, Commandes, Accessibilité). Nouvelles options : plein écran, synchronisation verticale, limite d'images par seconde, échelle de rendu 3D, compteur FPS, champ de vision, secousses de caméra.
- **Autres écrans refaits dans le même style** :
  - chargement ;
  - pause, avec confirmation avant de quitter ;
  - bulletin de fin de manche : classement, notes tamponnées, portrait 3D ;
  - salon, connexion, cinémathèque, terrain d'essai ;
  - roue d'émotes, menus des touches et du compte.
- **Polices et icônes** : polices intégrées (Oswald, Barlow, Anton, Bebas Neue, Caveat) et 70 icônes, pour un rendu identique sur tous les PC.
- **Navigation** : petits sons d'interface. Tout se fait au clavier ou à la manette, et Échap / B revient en arrière.
- **Écrans larges** : plus de bandes noires sur les écrans 16:9 ou ultralarges.
- **Anglais** : traductions ajoutées pour tous les nouveaux textes.

## Graphismes et ambiance

- **Ambiance de nuit** : ciel avec lune et étoiles, brouillard teinté, halos lumineux sur les lampes, les fenêtres, la lune, les archives et la sortie.
- **Décors redessinés** :
  - textures régulières quelle que soit la taille des murs ;
  - lumière en aplats nets et ombrage en pied de mur ;
  - grille au sol, teintes par zone de l'école ;
  - plafonds plus clairs et fenêtres éclairées par la lune.
- **Lumières et vie** : lampes chaudes, lanternes en forêt, lucioles en forêt et neige qui tombe sur la carte d'hiver.
- **Chemins** : ceux de la forêt et de la neige, devenus invisibles, sont de retour.
- **Rendu des personnages** : bandes de lumière nettes, liseré, contour encré visible, vêtements sans trous et ombre de contact sous les pieds.
- **Animations** :
  - pas calés sur la vitesse réelle : les pieds ne glissent plus ;
  - inclinaison dans les virages et tassement à l'atterrissage ;
  - cheveux et vêtements souples ;
  - transitions sans à-coups (chute, mise au sol) ;
  - une pose pour chaque capacité, alors que plusieurs utilisaient une pose par défaut.
- **Archives redessinées** : armoire, sceau lumineux, anneau de progression au sol et couleur selon l'état.
- **Effets visuels** :
  - impacts visibles du côté de l'attaquant ;
  - étoiles d'étourdissement au-dessus d'Alice pendant toute la durée ;
  - colonne de lumière sur la sortie ouverte et effet d'évasion ;
  - zones de soin animées ;
  - onde de Shadow Reveal, éclat de flashbang et bouclier de blocage.
- **Accessibilité** : l'option « Réduire les flashs » est respectée partout.

## Jouabilité et IA

- **Fluidité** : les personnages bougent de façon fluide, même sur les écrans 120 / 144 Hz.
- **Caméra** : elle ne rentre plus dans les murs, recule plus doucement et secoue moins brutalement. Les secousses passent à 30 % avec « Réduire les flashs » et peuvent être désactivées.
- **Saut plus tolérant** : un appui juste avant l'atterrissage, ou juste après avoir quitté un rebord, compte.
- **IA des élèves** :
  - fuient plus intelligemment ;
  - scellent les archives au rythme d'un joueur, en choisissant celles loin d'Alice ;
  - relèvent leurs alliés même après l'ouverture de la sortie ;
  - se cachent vraiment en LMS ;
  - anticipent leurs tirs (surchauffe, saisie, flashbang) ;
  - chargent leurs boosts au bon moment et utilisent mieux leurs soutiens ;
  - rampent vers le camarade qui vient les relever.
- **IA d'Alice** :
  - n'attaque plus dans un blocage ni une Lysia invulnérable ;
  - vise en priorité les élèves déjà relevés ;
  - garde la sortie ouverte et fouille les archives ;
  - garde sa True Form pour les moments décisifs ;
  - anticipe ses piques.
- **Son** :
  - musique de poursuite plus stable : elle ne clignote plus à la limite et ne trahit plus une Alice cachée ;
  - battements de cœur à l'approche d'Alice et son étouffé quand on est blessé ;
  - jingles de sortie ouverte, d'évasion et d'élimination.

## Corrections

- **Lysia** :
  - la prise ne bloque plus 15 s quand l'armure est pleine ;
  - on peut se débrancher en bougeant, avec INTERAGIR ou avec 4 ;
  - la prise enterrée de la forêt et de la neige est utilisable ;
  - un point d'apparition n'est plus coincé dans une prise.
- **Simon** : en boost, il peut de nouveau relever et sceller. Sa flashbang ne l'aveugle plus lui-même.
- **Après une mise au sol** : un boost en cours n'est plus conservé.
- **Drone** : il n'est plus gaspillé sur une Alice protégée et attend la fin de l'aura rouge. Un étourdissement sans effet sur Alice protégée est maintenant signalé.
- **True Form** : « TRUE FORM prête » n'est plus annoncé après son utilisation.
- **LMS** :
  - il ne se déclenche plus quand les autres élèves se sont échappés ;
  - le bouton « + ENDURANCE », sans effet, devient « + SOINS » et répare l'armure de Lysia ;
  - la musique LMS n'est plus relancée par la True Form et reprend là où elle s'était arrêtée ;
  - le LMS de Bleuette était environ 12 dB trop fort ; son niveau est aligné sur les autres.
- **Soin d'Elly** : il cible l'allié visé.
- **Doubles d'ombre** : leurs coups indiquent la bonne direction. Un plantage possible quand l'explosion de Lysia les dissipait est corrigé.
- **Décor** : panneaux mal orientés et textes superposés de l'école corrigés.
- **Écran de fin** : les effets n'y restent plus figés.

## Performances

- **Rendu** : appels de rendu divisés par 4 à 8 selon la vue. Par exemple, entrée de l'école : 2 597 → 344.
- **Ombres** : celles de la lune sont désactivées dans l'école, qui est couverte, et allégées en forêt.
- **Décors** : occlusion dans l'école, décors fusionnés par zones, arbres en instances.
- **Effets** : ils sont réutilisés au lieu d'être recréés. Environ 2 250 objets étaient créés par minute de jeu, une quinzaine maintenant.
- **Personnages** : animation allégée. Les os fixes sont ignorés, les personnages hors écran ou lointains sont mis à jour moins souvent et les doubles d'ombre sont allégés.
- **Bots** : recherche de chemin 5 à 9 fois plus rapide.
- **Réseau** : un paquet d'environ 800 octets toutes les 50 ms, au lieu de 7 paquets totalisant environ 7 Ko.
- **Musique** :
  - l'OST d'Usayuko passe d'un WAV de 50 Mo à un Ogg Vorbis haute qualité de 9 Mo, de même durée ;
  - les musiques LMS sont chargées au moment où elles servent.
- **Premier coup** : les effets sont préchauffés pendant le chargement, donc plus de saccade au premier coup.
- **Taille** : les fichiers inutilisés sont retirés et le fichier du jeu passe de 150 Mo à 87 Mo.

## Réseau

- **Protocole 0.12** : tous les joueurs doivent avoir cette version. L'APK Android 0.11 ne peut pas rejoindre un PC 0.12.

## Launcher

- **Style** : même style que le jeu, version 0.12.
