# Detective-UI — premier socle MATLAB

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

- Ouverture d'un projet par `shallowLoad`, navigation par positions et zones, fil d'Ariane.
- Une seule vue pour les images brutes et les zones extraites ; retour à la position et conservation du temps lorsque possible.
- Choix d'un canal brut ou d'un plan stocké de zone et d'une image temporelle.
- Messages d'indisponibilité à la place de l'image précédente, pour éviter toute confusion après un échec de lecture.
- État de navigation séparé de la fenêtre (`detecdivui.Session`) et lecteur historique derrière une première interface `readPlane`.

Le chargement d'une zone utilise son image en mémoire ou `roi.load('Data',false)` : il peut charger toute son extraction en mémoire et mettre à jour ses métadonnées d'affichage. Aucun enregistrement, extraction ni traitement n'est lancé par ce prototype. Le lecteur brut historique peut effectuer ses réparations habituelles de chemins en mémoire.

## Limites explicites

Le bandeau de parcours présente la direction UX ; il ne calcule pas encore les états des étapes. Les outils d'analyse, couches composites RGB, overlays de zones sur le champ, contraste mémorisé, annotations, sauvegarde et pipelines guidés ne sont pas encore intégrés. Les zones non extraites ne sont pas reconstruites depuis le brut. Les listes peuvent encore exposer les objets vides de la hiérarchie historique. La lecture reste synchrone, sans cache ni préchargement. Les plans stockés des zones ne représentent pas encore une gestion complète des canaux logiques et sous-canaux.

Les données de validation sont synthétiques. La validation sur un projet réel et les mesures de performance restent à effectuer.

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

Le test utilise un TIFF temporaire et une zone en mémoire. Il vérifie les pixels de la lecture brute, la navigation vers la zone par le callback réel de la liste, son affichage dans la fenêtre masquée, puis le retour au champ par le bouton. Il ne valide pas encore les extractions H5 ni les données réelles.

## Prochaine tranche

1. Faire essayer la navigation sur une acquisition représentative et recueillir les observations UX.
2. Afficher des noms métier et filtrer les placeholders historiques.
3. Gérer les canaux logiques, les overlays des zones et la sélection directe sur l'image.
4. Auditer les contrats d'un segmenter existant pour intégrer la première action guidée et son pipeline.

Les modifications non commitées du checkout initial ne sont toujours pas intégrées ici ; les comparer avant de reprendre les chemins de chargement ou d'affichage concernés.
