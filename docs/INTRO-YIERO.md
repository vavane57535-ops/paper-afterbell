# Prologue — Yiero (cinématique d'introduction, 0.16)

Film joué **une seule fois automatiquement**, au tout premier lancement du jeu (avant le menu), puis
revisionnable dans **Cinémathèque → « Prologue — Yiero »** (première entrée). Durée : **3 min 16 s (196 s)**.

- Code : `film_intro_yiero.gd` (`PaperPrologue`, le film, extension de `PaperCinema`),
  `yiero_model.gd` (`PaperYiero`, le démon construit par code), `intro_dimension.gd` (`PaperIntroVoid`,
  la dimension ténébreuse), `intro_overlay.gd` (`PaperIntroOverlay`, bandes, dialogues façon Undertale,
  jauge « Maintenir pour passer », carton-titre).
- Drapeau de premier lancement : `user://settings.cfg`, section `[story]`, clé `intro_seen` (booléen).
  Pour revoir le lancement automatique : supprimer la clé (ou le fichier).
- Passer le film : **maintenir** Échap, Espace, Entrée ou le bouton A de la manette (~1,1 s, jauge en bas à droite).
- Musique provisoire : `audio/cinematic/intro_yiero.ogg` (196 s, synthétisée par `tools/synth_intro_audio.py`).
  **À remplacer** par une vraie composition au **même minutage** (feuille de minutage plus bas).
- Bruitages : `audio/cinematic/sfx_*.wav` (synthétisés par le même script) + `audio/sfx/*` existants.
- Voix : **aucune voix humaine** (retirées en 0.13.1) ; chaque personnage parle par « blips » synthétisés
  (une petite onomatopée par lettre, comme dans Undertale), sous-titres français.

## Personnages et voix (blips)

| Perso | Caractère dans le film | Blip |
|---|---|---|
| Simon | éclaireur, rapide, nerveux mais courageux, parle vite | carré aigu ~640 Hz, 34 ms, 40 lettres/s |
| Ashura | observateur posé, bricoleur (drone, rollers), protecteur, phrases courtes | triangle ~300 Hz, 52 ms, 24 lettres/s |
| Yiero | démon colossal, sadique, moqueur, lent | dent de scie ~70 Hz + sous-octave + saturation + bruit, 120 ms, 11 lettres/s |
| Usayuko | protecteur, bagarreur, rieur, déjanté | carré grave ~250 Hz, 44 ms |
| Elly | soigneuse calme et rassurante | sinus ~540 Hz, 48 ms |
| Bleuette | timide, bégaie | sinus aigu ~860 Hz, 36 ms |
| Lysia | automate, voix « robot » cassée | carré bit-crushé + modulation en anneau ~430 Hz |

Armes bénies des dieux : **lumière dorée qui jaillit des poings** de Simon et d'Ashura, en plus de leurs
outils habituels du jeu (Simon : flashbang, poing éclair, course éclair / esquive ; Ashura : drone, rollers).

## Storyboard (plans, durées, dialogues, sons)

Temps en secondes depuis le début du film.

### Acte I — La dimension ténébreuse (0 → 30)
| # | Temps | Plan | Action / visage | Dialogue | Son |
|---|---|---|---|---|---|
| 1 | 0,0–5,0 | Noir | Carton « Avant la première sonnerie… » | — | drone grave, vent |
| 2 | 5,0–12,0 | Très grand plan large, grue qui descend | Mer d'encre, ciel rouge-noir avec éclipse, débris de papier en lévitation, brume ; deux silhouettes minuscules marchent. À 9,4 s l'encre frémit au loin (grandes ondes) : quelque chose bouge dessous. | — | nappe sombre, grondement lointain |
| 3 | 12,0–17,0 | Travelling latéral au ras de l'encre | Pas dans l'encre, ondes concentriques ; lueur dorée discrète dans les poings | — | pas mouillés |
| 4 | 17,0–24,0 | Plan à deux de face, la caméra recule devant eux | Simon inquiet (regard qui balaie), Ashura concentré | Simon : « C'est calme… beaucoup trop calme. » / Ashura : « Mes drones ne captent rien. Pas un seul écho. » | pulsation lente |
| 5 | 24,0–30,0 | Par-dessus l'épaule d'Ashura vers le vide | Battements lointains (25,0 / 26,2 / 27,4) ; Simon sursaute et s'arrête ; le ciel s'assombrit, l'éclipse s'éteint | Simon : « Hé… T'as entendu ça ? » | **silence 29–30** |

