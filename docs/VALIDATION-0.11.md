# Validation 0.11 — 20 septembre 2026

## Comportements vérifiés

- 68 contrôles de combat et de déplacement : charges et immobilisation, vitesses/durées, transport de Simon, drones et débris, prises de Lysia, surchauffe, chocolat, stun et invulnérabilité, True Form, déplacement avec le vrai moteur physique.
- 40 contrôles d'intégration PC et 42 en mode tactile : menus, remappage, sortie à 80 secondes, True Form et suspension du chrono, vraie fuite, réinitialisation entre manches, LMS et aura, durées des trois OST fournies, préparation de la True Form dans le terrain d'essai. Ces 40 contrôles passent aussi sur l'EXE Windows exporté, avec les scripts compilés.
- 265 contrôles des trois cartes : navigation, collisions, doubles issues et routes vers les étages. Quinze vues des cartes inspectées.
- 13 776 assertions sur les huit modèles, tailles, squelettes, déformations et poses ; 64 vues GPU. Après optimisation, poses comparées au retargeteur précédent avec une tolérance de 0,0001. Il s'agit d'assertions sur des composants de poses, pas de milliers de scènes de jeu distinctes.
- 64 contrôles des retours visuels/sonores : aura rouge, boost/charge, prise/chocolat, explosion/bond, respect des flashs réduits, géométries réutilisées, reprise LMS après True Form et nettoyage entre manches.
- 78 contrôles de traduction française/anglaise, menus et capacités, en préservant les pseudos.
- 50 contrôles du service HTTP et 35 du launcher exporté, dont téléchargement/installations de paquets de test, validation du hash et retour arrière.
- 34 contrôles du menu de compte en jeu avec un véritable service HTTP local : comptes, amis, invitations, règles du groupe et absence de serveur configuré.
- 50 contrôles réseau avec un serveur dédié réel, un client PC et un client en mode Android simulé : deux manches, survivants uniques, Alice bot, autorisations du chef, statistiques, revanche et transfert du contrôle après déconnexion du chef.
- Ces 50 contrôles ont ensuite été rejoués avec les livrables compilés : EXE/PCK livré pour le serveur et le client Windows, ressources réellement extraites de l'APK signé pour le client tactile. Réussite complète ; fins de manches provoquées par le scénario après cinq secondes. Le launcher exporté détecte le jeu dans le dossier livré et le lance effectivement, sans service configuré.

## Rendu et performance

Menus PC/tactiles, configuration des touches, terrain d'essai, visée de Simon et True Form capturés dans le moteur. Texte, contraste et chevauchements corrigés après inspection.

Sur la GTX 1650 de cette machine, à 1280×800, scénario à sept personnages avec le profil Fluide : intervalle médian entre images de 27,6 ms avant optimisation des rigs, puis 16,6 ms après ; 95e percentile de 65,8 puis 19,4 ms. Échantillons de 150 images après 150 images d'échauffement. Cela décrit ce court scénario local et ne garantit pas ces performances sur tous les PC ou téléphones. Les modèles cachés ne sont plus animés en doublon, les os/matrices sont mis en cache et les morphs inchangés ne sont plus renvoyés à chaque image.

Les textures extraites des modèles sont plafonnées à 2048 et compressées pour limiter la mémoire. Le rendu mobile conserve les ombres principales et réduit résolution et passes de lumière selon le profil.

## Limites des essais

L'APK final est signé avec la même clé que les versions précédentes (version 1100, paquet `org.paperafterbell.game`). Signature v2/v3, alignement du paquet, bibliothèques ARM64 compatibles avec les pages de 16 Ko, architecture ARMv7, mode paysage et permissions réseau vérifiés. **264 contrôles de contenu et d'identité** réussis : scripts compilés, modèles, musiques, portraits, textures mobiles et absence de fichiers privés. Les **42 contrôles d'intégration tactiles** passent également sur les ressources compilées extraites de cet APK, exécutées dans Godot sur PC. Cette vérification ne remplace pas une installation sur téléphone.

Aucun hébergement public ni test interrégional, aucune charge de plusieurs salons distants. Aucun téléphone Android ou ensemble complet de manettes physiques connecté. Le mode Android simulé n'est pas un test sur téléphone ; les périphériques précis et les réseaux réels doivent encore être éprouvés.

La validation des modèles ne remplace pas un jugement artistique. Les animations restent procédurales. L'école est retravaillée à partir des références, pas importée depuis une carte externe complète.

Rapports détaillés conservés dans `work/v11` du projet de développement. Les sources livrées ne contiennent pas les profils de test, mots de passe ou bases de comptes utilisés pendant les essais.
