# Validation 0.14 — 2 octobre 2026

## Ce qui a été vérifié

- **Parties automatiques sans interface graphique**, lancées avec le `PaperAfterbell.pck` livré (scripts compilés) :
  - les sept personnages, sur les trois cartes : huit parties de 160 secondes (Alice est jouée sur deux cartes) ;
  - les scénarios de fin : dernier survivant (LMS), victoire d'Alice et fin du temps ;
  - quatre manches complètes jouées jusqu'à leur fin naturelle : trois évasions (un ou deux élèves sortis, avec leur film) et un LMS gagné par Alice ;
  - un mode Android simulé ;
  - un salon hébergé ;
  - une partie en réseau local entre deux programmes : le second rejoint la manche en cours et reçoit 794 instantanés en 40 secondes.
  - **Résultat : 0 erreur de script.**
- **Animations** :
  - les 172 animations passent le contrôle automatique (poses valides, durées, repères d'effets) ;
  - un test de résistance de 84 000 images, avec des états, des actions, des vitesses et des durées d'image tirés au hasard pour les sept personnages et la True Form, n'a produit aucune pose invalide ni aucune erreur ;
  - le `.pck` livré les contient toutes : il a été relu après l'export, et il ne contient aucun outil de développement.
- **Films** : les 77 films de la cinémathèque ont été joués en entier, puis parcourus en avant et en arrière, sur les trois cartes. Cela fait 231 lectures et 78 354 images, sans erreur.
- **Écran de fin** : les portraits ont été joués pour les sept personnages et trois notes, sans erreur.
- **Menus** : le test automatique du survol passe ses 49 contrôles (boutons, cartes de personnages, personnages du menu illustré, clavier puis souris). Plus rien ne reste agrandi quand la souris est partie.
- **Captures d'écran**, regardées une par une :
  - chaque animation sous plusieurs angles ;
  - les effets, en studio et pendant de vraies manches ;
  - les films, image par image, sur les trois cartes ;
  - l'écran de fin ;
  - une manche lancée depuis le `.pck` livré.
- **Coût des nouveaux effets**, mesuré sur la même manche que la 0.13.1 : environ 2 appels de dessin de plus par image (186 contre 184 en moyenne) et moins d'une demi-milliseconde de calcul en plus par image sur la machine d'essai.

## Limites des essais

- **Rendu logiciel uniquement** : le rendu a été vérifié avec un pilote graphique logiciel (Mesa llvmpipe), pas sur une vraie carte graphique ni sous Windows.
- **Mouvement non vu en temps réel** : les animations, les effets et les films ont été contrôlés sur des images fixes rapprochées, pas en les regardant défiler à vitesse réelle. Le rythme ressenti reste à juger en jouant.
- **Même exécutable** : `PaperAfterbell.exe` est inchangé (moteur Godot 4.5.1 officiel). Seul le fichier `.pck` a changé, et il a été produit par le même moteur.
- **Réseau** : dans l'essai en réseau local, le second programme a rejoint la manche en spectateur. Aucune partie avec deux joueurs humains n'a été jouée.
- **Films** : la lecture complète des 77 films a été faite avec les sources du jeu, qui sont les mêmes scripts que ceux du `.pck` ; les films joués depuis le `.pck` sont ceux des scénarios et des manches complètes ci-dessus.
- **Matériel non testé** : ni manette physique ni téléphone Android. L'APK Android n'est pas mis à jour.
- **Équilibrage** : les règles n'ont pas changé. Les parties entre bots mesurent la stabilité, pas l'équilibrage ressenti par des joueurs humains.
