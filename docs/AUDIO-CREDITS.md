# Paper Afterbell 0.13 — crédits audio

Cette version utilise six montages de compositions de Scott Buckley (le septième, « Emergent », ancien LMS de Bleuette, n'est plus inclus), utilise les trois OST de Simon, Usayuko et Bleuette fournies par le propriétaire du projet, et 79 variantes de bruitages enregistrés CC0. L'ancien LMS de Bleuette n'est plus utilisé en partie. La True Form utilise Juggernaut à 86 % de vitesse de lecture ; elle suspend le LMS, repris à la fin de la forme.

## OST fournies pour ce projet

| Personnage | Fichier fourni | Durée complète | Format intégré | Ajustement de lecture |
| --- | --- | --- | --- | --- |
| Simon | Simon OST final mais vrmt final la ça y est c'est fini.mp3 | 5 min 10,91 s | MP3 stéréo 44,1 kHz, original 192 kbit/s | +1,34 dB |
| Usayuko | USAYUKO OST.wav | 4 min 43,17 s | Ogg Vorbis q8 stéréo 44,1 kHz, converti depuis le WAV fourni (durée identique) | −6,96 dB |
| Bleuette | BLEUETTE LMS.mp3 | 3 min 21,53 s | MP3 original conservé | −12,00 dB |

Ces trois OST remplacent les anciennes musiques LMS de ces personnages. Elles ne sont pas attribuées à Scott Buckley. Les noms d'artistes et les licences de redistribution publique n'ont pas été précisés avec les pièces jointes ; aucune licence Creative Commons ne leur est attribuée. En 0.11, chaque LMS dure exactement la durée de sa piste, avec suspension du temps et de la piste pendant la True Form.

Les MP3 de Simon et de Bleuette sont intégrés tels quels, octet pour octet. En 0.12, le WAV d'Usayuko (50 Mo) est intégré en Ogg Vorbis haute qualité (q8, 44,1 kHz, stéréo), de durée identique, pour alléger le jeu ; il n'y a aucune autre modification (ni tempo, ni hauteur, ni stéréo, ni découpage). Les trois pistes reçoivent un gain constant visant −17,5 LUFS : +1,34 dB pour Simon, −6,96 dB pour Usayuko et −12,00 dB pour Bleuette, dont la piste était environ 12 dB plus forte que les autres. La durée complète du morceau détermine désormais le LMS. Dans le terrain d'essai prolongé, la fin naturelle est suivie d'un redémarrage avec un fondu de 1,35 seconde. Les mêmes OST accompagnent les aperçus des fins LMS dans la galerie.

Les fichiers d'origine sont inclus dans le projet source sous `game/audio/lms_simon_user.mp3` et `game/audio/lms_usayuko_user.wav`. AUDIO-SOURCES.json contient leurs empreintes SHA-256 et les mesures.

## Musique — Scott Buckley

Licence : [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/). [Conditions officielles de la bibliothèque](https://www.scottbuckley.com.au/library/using-this-music/).

| Utilisation | Composition originale | Durée intégrée |
| --- | --- | --- |
| Couloirs et attente | [Signal to Noise](https://www.scottbuckley.com.au/library/signal-to-noise/) — Scott Buckley | 180 s |
| Poursuite d’Alice | [Juggernaut](https://www.scottbuckley.com.au/library/juggernaut/) — Scott Buckley | 166 s |
| Sortie et fin de partie | [Echoes Of Home](https://www.scottbuckley.com.au/library/echoes-of-home/) — Scott Buckley | 110 s |
| LMS Ashura — tension et surveillance | [Red](https://www.scottbuckley.com.au/library/red/) — Scott Buckley | 158 s |
| LMS Elly — courage et espoir | [Helios](https://www.scottbuckley.com.au/library/helios/) — Scott Buckley | 158 s |
| LMS Bleuette — pression, puis sursaut | [Emergent](https://www.scottbuckley.com.au/library/emergent/) — Scott Buckley | 158 s |
| LMS Lysia — résistance héroïque | [Vanguard](https://www.scottbuckley.com.au/library/vanguard/) — Scott Buckley | 158 s |

Attributions à conserver avec toute redistribution du jeu :

- “Signal to Noise” by Scott Buckley — released under CC-BY 4.0. www.scottbuckley.com.au
- “Juggernaut” by Scott Buckley — released under CC-BY 4.0. www.scottbuckley.com.au
- “Echoes Of Home” by Scott Buckley — released under CC-BY 4.0. www.scottbuckley.com.au
- “Red” by Scott Buckley — released under CC-BY 4.0. www.scottbuckley.com.au
- “Helios” by Scott Buckley — released under CC-BY 4.0. www.scottbuckley.com.au
- “Emergent” by Scott Buckley — released under CC-BY 4.0. www.scottbuckley.com.au
- “Vanguard” by Scott Buckley — released under CC-BY 4.0. www.scottbuckley.com.au

Modifications : sélection d’extraits, ajustement du niveau sonore, conversion des MP3 officiels en Ogg Vorbis stéréo 44,1 kHz, raccord de boucle par fondu de 2 secondes. Elly comporte aussi une jonction de 4 secondes entre deux passages du même morceau. Le tempo et la hauteur des musiques sont conservés. Les minutages exacts et les empreintes des sources sont dans AUDIO-SOURCES.json.

Les quatre pistes LMS de Scott Buckley couvrent 158 secondes sans reprise. Le duel se règle sur 120, 150 ou 180 secondes : les deux premiers réglages restent dans la première lecture ; à 180 secondes, le morceau reboucle avec son raccord intégré après 158 secondes. Les fondus entre ambiance, poursuite, LMS et fin durent 1,35 seconde. Les titres d’artiste sont également affichés pendant le LMS et les crédits sont intégrés au jeu.

Ces morceaux existent déjà dans la bibliothèque de l’artiste ; ce ne sont pas des compositions exclusives réalisées pour Paper Afterbell. Les arrangements hybrides comportent parfois des synthétiseurs modernes et des instruments échantillonnés. Ils ne sont pas présentés comme des prises acoustiques intégralement jouées en direct.

## Bruitages — enregistrements et foley CC0

Licence commune : [CC0 1.0 Universal](https://creativecommons.org/publicdomain/zero/1.0/). Les auteurs n’exigent pas d’attribution sous CC0 ; nous les créditons néanmoins.

- [Impact Sounds (1.0)](https://kenney.nl/assets/impact-sounds) — Kenney. [Archive source](https://kenney.nl/media/pages/assets/impact-sounds/87b4ddecda-1677589768/kenney_impact-sounds.zip).
- [RPG Audio](https://kenney.nl/assets/rpg-audio) — Kenney Vleugels. [Archive source](https://kenney.nl/media/pages/assets/rpg-audio/8e99002d76-1677590336/kenney_rpg-audio.zip).
- [The Free Firearm Sound Library](https://opengameart.org/content/the-free-firearm-sound-library) — Ben Jaszczak, Brian Nelson, Kevin Heras, Matthew Nanney. [Archive source](https://opengameart.org/sites/default/files/Prepared%20SFX%20Library.7z).
- [Shotgun Reload Sound effects](https://opengameart.org/content/shotgun-reload-sound-effects) — zer0_sol. [Archive source](https://opengameart.org/sites/default/files/shotgunsounds.zip).

Les quatre prises ajoutées pour les cinématiques proviennent de RPG Audio : `doorOpen_1.ogg`, `doorOpen_2.ogg`, `creak1.ogg` et `creak2.ogg`. Elles sont converties en PCM mono 44,1 kHz / 16 bits avec un gain de 0,8 et un fondu initial de 4 ms.

Kenney fournit les pas sur béton, bois, herbe et neige, impacts, cliquetis, tissus, verre, cuir et bois. Les tirs proviennent des véritables prises de Winchester Model 12 et Mossberg (fichiers K_17P, K_22P et N_30P, source 96 kHz / 24 bits). La manipulation du fusil utilise Rack.mp3 de zer0_sol.

Les effets fantastiques sont du sound design : les ombres associent un craquement de bois inversé et du tissu ralenti ; les piques associent roche et fracture de bois ; la flashbang combine un bref claquement de tir et une résonance métallique. Ce ne sont pas des enregistrements littéraux de pouvoirs imaginaires. Aucun bruitage n’utilise les anciens oscillateurs, sons carrés ou séquences 8 bits.

Modifications des bruitages : retrait du silence, mélanges de prises, légères variations de hauteur, fondus courts, conversion PCM mono 44,1 kHz / 16 bits, crêtes visées à −4,5 dBFS. AUDIO-SOURCES.json donne les fichiers d’origine pour chaque variante ; les notices Kenney d’origine sont dans AUDIO-LICENSES.

## Captures et vidéos du jeu

Les sept compositions de Scott Buckley restent soumises à CC-BY 4.0. Les deux OST fournies pour Simon et Usayuko sont distinctes de cette licence. Pour publier une vidéo avec cette bande-son, conserver le crédit des morceaux utilisés dans sa description, conformément aux indications de l’artiste. Les sources et licences présentes dans ce dossier doivent accompagner les redistributions du jeu.

Sources CC0/CC-BY vérifiées le 7 septembre 2026 ; intégration des OST fournies et de quatre prises de portes le 8 septembre 2026.

## Ajouts de la 0.12

- Battements de cœur à l'approche d'Alice : son de synthèse créé pour le jeu (`audio/fx_heartbeat.wav`).
- Jingles de sortie ouverte, d'évasion, d'élimination et de début de poursuite : montages des bruitages CC0 déjà crédités ci-dessus.
- Sons d'interface (survol, clic, retour, validation, changement de page) : sons de synthèse créés pour le jeu.
- L'ancien LMS « Emergent » de Bleuette, qui n'était plus utilisé, n'est plus inclus dans le jeu.

## Ajouts de la 0.13

**Nouvelles musiques** : « Fin des cours » (menu), « Sous les pins d'encre » (forêt), « Craie et givre » (neige), « Retenue » (défaite). Compositions originales créées pour le jeu, construites sur le carillon d'école de Westminster (domaine public).

**Ambiances et bruitages** : enregistrements issus de https://github.com/Fris0uman/CDDA-Soundpacks (dossier CC-Sounds). Seuls des fichiers sous licence CC0 ou CC BY ont été utilisés, crédités à leurs auteurs d'origine sur freesound.org :
- intérieur — blouhond (CC BY 3.0, freesound 163604)
- bourdonnement électrique — nicola_ariutti (CC BY 4.0, freesound 335365)
- nuit claire — rsn267 (CC0, freesound 275595) ; nuit nuageuse — beambot (CC0, freesound 259987)
- tempête de neige — guyburns (CC0, freesound 473815) ; flocons — florianreichelt (CC0, freesound 453167)
- pas sur sol dur — kretopi (CC0, freesound 406744–406749) ; pas sur terre — nuFF3 (CC BY, freesound 477390–477396)
- coups de poing — deleted_user_7146007 (CC0) ; impacts — mateusboga (CC0) ; mouvements — PorkMuncher et qubodup (CC0) ; porte métallique — Fabrizio84 (CC0)

Sons synthétisés pour le jeu : étoiles d'étourdissement, présence d'Alice, chouettes, déchirure de papier du menu.

## Ajouts de la 0.16

**Musiques générées avec ElevenLabs Music (v2.5), sur le compte ElevenLabs du joueur :**
- Prologue « Yiero » (`audio/cinematic/intro_yiero.ogg`, 196 s) : 13 sections composées séparément (ambiance, horreur, combat épique, retournement, élégie, poursuite, bagarre rock-électro, titre…), assemblées à la seconde près sur le film, avec silences, acouphène et boîte à musique désaccordée synthétisés pour le jeu.
- Course vers la sortie (`audio/exit_rush.ogg`, 80 s), qui s'intensifie jusqu'au final.
- Blocus (`audio/cinematic/blocus.ogg`, environ 39 s), volontairement ringard : flûte à bec, kazoo, tambour jouet.

**Compositions et sons créés par programme pour le jeu (synthèse) :**
- Les 18 musiques de danse (10 nouvelles et 8 recomposées), au BPM de chaque chorégraphie, en boucles sans clic. Mélodies, accords et instruments sont originaux ; seuls le genre, le tempo et l'ambiance s'inspirent des tendances citées.
- Les 6 stingers des victoires LMS, un par personnage.
- Les « blips » de dialogue façon Undertale et les bruitages du prologue (rugissement, impacts, papier).
- Les bruitages des exécutions d'Alice, l'alarme d'ouverture de la sortie et son dernier appel.
- Les sons d'émotes (clap, claque, bisou, obturateur…) et les nouveaux sons de curseur, de balayage, d'ouverture et de fermeture des menus.

**Niveaux :** toutes les musiques, y compris les OST fournies, sont normalisées à -18 LUFS intégrés par gain linéaire seul, sans compression. Les MP3 de Simon et de Bleuette sont donc ré-encodés (320 kbit/s) et ne sont plus identiques octet pour octet aux fichiers fournis. Celui de Bleuette, à -5,5 LUFS avec écrêtage, était la principale source de musique trop forte. La musique est ensuite baissée d'environ 7 dB dans le mixage du jeu.
