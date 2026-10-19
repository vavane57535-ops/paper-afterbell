# Paper Afterbell — brief général pour tous les agents

## Le projet
- Jeu de survie asymétrique : une tueuse, « Alice », contre 6 élèves (Ashura, Usayuko, Simon, Lysia, Elly, Bleuette).
  - Style « école de papier ».
  - Mode de règles « OM », inspiré d'Outcome Memories.
  - Godot **4.5.1**, rendu GL Compatibility.
  - Multijoueur hôte-autoritaire (ENet + netfox/noray), bots IA (`brain.gd`).
- Les sources ont été **reconstruites par décompilation** de l'export 0.15, puis enrichies en 0.16. Il y a peu de commentaires, mais le code est complet et fonctionne.
  - Presque tout est construit par code (une centaine de scripts à la racine).
  - Modèles 3D dans `models/supplied/`, musique dans `audio/`, UI dans `ui/`.
- Langue du jeu : **français** (texte source en français). La traduction anglaise passe par `localization.gd` (`PaperLanguage.t()`, dictionnaires FR→EN) et `localization_016.gd`.
- Docs : `docs/LISEZ-MOI.md`, `docs/CHANGEMENTS-0.1x.md` (règles, commandes, historique), `docs/INTRO-YIERO.md` (storyboard et minutage du prologue).

### Systèmes clés (points d'entrée)
- **`main.gd`** : nœud racine, boucle de partie, réseau, entrée joueur, caméra via `core_camera_rig.gd`, phases `menu/playing/...`, `time_left`, `lms`, sauvegarde `user://settings.cfg`.
- **`actor.gd`** (`PaperActor`) : hp, max_hp, effects, cooldowns, pack/unpack réseau, `NET_EFFECT_RULES` pour synchroniser les effets vers les clients.
- **`combat.gd`** (`PaperCombat`) :
  - capacités par personnage : `_simon/_lysia/_ashura/_elly/_bleuette/_usayuko/_alice` ;
  - dégâts, mort, relevages, LMS ;
  - portage de Simon (`carry_survivor`), prises (`OUTLET_*`), soins.
- **Animations** :
  - helpers de poses : `anim_pose.gd` ;
  - compilation de clés : `anim_clip.gd` (canaux par os, IK des mains et des pieds, visage) ;
  - registre : `anim_library.gd` (liste `SETS`) ;
  - jeux de clips : `anim_set_<perso>.gd`, `anim_set_common.gd`, `anim_set_emotes*.gd`, `anim_set_kills.gd` (exemple récent de clips longs écrits à la main) ;
  - visage : `anim_face.gd` ; style : `anim_style.gd` ;
  - `character_visual.gd` (`PaperVisual`) : squelette, mixage des clips, locomotion, visage ;
  - `imported_character.gd`.
- **Cinématiques** :
  - `cinematics.gd` (`PaperCinema`) : films écrits en timeline (`_shot`, `_move`, `_do`, `_cue`…), dont `_write_escape` (fuites en équipe) et `_write_kill` (« Alice · X rattrapé(e) ») ;
  - `film_intro_yiero.gd` (prologue), `yiero_model.gd` (le démon), `intro_dimension.gd`, `intro_overlay.gd` ;
  - `film_victories.gd` (victoires LMS), `film_blocus.gd`, `film_execution_end.gd` ;
  - `cinema_props.gd`, `gallery.gd` (cinémathèque), `fx_comic.gd`, `fx_screen.gd`, `effects.gd`.