### Acte II — L'apparition (30 → 58)
| # | Temps | Plan | Action / visage | Dialogue | Son |
|---|---|---|---|---|---|
| 6 | 30,0–34,0 | Gros plan Simon, lente poussée | Peur ; derrière lui, dans le noir, **deux yeux ronds pâles** s'ouvrent | — | chute de sous-basse |
| 7 | 34,0–40,0 | Contrechamp large, contre-plongée | Seuls les yeux et le **sourire** existent ; le sourire se fend lentement, dents pointues, gencives rouges, reflets humides | Yiero : « Hm hm hm… Deux petites lumières… » | cordes dissonantes |
| 8 | 40,0–46,0 | Panoramique vertical (tilt) de bas en haut | Révélation de la taille : épaules qui sortent de l'encre, mains griffues géantes qui émergent de chaque côté ; tremblements | — | grondement, crescendo |
| 9 | 46,0–52,0 | Ultra contre-plongée au ras de l'encre | Le visage remplit l'écran, se penche ; **la mâchoire s'ouvre** → **RUGISSEMENT** (50,2) : onde de choc, tempête de papier | Yiero : « …perdues dans MA dimension. » | **impact 50,2** |
| 10 | 52,0–58,0 | Plan moyen, vent de face | Ils résistent au souffle ; détermination ; à 55,0 **les poings s'embrasent d'or** | Ashura : « Simon. Les armes bénies. Maintenant. » / Simon : « Ouais ! On le renvoie d'où il vient ! » | montée héroïque, impact 55,0 |

### Acte III — Le combat (58 → 104)
| # | Temps | Plan | Action | Dialogue | Son |
|---|---|---|---|---|---|
| 11 | 58,0–62,0 | Plan héroïque en contre-plongée, orbite lente | Dos à dos, poings dorés, Yiero en fond | — | **DROP 58,0** |
| 12 | 62,0–65,5 | Plongée large | La griffe s'abat (impact 63,2, **ralenti** 63,2–63,9) ; Simon esquive à gauche, Ashura file à droite en rollers | — | impact 63,2 |
| 13 | 65,5–70,0 | Travelling rapide de profil | Course éclair de Simon (traînées) ; saut à 68,4 ; flashbang dorée lancée vers l'œil | — | whoosh |
| 14 | 70,0–73,0 | Gros plan œil de Yiero | Explosion dorée (69,5) ; l'œil se plisse, la tête recule | — | flash, grognement |
| 15 | 73,0–77,0 | Travelling bas sur Ashura en rollers | Glisse, lance le drone doré (74,6) → impact sur les dents (76,0), un éclat de dent saute | Simon : « Il recule ! Ashura, il recule ! » | impact 76,0 |
| 16 | 77,0–82,0 | Over-the-shoulder derrière eux en plein saut | Double coup de poing doré sur la mâchoire, **ralenti 79,0–80,2**, onde d'or, la tête part en arrière | Ashura : « Ensemble ! Vise la mâchoire ! » | **impact 79,0**, accord majeur (espoir) |
| 17 | 82,0–87,0 | Contre-champ par-dessus l'épaule de Yiero (masse noire au premier plan) | Ils atterrissent ; la tête revient lentement… le sourire s'élargit encore | Yiero : « Ha… Ha ha ha ha. C'est tout ? » | musique coupée, rire |
| 18 | 87,0–92,0 | Plan large, ciel qui tourbillonne | Retournement : les yeux s'embrasent, l'ombre s'étend, la lueur dorée vacille | Yiero : « Votre petite lumière… je vais l'ÉTEINDRE. » | variation sombre |
| 19 | 92,0–97,0 | Plan latéral rapide | Revers de main géant : Simon est projeté (**ralenti 92,9–93,4**), glisse sur l'encre | Ashura : « SIMON ! » | impact 92,9 |
| 20 | 97,0–104,0 | Contre-plongée | Ashura fonce en rollers vers Simon, la main s'abat devant lui et **l'attrape** (99,4) entre ses griffes, le soulève, minuscule, devant le visage | Yiero : « Toi, le petit observateur… Je vais t'effacer. » | impact 99,4 |

