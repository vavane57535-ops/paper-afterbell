# Validation 0.13 — 1er octobre 2026

## Ce qui a été vérifié

- **Parties automatiques sans interface graphique** avec le fichier `PaperAfterbell.pck` livré (scripts compilés) :
  - les trois nouvelles cartes et les sept personnages, dont Alice ;
  - les scénarios de fin : victoire d'Alice, dernier survivant (LMS) et fin du temps ;
  - un mode Android simulé ;
  - une partie en réseau local (254 instantanés reçus par le client).
  - **Résultat : 0 erreur de script.**
- **Cinémathèque** : les 77 films sont tous lancés, avancés et lus, sans erreur.
- **Menus** : parcours complet de toutes les pages, en français, en anglais et en mode Android simulé. Ce parcours inclut le survol et le clic sur chaque personnage du menu illustré, les transitions et tous les onglets de réglages.
- **Voix** : chaque situation (douleur, remerciements, deuil, poursuite, LMS, répliques d'Alice…) a été déclenchée et journalisée.
- **Niveaux sonores** mesurés : voix à environ −17 LUFS, musiques à −18 LUFS avant réglage de volume, aucune saturation.
- **Cartes** :
  - chaque point d'apparition, archive, prise, sortie et point de patrouille est accessible depuis le départ ;
  - aucun point d'apparition n'est bloqué ;
  - les élèves ont de la place pour courir au-delà de la sortie pendant les films de fin ;
  - des parties entre bots sur chaque carte montrent que les bots se déplacent, scellent les archives et s'échappent.
- **Animations** : un test de résistance de 42 000 images d'animation avec des états aléatoires n'a produit aucune pose invalide.
- **Captures d'écran** des menus, des cartes, des animations et des films, avant et après.

## Limites des essais

- **Rendu logiciel uniquement** : le rendu a été vérifié avec un pilote graphique logiciel (Mesa llvmpipe), pas sur une vraie carte graphique ni sous Windows.
- **Même exécutable** : `PaperAfterbell.exe` est inchangé (moteur Godot 4.5.1 officiel). Seul le fichier `.pck` a changé, et il a été produit par le même moteur.
- **Voix et musiques non écoutées** : je ne peux pas écouter le son. Voix et musiques ont été contrôlées par des mesures (durée, hauteur, volume, raccords de boucle), pas à l'oreille.
- **Voix générées par IA** : leur intonation reste celle d'une voix de synthèse.
- **Matériel non testé** : ni manette physique ni téléphone Android. L'APK Android n'est pas mis à jour.
- **Équilibrage** : les parties entre bots mesurent la stabilité et le comportement, pas l'équilibrage ressenti par des joueurs humains.