- **UI** :
  - `ui.gd` (`PaperUI`, tous les menus), `ui_hud.gd`, `ui_theme.gd`, `ui_widgets.gd`, `ui_collage.gd` ;
  - `ui_menu_vignettes.gd` (scènes 3D de survol de l'écran titre) ;
  - `ui_pause_menu.gd`, `emote_wheel.gd`, `online_menu.gd`, `controls_menu.gd`.
- **Audio** : `audio.gd` (`PaperAudio`, bus PaperMusic/PaperWorld/PaperFeedback), `dances.gd`, `audio/`.
- **Partie** : `escape_flow.gd`, `exit_alarm.gd`, `kill_scenes.gd`, `game_rules.gd` (`PaperRules`, `PROTOCOL` : ne le change pas), `data.gd` (stats et textes des capacités), `brain.gd` (IA).

## Outils et tests (obligatoires avant de rendre ton travail)
- **Import** : dans ta copie de travail, lance d'abord **une fois** `godot --headless --import` (environ 2 min ; crée le cache `.godot/`, ignoré par git).
- **Erreurs de script** : `timeout 200 godot --headless --quit-after 400 2>&1 | grep -E "SCRIPT ERROR|Parse Error|ERROR:"`. La sortie doit être vide, hors erreurs audio ALSA.
- **Partie simulée** (bots, sans rendu) : `timeout 300 godot --headless -- --simulate Simon --duration 60 --report /tmp/<toi>/rep.json`.
  - Personnages : Ashura, Usayuko, Simon, Lysia, Elly, Bleuette, Alice.
  - Options : `--scenario lms|killer_win|survivor_win`, `--map school|forest|snow`, `--speed 4`, `--seed N`.
- **Capture rendue** (llvmpipe, lent mais fonctionnel) : `timeout 300 xvfb-run -a -s "-screen 0 1280x800x24" godot --rendering-driver opengl3 -- --simulate Simon --duration 14 --capture /tmp/<toi>/cap.png --capture-at 10`.
  - **Regarde tes captures avec l'outil Read.**
- **Outils de test sur mesure** : `-- --tool nom` charge `res://tools/nom.gd`, un `Node` avec `func setup(world)` où `world` est le nœud main.
  - Beaucoup d'outils existent déjà dans `tools/` (test_intro, test_victory, test_victory_lms, film_capture, test_film_fusion, test_kills, test_mechanics, test_menus, test_menu_perf, test_player_path…) : lis leur en-tête.
  - Crée tes propres outils pour piloter une situation, forcer une animation ou faire des planches d'images. Capture avec `get_viewport().get_texture().get_image().save_png(...)` après `await RenderingServer.frame_post_draw`, puis `get_tree().quit()`.
- **Machine partagée** : elle n'a que 4 cœurs et d'autres agents travaillent en même temps. Utilise toujours `timeout`, fais des runs courts, préfère `--headless` pour la logique et garde les captures rendues pour le visuel.
- **Réglages isolés** : lance tes outils avec un `XDG_DATA_HOME` de test (un dossier à toi), pour ne pas toucher le `settings.cfg` partagé.

## Règles de travail
1. Tu travailles dans ta propre copie git (worktree).
   - **Commit souvent** ton travail sur ta branche, avec des messages clairs en français : la machine peut être réinitialisée.
   - Ne pousse pas.
   - Plusieurs agents modifient le projet en parallèle et l'intégrateur fusionnera : **ne reformate pas** les fichiers, ne renomme rien, ne déplace pas de code.
   - Fais des modifications ciblées dans les fichiers partagés et mets le gros de ta fonctionnalité dans **de nouveaux fichiers** dédiés.
2. Respecte le style du code existant : GDScript typé, tabulations, `class_name Paper…` ou `preload`. Écris des commentaires seulement là où ils aident.
3. **Multijoueur** : la simulation tourne chez l'hôte.
   - Tout état visible par les clients passe par les mécanismes existants : `effects` + `NET_EFFECT_RULES`, messages et événements de `main.gd`, instantanés.
   - Les bots doivent pouvoir utiliser ce que tu ajoutes quand c'est pertinent.
4. Le joueur est très exigeant sur la qualité visuelle : poses réalistes, visages expressifs, effets « film ». Vérifie visuellement avec des captures, corrige ce qui est moche, recommence.
5. **Musique et sons** : toute musique ou tout son que tu crées est composé par code (python3 + numpy, ffmpeg/libvorbis pour l'.ogg), avec le meilleur soin possible.
   - Niveau cible d'une musique : -18 LUFS intégrés, pic ≤ -1 dBFS.
   - Mesure avec `ffmpeg -af ebur128`.
6. N'invente pas de résultats. Si un test échoue ou si tu n'as pas pu vérifier quelque chose, dis-le.
