export const meta = {
  name: 'paper-afterbell-017',
  description: 'Paper Afterbell 0.17: Opus-only rework (title-screen scenes, natural texts, bespoke film animation, Simon Sonic run and carries, new Yiero model), one implementer then one adversarial reviewer per lot',
  phases: [
    { title: 'Implement', detail: 'one Opus agent per lot, in its own worktree' },
    { title: 'Review', detail: 'adversarial Opus reviewer per lot, fixes in the same worktree' },
  ],
}

const SP = '/tmp/claude-0/-home-user-paper-afterbell/3b6367fd-efb2-542d-99d0-4363092d5bea/scratchpad/'
const WT = '/home/user/paper-afterbell/.claude/worktrees/'
const MODEL = 'opus'

const LOTS = [
  { key: 'menus', title: 'Scènes de survol de l\'écran titre (toutes refaites, Réglages compris)', focus:
    'Refais toutes les scènes de survol de l\'écran titre (ui_menu_vignettes.gd) : settings (RÉGLAGES), play (JOUER), training (TERRAIN D\'ESSAI), friends (ENTRE AMIS), gallery (CINÉMATHÈQUE), credits (CRÉDITS), quit (QUITTER), shop (BOUTIQUE). La scène « dance » (aperçu d\'une danse précise depuis la boutique) reste la danse demandée. Refais AUSSI « settings » (Ashura qui répare Lysia) : le joueur a changé d\'avis, elle fait « gif » elle aussi. '
    + 'Pour chaque scène : une vraie petite scène mise en scène, longue (au moins 20 à 40 s avant de revenir au début), avec un début, des petits rebondissements et des moments de jeu d\'acteur, et une boucle INVISIBLE. Pour la boucle : pose finale qui raccorde exactement à la première, changement de plan ou fondu qui masque le retour, ou plusieurs variantes tirées au hasard pour ne jamais rejouer la même chose deux fois de suite. Elle ne doit plus jamais faire « gif qui se répète ». '
    + 'Persos libres (prends ceux qui collent le mieux à l\'entrée), accessoires, décor, lumière, caméra qui vit (travellings lents, recadrages, profondeur de champ si possible). Toutes les animations sont écrites à la main pour la scène (anim_set_menu.gd), sans clip du jeu ni émote (voir le brief). '
    + 'Trouve des idées fortes et drôles ou inquiétantes, dans l\'univers (école de papier, Alice qui rôde). Exemple : JOUER = Simon qui s\'échauffe, se croit seul, puis sent quelqu\'un derrière lui. '
    + 'Le passage rapide d\'un bouton à l\'autre doit rester fluide (fondus, pas de saut de pose). Vérifie : planches rendues serrées de chaque scène sur toute sa durée ; capture de l\'écran titre complet (les boutons et textes restent lisibles par-dessus la scène) ; tools/test_menu_perf (pas de saccade, construction sans gel de l\'interface) ; tools/test_menus et test_menu_nav.' },
  { key: 'textes', title: 'Textes naturels partout (hors films)', focus:
    'Passe sur TOUS les textes visibles hors films, en suivant le guide des textes du brief :'
    + '\n- menus : titre, préparation, salon, réglages et leurs descriptions, commandes, boutique (descriptions des danses et émotes), cinémathèque (titres et descriptions de catalogue() sauf les victoires LMS), pause, résultats et bulletin, crédits ;'
    + '\n- HUD et bulles : messages, consignes, noms et descriptions des capacités dans data.gd ;'
    + '\n- slogans des persos, par exemple « L\'OMBRE DE L\'ÉCOLE » et « Elle connaît la dernière sonnerie. » ;'
    + '\n- messages réseau et d\'erreur, terrain d\'essai, aides.'
    + '\nRéécris ce qui sonne IA ou générique. Garde ce qui est déjà naturel et précis : ne réécris pas pour réécrire. Les règles et les chiffres doivent rester exacts. Respecte la mise en page : vérifie en captures FR et EN, en 1280×800 et en 1920×1080, qu\'aucun texte ne déborde ni ne se coupe (tools/test_player_path, test_menus). '
    + '\nMets à jour les clés de traduction (localization.gd, dictionnaires V11, V12…, et localization_016.gd) : quand un texte français change, remplace l\'ancienne entrée par la nouvelle avec un anglais naturel. Vérifie qu\'aucun texte anglais ne retombe en français (tools/test_menu_i18n, test_ingame_i18n) et qu\'il n\'y a aucune clé en double. '
    + '\nÉcris docs/TEXTES-0.17.md avec l\'avant/après des principaux changements.' },
  { key: 'simon', title: 'Simon : course « Sonic » du boost et portages différents par allié', focus:
    '1) Course du boost (speed_boost, sur-sprint) : position « Sonic » / « Naruto run ». Buste penché très en avant (environ 45 à 60°), tête relevée qui regarde devant, bras tendus en ARRIÈRE le long du corps (légèrement écartés, mains ouvertes ou en poings), jambes très rapides avec une grande amplitude. Les transitions doivent être propres depuis le sprint normal et vers l\'arrêt ou le dérapage. Ne casse pas les genoux : respecte le garde-fou de _leg_ik. '
    + '\n2) Portage pendant le boost (carry_survivor) : une animation dédiée par allié, pour Simon ET pour l\'allié porté, avec le moment où il l\'attrape (transition) et la pose de course :'
    + '\n- ASHURA : tracté par la main, debout sur ses rollers, en position de patineur (genoux fléchis, l\'autre bras pour l\'équilibre, rollers visibles), petites traînées ou étincelles ;'
    + '\n- BLEUETTE : portée en princesse (un bras sous ses genoux, l\'autre dans son dos), elle s\'accroche à son cou, d\'abord effrayée puis rassurée ;'
    + '\n- ELLY : à toi d\'inventer (par exemple sur son dos, fusil pointé vers l\'arrière pour le couvrir) ;'
    + '\n- USAYUKO (plus lourd, vitesse ×0,85) : à toi, avec de l\'humour (par exemple traîné par le col, ou chargé sur l\'épaule).'
    + '\nLysia ne peut pas être portée : c\'est une règle, garde-la. Pendant un portage, Simon garde une position Sonic adaptée (un bras occupé). Les positions porteur/porté doivent être exactes : pas de membres qui se traversent, des mains qui tiennent vraiment. '
    + '\n3) Réseau : les clients voient la même animation (la variante se déduit du perso porté), bots compris. '
    + '\nTests : test_mechanics, parties simulées, test réseau hôte + client, terrain d\'essai, captures rendues de la course Sonic et de chaque portage sous plusieurs angles et en mouvement (planches serrées).' },
  { key: 'yiero', title: 'Nouveau modèle 3D de Yiero', focus:
    'Refais le modèle 3D de Yiero (yiero_model.gd, PaperYiero) pour qu\'il soit beau et terrifiant, fidèle à l\'image de référence : démon colossal, visage noyé dans le noir, deux yeux ronds pâles sans paupières, sourire immense aux dents pointues et gencives rouges, mains griffues géantes, corps qui sort d\'une mer d\'encre. '
    + 'Image de référence : ' + SP + 'images/yiero.png (si elle n\'est pas là, travaille avec la description de docs/INTRO-YIERO.md et signale-le). '
    + 'Garde un style cohérent avec le jeu (papier et encre, contours noirs, aplats), mais avec du volume :'
    + '\n- formes organiques soignées, sans cube ni sphère primitive visible, topologie lisse ;'
    + '\n- matériaux travaillés : encre brillante, fumée ou fibres, lueur des yeux, intérieur de la bouche.'
    + '\nUtilise Blender (bpy, voir le brief) pour modéliser et sculpter par script, puis exporter un .glb avec une armature ou des nœuds articulés : tête, mâchoire, cou, épaules, bras, mains, doigts, yeux. Sinon, génère un maillage organique par code. '
    + '\nGarde l\'API publique de PaperYiero utilisée par film_intro_yiero.gd : lis le film pour la recenser (sourire, mâchoire, yeux, mains, émergence, échelle, lueurs…) et fais-la fonctionner sur le nouveau modèle. Ajoute des contrôles plus fins (doigts, plissement des yeux, souffle, inclinaison de tête), documentés en tête de fichier pour les lots du prologue. NE MODIFIE PAS film_intro_yiero.gd. '
    + '\nVérifie avec des captures rendues comparées à la référence :'
    + '\n- une planche face / profil / trois-quarts ;'
    + '\n- les plans du prologue qui le montrent (30–60 s, 80–104 s, 122–150 s) avec tools/test_intro --intro-mode capture.'
    + '\nPerf : le prologue doit rester fluide (nombre de triangles raisonnable).' },
  { key: 'prologue_a', title: 'Prologue 0 → 104 s : dimension, apparition, combat, animés de A à Z', focus:
    'Prologue 0 → 104 s (_write_void_intro, _write_apparition, _write_fight dans film_intro_yiero.gd) : refais TOUTES les animations des personnages (Simon, Ashura) de A à Z, plan par plan, en clips écrits pour le film (anim_set_film_prologue_a.gd). Suis le storyboard de docs/INTRO-YIERO.md et les instants de synchro de la musique. '
    + '\nCe qui doit être joué :'
    + '\n- la marche dans l\'encre, avec un cycle écrit pour le plan : pieds qui ne glissent pas, ondes ;'
    + '\n- le regard qui balaie, la peur, les corps qui se figent, la résistance au souffle ;'
    + '\n- les poings qui s\'embrasent de lumière dorée ;'
    + '\n- le combat : esquive, course éclair, saut, flashbang, rollers, drone, double coup de poing au ralenti.'
    + '\nTout est joué comme au cinéma : anticipation, impacts lisibles, ralentis, visages expressifs, aucun clip du jeu. '
    + '\nYiero : anime-le avec l\'API actuelle de PaperYiero (émergence, mains, sourire, mâchoire, regard). Le lot « yiero » refait son modèle en parallèle en gardant cette API ; ne modifie pas yiero_model.gd. Plans et cadrages peuvent être retravaillés pour mieux servir l\'action. '
    + '\nRéécris les répliques de ces actes selon le guide des textes : Simon et Ashura naturels, Yiero sadique et moqueur sans grandiloquence. Garde leur place dans le minutage. '
    + '\nVérifie chaque plan en planches rendues serrées (tools/test_intro --intro-mode capture avec --fixed-fps et --intro-ranges). Les modes scan, gallery et first de test_intro doivent passer.' },
  { key: 'prologue_b', title: 'Prologue 104 → 196 s : défaite, poursuite, école, titre, animés de A à Z', focus:
    'Prologue 104 → 196 s (_write_defeat, _write_chase, _write_school, _write_footsteps dans film_intro_yiero.gd) : refais TOUTES les animations de A à Z en clips écrits pour le film (anim_set_film_prologue_b.gd). Aucun clip du jeu, et Alice aussi est animée en film, pas avec ses attaques du jeu. '
    + '\nLes moments à jouer :'
    + '\n- la défaite : Yiero tient Ashura, qui s\'efface en papier doré ; Simon hurle ;'
    + '\n- la fuite de Simon poursuivi, puis le plongeon dans la porte de sortie ;'
    + '\n- l\'arrivée à l\'école en pleine bagarre : Usayuko se bat comme un fou contre Alice avec son aura (vraie chorégraphie de combat écrite) ;'
    + '\n- Elly soigne Bleuette : gestes de soin précis, Bleuette qui tremble ;'
    + '\n- Lysia à moitié cassée : mouvements saccadés d\'automate abîmé ;'
    + '\n- Simon se joint au combat : coup double, arrêt sur image ;'
    + '\n- le titre, puis « Bienvenue dans votre nouvel enfer » (garde cette phrase exacte).'
    + '\nYiero : utilise l\'API actuelle de PaperYiero (son modèle est refait en parallèle) ; ne modifie pas yiero_model.gd. Réécris les répliques de ces actes selon le guide des textes. '
    + '\nVérifie en planches rendues serrées (tools/test_intro --intro-mode capture --intro-ranges). Les modes scan, gallery et first de test_intro doivent passer.' },
  { key: 'lms_wins', title: 'Les 6 victoires LMS animées de A à Z', focus:
    'Les 6 victoires LMS (film_victories.gd) : refais toutes les animations en clips écrits pour chaque film (anim_set_film_victory.gd), sans geste de capacité, émote ni locomotion du jeu :'
    + '\n- Simon : la vitesse ;'
    + '\n- Usayuko : la force ;'
    + '\n- Ashura : drone et rollers ;'
    + '\n- Lysia : surtension électrique ;'
    + '\n- Elly : soin, esquive, fusil ;'
    + '\n- Bleuette : chocolat, courage, sprint ;'
    + '\n- Alice, présente dans chaque film.'
    + '\nGarde la structure façon Outcome Memories : télé CRT, nuit pluvieuse, gros plans aux yeux qui brillent, geste signature, silhouettes à l\'encre sur papier. Garde les stingers (durées et synchro). Rends le jeu d\'acteur cinématographique : poses fortes, anticipation, impacts, regards. '
    + '\nRéécris les titres et descriptions (« Le poing de la dernière sonnerie »…) selon le guide des textes. '
    + '\nVérifie chaque film en planches rendues serrées (tools/test_victory --victory all avec --vcap-step). tools/test_victory_lms et test_victory_net doivent passer.' },
  { key: 'lms_losses', title: 'Les 6 « Alice · X rattrapé(e) » et l\'épilogue d\'exécution animés de A à Z', focus:
    'Les 6 films « Alice · X rattrapé(e) » (ending_killer, _write_kill dans cinematics.gd) et l\'épilogue d\'exécution (film_execution_end.gd) : refais toutes les animations en clips écrits pour ces films (anim_set_film_alice.gd), pour Alice comme pour chaque victime, sans clip du jeu. '
    + '\nPour chaque victime : une fuite écrite, une chute, une tentative de défense qui lui est propre, puis la mise à mort, montrée ou suggérée hors champ si c\'est plus fort. Alice inquiétante et précise. '
    + '\nGarde le fonctionnement : film joué chez tous les joueurs, durées compatibles avec main.gd et gallery.gd. Ne modifie pas les helpers partagés de cinematics.gd (voir le brief). '
    + '\nVérifie en planches rendues serrées (tools/film_capture --film ending_killer …, et l\'épilogue). tools/test_film_fusion --ff-mode killer et --ff-mode exec_end, ainsi que test_kills, doivent passer.' },
  { key: 'team_blocus', title: 'Les 63 fuites en équipe et le blocus animés de A à Z', focus:
    'Les 63 films de fuite en équipe (ending_survivors, _write_escape dans cinematics.gd, un par combinaison d\'élèves) et le blocus (film_blocus.gd, volontairement nul mais drôle) : refais les animations en clips écrits pour ces films (anim_set_film_escape.gd ; anim_set_blocus.gd pour le blocus), sans clip du jeu. '
    + '\nPour les fuites :'
    + '\n- sprint vers la sortie écrit pour le film ;'
    + '\n- entraide : on tire un ami, on fait la courte échelle, on se retourne pour attendre ;'
    + '\n- Alice qui arrive trop tard ;'
    + '\n- joie ou soulagement à la sortie, avec des attitudes propres à chaque perso.'
    + '\nComme c\'est combinatoire, écris des modules de mise en scène par perso et par rôle, qui se combinent sans se répéter visiblement. '
    + '\nLe blocus est animé à la main lui aussi : son côté « nul » vient de la mise en scène, pas des clips du jeu. Ne modifie pas les helpers partagés de cinematics.gd. '
    + '\nVérifie plusieurs combinaisons (1, 2, 3 et 6 élèves) et le blocus en planches rendues serrées. tools/test_forfeit_solo, test_network_alice --alice-scenario host_alice et test_film_fusion --ff-mode team et --ff-mode blocus doivent passer.' },
  { key: 'cartes', title: 'Cartes : objets qui flottent, incohérences, murs invisibles au bord', focus:
    'Retouche les 3 cartes (école, forêt, neige) sans les refaire : le joueur demande de « supprimer les trucs qui volent, réparer un peu les maps et enlever tout ce qui est illogique », et de « mettre des murs invisibles au bord des maps », parce qu\'on peut tomber, les bots aussi. '
    + '\nCe qu\'il faut faire :'
    + '\n- Fais l\'inventaire automatique des défauts, avec un outil : objets dont le bas ne touche ni le sol ni un support (ils flottent), objets enfoncés dans le sol ou qui se traversent, objets qui bloquent une porte ou un couloir, éléments hors limites, incohérences (meuble au plafond, porte qui donne sur un mur, escalier qui ne mène nulle part…). Vérifie-les ensuite en captures rendues.'
    + '\n- Corrige-les : repose les objets au sol, déplace ou supprime ce qui est illogique, bouche les trous.'
    + '\n- Ajoute des murs invisibles (collisions sans maillage visible) sur tout le pourtour jouable de chaque carte et partout où on peut tomber dans le vide. Joueurs, bots et Alice ne doivent plus jamais pouvoir sortir ni tomber. Vérifie que la caméra n\'est pas gênée de façon laide.'
    + '\n- Ne casse rien : chemins des bots (ai_nav, cache de navigation), points d\'apparition, sorties, archives, prises, portes, films de fin (les élèves courent au-delà de la sortie pendant les films : garde la place nécessaire), True Form.'
    + '\nTests : outil de contrôle des cartes (accessibilité de chaque point important, aucun objet flottant restant, test de chute : un acteur poussé vers chaque bord est retenu), parties simulées sur les 3 cartes (bots qui se déplacent, scellent les archives et s\'échappent), captures rendues avant/après des endroits corrigés.' },
  { key: 'reseau', title: 'Réseau : hitbox sans retard pour le joueur, ping optimisé', focus:
    'Le joueur joue en ligne avec des amis en France (environ 50 ms de ping) : avec beaucoup de ping, c\'est SA hitbox qui est en retard. Le serveur (l\'hôte) le voit à une position plus ancienne que celle qu\'il voit lui-même, donc il se fait toucher alors qu\'il avait esquivé, ou il rate une action. « Ça doit pas être nous, ça doit pas être visible. » '
    + '\nCommence par lire comment fonctionne le réseau : instantanés receive_snapshot et _send_snapshot de main.gd, envoi des entrées des clients, pack et unpack d\'actor.gd, physique et interpolation. Mesure ensuite le problème avec un vrai test hôte + client et un retard réseau simulé : retard artificiel à l\'envoi ou à la réception, 50, 100 et 150 ms, et du jitter. '
    + '\nPuis corrige, comme un jeu en ligne sérieux :'
    + '\n- prédiction côté client du joueur local : il bouge tout de suite chez lui, avec réconciliation douce et sans à-coups quand l\'hôte corrige ;'
    + '\n- l\'hôte fait confiance à la position envoyée par le client dans des limites anti-triche raisonnables (vitesse maximale, pas de traversée de murs) ;'
    + '\n- compensation du retard pour les coups : quand l\'hôte décide si une attaque touche (Alice qui frappe un élève, capacités qui touchent), il juge avec les positions que chaque joueur voyait, pas avec des positions en retard. Favorise celui qui esquive, en bornant le rembobinage (environ 200 ms au maximum) ;'
    + '\n- interpolation des AUTRES acteurs avec un petit tampon adaptatif, pour qu\'ils restent fluides.'
    + '\nOptimise aussi la latence : fréquence d\'envoi des instantanés et des entrées, taille des paquets, canaux fiable ou non fiable adaptés, compression, pas de travail inutile. Mesure avant/après (octets/s, délai entrée → mouvement visible). '
    + '\nNe change pas PaperRules.PROTOCOL (l\'intégrateur le passera à 17). L\'hôte reste autoritaire pour tout le reste (dégâts, capacités, chrono). Les bots ne changent pas. '
    + '\nTests : outils réseau existants (tools/test_network_alice et ses scénarios, test_kills_net, test_emote_net, test_victory_net) qui doivent tous passer, plus ton propre test de retard simulé qui montre avec des chiffres que la hitbox du client suit ce qu\'il voit (écart avant/après) et qu\'une esquive réussie chez le client n\'est pas comptée comme touchée.' },
]

