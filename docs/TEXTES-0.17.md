# Textes 0.17 — avant / après

Le joueur trouvait les textes « trop IA » : génériques, pompeux, pas assez humains (exemple cité : « la dernière
sonnerie »). Cette passe reprend **tous les textes visibles hors films** : menus, HUD, messages de partie,
répliques de Bleuette, fiches des persos et des capacités, boutique, cinémathèque (catalogue), réseau, terrain
d'essai, aides. Les films (prologue, victoires LMS, fins, blocus) appartiennent à leurs propres lots.

## Deuxième passe (reprise)

La première passe avait couvert presque tout. La reprise a relu chaque écran en captures, FR et EN, et corrigé ce
qui restait : les 63 descriptions des fuites en équipe (« Puis l’équipe s’échappe » même pour un survivant seul),
l’écran Crédits (notes de mixage brutes, en français même en anglais), le paragraphe hors sujet de l’onglet
Accessibilité, le passif d’Elly (elle entend aussi les pas d’Alice, et sur toutes les cartes), Alice vouvoyée
(« EMPÊCHEZ LEUR FUITE »), trois messages du service en ligne trop administratifs, et le ménage des traductions
(copies masquées et entrées mortes). `tools/test_textes.gd` gagne trois contrôles : `--tx-catalogue` (anglais de
toute la cinémathèque), `--tx-data` (fiches des persos telles que les montre la préparation) et les pages
défilées des crédits.

## La règle suivie

- **Dire ce que ça fait**, en phrases courtes. Vocabulaire d'école quand ça colle (grilles, cours, bulletin de
  notes, classe de neige), un peu d'humour quand ça tombe bien (« Interdit de courir dans les couloirs. Sauf ce
  soir. »).
- **Chaque perso parle comme lui-même** : Ashura posé et sec, Usayuko gouailleur, Simon nerveux et rapide, Lysia
  automate un peu cassée, Elly douce mais directe, Bleuette timide qui bégaie, Alice inquiétante sans en faire trop.
- **On tutoie le joueur** partout (« maintiens », « ton aura ») ; le « vous » reste quand on parle à toute l'équipe
  de survivants (« RESTEZ EN VIE »).
- **Aucun chiffre, aucune règle ne change.** Chaque description de capacité a été relue contre `combat.gd`
  (contre d'Usayuko : fenêtre de 1,2 s puis stun 4 s, recharge 20 s après un blocage réussi ; « Je crois en toi » :
  termine la plus longue recharge ; ralentissement de 15 % en portant Usayuko…).
- **Ce qui était déjà naturel et précis est resté** : réglages techniques, messages réseau, noms des capacités,
  termes de jeu fixés (LMS, True Form, Course éclair, Shadow reveal…), descriptions de cartes de la forêt et de la
  neige, la plupart des danses, toutes les commandes.
- **Moins de motifs « cloche / ombre / présence / dernière… »**, qui revenaient partout et donnaient l'effet
  généré. La cloche reste là où elle sonne vraiment (début de manche).
- **Moins de « … »** : gardés pour le bégaiement de Bleuette, le « six… seven » du mème et la chute du Mannequin
  Challenge.

## Les changements qui se voient le plus

| Où | Avant | Après | Anglais |
|---|---|---|---|
| Écran titre, sous le logo | La sonnerie ne vous sauvera pas. | Ne reste pas après les cours. | Don't stay after school. |
| Écran titre, ruban | DOSSIER 013 · LA SONNERIE NE VOUS SAUVERA PAS | DOSSIER 013 · FERMETURE DES GRILLES À 16 H 30 | FILE 013 · GATES CLOSE AT 4:30 PM |
| Écran titre, JOUER | Préparer une manche solo contre les bots : rôle, personnage et carte. | Une partie contre des bots. Choisis ton camp, ton perso et la carte. | A match against bots. Pick your side, your character and the map. |
| Écran titre, QUITTER | Fermer Paper Afterbell. | Fermer le jeu. À demain ! | Close the game. See you tomorrow! |
| Rôle d'Alice | L'OMBRE DE L'ÉCOLE | TUEUSE | KILLER |
| Rôle d'Elly | SOIGNEUR | SOIGNEUSE (accord) | HEALER |
| Alice | Elle connaît la dernière sonnerie. | Qui veut rester après les cours ? | Who wants to stay after school? |
| Ashura | Les yeux de l'équipe. | Pas de panique, j'ai un drone. | Relax. I've got a drone. |
| Usayuko | Tenez-vous derrière moi. | Derrière moi, les p'tits. | Get behind me, kids. |
| Simon | Un pas d'avance sur l'ombre. | J'cours d'abord, j'réfléchis après. | Run first, think later. |
| Lysia | L'armure se brise. La volonté reste. | Batterie faible. Tout va bien. | Battery low. Everything is fine. |
| Elly | Personne ne reste en arrière. | Bouge pas, je te soigne. | Hold still, I'll patch you up. |
| Bleuette | Je crois en toi. | J-je crois en toi. Vraiment ! | I-I believe in you. Really! |
| Noms des cartes | L'école après la cloche · La forêt des murmures · Le silence de l'hiver | L'école de Miss Circle · Les bois · La classe de neige | Miss Circle's School · The Woods · The Ski Trip |
| Chargement, école | Les couloirs gardent leurs secrets. | Interdit de courir dans les couloirs. Sauf ce soir. | No running in the halls. Except tonight. |
| Chargement, bois | Dans les bois, chaque bruit compte. | Le bus ne partira pas sans toi. Normalement. | The bus won't leave without you. Probably. |
| Chargement, neige | La neige étouffe les pas. Pas la peur. | Bonnet, gants, écharpe. Et cours ! | Hat, gloves, scarf. Now run! |
| Chargement, distribution | LES PRÉSENCES DE CETTE MANCHE | DANS CETTE MANCHE | IN THIS ROUND |
| Préparation, onglet Alice | L'ombre · empêcher la fuite | La tueuse · empêcher la fuite | The killer · stop the escape |
| Lancement d'une manche | LA CLOCHE SONNE | C'EST PARTI | HERE WE GO |
| En ligne | LES OMBRES VOUS ATTENDENT / En ligne, entre amis | JOUER EN LIGNE / Entre amis | PLAY ONLINE / With friends |
| Salon | Avant la cloche | En attendant les autres | Waiting for everyone |
| Pause | Retourner dans la manche, là où la cloche t'attend. | Retour à la partie. | Back to the match. |
| Pause, ruban | LA CLOCHE ATTEND · PAUSE | ON SOUFFLE UN COUP · PAUSE | CATCH YOUR BREATH · PAUSE |
| Résultats | LE BULLETIN DE LA NUIT / Bulletin de la nuit | FIN DE LA MANCHE / Bulletin de notes | END OF THE ROUND / Report card |
| Cinémathèque | LES HISTOIRES APRÈS LA CLOCHE | TOUS LES FILMS DU JEU | EVERY FILM IN THE GAME |
| Cinémathèque, prologue | … affrontent Yiero dans une dimension ténébreuse… puis Simon atterrit à l'école en plein combat. | Simon et Ashura tombent sur Yiero, un démon géant, au milieu d'une mer d'encre. Simon finit par atterrir à l'école, en pleine bagarre contre Alice. | Simon and Ashura run into Yiero, a giant demon, in the middle of a sea of ink. … |
| Cinémathèque, « Alice · X rattrapé(e) » | La dernière tentative de X échoue. Alice le rattrape, frappe et l'achève au sol. | X est le dernier encore debout. Alice finit par le rattraper. | X is the last one still standing. Alice catches up with him in the end. |
| Début du LMS | DERNIÈRE PRÉSENCE / « Simon · duel final » | DERNIER SURVIVANT (ou DERNIÈRE SURVIVANTE) / « Simon contre Alice » | LAST ONE STANDING / "Simon vs Alice" |
| Aura pleine | AURA ÉVEILLÉE · Dernière chance : tiens jusqu'à la sonnerie ! | AURA PLEINE · Tiens jusqu'à la fin de ta musique ! | AURA FULL · Hold on until your music ends! |
| Joueur éliminé | VOUS ÊTES TOMBÉ | TU ES ÉLIMINÉ (ou ÉLIMINÉE) | YOU'RE OUT |
| Alice repérée par une archive | ALERTE ARCHIVE · UNE PRÉSENCE A ÉTÉ RÉVÉLÉE | ALERTE ARCHIVE · UN ÉLÈVE S'EST FAIT REPÉRER | ARCHIVE ALERT · A STUDENT GOT SPOTTED |
| Ombres d'Alice | ALICE EST DANS TON OMBRE ! ELLE ARRIVE DERRIÈRE TOI | ALICE ARRIVE DERRIÈRE TOI ! BOUGE ! | ALICE IS RIGHT BEHIND YOU! MOVE! |
| Côté Alice | OMBRE PORTÉE · ÉMERGENCE DERRIÈRE LA CIBLE… | OMBRES · TU VAS SURGIR DERRIÈRE UN ÉLÈVE AU HASARD | SHADOWS · YOU'LL POP UP BEHIND A RANDOM STUDENT |
| Bleuette encourage Elly | C'est si soulageant de vous avoir à nos côtés, monsieur ! | Elly, t-tu nous sauves la vie ! Ton prochain soin comptera double. | Elly, y-you're a lifesaver! Your next heal will count double. |
| Bleuette encourage Usayuko | Heureusement que t'es là pour nous protéger, frangin ! | M-merci d'être là, Usayuko… Ton prochain stun dure 1,5 s de plus. | Th-thanks for being here, Usayuko… Your next stun lasts 1.5 s longer. |
| Archive (QTE) | ARCHIVE · CONTRÔLE D'INTÉGRITÉ | ARCHIVE · APPUIE SUR LA BONNE TOUCHE | ARCHIVE · PRESS THE RIGHT KEY |
| Crédits, musique du menu | « La dernière sonnerie » | « Fin des cours » | “End of Class” |
| Cinémathèque, fuite en solo | Ashura envoie son drone. Puis l’équipe s’échappe. | Ashura envoie son drone, puis se sauve. | Ashura launches his drone, then makes a run for it. |
| Cinémathèque, fuite à plusieurs | Simon lance sa flashbang ; Ashura envoie son drone ; Elly soigne le groupe. Puis l’équipe s’échappe. | Simon lance sa flashbang, Ashura envoie son drone et Elly soigne ceux qui en ont besoin. Puis tout le monde se sauve. | Simon throws his flashbang, Ashura launches his drone and Elly heals whoever needs it. Then everyone makes a run for it. |
| Côté Alice, objectif | EMPÊCHEZ LEUR FUITE | EMPÊCHE-LES DE FUIR | STOP THEIR ESCAPE |
| Passif d’Elly | Entend les actions d'Alice partout dans l'école. | Tu entends les pas et les capacités d’Alice partout sur la carte. | You hear Alice's footsteps and abilities anywhere on the map. |
| Réglages, onglet Accessibilité | un rappel de jeu (roue d’émotes, Simon, aura) sans rapport avec l’onglet | Tu peux aussi couper les secousses de caméra, les onomatopées et les effets d’écran dans l’onglet JEU. | You can also turn off camera shake, comic words and screen effects in the GAME tab. |
| Crédits audio | notes de mixage (LUFS, dB, encodage), noms de fichiers bruts, tout en français même en anglais | crédits écrits pour les joueurs, toutes les attributions gardées | version anglaise `audio/CREDITS.en.txt` |

