# Cell ACDC dans la migration Python de DetecDiv

Date : 16 octobre 2026. Cette étude complète la [stratégie Python et stockage](python_project_storage_architecture.md) et l’[intégration des projets et pipelines dans napari](napari_project_pipeline_integration.md).

## Conclusion pour DetecDiv

**Cell-ACDC reste une référence métier et un outil optionnel de correction et d’analyse des cellules de levure.** Il apporte des exemples pour les identités cellulaires, relations mère–bourgeon, annotations de cycle et corrections temporelles. L’orientation retenue est de préserver la richesse fonctionnelle de DetecDiv et de construire une interface Python centrée sur l’image, avec napari et une petite base SQLite par projet. L’interface Cell-ACDC ne constitue pas la cible de cette migration.

Le cœur DetecDiv conserverait le projet, les templates, les runs et les ressources. Une coopération avec Cell-ACDC pourrait passer par un échange explicite de données et de corrections, puis éventuellement un adaptateur de traitement par lots, si un besoin concret le justifie. Cette coopération n’est pas un préalable au prototype napari. La reprise éventuelle de fonctions isolées serait évaluée selon leur valeur et leur coût d’extraction.

Le code étudié est celui de `SchmollerLab/Cell_ACDC`, au commit `deb9229e2f141f359c9093058f39a602b3940617`. L’analyse porte sur la documentation et les parcours de chargement, workflow, sauvegarde et visualisation du code ; elle n’établit pas encore les performances ou l’ergonomie sur les données DetecDiv.

## Logiciel et usages scientifiques

