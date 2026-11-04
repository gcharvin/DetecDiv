# Detective-UI — synthèse et roadmap

Date : 4 novembre 2026. Document de cadrage issu de la discussion avec Gilles.
Statut : orientations retenues et roadmap proposée ; prototype MATLAB de navigation en cours. Voir l'avancement en section 11.

## 1. Objectif

Faire de DetecDiv un espace de travail scientifique centré sur les images et les intentions de l'utilisateur. La fenêtre principale s'ouvre au lancement de DetecDiv. La gestion des projets, classifiers, processors et pipelines devient un panneau de cet espace.

Le problème actuel dépasse l'apparence de `score.mlapp` : les outils sont dispersés entre fenêtres et l'utilisateur doit connaître l'architecture interne pour trouver les opérations à enchaîner. La nouvelle UI doit guider les workflows, plutôt que reproduire graphiquement une collection de fonctions en ligne de commande.

L'inspiration napari concerne la place de l'image, les couches et les outils contextuels. Elle ne constitue pas une décision de remplacer MATLAB immédiatement ou de reproduire exactement napari.

## 2. Orientations retenues

- Développer d'abord la nouvelle interface MATLAB, dans ce worktree isolé.
- Réutiliser les fonctions métier et préserver les fonctionnalités existantes ; adapter leurs interfaces si nécessaire plutôt que dupliquer les algorithmes.
- Préparer ensuite la transposition en Python. Il n'est pas prévu de développer deux interfaces complètes en parallèle.
- Tenir compte du fait que la segmentation, le tracking et d'autres traitements utilisent déjà Python et que cette part doit augmenter. MATLAB assure aujourd'hui notamment l'interface et l'affichage ; la transition doit suivre les dépendances réelles, à inventorier.
- Garder les pipelines au cœur de l'exécution reproductible, tout en masquant leur complexité dans les usages courants.
- Révéler progressivement les paramètres et les outils avancés.
- Utiliser une interface intégralement en anglais, des menus classiques et le vocabulaire DetecDiv (Project, FOV, ROI). Un arbre unique permet de parcourir plusieurs projets ouverts.
- Réserver l'aide contextuelle aux tooltips MATLAB et à la barre d'état ; ne pas ajouter de paragraphes explicatifs permanents dans la fenêtre.
- Étudier la possibilité de ne plus dupliquer systématiquement les pixels bruts dans les H5 de chaque ROI, sans imposer dès maintenant un changement de stockage.

## 3. Philosophie UX

### Partir des intentions

Les entrées principales doivent exprimer des objectifs :

1. Explorer une acquisition.
2. Choisir les zones à analyser.
3. Segmenter et suivre les cellules.
4. Examiner et corriger les résultats.
5. Mesurer, comparer et exporter.

La hiérarchie `shallow → fov → roi → dataseries` reste compatible en interne et visible dans le navigateur Project → FOV → ROI. À la demande explicite de Gilles, conserver le vocabulaire DetecDiv, avec tous les libellés d'interface en anglais. Une ROI ne désigne pas nécessairement une cellule unique. Les intentions guident les outils sans remplacer la hiérarchie du projet par de nouveaux termes.

### Fournir deux repères complémentaires

- **Localisation** : arbre multi-projets et fil d'Ariane, par exemple `Project → FOV 3 → ROI 12`.
- **Avancement** : actions disponibles et outils contextuels, avec états utiles. Les explications restent dans les tooltips ou la barre d'état ; aucun bandeau didactique permanent n'est requis.

Le parcours ne doit pas devenir un assistant rigide. Il reste possible de revenir aux images, de corriger un résultat, de reprendre une analyse existante ou de travailler sur une sélection partielle.

### Montrer la complexité au moment utile

Chaque outil propose une configuration initiale pertinente, quelques réglages essentiels, puis un accès aux paramètres détaillés et au pipeline. Préférer cette progression locale à une séparation globale et obligatoire entre utilisateurs débutants et experts.

Les valeurs proposées doivent être explicites et adaptées au contexte. Le périmètre du traitement, les résultats créés ou remplacés, leur destination et les échecs restent visibles, même lorsque les détails techniques sont repliés.

## 4. Organisation de la fenêtre proposée

| Zone | Rôle |
| --- | --- |
| Centre | Images, couches, sélection, zoom et déplacement |
| Gauche, repliable | Arbre multi-projets Project → FOV → ROI, extensible aux objets de traitement |
| Droite, contextuelle | Widgets correspondant à l'action : canaux, zones, segmentation, correction, mesures |
| Bas | Navigation temporelle et panneaux de signaux ou de lignées activables |
| Haut | Menus classiques File / Edit / View / Navigate / Help, puis fil d'Ariane et retour au FOV |

