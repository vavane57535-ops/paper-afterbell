# Validation 0.16 — 12 octobre 2026

## Ce qui a été vérifié

- **Parties automatiques sans interface graphique** sur le jeu complet (les dix lots de la 0.16 réunis, puis les cinq vérifications finales) :
  - les sept personnages, dont Alice, sur les trois cartes ;
  - deux LMS (Bleuette, Usayuko), la victoire d'Alice et la fin du temps ;
  - une manche complète de 340 secondes jouée jusqu'à sa fin.
  - Dans la victoire d'Alice, le chrono finit à 589,9 s, soit 320 s + 6 × 45 s : le bonus de +45 s par élimination s'applique bien.
  - **Résultat : 0 erreur de script.**
- **Exécutions d'Alice** :
  - les six exécutions et leurs six variantes True Form, chacune jusqu'à la mort de la victime ;
  - verrouillage pendant la scène puis libération d'Alice, +45 s au chrono ;
  - étourdissement de 5 s d'Alice après l'explosion de Lysia, y compris en True Form ;
  - en réseau, hôte et client voient les mêmes plans ;
  - épilogue quand l'exécution élimine le dernier survivant (solo, vue d'Alice, réseau).
- **Mécaniques**, 78 contrôles chiffrés :
  - surchauffe de Lysia : −40 PV en tout, environ −20 PV si elle est interrompue à 1,5 s, jamais sous 1 PV ;
  - soin à la prise : 60 PV en 12 s seule, en 8,05 s avec Ashura (×1,49) ;
  - l'IA d'Ashura rejoint Lysia branchée ;
  - X-ray : les 5 prises de la carte apparaissent à travers les murs pendant l'effet ;
  - encouragement de Bleuette sur chaque allié, dont +2 s de Course éclair pour Simon ;
  - PV du LMS : +65 et plafond de 150 pour chaque élève ; seul le courage de Bleuette dépasse 150.
- **Réseau local**, 92 contrôles, tous réussis. Six scénarios entre programmes séparés :
  - Alice jouée par un client ;
  - Alice jouée par l'hôte, y compris l'hôte-Alice qui quitte pendant une exécution ;
  - retour au salon ;
  - Alice IA ;
  - autorisations du chef ;
  - partie à trois programmes.
  - Ces scénarios couvrent le choix d'Alice par l'hôte, le badge ALICE et la fin par forfait avec le blocus.
- **Émotes** :
  - synchronisation locale : même phase à 70 m, une seule musique, pause, arrivée tardive, bots qui rejoignent puis s'arrêtent ;
  - synchronisation en réseau : écart de temps de 0,0000 s sur 1 723 images de danse partagée.
- **Caméra**, 47 contrôles :
  - rotation sans inertie, plage verticale de −77° à +69° ;
  - souris et stick indépendants des images par seconde ;
  - déplacements droits : écart de direction au plus 0,001°, contre 6 à 7° en 0.15 ;
  - modes Derrière et Libre 360° (visage visible), touche C et clic du stick droit, mode mémorisé ;
  - collisions contre de vrais murs de l'école, spectateur, drone d'Ashura et plans de cinéma.
- **Prologue Yiero** :
  - les 27 répliques s'affichent, sur 67 plans et 196 s, avec retours en arrière sans erreur ;
  - lecture depuis la cinémathèque ;
  - premier lancement : le film se joue, maintenir Échap, Entrée ou cliquer le passe ;
  - lancement suivant : menu direct.
- **Victoires LMS** : films joués jusqu'au bout puis écran de résultats, en solo (Simon, Usayuko) et en réseau (Ashura, chez l'hôte et chez le client).
- **Locomotion** : marche, footing et sprint des six survivants mesurés (cadence, amplitude du genou). Aucun pas à reculons sur les 18 allures.

## Vérification finale du jeu complet

Une fois tous les lots réunis, cinq vérifications indépendantes ont repris le jeu complet :
- partie en jeu ;
- menus et parcours du joueur ;
- films ;
- audit du code entre lots ;
- mixage audio.

