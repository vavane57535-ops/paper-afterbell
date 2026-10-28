# Afterbell — IA de trading crypto auto-apprenante

Afterbell est une application de bureau (Windows, macOS, Linux) qui :

- **analyse le marché crypto** en continu (scanner de toutes les paires d'un exchange, vue globale du marché, graphiques) ;
- **lit l'actualité** (CoinDesk, Cointelegraph, Decrypt, Bitcoin Magazine, CryptoSlate, The Block) et l'indice Fear & Greed, avec une analyse de sentiment spécialisée crypto (français + anglais) ;
- **apprend au fur et à mesure** : un ensemble d'« experts » (tendance, retour à la moyenne, cassure, modèle statistique en ligne, achat-conservation, cash) dont les poids s'ajustent en permanence selon leurs résultats réels ;
- **simule des milliers de marchés par seconde**, réalistes et calibrés sur les statistiques réelles des cryptos, pour entraîner l'IA et mesurer ses risques ;
- **fait du paper trading** (prix réels, argent fictif) ;
- puis seulement, **trade en réel** avec un capital que tu choisis, sous des limites de risque strictes.

---

## ⚠️ À lire avant tout : ce qu'Afterbell peut et ne peut pas faire

**Aucune IA — ni celle-ci, ni aucune autre — ne peut te garantir 95 % de chances de gagner.**
Les marchés crypto sont en grande partie imprévisibles. Quiconque promet un taux de réussite garanti
(robots « 95 % de réussite », signaux payants, etc.) se trompe ou cherche à t'arnaquer.

Ce qu'Afterbell fait à la place, honnêtement :

| Ce que tu voulais | Ce qu'Afterbell fait réellement |
|---|---|
| « 95 % de chances de réussite » | Il **mesure** la probabilité de gain et de perte sur des dizaines de milliers de scénarios simulés, avec intervalle de confiance, et te les montre tels quels. Il vise surtout à **limiter la perte** : par défaut, l'IA s'arrête d'elle-même dès −10 % depuis le plus haut, et la porte de validation exige que dans **au moins 95 % des simulations, la perte reste inférieure à 10 %**. C'est la seule version honnête du « 95 % » : un plafond de perte contrôlé, pas une promesse de gain. |
| « Voir que c'est 100 % safe » | Les simulations réduisent les mauvaises surprises mais **ne prédisent pas l'avenir** : le marché réel peut faire pire que tout ce qui a été simulé. C'est pour ça qu'il y a ensuite le paper trading (au moins 14 jours sur le vrai marché, sans argent), puis le réel avec de petites sommes. |
| « Mettre ma carte bancaire » | Afterbell **refuse toute carte bancaire** (voir plus bas). Ton argent reste sur ton compte d'exchange ; l'IA y passe des ordres via une clé API **sans droit de retrait**. |
| « Sécurisé et pas hackable » | Rien n'est « inviolable », mais Afterbell est conçu pour que même dans le pire cas, **personne ne puisse retirer ton argent** via l'application (voir « Sécurité »). |

**N'investis que ce que tu peux te permettre de perdre entièrement.**

---

## Pourquoi Afterbell ne demande jamais ta carte bancaire

1. Les exchanges (Binance, Kraken, Coinbase…) ne permettent pas à un robot de trader avec une carte :
   on dépose de l'argent **sur l'exchange**, via leur propre page de paiement (certifiée PCI-DSS, avec 3-D Secure).
2. Stocker une carte dans une application maison serait **le plus gros risque de sécurité possible** :
   un numéro de carte volé permet des achats immédiats.
3. À la place, Afterbell utilise une **clé API** que tu crées sur ton exchange avec :
   - ✅ droit de **trading spot uniquement** ;
   - ❌ **retraits désactivés** ;
   - ✅ restriction à **l'adresse IP** de ton ordinateur (si l'exchange le propose).

   Résultat : même si quelqu'un volait cette clé, il ne pourrait **pas sortir l'argent** de ton compte.