Exemple de capacité (Usayuko, Block / contre) — mêmes chiffres, dit comme on le dirait à un pote :

- avant : « Bloque 1,5 s. En cas d'impact, réappuie pour un contre de 4 s. Recharge réussie : 20 s. »
- après : « Garde de 1,5 s. Si Alice tape dedans, réappuie vite pour contrer : stun 4 s. Après un blocage réussi,
  la recharge n'est que de 20 s. »
- anglais : « Guard for 1.5 s. If Alice hits it, press again quickly to counter: 4 s stun. After a successful
  block, the cooldown is only 20 s. »

## Traductions

- Quand un texte français change, **son entrée est remplacée sur place** dans `localization.gd` (V11, V12, TEXT)
  ou `localization_016.gd`, avec un anglais naturel. L'ancienne clé n'est gardée que si le texte est encore
  utilisé ailleurs (aucun cas dans cette passe).
- Les rares textes **sans entrée d'origine** (« DERNIÈRE SURVIVANTE », « %s contre Alice », les deux nouvelles
  descriptions « … encore debout ») vont dans le nouveau **`localization_017.gd`** (même format que celui de la
  0.16, consulté en premier par `PaperLanguage._translate`). L'intégrateur peut y ajouter les traductions des
  autres lots.
- Les anciens modèles « La dernière tentative de %s échoue… » (4 dans `localization_016.gd`, 1 clé et 1 bloc
  `DISPLAY_TEMPLATES` dans `localization.gd`) et « %s · duel final » sont retirés : plus rien ne les produit.
- Anglais : apostrophe droite (comme la grande majorité des traductions existantes).
- Aucune clé en double dans un même dictionnaire. Entre dictionnaires, les 43 copies masquées héritées des
  versions précédentes (même texte dans V12, V11 et TEXT : seule la première était lue) sont retirées ; quand
  deux copies différaient, la meilleure traduction est gardée (« Consommation » → « Discharge », comme sur la
  fiche de Lysia ; « ARCHIVE · TOUCHE %s » → « TAP », c’est l’écran tactile). Restent seulement les paires voulues
  « texte exact + modèle `DISPLAY_TEMPLATES` » (le gabarit avant formatage et le texte déjà formaté).
- Retirées aussi : 8 entrées mortes qui recollaient les anciens passifs au rappel d’aura (le passif et le rappel
  sont traduits séparément par `PaperLanguage._translate`).
- En passant : « PRÊT POUR LA RENTRÉE » (réglages) était traduit « READY FOR AFTERBELL » → « BACK TO SCHOOL ».

## Vérifications

- `tools/test_textes.gd` (nouveau) : une capture par écran (titre et ses 8 aides, préparation des 7 persos,
  boutique, cinémathèque et ses catégories, crédits, réseau, salon, 5 onglets de réglages, carnet de commandes,
  compte, chargement, HUD, roue d'émotes, pause et confirmation, partie en Alice, terrain d'essai et son panneau,
  3 bulletins) **et** un relevé automatique des textes coupés ou qui sortent de leur cadre (labels, boutons,
  rôles des cartes de persos, onglets, cartes de terrain). Résultat : `TX_RESULT cuts=0` en FR et en EN, en
  1280×800 et en 1920×1080. Avant la passe, l'anglais débordait sur le résumé de la préparation
  (« SURVIVOR · USAYUKO · THE SCHOOL AFTER THE BELL », 341 px pour 334).
- `tools/test_ingame_i18n.gd` : liste étendue aux nouveaux messages de partie ; `I18N_RESULT OK`.
- `tools/test_menu_i18n.gd` : plus aucun texte modifié signalé ; restent les faux positifs déjà connus (mots
  « tickets », « volume », « non », « zone » de sa liste, pseudo par défaut « Élève », crédits audio en français).
