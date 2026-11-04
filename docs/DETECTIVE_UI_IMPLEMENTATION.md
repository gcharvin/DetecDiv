# Detective-UI — prototype MATLAB de navigation

## Démarrage

Utiliser une session MATLAB dédiée à ce worktree :

```matlab
cd('C:\Users\Gilles\Documents\MATLAB\Detective-UI');
detecdiv_setup_path(pwd, 'DetecDivRoot', pwd);
viewer = detecdiv_ui();
% Ou, avec un projet déjà chargé dans cette session :
viewer = detecdiv_ui(shallowObj);
```

Le paramètre `DetecDivRoot` est nécessaire : le helper peut sinon sélectionner automatiquement le checkout voisin `DetecDiv` comme moteur et omettre les nouvelles classes GUI du worktree. L'entrée habituelle `detecdiv` reste inchangée. Le prototype est une fenêtre MATLAB programmée ; son organisation reste exploratoire avant de stabiliser une source de layout App Designer. Il ne modifie pas les MLAPP existants.

## Capacités du premier socle

- Ouverture d'un projet par `shallowLoad`, navigation par positions et zones nommées, fil d'Ariane. Les placeholders historiques vides sont masqués sans modifier les indices des objets.
- Une seule vue pour les images brutes et les zones extraites ; retour à la position et conservation du temps lorsque possible.
- Choix d'un canal brut ou d'un canal logique nommé de zone, avec regroupement des trois sous-canaux RGB, y compris lorsqu'ils ne sont pas contigus. Les métadonnées absentes ou incompatibles donnent accès aux plans individuels.
- Contours des zones de référence sur le champ, avec ouverture au clic ; leur visibilité est réglable. Aucun déplacement temporel de ces contours n'est inféré.
- Navigation temporelle par numéro, curseur et boutons ; conservation du zoom entre images d'une même vue et du canal nommé entre contextes si possible.
- Panneaux Données et Outils repliables et indications contextuelles pour continuer.
- Messages d'indisponibilité à la place de l'image précédente, pour éviter toute confusion après un échec de lecture.
- État de navigation séparé de la fenêtre (`detecdivui.Session`) et lecteur historique derrière une première interface `readPlane`.

Le chargement d'une zone utilise son image en mémoire ou `roi.load('Data',false)` : il peut charger toute son extraction en mémoire et mettre à jour ses métadonnées d'affichage. Aucun enregistrement, extraction ni traitement n'est lancé par ce prototype. Le lecteur brut historique peut effectuer ses réparations habituelles de chemins en mémoire.

## Limites explicites

L'indication du parcours reste discrète et ne calcule pas encore les états des étapes. Les outils d'analyse, composition de plusieurs canaux, contraste mémorisé, annotations, sauvegarde et pipelines guidés ne sont pas encore intégrés. Un canal logique composé de trois plans est affiché comme une image RGB ; les autres groupes de plusieurs plans sont exposés individuellement. Les zones non extraites ne sont pas reconstruites depuis le brut. Les contours reprennent les rectangles de référence comme dans workflow ; les trajectoires mobiles ne sont pas reconstruites. La lecture reste synchrone, sans cache ni préchargement.

Les données de validation sont synthétiques. La validation sur un projet réel et les mesures de performance restent à effectuer.

Le contraste monochrome est ajusté au minimum et au maximum finis de l'image affichée ; il ne modifie pas les pixels. Les réglages de contraste persistants et les palettes de masques restent à intégrer.

## Premier inventaire des points de réutilisation

Cette table est un repérage initial du code, pas une certification de couverture fonctionnelle.

| Intention | Source existante | Adaptation à préparer |
| --- | --- | --- |
| Ouvrir une expérience | `structure/io/shallowLoad.m` | Ajouter le contexte de progression et les chemins/accès Hub pertinents |
| Explorer les images brutes | `structure/classes/@fov/readImage.m` | Lecture groupée, cache et distinction temps/canaux |
| Examiner une zone extraite | `structure/classes/@roi/load.m` | Lecture sélective et gestion des canaux logiques |
| Définir les zones | Packages `engine/dataloading/+roiManual`, `+roiPattern`, `+roiGrid`, `+roiTracked` | Paramètres et prévisualisation contextuelle sans importer les callbacks de workflow |
| Prévisualiser les zones et la dérive | `structure/GUI/workflow_extracted.m` : `renderCurrentFrame`, éditeurs et navigation | Identifier la référence runtime active et isoler transformations et interactions |
| Afficher les couches et résultats | `structure/GUI/score/score_display.m` et helpers de rendu | Détacher les dépendances aux tables, propriétés et figures de score |
| Corriger masques et tracking | Helpers `score_setEditMode`, `score_splitMaskObject`, `score_swapSelectedTrackIds` | Inventorier prérequis, sélection, sauvegarde et annulation avant intégration |
| Annoter et réviser | `structure/GUI/score/private/score_runtime_code.m` et tests de sessions d'annotation | Extraire actions et états du contrôleur graphique |
| Examiner lignées et signaux | Helpers de score, méthodes de `@dataseries` | Synchroniser temps et sélection avec la session unifiée |
| Lancer une analyse reproductible | `structure/io/runPipeline.m`, `@pipeline`, `pipelineRun` | Une action utilisateur configure un pipeline inspectable |
| Synchroniser les frontends | `helpers/detecdiv_event.m`, `detecdiv_frontend_plugins.m` | Définir le cycle de vie et les événements de la nouvelle fenêtre |
| Stabiliser le layout | `score_gui_layout.m`, `sync_score_layout.m` et équivalents | Préserver les sources design et code séparées lors du passage App Designer |

## Validation reproductible

```matlab
detecdivui.smokeTest();
```

Le test utilise deux TIFF temporaires et des zones en mémoire. Il vérifie les pixels bruts, le filtrage des placeholders en conservant leurs indices, l'ouverture par un contour, les canaux logiques et RGB non contigus, le maintien du canal et du zoom, la navigation temporelle, le retour au champ, le masquage des contours, le repli des panneaux, l'effacement des pixels après une lecture impossible et la récupération au changement de temps. Il ne valide pas encore les extractions H5 ni les données réelles. Un chemin PNG facultatif permet d'exporter la fenêtre pour vérification visuelle ; dans ce cas seulement, le test rend brièvement la fenêtre visible.

Validation du 4 novembre 2026 sous MATLAB R2026a : test réussi, Code Analyzer sans diagnostic sur les trois fichiers du package, et export de la fenêtre inspecté visuellement. La vérification couvre aussi les limites des axes et du contraste après récupération d'une erreur de lecture.

```matlab
detecdivui.smokeTest(fullfile(tempdir, 'detective-ui-preview.png'));
```

## Prochaine tranche

1. Faire essayer la navigation sur une acquisition représentative et recueillir les observations UX.
2. Compléter les couches composites et les réglages de contraste selon les retours.
3. Auditer les contrats d'un segmenter existant pour intégrer la première action guidée et son pipeline.
4. Reprendre le layout dans App Designer une fois les interactions essentielles validées.

Les orientations visuelles et les règles d'interaction sont consignées dans `DETECTIVE_UI_GUIDELINES.md`. La priorité confirmée est « Image centrale et outils contextuels ».

Les modifications non commitées du checkout initial ne sont toujours pas intégrées ici ; les comparer avant de reprendre les chemins de chargement ou d'affichage concernés.