Cell-ACDC a été présenté par Padovani, Mairhörmann, Falter-Braun, Lengefeld et Schmoller dans BMC Biology en 2022 pour la segmentation, le suivi et l’analyse du cycle cellulaire. Son développement a initialement visé la levure bourgeonnante, avec une portée plus générale pour les images segmentables. Référence : [article scientifique](https://pmc.ncbi.nlm.nih.gov/articles/PMC9356409/).

Le projet maintient une liste de publications utilisant le logiciel, notamment sur la levure et d’autres organismes. C’est un indicateur d’usage scientifique documenté ; la taille exacte de sa communauté utilisatrice ne se déduit pas de cette liste. Voir les [publications recensées](https://cell-acdc.readthedocs.io/en/latest/publications.html).

## Fonctions particulièrement pertinentes pour la levure

L’interface documente notamment la séparation mère–bourgeon, la modification ou fusion d’identités, l’assignation d’un bourgeon à sa mère, la correction du suivi et l’annotation du cycle. Elle propose aussi des outils pour revenir sur une cellule ou une paire sélectionnée et propager des modifications de lignée. Ces interactions répondent à des besoins biologiques précis, au-delà de la peinture d’un masque. Voir les [outils de correction et d’annotation](https://cell-acdc.readthedocs.io/en/latest/tooltips.html).

Pour DetecDiv, les fonctions à comparer en priorité seraient : retrouver une cellule et ses événements, corriger une association mère–fille, réparer une séparation ou une identité, puis rendre cohérentes les mesures et annotations concernées. La portée temporelle d’une correction doit être visible et vérifiable.

Le code contient des colonnes et traitements de cycle comme `cell_cycle_stage`, `generation_num`, `relative_ID`, `relationship`, `emerg_frame_i` et `division_frame_i`. Ces notions constituent des points de correspondance à établir, pas des équivalences automatiques avec les générations et événements de DetecDiv. Les conventions d’une division, d’une émergence et d’une histoire inconnue doivent être comparées sur des séquences annotées. Voir [cca_functions.py](https://github.com/SchmollerLab/Cell_ACDC/blob/deb9229e2f141f359c9093058f39a602b3940617/cellacdc/cca_functions.py).

## Interface et lien existant avec napari

Cell-ACDC possède sa propre interface Qt et utilise PyQtGraph ; ses dépendances graphiques sont séparées des dépendances de base dans son packaging. Il ne faut donc pas supposer que son application est déjà un plugin napari directement intégrable. Voir [pyproject.toml](https://github.com/SchmollerLab/Cell_ACDC/blob/deb9229e2f141f359c9093058f39a602b3940617/pyproject.toml).

Il dispose néanmoins d’une passerelle concrète vers napari-arboretum. Le code charge les images, masques et annotations d’une position, construit un arbre de lignée, produit des tracks et leurs relations, puis ouvre napari avec le panneau Arboretum. C’est un exemple de conversion de données métier vers les couches napari, à examiner pour notre adaptateur. Ce parcours n’établit pas à lui seul une synchronisation bidirectionnelle complète du projet. Voir [napari_utils/arboretum.py](https://github.com/SchmollerLab/Cell_ACDC/blob/deb9229e2f141f359c9093058f39a602b3940617/cellacdc/napari_utils/arboretum.py).

La reprise directe de widgets de correction demanderait d’isoler leurs dépendances aux objets de position, tables, raccourcis et états de la GUI. Elle ne doit pas être présumée moins coûteuse qu’un lancement de l’application spécialisée avec un échange de données.

## Gestion des données et stockage

La structure documentée est organisée en expériences et positions, avec un sous-dossier `Images` par position. Elle décrit des images par canal, des métadonnées, des masques et des tables. Voir la [structure des dossiers](https://cell-acdc.readthedocs.io/en/latest/data-structure.html).

Les sorties documentées comprennent notamment les labels comprimés dans `*_segm.npz`, les annotations et mesures dans `*_acdc_output.csv`, et les informations d’acquisition ou de préparation dans des fichiers associés. Certains lecteurs acceptent aussi des ressources HDF5 ; cela ne garantit pas qu’ils interprètent les datasets, attributs et sous-canaux des ROI DetecDiv. Voir les [sorties Cell-ACDC](https://cell-acdc.readthedocs.io/en/latest/datastruc.html) et le lecteur utilisé dans la passerelle napari ci-dessus.

**Cell-ACDC ne constitue donc pas un précédent imposant une base SQL contenant toutes les images.** Son parcours documenté est fondé sur des fichiers par position. Il montre qu’une interface d’analyse cellulaire riche peut s’appuyer sur cette organisation ; il ne tranche pas la question des transactions et recherches transversales du futur DetecDiv.

Une position Cell-ACDC pourrait correspondre à une FOV ou à un crop de ROI selon l’échange choisi. Pour un premier essai sur des pièges, une ROI DetecDiv pourrait être exportée comme position de travail. Le manifeste d’échange devrait conserver son projet, sa FOV parent, sa géométrie et ses frames absolues. Une position ou une ROI ne serait jamais assimilée à une cellule unique.

## Workflows et traitement par lots

Le code offre un parcours de sauvegarde de workflows en INI et une entrée CLI avec `acdc -p <workflow.ini>`. Les paramètres couvrent notamment les chemins, le modèle, le tracker, le prétraitement, le post-traitement et les mesures. Les kernels peuvent traiter une liste de positions. Références : [sauvegarde depuis la GUI](https://github.com/SchmollerLab/Cell_ACDC/blob/deb9229e2f141f359c9093058f39a602b3940617/cellacdc/segm.py), [exécution CLI](https://github.com/SchmollerLab/Cell_ACDC/blob/deb9229e2f141f359c9093058f39a602b3940617/cellacdc/_run.py), [kernels](https://github.com/SchmollerLab/Cell_ACDC/blob/deb9229e2f141f359c9093058f39a602b3940617/cellacdc/cli.py).

Ce chemin est une piste sérieuse pour un module externe DetecDiv. Il serait inexact de réduire Cell-ACDC à une application uniquement interactive. Les workflows examinés sont toutefois spécialisés autour de segmentation, tracking et mesures ; ils ne démontrent pas une équivalence avec le graphe général, les contrats de ressources et les politiques de runs DetecDiv.

L’adaptateur éventuel préparerait les entrées et l’INI dans un espace de travail de run, lancerait l’environnement Cell-ACDC identifié, vérifierait les sorties, puis publierait les ressources sous des noms explicites. Annulation, progression, reprise et distinction entre erreur de processus et résultat scientifique complet restent des points à adapter et tester.

Les modèles et trackers ont des interfaces dédiées, par exemple `Model.segment` et `tracker.track`. Leur bibliothèque mérite une inspection ciblée. Lorsqu’un modèle est déjà disponible dans sa bibliothèque d’origine ou dans DetecDiv, il faut comparer la valeur de l’adaptateur Cell-ACDC avant d’ajouter une dépendance supplémentaire. Voir les [modèles et leurs interfaces](https://github.com/SchmollerLab/Cell_ACDC/blob/deb9229e2f141f359c9093058f39a602b3940617/cellacdc/docs/source/models.rst).

## Place des différentes briques

| Brique | Contribution à privilégier | Travail restant pour notre cible |
| --- | --- | --- |
| DetecDiv actuel | Projet historique, templates, contrats, runs et traitements validés | Adaptateurs de persistance et portage progressif en Python |
| pyDetecDiv de Fred | Composants et traitements Python proches des usages DetecDiv | Adaptation aux données actuelles et séparation des couplages à sa GUI |
| napari | Viewer multidimensionnel et hôte des panneaux projet/pipelines | Gestion métier du projet, ressources, annotations et runs |
| Cell-ACDC | Correction et annotation biologiques, cycle levure, workflows spécialisés | Correspondance des identités, formats, événements et provenance |

La priorité est l’interface DetecDiv unifiée dans napari. Les fonctions et interactions de Cell-ACDC peuvent informer sa conception ; un compagnon externe reste possible pour une tâche spécialisée. Le projet et le pipeline resteraient contrôlés par DetecDiv.

## Essai optionnel d’interopérabilité

1. **Préparer un échantillon.** Choisir une séquence DetecDiv avec plusieurs cellules, une naissance ou division et une correction connue. Exporter une copie compatible Cell-ACDC, avec images, labels et manifeste des correspondances. Mesurer le coût de conversion et le volume temporaire.
2. **Vérifier la lecture sans modification.** Comparer les pixels, labels, calibrations et frames. Tester la correspondance des identités et la réimportation sans édition avant de tirer des conclusions sur les corrections.
3. **Effectuer une correction représentative.** Réparer une identité ou séparation et une association mère–bourgeon ; documenter les frames touchées et les éventuelles propagations. Comparer le nombre d’actions et la lisibilité avec le parcours DetecDiv actuel.
4. **Réimporter une nouvelle révision.** Conserver le résultat d’origine, réimporter les masques et annotations corrigés, enregistrer version du logiciel et révision source, et signaler les mesures devenues obsolètes. Recalculer celles-ci dans le pipeline lorsque nécessaire.
5. **Évaluer le batch séparément.** Sur la copie de travail, enregistrer puis exécuter un workflow INI ; vérifier les sorties et le comportement après interruption. Cette expérience déciderait de l’intérêt d’un module externe.

L’identité d’un objet échangé doit inclure son espace de travail et sa position/ROI, en plus de l’identifiant Cell-ACDC. Les frames, générations et relations cellulaires nécessitent des règles explicites. Les fichiers de travail Cell-ACDC et la base DetecDiv ne devraient pas être simultanément éditables comme deux versions autoritatives d’une même annotation.

L’environnement Cell-ACDC serait préparé séparément pour cet essai, avec ses versions et modèles identifiés. Le processus GUI napari n’aurait pas à charger toutes ses dépendances. Aucune opération d’échange ne copierait un arbre complet de modèle, projet ou entraînement en guise de runtime.

Si cet essai est entrepris, son bilan déterminerait l’intérêt de conserver l’application comme compagnon ou de reprendre quelques fonctions isolées. Le développement du parcours d’annotation dans napari reste une composante du prototype DetecDiv et peut progresser indépendamment de cet échange.