- `tools/test_film_fusion.gd` : contrôle des descriptions « rattrapé(e) » mis à jour (accord et anglais).

## Laissé tel quel, exprès

- Titres et descriptions des victoires LMS (`film_victories.gd`, lot lms_wins), dont « Usayuko · Le poing de la
  dernière sonnerie » : c'est à ce lot de les reprendre.
- Les panneaux du décor de l'ancienne école (`school.gd`, « APRÈS LA SONNERIE, LES OMBRES RESTENT. »…) : ce code
  n'est plus construit en mode OM.
- `VERSION_TEXT` (« v0.16 ») et « Tous les joueurs doivent utiliser Paper Afterbell 0.16 · OM. » : la montée de
  version revient à l'intégrateur, avec `PaperRules.PROTOCOL`.
- Les noms d'émotes et de danses, les noms des capacités et les termes de jeu fixés.

## Liste complète

Toutes les entrées, par fichier (« Après » = texte affiché en français, « Anglais » = traduction de `localization*.gd`).

### `data.gd` (43)

| Avant | Après | Anglais |
|---|---|---|
| SOIGNEUR | SOIGNEUSE | HEALER |
| L'OMBRE DE L'ÉCOLE | TUEUSE | KILLER |
| Les yeux de l'équipe. | Pas de panique, j’ai un drone. | Relax. I've got a drone. |
| Tenez-vous derrière moi. | Derrière moi, les p’tits. | Get behind me, kids. |
| Un pas d'avance sur l'ombre. | J’cours d’abord, j’réfléchis après. | Run first, think later. |
| L'armure se brise. La volonté reste. | Batterie faible. Tout va bien. | Battery low. Everything is fine. |
| Personne ne reste en arrière. | Bouge pas, je te soigne. | Hold still, I'll patch you up. |
| Je crois en toi. | J-je crois en toi. Vraiment ! | I-I believe in you. Really! |
| Elle connaît la dernière sonnerie. | Qui veut rester après les cours ? | Who wants to stay after school? |
| 3 change de mode ; 1 lance. Rapide : stun 2 s, recharge 25 s. Précis : contrôle en vue drone, Ashura immobile, stun 4 s, recharge 35 s. Batterie 10 s ; face à l’aura rouge d’Alice, le drone attend qu’elle s’éteigne. Épave 15 s, Lysia la mange pour 7 PV. | 1 lance le drone, 3 change de mode. Rapide : stun 2 s, recharge 25 s. Précis : tu le pilotes en vue drone pendant qu’Ashura reste planté là ; stun 4 s, recharge 35 s. 10 s de batterie. Si Alice a son aura rouge, le drone attend qu’elle s’éteigne. L’épave reste 15 s, et Lysia peut la manger (+7 PV). | 1 launches the drone, 3 switches mode. Quick: 2 s stun, 25 s cooldown. Precise: you fly it in drone view while Ashura stands still; 4 s stun, 35 s cooldown. 10 s of battery. If Alice has her red aura, the drone waits for it to fade. The wreck stays for 15 s, and Lysia can eat it (+7 HP). |
| Maintiens pour charger sans bouger, relâche pour partir. 1–2 s : boost 3 s ; 2–3 s : 4 s ; 3 s et plus : 6 s. Vitesse identique à Simon. Permet de glisser sur les rails. | Maintiens sans bouger pour charger, relâche pour partir. 1–2 s de charge : 3 s de boost ; 2–3 s : 4 s ; 3 s ou plus : 6 s. Aussi rapide que Simon, et tu peux glisser sur les rails. | Hold still to charge, release to go. 1–2 s of charge: 3 s boost; 2–3 s: 4 s; 3 s or more: 6 s. As fast as Simon, and you can grind on rails. |
| Change le mode du drone ; recharge partagée, conservée en changeant de mode. | Passe le drone de rapide à précis, et inversement. Les deux modes partagent la même recharge : changer ne la remet pas à zéro. | Switches the drone between quick and precise. Both modes share one cooldown, so switching doesn't reset it. |
| Charge 4 s vers ton viseur, attrape Alice au contact et emporte-la. Impact contre un mur : stun 3 s. | Tu fonces 4 s là où tu vises. Si tu touches Alice, tu l’embarques ; écrase-la contre un mur et elle est stun 3 s. | You charge for 4 s wherever you're aiming. Hit Alice and you carry her off; slam her into a wall for a 3 s stun. |
| Bloque 1,5 s. En cas d'impact, réappuie pour un contre de 4 s. Recharge réussie : 20 s. | Garde de 1,5 s. Si Alice tape dedans, réappuie vite pour contrer : stun 4 s. Après un blocage réussi, la recharge n’est que de 20 s. | Guard for 1.5 s. If Alice hits it, press again quickly to counter: 4 s stun. After a successful block, the cooldown is only 20 s. |
| Coup de poing : 2 s d'étourdissement. | Un bon coup de poing : Alice est étourdie 2 s. | A solid punch: Alice is stunned for 2 s. |
| Une charge unique, recul et 5 s d'étourdissement. | Une seule fois en LMS : tu fonces, Alice recule et reste étourdie 5 s. | Once per LMS: you rush in, Alice gets knocked back and stunned for 5 s. |
| 3 change de mode. Lancer : active 1 pour viser, puis 1 ou clic pour lancer ; clic droit annule. Grenade : stun 2–4 s. Poing : stun 2,5 s et aveuglement 4 s. | 3 change de mode. En lancer : 1 pour viser, puis 1 ou clic pour lancer (clic droit annule). La grenade étourdit 2 à 4 s. En poing : stun 2,5 s et Alice aveuglée 4 s. | 3 switches mode. Throw: 1 to aim, then 1 or click to throw (right-click cancels). The grenade stuns for 2 to 4 s. Punch: 2.5 s stun and Alice blinded for 4 s. |
| Maintiens en restant immobile. Charge 1–2 s : boost 3 s ; 2–3 s : 4 s ; ≥3 s : 6 s, même vitesse. E pendant le boost pour emporter un allié proche, sauf Lysia. Usayuko réduit la vitesse de 15 %. | Maintiens sans bouger pour charger. 1–2 s : 3 s de boost ; 2–3 s : 4 s ; 3 s ou plus : 6 s, toujours à la même vitesse. E pendant le boost pour embarquer un allié proche (pas Lysia, trop lourde). Avec Usayuko, tu perds 15 % de vitesse. | Hold still to charge. 1–2 s: 3 s boost; 2–3 s: 4 s; 3 s or more: 6 s, always at the same speed. E during the boost to grab a nearby ally (not Lysia, she's too heavy). Carrying Usayuko slows you down by 15%. |
| Change le mode de la Flashbang, sans réinitialiser sa recharge. | Passe la Flashbang du lancer au poing, sans toucher à sa recharge. | Switches the Flashbang between throw and punch without touching its cooldown. |
| Charge en avant. Au contact : Alice immobilisée 3 s, puis stun 2 s supplémentaires. Lysia invincible pendant la charge et la surchauffe, mais la chaleur use doucement son armure : −40 PV sur les 3 s (au prorata si elle est interrompue), jamais sous 1 PV. | Tu charges là où tu vises. Au contact, Alice est bloquée 3 s, puis étourdie 2 s de plus. Tu es invincible pendant la charge et la surchauffe, mais la chaleur grignote ton armure : −40 PV sur les 3 s (au prorata si elle est coupée), sans jamais descendre sous 1 PV. | You charge wherever you're aiming. On contact, Alice is pinned for 3 s, then stunned for 2 s more. You're invincible during the charge and the overheat, but the heat eats into your armour: −40 HP over the 3 s (pro rata if it's cut short), never below 1 HP. |
| Repousse Alice sur 20 m, jusqu’au premier obstacle. | Envoie valser Alice jusqu’à 20 m, ou jusqu’au premier obstacle. | Sends Alice flying up to 20 m, or until she hits something. |
| Voit Alice et les prises électriques à travers les murs pendant 3 s. | Pendant 3 s, tu vois Alice et les prises électriques à travers les murs. | For 3 s, you see Alice and the power outlets through walls. |
| Près d’une prise, branche-toi jusqu’à 15 s : +10 PV toutes les 2 s sans bouger, arrêt à armure pleine. Ashura à moins de 4 m : soin 1,5 fois plus rapide. Bouger, INTERAGIR ou 4 te débranche. Recharge 30 s après la fin du soin. Être frappée interrompt le branchement. | Près d’une prise, branche-toi jusqu’à 15 s : +10 PV toutes les 2 s tant que tu ne bouges pas, jusqu’à l’armure pleine. Si Ashura est à moins de 4 m, ça va 1,5 fois plus vite. Bouger, INTERAGIR ou 4 te débranche, un coup aussi. Recharge de 30 s une fois le soin fini. | Next to an outlet, plug in for up to 15 s: +10 HP every 2 s as long as you don't move, until your armour is full. With Ashura within 4 m, it goes 1.5 times faster. Moving, INTERACT or 4 unplugs you, and so does getting hit. 30 s cooldown once the healing ends. |
| Soigne de 50 PV l’allié visé (sinon le plus proche) en 3 s, tous deux immobiles. | Rend 50 PV à l’allié visé (ou au plus proche) en 3 s. Vous restez immobiles tous les deux. | Gives 50 HP back to the targeted ally (or the closest one) over 3 s. You both stay still. |
| 2 PV/s dans la zone pendant 20 s. | Une zone qui rend 2 PV/s pendant 20 s. | A zone that heals 2 HP/s for 20 s. |
| Un tir unique : 203 dégâts, aveuglement et stun 3 s. Alice reste immortelle. | Une seule cartouche : 203 dégâts, Alice aveuglée et stun 3 s. Elle ne meurt pas pour autant. | One shell: 203 damage, Alice blinded and stunned for 3 s. She still doesn't die. |
| Vise n’importe quel allié à moins de 6 m : prochain drone -25 % recharge ; prochain stun d’Usayuko +1,5 s ; prochaine Course éclair de Simon +2 s ; prochaine recharge de Lysia -25 % ; prochain soin d’Elly ×2. | Vise un allié à moins de 6 m pour booster sa prochaine action : drone d’Ashura −25 % de recharge, stun d’Usayuko +1,5 s, Course éclair de Simon +2 s, recharge de Lysia −25 %, soin d’Elly ×2. | Aim at an ally within 6 m to boost their next move: Ashura's drone −25% cooldown, Usayuko's stun +1.5 s, Simon's Flash Sprint +2 s, Lysia's recharge −25%, Elly's heal ×2. |
| Recharge une capacité d’un allié visé à moins de 6 m et situé à moins de 12 m d’Alice. | Termine d’un coup la plus longue recharge d’un allié à moins de 6 m, s’il est à moins de 12 m d’Alice. | Instantly finishes the longest cooldown of an ally within 6 m, if they're within 12 m of Alice. |
| Seulement blessée, deux tablettes par partie. +20 PV immédiatement, puis +20 PV progressivement en 10 s. | Deux tablettes par partie, seulement si tu es blessée : +20 PV tout de suite, puis +20 PV sur 10 s. | Two bars per match, only when you're hurt: +20 HP right away, then +20 HP over 10 s. |
| Aura remplie : augmente une fois les PV maximum de 30. Seul moyen de dépasser 150 PV en LMS. | Avec l’aura pleine, une seule fois : +30 PV max. C’est le seul moyen de dépasser 150 PV en LMS. | With a full aura, once: +30 max HP. It's the only way to go past 150 HP in LMS. |
| Griffe en volume devant toi : 30 dégâts. Le cube rouge montre la zone du coup. | Un coup de griffes devant toi : 30 dégâts. Le cube rouge montre où ça touche. | A claw swipe in front of you: 30 damage. The red cube shows where it lands. |
| Révèle tous les survivants sauf Simon. | Montre où sont tous les survivants, sauf Simon. | Shows where every survivor is, except Simon. |
| Prépare, vise, confirme : les piques avancent rapidement sur 15 m. 20 dégâts par cible, lenteur 15 %. Clic droit annule. | Prépare, vise, confirme : les piques filent sur 15 m. 20 dégâts par cible et 15 % de lenteur. Clic droit pour annuler. | Ready, aim, confirm: the spikes shoot out over 15 m. 20 damage per target and 15% slow. Right-click to cancel. |
| Ombres derrière chaque élève, vraie Alice derrière un élève au hasard après 1,2 s. En True Form : bond frontal infligeant 40 dégâts, recharge 6 s. | Une ombre apparaît derrière chaque élève ; 1,2 s plus tard, tu surgis derrière l’un d’eux, au hasard. En True Form : un bond en avant à 40 dégâts, recharge 6 s. | A shadow appears behind every student; 1.2 s later you pop up behind one of them at random. In True Form: a forward pounce for 40 damage, 6 s cooldown. |
| Deux ombres poursuivent en marchant pendant 25 s : 10 dégâts au contact. Les capacités de survivants les dispersent. | Deux ombres traquent les élèves en marchant pendant 25 s : 10 dégâts au contact. Une capacité de survivant lancée près d’elles les dissipe. | Two shadows stalk the students at walking pace for 25 s: 10 damage on contact. A survivor ability used near them breaks them up. |
| 15 stuns subis débloquent une unique transformation de 30 s : vitesse +70 %, bond meurtrier, chronomètre suspendu et sortie fermée. | Après 15 stuns subis, tu peux te transformer une fois, pendant 30 s : +70 % de vitesse, bond mortel, chrono en pause et sortie fermée. | After taking 15 stuns, you can transform once, for 30 s: +70% speed, deadly pounce, timer paused and exit closed. |
| Quand tu es frappé, tes alliés voient ta silhouette à travers les murs. Près de Lysia branchée à une prise (4 m), sa recharge est 1,5 fois plus rapide. | Quand tu prends un coup, tes alliés voient ta silhouette à travers les murs. À moins de 4 m de Lysia branchée à une prise, tu accélères sa recharge (×1,5). | When you get hit, your allies see your outline through walls. Within 4 m of Lysia while she's plugged in, you speed up her recharge (×1.5). |
| 115 PV + 50 surPV soignables. Protège les alliés collés à lui (1,5 m) : la griffe d’Alice ne touche que lui. Peut bloquer ou contrer. Chaque protection remplit l’aura. | 115 PV + 50 surPV soignables. Les alliés collés à toi (1,5 m) sont à l’abri : la griffe d’Alice ne touche que toi. Tu peux bloquer ou contrer, et chaque protection remplit ton aura. | 115 HP + 50 healable bonus HP. Allies right next to you (1.5 m) are safe: Alice's claw only hits you. You can block or counter, and every save fills your aura. |
| Invisible au Shadow reveal. Après un coup : +30 % vitesse 5 s. Esquive : 10 %. LMS : recharges améliorées. | Le Shadow reveal ne te montre pas. Après un coup : +30 % de vitesse pendant 5 s. 10 % de chances d’esquiver. En LMS : recharges plus courtes. | Shadow reveal doesn't show you. After a hit: +30% speed for 5 s. 10% chance to dodge. In LMS: shorter cooldowns. |
| Armure 200. Mange les épaves de drone au contact : +7 PV. Se recharge aux prises. Les soins d’Elly ne fonctionnent pas sur elle. Explose à sa mort : Alice étourdie 5 s dans un rayon de 7 m. Ne peut pas être réanimée. | 200 d’armure. Tu manges les épaves de drone au contact (+7 PV) et tu te recharges aux prises. Les soins d’Elly ne marchent pas sur toi. À ta mort, tu exploses : Alice est étourdie 5 s si elle est à moins de 7 m. Personne ne peut te réanimer. | 200 armour. You eat drone wrecks on contact (+7 HP) and recharge at outlets. Elly's heals don't work on you. When you die, you explode: Alice is stunned for 5 s if she's within 7 m. Nobody can revive you. |
| Entend les actions d'Alice partout dans l'école. LMS : Shotgun unique. | Tu entends les pas et les capacités d’Alice partout sur la carte. En LMS : un tir de Shotgun, une seule fois. | You hear Alice's footsteps and abilities anywhere on the map. In LMS: one Shotgun blast, just once. |
| Après un coup : vitesse ×2 pendant 3 s. LMS : hausse des ressources. | Après un coup : vitesse ×2 pendant 3 s. En LMS : « Je peux le faire » se débloque. | After a hit: speed ×2 for 3 s. In LMS: “I can do it” unlocks. |
| Une seule porte condamnée à la fois. Traverse ses propres piques. Après chaque stun : aura rouge et protection contre les stuns pendant 5 s. | Une seule porte condamnée à la fois. Tu traverses tes propres piques. Après chaque stun : aura rouge, et plus aucun stun pendant 5 s. | Only one door sealed at a time. You pass through your own spikes. After each stun: red aura, and no more stuns for 5 s. |

### `ui.gd` (48)

| Avant | Après | Anglais |
|---|---|---|
| L'école de Miss Circle sur deux étages : un atrium et ses deux escaliers, un couloir de casiers en boucle, des classes à deux portes. Les portes offrent à Alice des occasions de condamner un passage. | L’école de Miss Circle, sur deux étages : l’atrium et ses deux escaliers, un couloir de casiers qui fait le tour, des classes à deux portes. Alice peut condamner une porte à la fois. | Miss Circle's school, on two floors: the atrium and its two staircases, a locker corridor that loops around, classrooms with two doors. Alice can seal one door at a time. |
| Les couloirs gardent leurs secrets. | Interdit de courir dans les couloirs. Sauf ce soir. | No running in the halls. Except tonight. |
| Dans les bois, chaque bruit compte. | Le bus ne partira pas sans toi. Normalement. | The bus won't leave without you. Probably. |
| La neige étouffe les pas. Pas la peur. | Bonnet, gants, écharpe. Et cours ! | Hat, gloves, scarf. Now run! |
| Simon et Ashura : maintenez la capacité 2 pour charger. Trois secondes de charge donnent six secondes de boost. | Simon et Ashura : maintiens la capacité 2 pour charger. 3 s de charge, 6 s de boost. | Simon and Ashura: hold ability 2 to charge. 3 s of charge gets you a 6 s boost. |
| Après chaque étourdissement, Alice résiste aux nouveaux stuns pendant 5 secondes : espacez vos attaques. | Après un stun, Alice ne peut plus être étourdie pendant 5 s. Ne balancez pas tout en même temps. | After a stun, Alice can't be stunned again for 5 s. Don't fire everything at once. |
| Début de LMS : +65 PV, jusqu’à 150 PV. Seul le courage de Bleuette (Je peux le faire) dépasse 150. | En LMS, tu gagnes 65 PV (150 max). Seule Bleuette peut dépasser 150, avec « Je peux le faire ». | In LMS you gain 65 HP (150 max). Only Bleuette can go past 150, with “I can do it”. |
| Aidez l’équipe pour remplir votre aura : soins, boosts, protections et stuns comptent. | Soins, boosts, protections, stuns : tout ce qui aide l’équipe remplit ton aura. | Heals, boosts, saves, stuns: anything that helps the team fills your aura. |
| Archives : maintenez E, puis appuyez sur la bonne touche J, K ou L. Une erreur déclenche l’alarme. | Archives : maintiens E, puis appuie sur la bonne touche (J, K ou L). Une erreur, et l’alarme sonne. | Archives: hold E, then press the right key (J, K or L). One mistake and the alarm goes off. |
| DOSSIER 013  ·  LA SONNERIE NE VOUS SAUVERA PAS | DOSSIER 013  ·  FERMETURE DES GRILLES À 16 H 30 | FILE 013  ·  GATES CLOSE AT 4:30 PM |
| La sonnerie ne vous sauvera pas. | Ne reste pas après les cours. | Don't stay after school. |
| Préparer une manche solo contre les bots : rôle, personnage et carte. | Une partie contre des bots. Choisis ton camp, ton perso et la carte. | A match against bots. Pick your side, your character and the map. |
| Salon Internet par code, connexion directe, comptes et groupes. | Joue avec tes potes : salon par code, connexion directe ou compte. | Play with your friends: lobby code, direct connection or account. |
| École ouverte sans chrono : teste chaque capacité, le LMS et la True Form. | L’école sans chrono, pour tester toutes les capacités, le LMS et la True Form. | The school with no timer, to try every ability, LMS and True Form. |
| Prologue, fins d’équipe et LMS. | Revois le prologue et toutes les fins. | Rewatch the prologue and every ending. |
| Des danses à acheter avec tes tickets, à faire en partie : roue des émotes (G), puis Tab. | Des danses à acheter avec tes tickets. En partie : G, puis Tab. | Dances to buy with your tickets. In a match: G, then Tab. |
| Fermer Paper Afterbell. | Fermer le jeu. À demain ! | Close the game. See you tomorrow! |
| Chaque manche rapporte des tickets (+30, plus ton score, plus un bonus si ton camp gagne). En partie, les danses sont dans la roue des émotes (G), pages DANSES (Tab). Les survivants proches qui font la même émote ou la même danse se synchronisent, musique et sons compris. | Chaque manche rapporte des tickets : 30, plus ton score, plus un bonus si ton camp gagne. En partie, G ouvre la roue des émotes et Tab passe aux danses. Des survivants proches qui font la même émote ou la même danse se synchronisent, musique et sons compris. | Every round earns you tickets: 30, plus your score, plus a bonus if your side wins. In a match, G opens the emote wheel and Tab switches to dances. Nearby survivors doing the same emote or dance sync up, music and sounds included. |
| L’ombre · empêcher la fuite | La tueuse · empêcher la fuite | The killer · stop the escape |
| LA CLOCHE SONNE | C’EST PARTI | HERE WE GO |
| DOSSIER  ·  L’OMBRE DE L’ÉCOLE | DOSSIER  ·  LA TUEUSE | FILE  ·  THE KILLER |
| Prix prévu : 700. Accessible pour tester cette alpha. | Prix prévu : 700. Gratuite pendant l’alpha, pour que tu puisses l’essayer. | Planned price: 700. Free during the alpha so you can try her. |
| LES OMBRES VOUS ATTENDENT | JOUER EN LIGNE | PLAY ONLINE |
| En ligne, entre amis | Entre amis | With friends |
| Retrouve tes amis et tes groupes privés sur le service configuré. Aucun serveur régional public n'est encore hébergé pour cette version. | Pour retrouver tes amis et tes groupes. Il n’y a pas encore de serveur régional public pour cette version. | To find your friends and parties. There's no public regional server for this version yet. |
| Crée un salon Internet et partage son code. Dans ce mode, un joueur héberge la partie. Tes amis peuvent jouer depuis une autre connexion. | Crée un salon et envoie le code à tes amis. C’est toi qui héberges la partie ; eux peuvent jouer de chez eux. | Create a lobby and send the code to your friends. You host the match; they can play from home. |
| Connexion automatique avec relais de secours. Le service de salons public de cette alpha est expérimental ; sa disponibilité peut varier. | Si la connexion directe ne passe pas, le jeu prend un relais. Le service de salons est encore expérimental : il peut lâcher de temps en temps. | If a direct connection doesn't work, the game falls back to a relay. The lobby service is still experimental, so it may drop out now and then. |
| Le jeu établit une connexion entre les participants. Cela peut prendre quelques secondes. | Connexion aux autres joueurs. Ça peut prendre quelques secondes. | Connecting to the other players. This can take a few seconds. |
| Le mode Internet utilise normalement le service public. Un groupe disposant de son propre serveur Noray peut le renseigner ici. | Par défaut, le mode Internet passe par le service public. Si ton groupe a son propre serveur Noray, mets son adresse ici. | By default, Internet mode goes through the public service. If your group runs its own Noray server, enter its address here. |
| Connexion directe facultative : utile sur le même réseau ou avec un serveur déjà accessible. Le salon Internet n'en a pas besoin. | Pas obligatoire : utile sur le même réseau, ou si l’hôte est déjà joignable. Le salon Internet n’en a pas besoin. | Optional: handy on the same network, or if the host can already be reached. Internet lobbies don't need it. |
| Avant la cloche | En attendant les autres | Waiting for everyone |
| Les places restantes sont complétées par des bots. Les amis présents gardent leur place si leur nombre dépasse ce réglage. | Des bots prennent les places libres. Si vous êtes plus nombreux que ce réglage, personne ne perd sa place. | Bots fill the empty spots. If there are more of you than this setting, nobody loses their spot. |
| École ouverte sans chrono. F2 permet de changer de personnage, préparer un LMS et réinitialiser. L’hôte règle les mannequins ; chaque ami contrôle ses propres essais. | L’école sans chrono. F2 pour changer de perso, lancer un LMS ou tout remettre à zéro. L’hôte règle les mannequins, chacun gère ses propres essais. | The school with no timer. F2 to switch characters, start an LMS or reset everything. The host sets up the dummies; everyone runs their own tests. |
| Suivi amorti derrière le personnage. | La caméra suit ton perso en douceur. | The camera follows your character smoothly. |
| Tremblement lors des coups et des impacts. | L’écran tremble quand ça cogne. | The screen shakes when things hit hard. |
| Objectif : atteindre la sortie lorsqu’elle s’ouvre à 01:20. Le dernier survivant a un LMS de la durée de sa musique. Alice ferme la sortie et suspend le chrono pendant sa True Form, une seule fois après 15 stuns. Simon et Ashura : maintenir la capacité 2 pour charger, puis relâcher. Le boost dure 3, 4 ou 6 s selon la charge. | Le but : atteindre la sortie quand elle s’ouvre, à 01:20. Le dernier survivant a droit à un LMS qui dure le temps de sa musique. Après 15 stuns, Alice peut passer en True Form, une seule fois : sortie fermée et chrono en pause. Simon et Ashura chargent leur capacité 2 en la maintenant ; selon la charge, le boost dure 3, 4 ou 6 s. | The goal: reach the exit when it opens, at 01:20. The last survivor gets an LMS that lasts as long as their music. After 15 stuns, Alice can go True Form, once: exit closed and timer paused. Simon and Ashura charge ability 2 by holding it; depending on the charge, the boost lasts 3, 4 or 6 s. |
| G · roue d’émotes. Simon OM : 3 alterne lancer et coup éclair. L’aura récompense les actions utiles ; 100 points débloquent les bonus pendant le LMS. (onglet Accessibilité) | Tu peux aussi couper les secousses de caméra, les onomatopées et les effets d’écran dans l’onglet JEU. | You can also turn off camera shake, comic words and screen effects in the GAME tab. |
| 15 étourdissements débloquent la True Form d’Alice : 30 secondes, chrono suspendu, sortie fermée. (astuce) | Après 15 stuns, Alice peut passer en True Form, une seule fois : 30 s, chrono en pause et sortie fermée. | After 15 stuns, Alice can go True Form, just once: 30 s, timer paused and exit closed. |
| Elly entend les capacités d’Alice partout dans l’école. (astuce) | Elly entend les pas et les capacités d’Alice partout sur la carte. | Elly hears Alice's footsteps and abilities anywhere on the map. |
| LES HISTOIRES APRÈS LA CLOCHE | TOUS LES FILMS DU JEU | EVERY FILM IN THE GAME |
| Revois le prologue et choisis qui affronte Alice. Les fins d’équipe s’adaptent aux survivants présents. | Revois le prologue et toutes les fins. Pour les fuites en équipe, choisis qui s’en sort : la scène change avec. | Rewatch the prologue and every ending. For team escapes, pick who makes it out: the scene changes to match. |
| Coche les personnages qui ont survécu pour voir leur fin exacte. Sans sélection, les 63 compositions sont affichées. | Coche les survivants pour voir leur fin. Sans rien cocher, les 63 combinaisons s’affichent. | Tick the survivors to see their ending. With nothing ticked, all 63 combinations show up. |
| La cloche attend | Souffle un coup | Catch your breath |
| LE BULLETIN DE LA NUIT | FIN DE LA MANCHE | END OF THE ROUND |
| Bulletin de la nuit | Bulletin de notes | Report card |
| Les soins effectifs, stuns, boosts, protections et le temps passé en danger comptent. Choisis un élève pour voir sa réaction. | Ce qui compte : soins, stuns, boosts, protections et temps passé en danger. Choisis un élève pour voir sa réaction. | What counts: heals, stuns, boosts, saves and time spent in danger. Pick a student to see their reaction. |
| LES PRÉSENCES DE CETTE MANCHE | DANS CETTE MANCHE | IN THIS ROUND |
| L’hôte réinitialise les archives communes. Approche une archive pour y travailler. | Les archives sont communes : seul l’hôte peut les remettre à zéro. Approche-toi d’une archive pour t’entraîner. | Archives are shared: only the host can reset them. Walk up to one to practise. |

### `localization.gd` (1)

| Avant | Après | Anglais |
|---|---|---|
| LA SONNERIE NE VOUS SAUVERA PAS. | NE RESTE PAS APRÈS LES COURS. | DON'T STAY AFTER SCHOOL. |

### `ui_pause_menu.gd` (2)

| Avant | Après | Anglais |
|---|---|---|
| Retourner dans la manche, là où la cloche t’attend. | Retour à la partie. | Back to the match. |
| LA CLOCHE ATTEND | ON SOUFFLE UN COUP | CATCH YOUR BREATH |

### `main.gd` (13)

| Avant | Après | Anglais |
|---|---|---|
| L'école après la cloche | L’école de Miss Circle | Miss Circle's School |
| La forêt des murmures | Les bois | The Woods |
| Le silence de l'hiver | La classe de neige | The Ski Trip |
| AURA ÉVEILLÉE | AURA PLEINE | AURA FULL |
| Les bonus de LMS sont disponibles. | Tes bonus de LMS sont débloqués. | Your LMS bonuses are unlocked. |
| VOUS ÊTES TOMBÉE | TU ES ÉLIMINÉE | YOU'RE OUT |
| VOUS ÊTES TOMBÉ | TU ES ÉLIMINÉ | YOU'RE OUT |
| ALERTE ARCHIVE · UNE PRÉSENCE A ÉTÉ RÉVÉLÉE | ALERTE ARCHIVE · UN ÉLÈVE S’EST FAIT REPÉRER | ARCHIVE ALERT · A STUDENT GOT SPOTTED |
| La cloche a sonné. Rejoignez la sortie lorsqu’elle s’ouvrira à 1:20. | La cloche a sonné. La sortie s’ouvre à 01:20. | The bell has rung. The exit opens at 01:20. |
| DERNIÈRE PRÉSENCE | DERNIER SURVIVANT | LAST ONE STANDING |
| — | DERNIÈRE SURVIVANTE | LAST ONE STANDING |
| %s · duel final | %s contre Alice | %s vs Alice |
| DERNIÈRE PRÉSENCE / « X · duel final » | DERNIER SURVIVANT ou DERNIÈRE SURVIVANTE / « X contre Alice » | LAST ONE STANDING / "X vs Alice" |

### `combat.gd` (19)

| Avant | Après | Anglais |
|---|---|---|
| Ce personnage n'a pas de bonus Boost défini. Utilise Je crois en toi. | Pas d’encouragement prévu pour ce perso. Essaie plutôt « Je crois en toi ». | No cheer planned for this character. Try “I believe in you” instead. |
| DERNIÈRE PRÉSENCE · +%d PV (maximum 150) | LMS · +%d PV (150 max) | LMS · +%d HP (150 max) |
| AURA ÉVEILLÉE · Dernière chance : tiens jusqu'à la sonnerie ! | AURA PLEINE · Tiens jusqu’à la fin de ta musique ! | AURA FULL · Hold on until your music ends! |
| AURA ÉVEILLÉE · 4 : Dropkick unique (5 s de stun) | AURA PLEINE · 4 : un Dropkick (5 s de stun) | AURA FULL · 4: one Dropkick (5 s stun) |
| AURA ÉVEILLÉE · 4 : Shotgun unique (3 s de stun) | AURA PLEINE · 4 : un tir de Shotgun (3 s de stun) | AURA FULL · 4: one Shotgun blast (3 s stun) |
| AURA ÉVEILLÉE · 4 : Je peux le faire ! | AURA PLEINE · 4 : Je peux le faire ! | AURA FULL · 4: I can do it! |
| AURA ÉVEILLÉE · un allié éliminé peut réparer ton armure (150 PV max). | AURA PLEINE · un allié éliminé peut réparer ton armure (150 PV max). | AURA FULL · an eliminated ally can repair your armour (150 HP max). |
| ALICE DANS TON OMBRE ! Elle émerge dans 1,2 s : déplace-toi ! | ALICE ARRIVE DERRIÈRE TOI ! Dans 1,2 s. Bouge ! | ALICE IS COMING UP BEHIND YOU! 1.2 s. Move! |
| TRUE FORM · bond meurtrier · chronomètre suspendu | TRUE FORM · bond mortel · chrono en pause | TRUE FORM · deadly pounce · timer paused |
| Ton drone nous protège ! Sa prochaine recharge sera 25 % plus rapide. | A-Ashura, ton drone, il gère ! Sa prochaine recharge ira 25 % plus vite. | A-Ashura, your drone is great! Its next recharge will be 25% faster. |
| Heureusement que t'es là pour nous protéger, frangin ! | M-merci d’être là, Usayuko… Ton prochain stun dure 1,5 s de plus. | Th-thanks for being here, Usayuko… Your next stun lasts 1.5 s longer. |
| Cours, Simon, on te suit ! Ta prochaine Course éclair durera 2 s de plus. | C-cours, Simon, on te suit ! Ta prochaine Course éclair durera 2 s de plus. | R-run, Simon, we're right behind you! Your next Flash Sprint will last 2 s longer. |
| Allez, on va y arriver ensemble ! | On… on va y arriver, Lysia ! Ta prochaine recharge sera 25 % plus courte. | We… we can do this, Lysia! Your next recharge will be 25% shorter. |
| C'est si soulageant de vous avoir à nos côtés, monsieur ! | Elly, t-tu nous sauves la vie ! Ton prochain soin comptera double. | Elly, y-you're a lifesaver! Your next heal will count double. |
| Je crois en toi ! Capacité rechargée. | J-je crois en toi ! Capacité rechargée. | I-I believe in you! Ability recharged. |
| Aucun espace libre derrière les élèves pour émerger. | Pas de place derrière les élèves pour surgir. | No room behind the students to pop up. |
| UNE OMBRE DERRIÈRE TOI · Alice émerge dans 1,2 s ! | UNE OMBRE DERRIÈRE TOI · Alice arrive dans 1,2 s ! | A SHADOW BEHIND YOU · Alice arrives in 1.2 s! |
| SOIN · pose-toi au sol pour soigner. | SOIN · pas en plein saut : attends d’atterrir. | HEAL · not mid-jump: wait until you land. |
| oriente ton regard vers Alice | tourne-toi vers Alice | turn to face Alice |

### `ui_hud.gd` (10)

| Avant | Après | Anglais |
|---|---|---|
| ARCHIVE · CONTRÔLE D’INTÉGRITÉ | ARCHIVE · APPUIE SUR LA BONNE TOUCHE | ARCHIVE · PRESS THE RIGHT KEY |
| L'ÉCOLE SE REFERME | LES GRILLES SONT FERMÉES | THE GATES ARE LOCKED |
| ALICE · Éliminez tous les survivants. | ALICE · Attrape-les avant qu’ils sortent. | ALICE · Catch them before they get out. |
| LA DERNIÈRE BLESSURE… | TU T’ÉCROULES… | YOU COLLAPSE… |
| ALICE EST DANS TON OMBRE ! ELLE ARRIVE DERRIÈRE TOI | ALICE ARRIVE DERRIÈRE TOI ! BOUGE ! | ALICE IS RIGHT BEHIND YOU! MOVE! |
| OMBRE PORTÉE · ÉMERGENCE DERRIÈRE LA CIBLE… | OMBRES · TU VAS SURGIR DERRIÈRE UN ÉLÈVE AU HASARD | SHADOWS · YOU'LL POP UP BEHIND A RANDOM STUDENT |
| Les élèves prennent de l'avance… | Les élèves ont quelques secondes d’avance. | The students get a few seconds' head start. |
| TRUE FORM · %.0f s · COMPÉTENCE 4 : BONDIR | TRUE FORM · %.0f s · CAPACITÉ 4 : BONDIR | TRUE FORM · %.0f s · ABILITY 4: POUNCE |
| EMPÊCHEZ LEUR FUITE (objectif d’Alice) | EMPÊCHE-LES DE FUIR | STOP THEIR ESCAPE |
| SORTIE OUVERTE · EMPÊCHEZ LEUR FUITE | SORTIE OUVERTE · EMPÊCHE-LES DE FUIR | EXIT OPEN · STOP THEIR ESCAPE |

### `online_menu.gd` (13)

| Avant | Après | Anglais |
|---|---|---|
| Ton compte est nécessaire | Il te faut un compte | You need an account |
| Ces statistiques proviennent des parties validées par les serveurs dédiés. Le solo et les essais du bac à sable ne les modifient pas. | Seules les parties sur serveur dédié comptent ici. Le solo et le bac à sable ne changent rien. | Only matches on dedicated servers count here. Solo and sandbox don't change anything. |
| Le couloir est encore calme | Personne pour l’instant | Nobody here yet |
| Les amis apparaîtront ici après acceptation de leur demande. | Tes amis s’affichent ici une fois leur demande acceptée. | Your friends show up here once their request is accepted. |
| Votre groupe privé | Ton groupe privé | Your private party |
| Ensemble, jusqu’à la sortie | On joue ensemble | Playing together |
| Créer votre partie | Créer ta partie | Create your match |
| Un serveur dédié exécute la simulation. Les bots complètent l’équipe. Ordinateurs et Android rejoignent le même groupe. | La partie tourne sur un serveur dédié. Des bots complètent l’équipe, et PC et Android peuvent jouer dans le même groupe. | The match runs on a dedicated server. Bots fill out the team, and PC and Android can play in the same party. |
| Forêt enneigée | Classe de neige | Ski trip |
| Forêt | Bois | Woods |
| Aucun serveur régional public n’est fourni pour l’instant. Le solo reste disponible. L’administrateur devra fournir l’adresse HTTPS du service. | Pas encore de serveur régional public. Le solo marche toujours. Pour le reste, il faut l’adresse HTTPS du service : demande-la à l’admin. | No public regional server yet. Solo still works. For everything else, you need the service's HTTPS address: ask the admin for it. |
| Sans hébergement configuré, les comptes et les parties régionales restent indisponibles. Utilise la même adresse sur ordinateur et Android. | Sans cette adresse, pas de comptes ni de parties régionales. Mets la même sur PC et sur Android. | Without this address, there are no accounts or regional matches. Use the same one on PC and Android. |
| Aucune région n’est hébergée pour l’instant. Les parties régionales deviendront disponibles quand un administrateur déploiera le serveur. | Aucune région n’est hébergée pour l’instant. Les parties régionales arriveront quand un admin aura mis le serveur en ligne. | No region is hosted yet. Regional matches will show up once an admin puts the server online. |

### `controls_menu.gd` (1)

| Avant | Après | Anglais |
|---|---|---|
| Choisis une commande à modifier. Échap annule la capture. | Choisis une commande, puis appuie sur la nouvelle touche. Échap pour annuler. | Pick a control, then press the new key. Esc to cancel. |

### `dances.gd` (6)

| Avant | Après | Anglais |
|---|---|---|
| Mains crochues, épaules qui sursautent, pas traînés. Pour la nuit de la cloche. | Mains crochues, épaules qui sursautent, pas traînés. Le zombie, quoi. | Clawed hands, twitchy shoulders, dragging feet. The zombie, basically. |
| Chasseuse de démons : dégainer, garde, coups nets et grand V doré. Le refrain qui a conquis 2025. | Chasseuse de démons : dégainer, garde, coups nets et grand V doré. Le refrain, tu l’as forcément eu dans la tête. | Demon hunter: draw, guard, clean strikes and a big golden V. You've definitely had that chorus stuck in your head. |
| Poignets croisés sur les rênes, pas chassés… et le lasso. | Poignets croisés sur les rênes, pas chassés, et pour finir le lasso. | Wrists crossed on the reins, side shuffles, and the lasso to finish. |
| L’air blasé… puis d’un coup les pouces levés qui montent et descendent, façon pom-pom girl coréenne. | L’air blasé, puis d’un coup les pouces levés qui montent et descendent, façon pom-pom girl coréenne. | Looking bored, then suddenly thumbs up bouncing up and down, Korean cheerleader style. |
| Casque sur les oreilles, on vibre seul… jusqu’à ce qu’un ami vienne danser derrière toi. | Casque sur les oreilles, tu vibres dans ton coin, jusqu’à ce qu’un ami vienne danser derrière toi. | Headphones on, you vibe on your own until a friend starts dancing behind you. |
| Les ailes de poulet qui battent, la tête qui picore… puis la banane, bras en arc au-dessus de la tête. | Les ailes de poulet qui battent, la tête qui picore, puis la banane : bras en arc au-dessus de la tête. | Flapping chicken wings, pecking head, then the banana: arms arched overhead. |

### `training.gd` (2)

| Avant | Après | Anglais |
|---|---|---|
| Blessure fatale appliquée : première chute, ou mort définitive après une réanimation. Lysia ne peut pas être relevée. | Tu tombes : la première fois, un allié peut te relever ; la deuxième, c’est fini. Lysia, elle, ne se relève jamais. | You go down: the first time, an ally can revive you; the second time, you're out. Lysia never gets back up. |
| True Form prête · ferme le panneau et active la compétence 6. | True Form prête · ferme le panneau et lance la capacité 6. | True Form ready · close the panel and use ability 6. |

### `cinematics.gd` (3)

| Avant | Après | Anglais |
|---|---|---|
| Le film du premier lancement : Simon et Ashura affrontent Yiero dans une dimension ténébreuse… puis Simon atterrit à l’école en plein combat. | Le film du premier lancement. Simon et Ashura tombent sur Yiero, un démon géant, au milieu d’une mer d’encre. Simon finit par atterrir à l’école, en pleine bagarre contre Alice. | The film from the very first launch. Simon and Ashura run into Yiero, a giant demon, in the middle of a sea of ink. Simon ends up crash-landing at school, right in a fight with Alice. |
| La dernière tentative de/d’ X échoue. Alice le/la rattrape, frappe et l’achève au sol. | X est le dernier / la dernière encore debout. Alice finit par le / la rattraper. | X is the last one still standing. Alice catches up with him / her in the end. |
| 63 fuites en équipe : « A ; B ; C. Puis l’équipe s’échappe. » (même pour un survivant seul) | Seul : « A, puis se sauve. » À deux : « A et B. Puis les deux se sauvent. » À trois et plus : « A, B et C. Puis tout le monde se sauve. » Elly en groupe : « soigne ceux qui en ont besoin », Bleuette en groupe : « encourage l’équipe ». | Solo: “A, then makes a run for it.” Two: “A and B. Then they both make a run for it.” Three or more: “A, B and C. Then everyone makes a run for it.” |

### `escape_flow.gd` (1)

| Avant | Après | Anglais |
|---|---|---|
| LMS · AURA COMPLÈTE, SORTIE MAINTENUE | LMS · AURA PLEINE : LA SORTIE RESTE OUVERTE | LMS · AURA FULL: THE EXIT STAYS OPEN |

### `exit_alarm.gd` (1)

| Avant | Après | Anglais |
|---|---|---|
| EMPÊCHEZ LEUR FUITE (bannière d’Alice à l’ouverture de la sortie) | EMPÊCHE-LES DE FUIR | STOP THEIR ESCAPE |

### `audio/CREDITS.txt` et `audio/CREDITS.en.txt`

L’écran Crédits affichait le fichier tel quel : notes de mixage (gains en dB, −17,5 LUFS, Ogg q8, 320 kbit/s),
nom de fichier brut (« Simon OST final mais vrmt final… .mp3 »), un ancien LMS qui n’est plus dans le jeu, et tout
en français même avec le jeu en anglais. Il est réécrit pour les joueurs :

- **toutes les attributions sont gardées mot pour mot** (« “Red” by Scott Buckley — released under CC-BY 4.0. »,
  liens, auteurs freesound et licences CC BY / CC0), avec la mention des modifications demandée par CC BY
  (« coupés, raccordés et remis à niveau », Juggernaut ralenti en True Form) ;
- les musiques composées pour le jeu sont toutes citées (« Fin des cours », « Sous les pins d’encre »,
  « Craie et givre », « Retenue », danses, victoires LMS, prologue, blocus, « Course vers la sortie ») ;
- le détail technique reste dans `docs/AUDIO-CREDITS.md` et `docs/AUDIO-SOURCES.json` ;
- `audio/CREDITS.en.txt` (nouveau) est la version anglaise ; `ui.gd` la charge quand le jeu est en anglais
  (`*.txt` est déjà dans le filtre d’export).

### `localization.gd (anglais seul)` (1)

| Avant | Après | Anglais |
|---|---|---|
| PRÊT POUR LA RENTRÉE → READY FOR AFTERBELL | PRÊT POUR LA RENTRÉE (inchangé) | BACK TO SCHOOL |