Les outils doivent pouvoir être mobilisés dans la fenêtre principale. Commencer par des panneaux repliables et des dispositions mémorisables ; évaluer ensuite le détachement et le déplacement libre selon les capacités de MATLAB.

Précision de Gilles : le docking réel est requis dès la coquille, avant d'ajouter davantage d'outils. Projects, Image et Display doivent pouvoir être détachés et réancrés, avec sauvegarde et restauration du layout. L'hôte de docking est programmé via les API internes R2026a ; App Designer reste une option pour le contenu des widgets, pas pour la disposition globale.

La navigation position → zone → retour à la position utilise le même espace d'affichage. Préserver le temps, les canaux et la sélection lorsque leur correspondance est définie. Distinguer clairement aperçu depuis les données brutes et données extraites ou calculées.

## 5. Pipelines intégrés aux actions

Exemple : « Segmenter ces cellules » présente la sélection, une méthode proposée et les réglages essentiels. L'action construit ou configure un pipeline et lance une exécution traçable. « Voir le pipeline » donne accès aux étapes et paramètres détaillés de cette même exécution.

- `@pipeline` reste le modèle indépendant ; `pipelineRun` représente l'exécution sur les données.
- Réutiliser `runPipeline.m`, la validation, le dry-run, les politiques de réexécution et les rapports disponibles.
- Prévoir la reprise, l'annulation et les traitements distants selon les capacités effectives du moteur et du Hub ; identifier les écarts lors de l'audit.
- Conserver la provenance : sélection, paramètres effectifs, modèle utilisé, versions et résultats.
- Les processors restent des modules de premier plan, au même titre que les classifiers.

## 6. Architecture pour MATLAB puis Python

Séparer quatre responsabilités :

1. **Présentation** : widgets, disposition, interactions et rendu.
2. **État de session** : expérience active, sélection, temps, canaux, outil et état du parcours, sans dépendre des handles graphiques.
3. **Actions et orchestration** : traduire une intention en sélection et configuration de pipeline, puis suivre l'exécution.
4. **Métier et accès aux données** : packages existants, moteurs MATLAB/Python, lecture et sauvegarde.

Les callbacks graphiques ne doivent pas devenir le lieu des décisions scientifiques. Les fonctions de `score` dépendant directement de tables ou de composants de l'app demanderont des adaptateurs ou une extraction ciblée de leur logique.

Préserver la chaîne App Designer / code synchronisé. Les helpers `score_gui_layout.m`, `sync_score_layout.m` et leurs équivalents sont des références à examiner avant toute modification des MLAPP.

Pour la future version Python, stabiliser les descriptions des actions, paramètres, sélections, résultats et erreurs. Ne pas tenter de sérialiser directement des objets graphiques ou de copier toute la hiérarchie MATLAB. Inventorier aussi les dépendances de lecture, sauvegarde et annotation encore propres à MATLAB.

## 7. Pixels bruts : référence, cache et extraction

Objectif à étudier : permettre à une zone d'analyse d'exister sans copie persistante de ses pixels bruts.

| Mode envisagé | Avantage | Contrainte |
| --- | --- | --- |
| Référence aux sources | Évite la duplication des pixels | Sources accessibles et coût de relecture |
| Cache à la demande | Réutilisation locale entre consultations et traitements | Budget disque, invalidation et gestion du cache |
| Extraction persistante | Sous-ensemble autonome, accès potentiellement plus rapide | Duplication des pixels |

La référence doit suffire à reconstruire les pixels : identité de la source, position, géométrie, temps, canaux et transformations appliquées, notamment dérive et orientation. Définir comment détecter une source modifiée et éviter un cache périmé. L'accès aux sources depuis les workers distants doit être vérifié.

Les modules devraient demander des images pour une sélection de temps et de canaux via une couche d'accès commune, plutôt que supposer que `roi.image` est chargé ou qu'un dataset H5 existe. Le format exact de cette couche reste à concevoir. Les H5 existants restent lisibles et peuvent continuer à stocker les résultats dérivés.

Mesurer les performances avant de choisir un défaut : stockage local/réseau, formats sources, nombre de zones, chevauchements, accès séquentiel/aléatoire et traitements successifs. Étudier la lecture groupée par position et blocs temporels, ainsi que la réutilisation entre étapes. Définir le comportement lorsque la source est absente et le moyen de rendre une analyse autonome.

Ne pas supprimer les extractions existantes et ne pas changer globalement les contrats des pipelines avant validation. Dans l'UX cible, distinguer « définir une zone » et « matérialiser ses pixels ».