### Acte IV — La défaite (104 → 122)
| # | Temps | Plan | Action | Dialogue | Son |
|---|---|---|---|---|---|
| 21 | 104,0–109,0 | Gros plan bas sur Simon au sol | Douleur, panique, il tend la main | Simon : « ASHURA ! Lâche-le ! » | élégie |
| 22 | 109,0–113,5 | Gros plan Ashura dans la griffe | Tristesse puis calme résigné, la lumière dorée s'éteint | Ashura : « Simon… cours. Ne te retourne pas. » | voix soliste |
| 23 | 113,5–119,0 | Plan moyen puis large | Ashura pendu aux griffes devant la gueule grande ouverte ; **il est effacé** : il se décolore, puis se désintègre en papier et en encre des pieds à la tête (bord doré qui brûle), les lambeaux s'envolent vers la bouche de Yiero ; son drone tombe dans l'encre | — | déchirure de papier, souffle inversé |
| 24 | 119,0–122,0 | Très gros plan Simon | Désespoir, cri | Simon : « ASHURAAA ! » | **silence 119,2–121** |

### Acte V — La course-poursuite (122 → 148)
| # | Temps | Plan | Action | Dialogue | Son |
|---|---|---|---|---|---|
| 25 | 122,0–126,0 | Plongée sur Simon, la tête de Yiero descend | Simon se relève, recule, se retourne et court (125,0) | Yiero : « Un de moins. À ton tour, petite lumière. » | — |
| 26 | 126,0–131,0 | **Caméra frontale** qui recule devant Simon | Panique ; le visage de Yiero remplit tout le fond et gagne du terrain | Simon : « Non non non non non… » | 160 bpm, battements |
| 27 | 131,0–135,5 | Travelling latéral bas | Griffes qui transpercent l'encre (132,0 et 133,6), geysers d'encre ; esquive | — | impacts |
| 28 | 135,5–140,0 | Plongée très large | Simon minuscule, les mains de Yiero avancent comme une araignée | Yiero : « Cours ! COURS ! C'est tellement plus drôle ! » | — |
| 29 | 140,0–144,5 | Derrière Simon, au ras du sol | Sursaut doré, vitesse maximale ; au loin un rectangle de lumière chaude : une porte | Simon : « Une porte… ?! » | cordes d'espoir |
| 30 | 144,5–148,0 | Frontale serrée | Épuisé mais déterminé ; la gueule s'ouvre derrière lui, la mâchoire racle le sol | Yiero : « Tu ne m'échapperas JAMAIS. » | pression maximale |

### Acte VI — La porte (148 → 154)
| # | Temps | Plan | Action | Son |
|---|---|---|---|---|
| 31 | 148,0–151,0 | Over-the-shoulder, porte éblouissante | Simon plonge (149,2), **ralenti 149,2–150,6** | accord tenu |
| 32 | 151,0–154,0 | Blanc | Les dents claquent juste derrière lui (150,6), blanc total, acouphène ; la sonnerie de l'école retentit (153,2) | **CHOMP 150,6**, cloche |