const SCHEMA = {
  type: 'object',
  properties: {
    worktree_path: { type: 'string' }, branch: { type: 'string' }, final_commit: { type: 'string' },
    verdict: { type: 'string', enum: ['ready', 'ready_with_limits', 'not_ready'] },
    done: { type: 'array', items: { type: 'object', properties: { item: { type: 'string' }, evidence: { type: 'string' } }, required: ['item', 'evidence'] } },
    issues: { type: 'array', items: { type: 'object', properties: { issue: { type: 'string' }, severity: { type: 'string', enum: ['blocker', 'major', 'minor'] }, fixed: { type: 'boolean' }, how: { type: 'string' } }, required: ['issue', 'severity', 'fixed', 'how'] } },
    tests: { type: 'string' }, remaining: { type: 'string' },
    translations: { type: 'array', items: { type: 'object', properties: { fr: { type: 'string' }, en: { type: 'string' } }, required: ['fr', 'en'] } },
    integration_notes: { type: 'string' },
  },
  required: ['worktree_path', 'branch', 'final_commit', 'verdict', 'done', 'issues', 'tests', 'remaining', 'translations', 'integration_notes'],
}

const RESUME_NOTE = 'REPRISE (important) : un précédent agent a déjà commencé CE lot dans ce worktree, puis a été coupé (limite de session) avant de finir. Son travail est là : commits (« git log --stat 0c3243f..HEAD ») et peut-être des modifications non commitées (« git status », « git diff »). Commence par faire le point : lis ce qui existe, relance « godot --headless --import », vérifie qu\'il n\'y a pas d\'erreur de script, et regarde le résultat actuel en captures rendues. Garde ce qui est bon, termine ou corrige le reste (des modifications non commitées peuvent être inachevées : commit-les seulement si elles sont correctes), puis va jusqu\'au bout de la mission.\n\n'

