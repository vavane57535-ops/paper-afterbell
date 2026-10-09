# Validation 0.13.1 — 1er octobre 2026

## Ce qui a été vérifié

- **Voix absentes du jeu livré** : le fichier `PaperAfterbell.pck` ne contient plus aucun fichier du dossier des voix, ni le script qui les jouait.
- **Parties automatiques sans interface graphique**, lancées avec le `PaperAfterbell.pck` livré :
  - les trois cartes (école, forêt, neige), en survivant et en Alice ;
  - le dernier survivant (LMS) et la victoire d'Alice ;
  - la fin du temps ;
  - un salon hébergé en réseau local.
  - **Résultat : 0 erreur de script.** Des relevages ont eu lieu pendant ces parties, ce qui déclenche le nouveau geste de remerciement muet.
- **Réglages** : les options « Voix des personnages » et « Sous-titres des voix » ont disparu. Un ancien fichier de réglages qui les contient encore est simplement ignoré.

## Limites des essais

- **Seules les voix ont changé** : les vérifications détaillées de la 0.13 (menus, cinémathèque, cartes, animations) restent valables. Voir `VALIDATION-0.13.md`.
- **Rendu logiciel uniquement** : comme pour la 0.13, le jeu n'a pas été lancé sur une vraie carte graphique ni sous Windows. L'exécutable est inchangé, seul le `.pck` a été reconstruit avec le même moteur.
