# Paper Afterbell 0.17 — brief commun (à lire EN ENTIER, après le brief général)

> **MISE À JOUR, PRIORITAIRE sur la consigne de ton message** : pour aller plus vite, le joueur a demandé de SUPPRIMER l'étape de relecture.
> **Si tu es un RELECTEUR (« review »)**, ne refais pas de vérification complète. Fais seulement ceci :
> 1. lance `godot --headless --import` ;
> 2. vérifie qu'il n'y a aucune erreur de script (`timeout 200 godot --headless --quit-after 400`) et corrige-la s'il y en a une ;
> 3. commit si besoin ;
> 4. rends tout de suite le rapport final en reprenant celui de l'implémenteur (en ajoutant le commit final).
>
> Les implémenteurs, eux, vérifient leur travail eux-mêmes avec le même soin qu'avant : ils sont désormais les seuls à le faire.

Le brief général du projet (outils, tests, structure du code) reste valable :
`/tmp/claude-0/-home-user-paper-afterbell/3b6367fd-efb2-542d-99d0-4363092d5bea/scratchpad/BRIEF.md`.
Lis-le d'abord. Ce document-ci le complète pour la 0.17.

## Contexte
La 0.16 est livrée et jouée par le joueur. Elle est sur la branche `claude/survivor-animations-mechanics-8kc1vj`, commit `0c3243f`. Les notes de version sont dans `docs/CHANGEMENTS-0.16.md`.

Le joueur est très exigeant et a renvoyé ce retour, résumé fidèlement :
1. **Écran titre** : quand on survole les boutons, une petite scène 3D avec les persos se joue à droite.
   - Les animations sont « pas ouf » : trop courtes, elles se répètent et font « un gif dégueulasse ».
   - Il veut que tout soit refait en mieux, quitte à prendre d'autres persos.
   - MISE À JOUR : le joueur veut finalement que la scène des **Réglages** (Ashura qui répare Lysia) soit refaite aussi, car « on dirait un gif ». Elle n'est plus une exception.