function head(lot) {
  const path = WT + 'lot17-' + lot.key
  return 'Projet : jeu Godot « Paper Afterbell », version 0.17. Lis d\'abord EN ENTIER, dans cet ordre : ' + SP + 'BRIEF.md (brief général : outils, tests, code) puis ' + SP + 'BRIEF-017.md (retour du joueur, règles 0.17, guide d\'animation, guide des textes, carte des fichiers).\n'
    + 'Ton lot : « ' + lot.key + ' » — ' + lot.title + '.\n'
    + 'Ta copie de travail EXISTE DÉJÀ : ' + path + ' (branche lot17-' + lot.key + '). Travaille UNIQUEMENT dedans, avec des chemins absolus ; préfixe chaque commande par « cd ' + path + ' && ». Ne modifie jamais /home/user/paper-afterbell ni les autres worktrees. Respecte la carte des fichiers du brief. COMMIT TRÈS SOUVENT (au moins toutes les 20-30 min).\n\n'
}

function implPrompt(lot, resume) {
  return 'Tu es un développeur et animateur 3D senior, très exigeant sur la qualité visuelle. ' + head(lot)
    + (resume ? RESUME_NOTE : '')
    + 'TA MISSION :\n' + lot.focus + '\n\n'
    + 'Travaille comme un pro : regarde d\'abord l\'existant en captures (pour voir ce que le joueur trouve « pas ouf »), prévois ta mise en scène, écris, rends, regarde, corrige, recommence jusqu\'à un résultat dont tu es fier. Commit souvent. Rends le rapport structuré demandé (schéma), avec tes preuves.'
}