L'application détecte et rejette automatiquement tout numéro de carte bancaire saisi par erreur.

---

## Installation et lancement

Prérequis : **Python 3.10 ou plus récent** ([python.org](https://www.python.org/downloads/) — sous Windows, coche « Add Python to PATH »).

### Windows
Double-clique sur `scripts\start_windows.bat`.

### macOS / Linux
```bash
./scripts/start_mac_linux.sh
```

Le script crée un environnement isolé (`.venv`), installe les dépendances, puis ouvre l'interface
(fenêtre native si `pywebview` est disponible, sinon ton navigateur).

### Manuellement
```bash
python -m venv .venv
source .venv/bin/activate        # Windows : .venv\Scripts\activate
pip install -e ".[desktop]"      # ou: pip install -e .
python -m afterbell              # options : --port 8765 --no-window --no-browser --data-dir DOSSIER
```

Tes données (coffre-fort chiffré, journal, modèle entraîné, cache de marché) sont dans `~/.afterbell/`.

---

## Parcours conseillé

1. **Sécurité** → crée ton coffre-fort (mot de passe fort, 12 caractères minimum).
2. **Simulation** → lance quelques milliers de simulations pour voir comment l'IA se comporte (avant entraînement).
3. **Entraînement** → l'IA s'entraîne sur des marchés simulés variés (et sur l'historique réel si disponible),
   puis est validée sur **10 000 scénarios jamais vus** et sur **9 scénarios de crise** inspirés de faits réels
   (krach COVID 2020, effondrement LUNA, faillite FTX, flash crash, marché baissier 2022, panne d'exchange…).
4. **Paper trading** → au moins 14 jours sur le vrai marché avec de l'argent fictif.
5. **Lancement réel** → se déverrouille **uniquement** si toutes les conditions sont remplies.
   Commence petit. Tu peux tout arrêter à tout moment avec le bouton rouge **ARRÊT D'URGENCE**.

### Créer une clé API sûre (exemple Binance)
1. Binance → Profil → **Gestion des API** → Créer une API (type « générée par le système »).
2. Restrictions : coche **uniquement** « Activer le trading Spot et sur marge » (Afterbell ne fait que du spot, sans levier).
3. **Ne coche jamais** « Activer les retraits ».
4. Restreins l'accès à **ton adresse IP**.
5. Copie la clé et le secret dans Afterbell → **Sécurité** → Clés API. Ils sont chiffrés dans le coffre-fort.

Afterbell vérifie les permissions quand l'exchange le permet et **refuse de démarrer** si les retraits sont activés.

---

## Comment fonctionne l'IA

Le « cerveau » est **le même code** en simulation, en paper trading et en réel (aucune triche possible entre les modes).

- **Indicateurs** calculés en continu : momentum, écart de moyennes mobiles, RSI, bandes de Bollinger,
  volatilité courte/longue, volumes, position dans le canal haut/bas, drawdown, sentiment des news.
- **Six experts** proposent chacun une exposition (0 % à 100 % du capital alloué) :
  `cash`, `achat-conservation`, `tendance`, `retour à la moyenne`, `cassure`, `modèle ML`.
- **Apprentissage en ligne** :
  - un modèle de régression logistique (AdaGrad) apprend à chaque bougie si le prochain mouvement dépassera les frais ;
  - l'algorithme **Hedge** (poids multiplicatifs avec oubli) augmente le poids des experts qui gagnent et
    diminue celui des perdants, et s'adapte quand le marché change de régime. Comme l'expert « cash » en fait partie,
    l'ensemble ne peut pas durablement faire beaucoup pire que « ne rien faire ».
- **Surcouche de risque** : protection anti-krach (volatilité qui explose), mode défensif si les news sont très
  négatives, ciblage de volatilité, hystérésis pour éviter de payer des frais inutiles.
- **Uniquement du spot, sans levier ni vente à découvert.**

L'**entraînement** combine l'expérience accumulée sur des milliers de marchés simulés et une recherche
évolutive des meilleurs réglages, jugés sur un score qui pénalise fortement les pertes extrêmes.

## Le simulateur

- **Régimes de marché** (haussier, baissier, range, krach) qui alternent selon une chaîne de Markov ;
- **volatilité en grappes** (GARCH) et **queues épaisses** (loi de Student) comme sur les vraies cryptos ;
- **sauts** (chocs soudains, plus souvent à la baisse) ;
- volumes corrélés à la volatilité ; sentiment des news **réactif** (il réagit aux prix, il ne les devine jamais) ;
- **bootstrap de l'historique réel** (rejoue des morceaux du vrai passé dans un ordre aléatoire) ;
- **coûts réels** : frais de l'exchange, spread qui s'élargit quand ça bouge, glissement selon la taille, latence ;
- exécution **sans regard vers le futur** : l'IA décide avec les données disponibles à l'instant t uniquement.

Les paramètres par défaut reproduisent les faits statistiques du Bitcoin (2018-2025) avec une tendance de long terme
volontairement **prudente**, pour ne pas surestimer les gains.

## La porte de validation (déverrouillage du réel)

| Étape | Condition (par défaut) |
|---|---|
| Simulation | ≥ 10 000 scénarios de validation |
| Simulation | Probabilité de perdre plus de 10 % ≤ 5 % |
| Simulation | Probabilité de finir en gain ≥ 50 % et rendement médian ≥ 0 |
| Simulation | Arrêt d'urgence déclenché dans ≤ 15 % des scénarios |
| Crises | Perte médiane ≤ 20 % dans chacun des 9 scénarios de crise |
| Paper trading | ≥ 14 jours, ≥ 5 trades, drawdown ≤ 8 %, aucun arrêt d'urgence |

Passer la porte **n'est pas une garantie** : c'est une mesure dans des conditions simulées et sur une courte période réelle.

## Limites de risque en réel (modifiables dans Sécurité, sans pouvoir désactiver la protection)

- exposition totale max 80 % du capital alloué, 50 % par actif ;
- perte journalière max 3 % → tout est vendu et l'IA se met en pause jusqu'au lendemain ;
- perte max 10 % depuis le plus haut → **arrêt d'urgence**, réarmement manuel obligatoire ;
- ordres à cours limité uniquement avec protection de prix, 30 ordres/heure max ;
- uniquement des marchés liquides (≥ 20 M$ de volume sur 24 h) ;
- aucune décision si les données sont périmées ;
- l'IA n'utilise **que le capital alloué**, jamais le reste de ton compte.

---

## Sécurité

- **Coffre-fort chiffré** : scrypt + AES-256-GCM, mot de passe fort obligatoire, verrouillage automatique
  après inactivité, protection contre les essais répétés. Les secrets ne sont jamais affichés ni journalisés en clair.
- **Serveur local uniquement** (`127.0.0.1`), jeton de session aléatoire de 256 bits, protection contre le
  DNS rebinding et le CSRF, politique de sécurité du contenu stricte, aucune ressource externe dans l'interface.
- **Journal d'audit infalsifiable** : chaque action (ordre, démarrage, arrêt, réglage) est enchaînée par hachage ;
  toute modification est détectée.
- **Aucune fonction de retrait** n'existe dans le code.
- Ce qui reste de ta responsabilité : garder ton ordinateur à jour et sans logiciel malveillant, activer la double
  authentification (2FA) sur ton exchange, ne jamais partager ta clé API ni ton mot de passe.

---

## Pour les développeurs

- Architecture et contrats des modules : [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)
- Tests : `pip install -e ".[dev]" && pytest`
- Benchmark du simulateur : `python scripts/benchmark_sim.py`

Licence MIT. Afterbell est un outil logiciel, pas un conseil en investissement.