Elles ont corrigé 46 défauts, surtout nés de la rencontre entre les lots :

- **Son** :
  - la musique du prologue était presque inaudible, atténuée deux fois ; celle des victoires LMS était trop basse ;
  - les bruitages des films couvraient la musique ;
  - une danse proche se superposait à la musique d'exploration ;
  - l'aperçu de danse de la boutique jouait par-dessus la musique du menu.
- **Sortie ouverte** : la musique de course se coupait jusqu'à 43 s après un bonus de +45 s. La sirène débordait sur le film de fin.
- **Exécutions** :
  - la touche C, la souris et le stick agissaient encore pendant le plan ;
  - la roue d'émotes restait ouverte ;
  - des débris de Lysia apparaissaient dans le film de fin ;
  - le filtre rouge de l'alerte noyait le plan ;
  - le dernier survivant exécuté réapparaissait entier dans le film d'Alice. Ce film est remplacé par un épilogue.
- **Menus** :
  - les titres en collage avaient des lettres qui se chevauchaient (« SETTINGS » se lisait « SETINGS ») : 102 mots sur 112 étaient touchés, plus aucun ensuite ;
  - les messages s'accordent au féminin pour Lysia, Elly et Bleuette ;
  - la barre de lecture de la cinémathèque cachait le bas des films ;
  - une liste du carnet de commandes recouvrait le texte.
- **HUD** : le bandeau de caméra, les bulles et l'alerte de sortie se chevauchaient. Le « +0:45 » s'affichait sur la pause ou sur les bandes noires.

**Captures rendues regardées**, en français et en anglais, en 1280×800 et 1920×1080 :
- le parcours complet du joueur (premier lancement, menu, préparation, réglages, salon, boutique, cinémathèque, pause, résultats) ;
- les films : prologue (19 moments clés), 6 victoires LMS, 12 exécutions en vue d'Alice et en vue monde, blocus, fuites en équipe, victoire d'Alice ;
- des situations de partie : alerte de sortie, danse synchronisée, LMS de Bleuette, prises de Lysia, pause.

**Mixage mesuré** sur la sortie réelle du jeu, réglages par défaut :

| Situation | Niveau |
|---|---|
| Menu | −33 LUFS |
| Ambiances | −36,6 LUFS |
| Poursuite | −31,5 LUFS |
| LMS | −30,5 LUFS |
| Musique du prologue | −30,5 LUFS |

- La musique est 6 à 7,4 dB plus basse qu'en 0.15.
- Chaque famille de musiques tient dans ±0,2 LU.
- Aucune saturation : le limiteur n'est jamais atteint pendant les films.
- Les curseurs Général, Musique et Effets, ainsi que « Couper les sons », ont été contrôlés.

## Limites des essais

- **Rendu logiciel uniquement** (Mesa llvmpipe), pas sur une vraie carte graphique ni sous Windows. `PaperAfterbell.exe` est inchangé (moteur Godot 4.5.1 officiel) ; seul le `.pck` a été reconstruit avec le même moteur.
- **Son non écouté** : musiques et sons sont contrôlés par des mesures (niveau LUFS, pics, durées, raccords), pas à l'oreille. Points à juger à l'écoute en priorité :
  - le dosage des bruitages des films ;
  - le battement de cœur dans le final de la sortie ;
  - la boucle de la musique de course après un bonus.
- **Réseau testé sur une seule machine**, sans Internet réel ni relais distant.
- **Matériel non testé** : aucune manette physique (événements simulés) ni aucun téléphone. L'APK Android n'est pas mis à jour.
- **Équilibrage** : les parties entre bots mesurent la stabilité et le comportement, pas le ressenti de joueurs humains.
- Un avertissement « resources still in use at exit » apparaît parfois à la fermeture du programme de test. Il existait déjà en 0.15 et n'a aucun effet en jeu.