function reviewPrompt(lot, impl) {
  return 'Tu es le relecteur ADVERSARIAL et exigeant de ce lot (le joueur juge sévèrement la qualité visuelle et le naturel des textes). ' + head(lot)
    + 'La mission confiée à l\'implémenteur était :\n' + lot.focus + '\n\n'
    + 'L\'implémenteur a terminé. Son rapport (JSON) :\n' + JSON.stringify(impl).slice(0, 30000) + '\n\n'
    + 'TON TRAVAIL : dans le même worktree, vérifie TOUT par toi-même. Commence par git log et git diff 0c3243f..HEAD, puis lance les tests et fais tes propres captures rendues (planches serrées), que tu regardes avec Read. Points à contrôler :\n'
    + '- la demande du joueur est-elle vraiment remplie ? (aucun clip du jeu ni émote dans les films et les scènes refaites ; animation de qualité « film » ; boucles invisibles ; textes naturels et pas « IA » ; position Sonic ; portages exacts…) ;\n'
    + '- défauts visibles : membres cassés ou qui traversent, pieds qui glissent, raideur, répétition, cadrage raté, textes qui débordent ;\n'
    + '- régressions : tests du lot et non-régression générale (démarrage sans erreur de script, parties simulées, outils concernés) ;\n'
    + '- respect de la carte des fichiers ; traductions complètes.\n'
    + 'CORRIGE toi-même ce qui ne va pas (commits clairs et fréquents), jusqu\'à ce que le lot soit vraiment bon. Rends le rapport final complet du lot (schéma) : tout ce qui est fait (implémenteur + toi), problèmes trouvés et corrigés, ce qui reste, traductions (liste complète du lot), notes d\'intégration, commit final.'
}

const keys = Array.isArray(args) ? args : (args && args.keys) || []
const resume = !Array.isArray(args) && args && args.resume === true
const withReview = !Array.isArray(args) && args && args.review === true
const reviewOnly = (!Array.isArray(args) && args && args.reviewOnly) || []
const wanted = keys.length ? LOTS.filter(l => keys.includes(l.key)) : LOTS
log('Lots (Opus 5.5) : ' + wanted.map(l => l.key).join(', ') + (resume ? ' (reprise)' : ''))
const results = await pipeline(wanted,
  lot => reviewOnly.includes(lot.key) ? { reviewOnly: true } : agent(implPrompt(lot, resume), { label: 'impl:' + lot.key, phase: 'Implement', schema: SCHEMA, model: MODEL }).then(r => r || { failed: true }),
  (impl, lot) => (impl && impl.failed) || !withReview ? { key: lot.key, impl: impl, review: null } : agent(reviewPrompt(lot, impl), { label: 'review:' + lot.key, phase: 'Review', schema: SCHEMA, model: MODEL })
    .then(r => ({ key: lot.key, impl: impl, review: r })))
return results.map((r, i) => r || { key: wanted[i].key, failed: true })
