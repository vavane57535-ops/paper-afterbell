# Validation 0.16 — 12 octobre 2026

## Ce qui a été vérifié

- **Parties automatiques sans interface graphique** sur le jeu complet (les dix lots de la 0.16 réunis) :
  - les sept personnages, dont Alice, sur les trois cartes ;
  - deux LMS (Bleuette, Usayuko), la victoire d'Alice et la fin du temps ;
  - une manche complète de 340 secondes jouée jusqu'à sa fin.
  - Dans la victoire d'Alice, le chrono finit à 589,9 s, soit 320 s + 6 × 45 s : le bonus de +45 s par élimination s'applique bien.
  - **Résultat : 0 erreur de script.**
- **Exécutions d'Alice** :
  - les six exécutions et leurs six variantes True Form, chacune jusqu'à la mort de la victime ;
  - verrouillage pendant la scène, puis libération d'Alice ;
  - +45 s au chrono ;
  - étourdissement de 5 s d'Alice après l'explosion de Lysia, y compris en True Form ;
  - 9 familles de bruitages.
- **Mécaniques**, 78 contrôles chiffrés :
  - surchauffe de Lysia : −40 PV complète, environ −20 PV si elle est interrompue à 1,5 s, jamais sous 1 PV ;
  - soin à la prise : 60 PV en 12 s seule, en 8,05 s avec Ashura (×1,49) ;
  - l'IA d'Ashura rejoint Lysia branchée ;
  - X-ray : les 5 prises de la carte apparaissent à travers les murs pendant l'effet ;
  - encouragement de Bleuette sur chaque allié, dont +2 s de Course éclair pour Simon ;
  - PV du LMS : +65 et plafond de 150 pour chaque élève, seul le courage de Bleuette dépasse 150.
- **Réseau local**, 92 contrôles, tous réussis. Six scénarios entre programmes séparés :
  - Alice jouée par un client ;
  - Alice jouée par l'hôte ;
  - retour au salon ;
  - Alice IA ;
  - autorisations du chef ;
  - une partie à trois programmes.
  - Ces scénarios couvrent le choix d'Alice par l'hôte, le badge ALICE et la fin par forfait.
- **Forfait** : le blocus se lance et mène à l'écran de résultats.
- **Émotes** :
  - synchronisation locale : même phase à 70 m, une seule musique, pause, arrivée tardive, bots qui rejoignent puis s'arrêtent ;
  - synchronisation en réseau : écart de temps de 0,0000 s sur 1 723 images de danse partagée.
- **Caméra**, 47 contrôles :
  - rotation sans inertie ;
  - plage verticale de −77° à +69° ;
  - souris et stick indépendants des images par seconde ;
  - déplacements droits : écart de direction au plus 0,001°, contre 6 à 7° en 0.15 ;
  - modes Derrière et Libre 360° (visage visible), touche C et clic du stick droit, mode mémorisé ;
  - collisions contre de vrais murs de l'école, spectateur, drone d'Ashura et plans de cinéma.
- **Prologue Yiero** :
  - les 27 répliques s'affichent, sur 67 plans et 196 s ;
  - retours en arrière sans erreur ;
  - lecture depuis la cinémathèque ;
  - premier lancement : le film se joue, maintenir Échap le passe ;
  - lancement suivant : menu direct.
- **Victoires LMS** :
  - films joués jusqu'au bout puis écran de résultats, en solo (Simon, Usayuko) ;
  - en réseau (Ashura), chez l'hôte et chez le client.
- **Locomotion** : marche, footing et sprint des six survivants mesurés. Cadence, amplitude du genou et aucun pas à reculons (0 sur les 18 allures).

## Limites des essais

- **Rendu logiciel uniquement** (Mesa llvmpipe), pas sur une vraie carte graphique ni sous Windows. `PaperAfterbell.exe` est inchangé (moteur Godot 4.5.1 officiel) ; seul le `.pck` a été reconstruit avec le même moteur.
- **Son non écouté** : musiques et sons sont contrôlés par des mesures (niveau LUFS, pics, durées, raccords), pas à l'oreille.
- **Réseau testé sur une seule machine**, sans Internet réel ni relais distant.
- **Matériel non testé** : aucune manette physique ni aucun téléphone. L'APK Android n'est pas mis à jour.
- **Équilibrage** : les parties entre bots mesurent la stabilité et le comportement, pas le ressenti de joueurs humains.
