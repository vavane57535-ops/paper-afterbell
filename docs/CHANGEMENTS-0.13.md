# Changements 0.13

Cette version refait les animations, donne une voix aux personnages, ajoute des musiques et des sons, transforme le menu en illustration animée et redessine les trois cartes en s'inspirant d'Outcome Memories. Les règles du mode OM ne changent pas : capacités, recharges, dégâts, durées, chronomètre, LMS calé sur la musique, relevage immédiat avec E. Les musiques LMS sont intactes.

## Animations (tout refait)

- **Course et marche** : foulées calées sur la vitesse du jeu, vraie trajectoire du pied (décollage, talon, genou, réception), le buste compense, les coudes suivent, la tête reste stable.
- **Au repos** : respiration, transfert du poids d'une jambe à l'autre, regards autour, et une petite habitude propre à chaque personnage.
- **Un style par personnage** :
  - Alice glisse bas, griffes prêtes ;
  - Usayuko est lourd et large, poings serrés ;
  - Simon est nerveux et vif ;
  - Lysia bouge par à-coups mécaniques ;
  - Elly est calme ;
  - Bleuette sautille ;
  - Ashura est décontracté.
- **Coups reçus** : le corps encaisse du côté opposé à l'attaque, la tête suit avec un temps de retard, les genoux fléchissent, le visage grimace.
- **Visage** : clignement des yeux naturel, une vingtaine d'expressions qui se fondent, bouche qui bouge quand le personnage parle.
- **Cheveux et vêtements** : souples, ils réagissent aux sauts et aux chutes.
- **Épaules** : elles bougent enfin (respiration, bras levés).
- **Autres animations refaites** :
  - sauts et atterrissages, étourdissement ;
  - rampé à quatre pattes quand on est à terre, relevage ;
  - quatre morts différentes qui s'écrasent au sol sans passer à travers ;
  - toutes les capacités de chaque personnage, et les exécutions d'Alice ;
  - les huit émotes ;
  - réactions sociales : remercier, pleurer un allié, sursauter ;
  - réactions sur l'écran de fin selon la note.
- **Cinématiques** :
  - fins refaites en vrais enchaînements : Alice réagit à chaque coup, les élèves freinent et se retournent à la sortie, soulagement ;
  - fin d'Alice avec un dernier assaut et une attitude triomphante ;
  - intro retravaillée.

## Voix et interactions (retirées en 0.13.1)

- **Les 7 personnages parlent français** : 360 répliques et 92 sons vocaux (douleur, soupirs, halètements, rire d'Alice), chacun avec sa voix. Les voix sont générées par IA : Piper, voix française SIWIS.
- **Interactions** :
  - remerciements nominatifs après un soin ou un relevage (« Merci, Elly ! ») ;
  - tristesse quand un allié tombe ;
  - encouragements de Bleuette ;
  - peur quand Alice poursuit ;
  - cris de victoire en sortant ;
  - Alice nargue, chuchote quand elle rôde et réagit quand on l'étourdit.
- **Sans cacophonie** : un seul personnage parle à la fois, et chacun a des temps de repos.
- **Sous-titres** : ils sont en français, ou en anglais si le jeu est en anglais.
- **Réglages** : deux nouvelles options dans Réglages → Accessibilité, « Voix des personnages » et « Sous-titres des voix ».

## Musiques et sons

- **Nouvelles musiques** : un thème pour le menu, une musique pour la forêt, une pour la neige, et une musique de défaite quand Alice gagne. Ce sont des compositions originales autour du carillon d'école.
- **Ambiances sonores par carte** : bourdonnement et horloge dans l'école, grillons et vent en forêt, vent et neige soufflée dans la carte d'hiver.
- **Nouveaux bruitages** : pas sur plancher et sur terre, coups, frappes et portes variés, étoiles d'étourdissement, présence d'Alice quand elle rôde sans être vue, chouettes en forêt.
- **Pas d'Alice** : plus graves, on les reconnaît.
- **LMS** : les musiques LMS ne changent pas.

## Menu

- **Illustré et animé** : les 7 personnages sont dessinés en découpages de papier, avec respiration, petits sauts, parallaxe à la souris et halo au survol. Cliquer sur un personnage prépare une manche avec lui.
- **Animations d'interface** : le logo s'anime (bande de papier déchiré, lettres qui tombent, tampon PAPER), et les pages changent avec un effet de feuille déchirée.
- **Écran de préparation** : grande illustration du personnage choisi, qui s'encre à chaque changement.
- **Écran de chargement** : ton personnage apparaît à l'encre.
- **Performance** : le menu est plus léger, car la 3D est coupée pendant les menus.

## Cartes (inspirées d'Outcome Memories, univers FPE)

- **L'école de Miss Circle**, sur deux étages :
  - un atrium avec la pomme géante et deux escaliers ;
  - un couloir de casiers en boucle ;
  - bibliothèque, cantine, gymnase, labo de Miss Bloomie, bureau du principal, salle de retenue, galeries pour les rails d'Ashura ;
  - chaque salle a au moins deux sorties.
- **La forêt derrière l'école** : la fosse et son pont cassé, la serre de Miss Bloomie, la cabane perchée, les haies, le potager et le portail du bus pour s'échapper.
- **La classe de neige** : un chalet sur deux étages relié à la crête par une passerelle couverte, des chalets à deux portes, un étang gelé et le téléphérique pour s'échapper.
- **Cartes plus compactes**, comme dans la mise à jour d'Outcome Memories : moins de temps perdu à traverser, des repères clairs dans chaque zone, et une sortie avec au moins deux accès.
- **Bots** : ils trouvent leur chemin partout, scellent plus d'archives et s'échappent plus souvent.

## Divers

- Protocole réseau 0.13 : tous les joueurs doivent avoir cette version.
- Launcher mis à jour.