### Acte VII — L'école Paper Afterbell (154 → 182)
| # | Temps | Plan | Action | Dialogue |
|---|---|---|---|---|
| 33 | 154,0–157,5 | Hall de l'école (carte école) | Un portail de papier lumineux ; Simon en jaillit et roule au sol, épuisé ; dans le portail qui se referme, les yeux et le sourire de Yiero apparaissent une demi-seconde | — |
| 34 | 157,5–162,0 | Panoramique filé vers le combat | **Usayuko contre Alice**, aura hyper stylée (flammes or et blanc, anneau de runes au sol, talismans de papier en orbite, éclairs) : griffe d'Alice, blocage, contre, coup de poing | — |
| 35 | 162,0–166,0 | Plan large dynamique | Dropkick d'Usayuko, Alice projetée ; Usayuko éclate de rire | Usayuko : « HA HA ! C'est tout ce que t'as, Alice ?! » |
| 36 | 166,0–170,0 | Sur le côté | Elly soigne Bleuette blessée (zone de soin, croix de soin) | Elly : « Tiens bon, Bleuette. Personne ne reste en arrière. » / Bleuette : « J-je vais bien… enfin, je crois… » |
| 37 | 170,0–173,5 | Plan serré | Lysia à moitié cassée, à genoux branchée à une prise : étincelles électriques, lumière qui grésille, vapeur | Lysia : « Armure à quarante pour cent… Je tiens encore. » |
| 38 | 173,5–177,0 | Champ / contrechamp | Usayuko remarque Simon ; Simon se relève, le poing brille d'or une dernière fois | Usayuko : « SIMON ?! T'étais passé où, toi ?! » / Simon : « …Longue histoire. Je suis avec toi ! » |
| 39 | 177,0–182,0 | Plan héroïque | Simon fonce et frappe Alice en même temps qu'Usayuko (179,0) → **arrêt sur image** façon case de BD, puis noir (181,6) | — |

### Acte VIII — Le titre (182 → 196)
| # | Temps | Action |
|---|---|---|
| 40 | 182,0–184,6 | Noir ; les yeux de Yiero apparaissent en surimpression, le sourire s'ouvre |
| 41 | 184,6 | **« PAPER AFTERBELL »** (logo du jeu) claque au centre |
| 42 | 186,6–192,0 | Dessous, en rouge, tapé lettre par lettre avec la voix de Yiero : « Bienvenue dans votre nouvel enfer. » |
| 43 | 192,0–196,0 | Les yeux et le sourire se dissolvent, fondu au noir → menu |

## Feuille de minutage musicale (pour la vraie composition)

Fichier attendu : `audio/cinematic/intro_yiero.ogg`, **196,0 s**, stéréo, 44,1/48 kHz, sans boucle.
Le film suit le minutage ci-dessous à la seconde près (les impacts visuels tombent sur ces temps).
Tonalité suggérée : ré mineur ; thème principal = motif de 4 notes descendant (ré–do–la–sol♯) qui revient
en majeur au moment d'espoir (79 s) et en boîte à musique désaccordée pour la phrase finale.