## 8. Roadmap proposée et critères de passage

### Étape 0 — audit et scénario de référence

- Inventorier les fonctionnalités de `detecdiv`, `workflow` et `score`, leurs points d'entrée et leurs dépendances aux composants graphiques.
- Établir une matrice : fonction existante, intention utilisateur, backend réutilisable, adaptation requise et validation.
- Choisir une acquisition représentative et une analyse existante, sans modifier les originaux.
- Recenser les prérequis MATLAB/Python et les références de code effectivement actives.

**Critère :** périmètre du premier prototype défini, avec une liste explicite des fonctions différées.

### Étape 1 — fenêtre MATLAB et navigation unifiée

- Créer une entrée expérimentale distincte des applications actuelles.
- Afficher une acquisition, naviguer entre positions, ouvrir une zone et revenir au champ dans la même fenêtre.
- Ajouter le fil d'Ariane, le parcours, la navigation temporelle et les premiers panneaux contextuels.
- Réutiliser d'abord les accès aux données existants.

**Critère :** le parcours brut → zone → retour fonctionne sur des données réelles sans lancer une deuxième fenêtre de travail.

### Étape 2 — première action guidée avec pipeline

- Intégrer « Segmenter ces cellules » avec configuration proposée et portée explicite.
- Relier l'action aux modules et au runner existants.
- Afficher progression, résultats, erreurs et provenance ; rendre le pipeline inspectable.

**Critère :** ouvrir → sélectionner une zone → segmenter → examiner et corriger un résultat dans un parcours cohérent et traçable.

### Étape 3 — couverture fonctionnelle progressive

- Intégrer les modes de zones manuelles, par motif, grille et suivies.
- Étendre aux corrections de masques, annotations, tracking, lignées, signaux, quantification et exports.
- Intégrer gestion des projets, classifiers, processors et pipelines dans les panneaux adaptés.
- Vérifier sauvegarde, réouverture et compatibilité avec les interfaces historiques.

**Critère :** la matrice de couverture identifie les capacités reprises, vérifiées et encore disponibles seulement dans les anciennes apps.

### Étape 4 — prototype de lecture à la demande

Cette étude peut commencer tôt, mais son adoption ne bloque pas la première UI.

- Concevoir une couche de lecture commune avec adaptateurs pour extractions historiques et sources brutes.
- Tester référence seule, cache et extraction persistante sur les mêmes analyses.
- Vérifier l'équivalence des pixels et résultats, la mémoire, les temps d'accès, le disque et l'exécution distante.

**Critère :** décision documentée sur les modes proposés et leurs valeurs par défaut, sans régression des projets existants.

### Étape 5 — adoption et transition Python

- Faire de la nouvelle fenêtre l'entrée par défaut seulement après validation des usages essentiels.
- Porter progressivement les fonctions métier encore nécessaires en MATLAB selon l'inventaire.
- Transposer ensuite l'interface et le rendu en Python en conservant les parcours, contrats et pipelines validés.

**Critère :** vérifier explicitement les capacités autonomes en Python ; ne pas assimiler interface Python et absence de dépendance MATLAB.

## 9. Isolation et reprise du travail

- Worktree : `C:\Users\Gilles\Documents\MATLAB\Detective-UI`.
- Branche : `codex/detective-ui`.
- Base : `e0e7c99150c51e9475c7e51a54e2bc8c1b240fbf`, HEAD de `unstable` lors de la création.
- Le checkout initial contient des changements non commités, notamment dans l'affichage et le cache de `score`, le chargement des ROIs et des classifiers et leurs tests. Ils n'ont pas été copiés dans ce worktree. Comparer et intégrer les correctifs pertinents explicitement avant de remplacer les comportements concernés.
- Utiliser une session MATLAB dédiée et vérifier le path actif pour éviter de charger des fonctions de l'autre checkout.
- Aucun changement de traitement, migration de données, push ou déploiement n'est réalisé par cette note. Les règles de `AGENTS.md` restent applicables aux travaux ultérieurs.

## 10. Prochain livrable

Un inventaire des fonctionnalités et une première fenêtre MATLAB démontrant la navigation unifiée sur des données réelles. La première validation doit porter sur le guidage, la continuité de navigation et l'accès progressif aux outils, avant une reprise exhaustive de `score`.

## 11. Avancement au 4 novembre 2026

