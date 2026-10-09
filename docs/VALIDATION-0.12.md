# Validation 0.12 — 30 septembre 2026

## Ce qui a été vérifié

- **Parties automatiques sans interface graphique** avec les scripts compilés du fichier `PaperAfterbell.pck` livré :
  - les trois cartes et les sept personnages, dont Alice, à vitesse accélérée ;
  - les scénarios de fin : victoire d'Alice, dernier survivant (LMS) et fin du temps ;
  - un mode Android simulé ;
  - une partie en réseau local entre un hôte et un client (231 instantanés reçus par le client).
  - **Résultat : 0 erreur de script.**
- **Autres modes** : terrain d'essai (entrée, panneau F2, retour au menu), cinémathèque, pause et réglages. Tous les écrans de menu ont été ouverts un par un, en français, en anglais et en mode Android simulé, sans erreur.
- **Captures d'écran** en 1280×720, 1440×900, 1600×900 et 2560×1080 : menus, préparation de manche, HUD, réglages, pause, chargement, bulletin de fin, salon, cinémathèque, cartes, effets et launcher. Les défauts repérés (chevauchements, textes coupés, contrastes) ont été corrigés.
- **Mesures de rendu** (nombre d'appels de dessin) avant et après, sur des vues fixes des trois cartes : division par 4 à 8.
- **Mesures de logique** : parties comparées à la version 0.11 dans les mêmes conditions. Temps de calcul de la simulation en baisse, paquets réseau d'environ 800 octets au lieu d'environ 7 Ko, objets créés par les effets pendant une partie passés d'environ 2 250 à 15.

## Limites des essais

- Le rendu a été vérifié avec un pilote graphique logiciel (Mesa llvmpipe, OpenGL 3.3), pas sur une vraie carte graphique ni sous Windows. L'exécutable `PaperAfterbell.exe` est celui de la 0.11 (moteur Godot 4.5.1 officiel) : seul le fichier `.pck` a changé, et il a été produit par le même moteur 4.5.1.
- Les images par seconde réelles dépendent de ta machine. Les réglages Graphismes (qualité, échelle de rendu, limite FPS) permettent d'ajuster.
- Aucune manette physique ni téléphone Android n'a été testé. L'APK Android n'est pas mis à jour dans cette livraison.
- Les parties entre bots mesurent la stabilité et le comportement, pas l'équilibrage ressenti par des joueurs humains.

Les notes de validation de la version précédente sont conservées dans `VALIDATION-0.11.md`.