2. **Textes « IA »** : tous les textes des menus, et même des dialogues, sonnent trop génériques, « trop IA », pas assez humains. Exemple cité : « la dernière sonnerie ». Il veut des textes plus naturels, comme écrits par une vraie personne.
3. **Films de la cinémathèque** (prologue Yiero, victoires LMS, et en fait tous les films qu'on y trouve) : il ne veut PLUS d'animations de jeu.
   - Les films réutilisent aujourd'hui les clips du jeu : course, attaques, émotes, gestes des capacités.
   - Il veut des animations faites de A à Z pour chaque film, « comme sur Blender » : une vraie animation 3D jouée, pas « un truc de jeu vidéo répétitif ».
4. **Simon en super-vitesse** (boost) : la course doit prendre la **position « Sonic »**, buste très penché en avant et **bras tendus en arrière**.
5. **Simon qui attrape un allié pendant son boost** : une animation différente selon l'allié.
   - **Ashura** : Simon le tire par la main et Ashura se laisse tracter sur ses rollers.
   - **Bleuette** : portée dans les bras « comme une princesse ».
   - **Elly** : le joueur dit « débrouille-toi » ; les autres alliés aussi sont à inventer.
6. **Le modèle 3D de Yiero est « vraiment moche »** : il faut le refaire.
7. **Cartes** (nouveau) : le joueur ne veut pas tout refaire.
   - Supprimer les objets qui flottent en l'air.
   - Réparer un peu les cartes et enlever ce qui est illogique (objets mal placés, incohérences).
   - Au bord des cartes, on peut tomber dans le vide, et les bots aussi : ajouter des murs invisibles.
8. **Réseau** (nouveau) : avec beaucoup de ping, c'est la hitbox du joueur qui est en retard.
   - Ça ne doit plus être visible ni pénaliser le joueur : ce qu'il voit de lui-même doit être ce qui compte.
   - Optimiser aussi le ping : ils jouent entre joueurs en France, autour de 50 ms.

## Règles de travail (en plus du brief général)
- Ta copie de travail (worktree) existe déjà, sur ta branche `lot17-<axe>`, créée depuis `0c3243f`.
  - Travaille UNIQUEMENT dedans, avec des chemins absolus.
  - Préfixe chaque commande par `cd <ton worktree> && `.
  - Lance d'abord `godot --headless --import`.
- **Commit TRÈS souvent** (`git add -A && git commit`), au moins toutes les 20 à 30 minutes et à chaque étape qui marche, avec des messages clairs en français.
  - Une précédente tentative de ce chantier a été entièrement perdue : la machine a été réinitialisée avant la sauvegarde. L'intégrateur sauvegarde maintenant les commits régulièrement.
  - Ne pousse pas. Ne commite ni `.godot/` ni de fichiers temporaires.
- **Propriété des fichiers** : chaque lot ne touche qu'à ses fichiers (voir la carte plus bas), pour que l'intégrateur puisse fusionner 9 lots.
  - Mets le gros de ton travail dans de NOUVEAUX fichiers.
  - Dans un fichier partagé, fais des insertions courtes et ciblées : ne reformate rien, ne déplace rien.
  - `anim_library.gd` (liste `SETS`) : ajoute seulement ta ligne.
- **Traductions** : seul le lot « textes » modifie `localization.gd` et `localization_016.gd`. Tous les autres lots listent, dans la section TRADUCTIONS de leur rapport, chaque texte français NOUVEAU ou MODIFIÉ avec son anglais naturel. L'intégrateur les ajoutera.
- **Réseau** : la simulation tourne chez l'hôte. Tout état visible doit passer par les mécanismes existants, et les clients doivent voir la même chose. Ne change pas `PaperRules.PROTOCOL` : l'intégrateur le passera à 17.
- **Musique et sons** :
  - La musique du prologue (`audio/cinematic/intro_yiero.ogg`, 196 s) est DÉFINITIVE et calée à la seconde : garde les instants de synchro de `docs/INTRO-YIERO.md` (impacts, rugissement, drops, titre).
  - Les stingers des victoires LMS sont définitifs aussi.
  - S'il te faut un nouveau bruitage, compose-le par code (comme les précédents), à -18 LUFS pour une musique.
- **Vérification visuelle OBLIGATOIRE** : fais des captures rendues avec `xvfb-run` et `--rendering-driver opengl3`, souvent avec `--fixed-fps 30`, et REGARDE-LES avec Read.
  - Pour une animation, regarde une planche d'images serrées (tous les 0,1 à 0,25 s) sur chaque plan : c'est le mouvement qu'on juge, pas une image isolée.
  - Corrige ce qui est raide, mou, cassé (genou ou coude à l'envers, membre qui traverse le corps ou le sol, pied qui glisse, main qui ne touche pas ce qu'elle tient) ou moche, puis recommence.
- **Blender** est disponible en module Python (`bpy`, Blender 5 sans interface) : `/tmp/claude-0/-home-user-paper-afterbell/3b6367fd-efb2-542d-99d0-4363092d5bea/scratchpad/tools/blender-venv/bin/python`. Utile pour modéliser, sculpter par script, remailler, déplier les UV ou cuire des textures, puis exporter en `.glb` pour Godot.
- N'invente aucun résultat. Si tu n'as pas pu vérifier quelque chose, dis-le.

## Efficacité (le joueur veut que ça aille PLUS VITE)
Le travail est limité par un budget d'usage : chaque image regardée et chaque relecture de gros fichier coûte cher. Garde la même exigence de qualité, mais travaille efficacement.
- **Planches contact** : assemble les images d'un plan en UNE planche à basse résolution, et regarde la planche plutôt que les images une par une. Exemple : `ffmpeg -y -pattern_type glob -i 'f_*.png' -vf "scale=320:-1,tile=4x3" planche.png`. Garde la pleine résolution pour juger un détail précis (main, visage, contact).
- **Rendus ciblés** : après une retouche, ne refais que les plans modifiés, pas tout le film.
- **Lecture ciblée** : cherche avec `grep -n` et lis des tranches de fichiers (`sed -n 'a,bp'`), plutôt que des fichiers entiers de milliers de lignes.
- **Relecteurs** : concentrez-vous sur ce que le joueur verra vraiment (défauts visibles, demande non remplie, régressions). Corrigez-les sans tout refaire.

## Ce que veut dire « animation faite de A à Z » (lots films et écran titre)
Le système du jeu permet déjà des clips longs, clé par clé, sur chaque os :
- `anim_clip.gd` : canaux `body`, `chest`, `head`, clavicules, bras, coudes, mains, jambes, genoux, chevilles ;
- `anim_pose.gd` : cibles d'IK des mains `ik_l`/`ik_r` et des pieds, bassin `H(...)`, `plant`, `gsnap` ;
- doigts `curl` / `curl_l`, visage `face`, paupières `lid`, `jaw` ;
- et les canaux `ev`, `fx`, `prop`, `gesture`.

`anim_set_kills.gd` en est un exemple récent (exécutions de 3 à 4 s, écrites à la main). Les films jouent un clip avec `cinema._do(i, t, "play", "nom_du_clip")`.

Pour la 0.17, dans les films et les scènes de l'écran titre :
- **Interdit** : réutiliser un clip du jeu (`anim_set_<perso>`, `common`, `emotes`, `emotes_plus`, `tiktok`, `kills`, `extra`…), une émote (`emote`), le geste d'une capacité (`trigger`), ou la locomotion automatique du jeu pour faire bouger un corps (`_move` avec course ou marche calculées par la vitesse).
  - Chaque mouvement de corps visible est un clip écrit POUR ce plan, dans un nouveau fichier `anim_set_film_<lot>.gd` ou `anim_set_menu.gd`, avec des noms préfixés et uniques.
  - Les effets d'état purement visuels (aura, éclairs, poings dorés, accessoires) restent permis.
  - Les déplacements doivent avoir leur propre cycle écrit pour le plan (course, glissade, saut), synchronisé avec le déplacement : les pieds ne glissent pas.
- **Exigé**, comme un animateur sous Blender :
  - de vraies poses clés, puis des intervalles ;
  - anticipation, action, rattrapage (follow-through) et chevauchement : la tête, les mains et les cheveux arrivent après le corps ;
  - poids et appuis, transferts de poids, arcs ;
  - variations de rythme (jamais un tempo mécanique), asymétrie ;
  - regard qui précède le mouvement, clignements ;
  - expressions du visage qui évoluent dans le plan ;
  - mains qui « jouent » (doigts, contacts précis avec ce qu'elles touchent) ;
  - aucun cycle qui se répète à l'identique de façon visible.
  - La caméra et le cadrage servent le jeu d'acteur, et chaque plan est composé.
- Les répliques et le minutage d'un film peuvent être retravaillés, mais garde l'histoire et les instants de synchro de la musique. Les dialogues de ton film suivent le guide des textes plus bas.

## Guide des textes (pour TOUS les lots qui écrivent du texte)
Le joueur trouve les textes « trop IA ». Écris comme une vraie personne : un ado ou un étudiant qui fait son jeu d'horreur dans une école de papier, en français courant.
- **À bannir** :
  - formules pompeuses et creuses (« la dernière sonnerie », « l'ombre de l'école », « votre destin », « au cœur de… », « plongez dans… », « l'ultime… », « un voyage… ») ;
  - triplets d'adjectifs, métaphores filées, slogans de bande-annonce ;
  - abus de « … » et de majuscules d'emphase ;
  - phrases qui expliquent ce que le joueur voit déjà ;
  - ton publicitaire.
- **À préférer** :
  - phrases courtes et concrètes, qui disent ce que ça fait ;
  - humour léger quand ça colle, vocabulaire d'école (casier, préau, cantine, pion, perm, sonnerie de 16 h…) ;
  - des personnages qui parlent comme eux-mêmes : Simon nerveux et rapide, Ashura posé et sec, Usayuko gouailleur, Elly douce mais directe, Bleuette timide qui bégaie, Lysia automate un peu cassée, Alice inquiétante sans grandiloquence, Yiero sadique et moqueur ;
  - des dialogues qui sonnent à l'oral : contractions (« t'as », « j'sais pas »), interruptions, phrases inachevées quand c'est naturel.
- Garde les noms propres, les termes de jeu fixés (LMS, True Form, Course éclair…) et les phrases que le joueur a demandées mot pour mot, par exemple « Bienvenue dans votre nouvel enfer » à la fin du prologue.
- Chaque texte français modifié ou nouveau doit avoir sa traduction anglaise naturelle (pas mot à mot), dans ton rapport ou dans les fichiers de traduction pour le lot « textes ».

## Carte des lots et des fichiers
| Lot | Axe | Fichiers à toi (en plus de tes nouveaux fichiers) |
|---|---|---|
| menus | Scènes de survol de l'écran titre, TOUTES refaites (Réglages compris) | `ui_menu_vignettes.gd`, nouveau `anim_set_menu.gd`. Ne touche pas aux textes de `ui.gd`. |
| textes | Textes naturels partout, hors films | `data.gd`, `ui.gd`, `ui_hud.gd`, `ui_pause_menu.gd`, `ui_widgets.gd`, `online_menu.gd`, `controls_menu.gd`, `survivor_roster.gd`, `gallery.gd`, les chaînes de `main.gd` et `combat.gd`, `cinematics.gd` (SEULEMENT la fonction `catalogue()` : titres et descriptions de la cinémathèque, sauf les victoires LMS), `localization*.gd`, `audio/CREDITS.txt` (pas obligatoire), `docs/LISEZ-MOI.md` |
| simon | Course « Sonic » du boost et portages différents par allié | `anim_set_simon.gd`, `character_visual.gd`, la logique de portage de `combat.gd`, `actor.gd` (si un effet réseau est nécessaire), nouveau `anim_set_carry.gd` |
| yiero | Nouveau modèle 3D de Yiero | `yiero_model.gd` et ses ressources (nouveau dossier `models/yiero/` si besoin). Ne touche PAS à `film_intro_yiero.gd` : garde (et élargis si besoin) l'API publique de `PaperYiero` utilisée par le film. |
| prologue_a | Prologue 0 → 104 s (dimension, apparition, combat) | dans `film_intro_yiero.gd`, SEULEMENT `_write_void_intro`, `_write_apparition`, `_write_fight` et leurs helpers ; nouveau `anim_set_film_prologue_a.gd` ; `intro_dimension.gd` |
| prologue_b | Prologue 104 → 196 s (défaite, poursuite, école, titre) | dans `film_intro_yiero.gd`, SEULEMENT `_write_defeat`, `_write_chase`, `_write_school`, `_write_footsteps` et leurs helpers ; nouveau `anim_set_film_prologue_b.gd` ; `intro_overlay.gd` (carton-titre) |
| lms_wins | Les 6 victoires LMS | `film_victories.gd` (titres et descriptions compris), nouveau `anim_set_film_victory.gd` |
| lms_losses | Les 6 « Alice · X rattrapé(e) » (`ending_killer`) et l'épilogue d'exécution | `_write_kill` dans `cinematics.gd`, `film_execution_end.gd`, nouveau `anim_set_film_alice.gd` |
| team_blocus | Les 63 fuites en équipe (`ending_survivors`) et le blocus | `_write_escape` dans `cinematics.gd`, `film_blocus.gd`, `film_blocus_overlay.gd`, `anim_set_blocus.gd`, nouveau `anim_set_film_escape.gd` |
| cartes | Cartes : objets qui flottent, incohérences, murs invisibles au bord | `map_school.gd`, `map_forest.gd`, `map_snow.gd`, `map_kit.gd`, `map_interactables.gd`, `school.gd`, `om_maps.gd`, `om_navigation_cache.gd`, `ai_nav.gd` (ne casse pas les chemins des bots, les points d'apparition, les sorties, les archives ni les prises) |
| reseau | Hitbox sans retard pour le joueur en multijoueur, ping optimisé | les parties réseau de `main.gd` (envoi et réception des instantanés et des entrées), `actor.gd` (pack/unpack, prédiction), la détection des coups dans `combat.gd` (compensation du retard), nouveaux fichiers `net_*.gd`. Insertions ciblées : d'autres lots touchent aussi ces fichiers. |

Règles de partage :
- Dans `cinematics.gd`, les lots lms_losses et team_blocus ne doivent PAS modifier les helpers partagés par `_write_kill` et `_write_escape` (`_answer`, `_strike`, `_frame_play`, `_alice_misses`, `_blow`, `_stun`, `_knock`, `_move`, `_shot`…). Copie ce dont tu as besoin dans ton nouveau fichier.
- Règle de jeu à garder : Simon ne peut pas porter Lysia (trop lourde).
- Les deux lots du prologue écrivent dans le même fichier, `film_intro_yiero.gd`, mais pas dans les mêmes fonctions : ne touche jamais aux fonctions de l'autre. Les helpers communs vont dans tes nouveaux fichiers.

## Rapport final (ta réponse finale)
Rends un rapport structuré :
- verdict ;
- ce qui est fait, avec des preuves (captures regardées, mesures) ;
- problèmes connus ;
- tests lancés ;
- ce qui reste ;
- TRADUCTIONS (français → anglais, textes nouveaux ou modifiés) ;
- notes d'intégration : fichiers touchés, commit final, conflits probables.