- Branche publiée sur le remote GitLab existant : `gitlab/codex/detective-ui`.
- Première fenêtre MATLAB expérimentale disponible via `detecdiv_ui` ; navigation champ/zone, fil d'Ariane, contrôles temporels, canaux logiques et RGB, contours cliquables et panneaux repliables.
- Priorité visuelle confirmée par Gilles : **image centrale et outils contextuels**. Voir `DETECTIVE_UI_GUIDELINES.md`.
- Premier inventaire de réutilisation et procédure de lancement dans `DETECTIVE_UI_IMPLEMENTATION.md`.
- Validation automatisée sur données synthétiques TIFF et zones en mémoire ; l'étape 1 reste à valider sur une acquisition réelle. Aucun pipeline guidé, changement de stockage ou migration de données n'est encore réalisé.
- Révision UX demandée par Gilles : menus conventionnels, interface en anglais, suppression des textes explicatifs permanents et restauration du vocabulaire DetecDiv. Un arbre unique Project → FOV → ROI permet d'ouvrir, parcourir et fermer plusieurs projets, avec conservation du temps et du canal par projet. Les nouvelles guidelines remplacent les choix de vocabulaire du premier prototype.
- Coquille de docking intégrée et validée : `detecdivui.DockingHost` isole AppContainer, les trois widgets natifs et l'adaptation des menus classiques. Tests de détachement/réancrage et de restauration du layout réussis ; Gilles confirme le bon fonctionnement interactif. Le contrat et les vérifications du layout sont décrits dans `DETECTIVE_UI_DOCKING.md`.
- Coquille commitée et poussée sur GitLab : `cb17350f2c9d4da3e5d2c612f21eb2b74c45e657`.
- Display dispose de couches visibles indépendamment, de couleurs, d'opacité, de contraste min/max, d'un curseur de contraste et d'Auto. Le rendu réutilise score ; les réglages sont conservés par projet/FOV/ROI pendant la session sans modifier les sources. Voir `DETECTIVE_UI_DISPLAY.md`.
- Demande de Gilles pour la suite : distinguer les Classifiers dans le navigateur, éventuellement comme collection typée dans le même widget que Projects, et prévoir un widget Pipeline dédié. La sélection de modèles compatibles doit précéder l'action Segment Cells. Aucun classifier ne devient un projet `@shallow`, et les templates `@pipeline` restent indépendants.
- Projects : fiche contextuelle, chemin copiable et découverte des objets du workspace livrés et poussés (`b47f69a1`).
- Widget Pipeline intégré : templates du workspace/JSON, étapes, paramètres et portée, validation/dry-run sans exécution, historique des runs du projet et inspecteur existant. Le docking et les anciens layouts sont préservés. L'édition détaillée et la configuration/exécution des runs restent accessibles via `pipeline2` ; leur intégration dans le widget est la tranche suivante. Voir `DETECTIVE_UI_PIPELINE.md`.
- Ouverture du viewer et import des projets sans lecture d'images ni recherche des bruts. Les pixels sont demandés par sélection FOV/ROI ou Load Image. Les chemins manquants proposent Relink Raw Data... avec les helpers existants ; un relink réussi reprend la lecture demandée. Les lectures explicites restent synchrones. `lazyImageTest` vérifie l'absence d'accès au démarrage, les sources manquantes, le relink réel et le chargement H5 à la demande, en isolant les préférences du test.
- Pipeline : édition native des paramètres de run simples, brouillons indépendants par projet/template, Reset, prise en compte par validation/dry-run et transmission à `pipeline2` sans modifier le template ni choisir implicitement le remplacement des résultats. Consultation native des runs (résumé, étapes, problèmes) via `pipelineRunReview`, uniquement sur demande. Les prochaines intégrations restent la sélection compatible des classifieurs, les paramètres complexes et le lancement/suivi complet dans la fenêtre principale.
- New Run ouvre une configuration compacte défilante : source, FOV/ROI/frames, reprise, résultats existants, périphérique et cible d'exécution. Save Run crée un `pipelineRun` et son JSON via les helpers existants, sans lancer de traitement. Les étapes disposent d'un graphe vertical avec liens réels et sélection des modules, ainsi que d'une vue List ; les runs affichent leur propre snapshot et leurs états issus de la revue. `newRunTest` vérifie les callbacks natifs, la sauvegarde/relecture, les sélections et le passage vers l'éditeur.
- Progression : audit reproductible des dialogues et des passages entre frontends, dont les 61 sites des cinq apps principales. Indicateurs transitoires dans les widgets et repli vers une vue visible, connexion au callback de chargement de projet, nettoyage imbriqué en cas d'erreur/retour anticipé, 49 gardes supplémentaires pour les dialogues locaux historiques. Les owners asynchrones et les contrats d'annulation existants sont conservés. Les prochains ports doivent inclure cette revue ; voir `DETECTIVE_UI_PROGRESS.md`.