| Début | Fin | Section | Ambiance / instrumentation | Intensité (0–10) | Points de synchro |
|---|---|---|---|---|---|
| 0,0 | 5,0 | Ouverture | noir, drone sous-grave 30–40 Hz, vent | 1 | — |
| 5,0 | 17,0 | Dimension | nappe sombre, chœur lointain très bas, réverbération immense | 2 | — |
| 17,0 | 24,0 | Marche | + pulsation sourde 50 bpm (comme un cœur) | 2–3 | — |
| 24,0 | 29,0 | Tension | harmonique de cordes aiguës en trémolo, crescendo | 3→5 | battements 25,0 / 26,2 / 27,4 |
| 29,0 | 30,0 | **Silence** | rien | 0 | — |
| 30,0 | 34,0 | Peur | chute de sous-basse (30,2), une note grave de piano (32,0) | 3 | 30,2 |
| 34,0 | 46,0 | Horreur | clusters de cordes dissonants qui montent, cuivres graves, tic-tac | 4→6 | grondement 40,0 |
| 46,0 | 50,0 | Suspense | accord dissonant tenu, crescendo | 6→7 | — |
| 50,0 | 52,0 | Rugissement | **impact orchestral massif 50,2** (cuivres + percussions), puis creux | 8 | **50,2** |
| 52,0 | 58,0 | Montée héroïque | ostinato de cordes + taikos, 140 bpm ; chœur entre sur l'embrasement doré | 6→8 | **55,0** |
| 58,0 | 82,0 | Combat épique | orchestre complet + chœur + taikos, 140 bpm, ostinato | 8–9 | **58,0** drop, 63,2, 69,5, 76,0, **79,0** (accord majeur, espoir, 79–82) |
| 82,0 | 87,0 | Moquerie | tout s'arrête sauf une note grave tenue ; rire de Yiero | 4 | 83,0 |
| 87,0 | 104,0 | Retournement | variation sombre et lourde du thème, demi-tempo (70 bpm) | 9 | 92,9, 99,4 |
| 104,0 | 119,2 | Défaite | élégie de cordes, voix soliste ; souffle inversé pendant l'effacement (113,8–117,5) | 5 | 113,8 |
| 119,2 | 121,0 | **Silence** | seulement un sifflement d'oreille | 0 | 119,2 (cri) |
| 121,0 | 122,0 | Reprise | sous-basse menaçante | 3 | — |
| 122,0 | 148,0 | Course-poursuite | frénétique 160 bpm, percussions, cordes staccato, coups de cuivres | 9→10 | 132,0, 133,6 ; 140,0 cordes aiguës « d'espoir » (la porte) |
| 148,0 | 150,6 | Plongeon | énorme accord tenu (ralenti) | 10 | — |
| 150,6 | 153,2 | **Silence blanc** | sinus aigu (acouphène) | 0 | **150,6** CHOMP |
| 153,2 | 157,5 | École | sonnerie (bruitage), petit motif de piano doux | 2 | 153,2 |
| 157,5 | 166,0 | Bagarre déjantée | rock/électro énergique et fun, 165 bpm | 7 | — |
| 166,0 | 173,5 | Côté soin | même groove filtré, discret sous les dialogues | 4 | — |
| 173,5 | 179,0 | Simon rejoint | reprise héroïque | 7→9 | **179,0** coup double |
| 179,0 | 182,0 | **Arrêt sur image** | coupure nette à 179,2, silence | 0 | — |
| 182,0 | 184,6 | Retour du démon | drone sombre, battements graves | 3 | — |
| 184,6 | 186,6 | **Titre** | impact orchestral + chœur (stinger du titre) | 9 | **184,6** |
| 186,6 | 192,0 | « Bienvenue… » | boîte à musique désaccordée sur le thème, très sinistre | 3 | — |
| 192,0 | 196,0 | Fin | fondu au silence | 1→0 | 196,0 |

## Vérification
- `tools/test_intro.gd` (voir l'en-tête du fichier) : `--intro-mode scan` (lecture complète sans rendu, répliques,
  retours en arrière), `capture` (une image toutes les 2 s + moments clés ; lancer avec `--fixed-fps 8`),
  `gallery` (lecture/pause/avance/retour depuis la cinémathèque), `first` / `second` (premier lancement puis
  lancement suivant, à lancer avec un `XDG_DATA_HOME` de test et `--first-launch`).
- Le prologue ne se lance pas automatiquement avec `--simulate`, `--capture`, `--dedicated`, `--tool` (sauf
  `--first-launch`), `--menu-preview` ni `--no-intro`.

## Notes de réalisation
- Inspirations de mise en scène : contre-plongées et échelle « kaiju » (Shadow of the Colossus, Attack on Titan),
  ralentis sur les impacts et plans over-the-shoulder des combats finaux (Dark Souls / Elden Ring,
  Naruto vs Sasuke, Dragon Ball), course-poursuite caméra frontale (Inside, Little Nightmares),
  arrêt sur image façon case de BD pour le dernier coup (Persona 5).
- Yiero n'a pas de paupières : son regard reste fixe ; ses pupilles minuscules suivent sa cible.
- Le film est entièrement déterministe en fonction du temps (la cinémathèque peut avancer, reculer, mettre en pause).
