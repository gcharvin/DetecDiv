# DetecDiv Python et stockage des projets en base de données

Date : 16 octobre 2026. Statut : proposition d’architecture à évaluer sur des projets réels. Cette note complète [le format projet v2](project_format_v2.md) ; elle ne modifie pas le format actuellement utilisé.

## Recommandation

Une base par projet présente un intérêt réel pour DetecDiv : elle permettrait de centraliser les métadonnées, annotations, mesures et références des résultats, de les interroger sans ouvrir toutes les ROI et d’enregistrer les changements par transactions. Elle faciliterait une interface Python reliant images, courbes et exécutions de pipelines.

L’orientation retenue pour le prototype est une architecture hybride : **une petite base SQLite par projet pour les informations interrogeables et des ressources de tableaux externes pour les images et masques volumineux**. SQLite convient à un projet local avec des écritures coordonnées. L’accès partagé entre machines demande un service propriétaire de la base ou un moteur client-serveur.

L’objectif produit est de préserver la richesse fonctionnelle de DetecDiv tout en réunissant ses parcours dans une interface Python centrée sur l’image. La fragmentation entre plusieurs GUI et la perte de contexte visuel entre les tâches constituent les difficultés à résoudre. Le projet, les pipelines, les annotations et les mesures doivent partager une même sélection et un même espace de travail.

Il faut distinguer trois décisions : adopter une base, regrouper les fichiers d’images et supprimer les sauvegardes manuelles ROI par ROI. Ces décisions peuvent avancer séparément. L’utilisateur pourrait ne plus appeler `roi.save`, alors que le moteur conserverait des points de reprise par ROI ou par bloc de frames.

La stratégie de développement proposée est de **reprendre les composants utiles de pyDetecDiv et de construire progressivement le cœur Python autour des contrats du DetecDiv actuel**. Le premier prototype doit réunir lecture des données existantes, visualisation synchronisée, annotation persistante et lancement d’un pipeline MATLAB depuis cette interface.

L’[étude d’intégration dans napari](napari_project_pipeline_integration.md) précise désormais l’interface candidate prioritaire du prototype : des panneaux DetecDiv de gestion de projet et de pipelines dans napari, reliés à un cœur indépendant du viewer. Les composants de Fred restent des sources de réutilisation selon leur compatibilité avec cet assemblage.

L’[étude de Cell-ACDC](cell_acdc_comparison.md) reste une référence pour la correction des identités, relations mère–bourgeon et annotations de cycle, ainsi que pour ses workflows CLI et son stockage par positions. Son utilisation comme outil externe reste optionnelle ; elle ne conditionne pas le prototype de l’interface DetecDiv dans napari.

## Point de départ et apport de pyDetecDiv

La note v2 propose déjà un manifeste JSON léger et des ressources externes. Le code actuel de `shallowSave` écrit ce JSON par défaut et réserve la sauvegarde MATLAB historique aux options correspondantes. `shallowLoad` sait relire le JSON. La comparaison doit donc porter sur **JSON léger plus fichiers de résultats**, et pas seulement sur l’ancien gros objet MATLAB sérialisé.

Les images extraites restent dans des `.h5` de ROI et les données quantitatives sont encore sauvegardées séparément en `.mat` par `roi.save`. Le [catalogue SQLite actuel](project_catalog.md) sert d’index de découverte ; il ne constitue pas la persistance scientifique de chaque projet.

Le dépôt de Fred fournit un précédent utile : `open_project` ouvre un fichier SQLite par projet ; le plugin de classification stocke des résultats par run, ROI et frame dans une table. Les images HDF5 sont lues dans des ressources externes. **Son architecture n’implique donc pas de placer toutes les images dans SQLite.** Références : [persistance des projets](https://github.com/fplewniak/pyDetecDiv/blob/75b10bbb0db0bdde56f8231512db9071d5b3ffee/src/pydetecdiv/persistence/project.py), [résultats de classification](https://github.com/fplewniak/pyDetecDiv/blob/75b10bbb0db0bdde56f8231512db9071d5b3ffee/src/pydetecdiv/plugins/roi_classification/__init__.py), [lecteur HDF5](https://github.com/fplewniak/pyDetecDiv/blob/75b10bbb0db0bdde56f8231512db9071d5b3ffee/src/pydetecdiv/domain/Hdf5ImageResource.py).

L’analyse de `main` au commit ci-dessus et de `develop` au commit `2bfb691f087ebc620404d5d50cdbef1824efcd66` montre des composants de visualisation, annotation et classification réutilisables. Elle ne montre pas un moteur équivalent à l’ensemble actuel `pipeline`, `pipelineRun`, validation et reprise de DetecDiv. Certains calculs, dont la détection de ROI, restent dans l’interface. La migration Python devrait reprendre ces composants tout en conservant les contrats du moteur actuel. Voir [FOVmanager](https://github.com/fplewniak/pyDetecDiv/blob/75b10bbb0db0bdde56f8231512db9071d5b3ffee/src/pydetecdiv/app/gui/FOVmanager.py) et [Run](https://github.com/fplewniak/pyDetecDiv/blob/75b10bbb0db0bdde56f8231512db9071d5b3ffee/src/pydetecdiv/domain/Run.py).

## Ce que la base changerait pour les données et l’interface

Une base permettrait de demander directement « quelles cellules ont une division dans cet intervalle ? », « quelles ROI ont échoué à cette étape ? » ou « quelles mesures correspondent à cette version de segmentation ? ». Les index limiteraient les lectures aux résultats utiles, sans charger tous les objets et fichiers de ROI. Le gain de latence reste à mesurer sur les charges réelles.

Une correction d’annotation pourrait être enregistrée immédiatement avec son auteur, sa révision et son contexte. L’application indiquerait si la modification est en attente, enregistrée ou en erreur. La transaction serait déclenchée à la validation d’une action, plutôt qu’à chaque mouvement de souris.

Le lien entre un objet affiché, une courbe et un résultat de pipeline reposerait sur des identifiants stables. Une ROI resterait une région spatiale ; des cellules et trajectoires distinctes pourraient lui être associées. Le modèle ne supposerait pas une cellule par ROI.

La base ne rendrait pas à elle seule les vidéos plus fluides. La navigation temporelle exige aussi une lecture partielle, un cache borné, éventuellement des aperçus et une synchronisation des vues. Les viewers de Fred constituent une base ; le choix éventuel de napari doit être évalué sur ces usages.

## Répartition recommandée du stockage

La base doit rester légère par son contenu : identifiants stables, géométries et liens, annotations, paramètres résolus, provenance, états de runs et mesures usuelles nécessaires aux requêtes. Les images, masques denses, grosses matrices et caches reconstruisibles restent externes. Cette séparation permet une persistance fréquente des petites modifications sans réécrire les volumes d’images.

| Information | Stockage proposé | Usage principal |
| --- | --- | --- |
| Identité projet, sources, FOV, ROI et coordonnées | Tables relationnelles | Navigation et sélection sans chargement des images |
| Cellules, trajectoires, liens de lignée, événements | Tables avec identifiants stables | Requêtes, liens et corrections |
| Annotations, classes, scores, mesures scalaires et séries temporelles usuelles | Tables indexées | Filtrage et comparaison entre exécutions |
| Grandes matrices numériques ou sorties très denses | Tableaux externes référencés ; tables seulement si les mesures le justifient | Lecture par blocs et maîtrise du volume |
| Images brutes | Sources d’acquisition existantes référencées | Éviter la duplication des acquisitions |
| Images extraites, masques denses, cartes de probabilités | HDF5 existant, puis regroupement éventuel ou Zarr | Accès spatial et temporel partiel |
| Paramètres résolus, version du module et provenance d’un run | Enregistrements structurés et snapshot de la définition exécutée | Reproductibilité |
| Modèles et gros artefacts | Ressources externes identifiées | Réutilisation et traçabilité |

Les métadonnées des tableaux doivent expliciter axes, forme, type numérique, unités, canaux, frames absolues et transformations spatiales. Le passage de l’indexation MATLAB à Python doit être défini et testé. Une ressource serait désignée par un identifiant, une localisation relinkable et un chemin interne de dataset, sans dépendre d’un chemin absolu propre à une machine.

Pour les ROI suivies, le lien au brut peut nécessiter une transformation par frame. Une ROI virtuelle peut éviter une extraction lorsque le lecteur et le traitement savent appliquer cette transformation à la demande. L’extraction physique reste disponible pour les traitements qui en ont besoin.

## Faut-il mettre aussi les images dans la base

SQLite accepte des objets binaires et peut être pertinent pour des vignettes ou de petits objets compacts. Ce choix doit être mesuré selon leur taille et leur fréquence d’accès. Le benchmark officiel sur les [BLOB internes et externes](https://sqlite.org/intern-v-extern-blob.html) ne constitue pas une règle universelle pour les hypervolumes de microscopie.

Pour de grands tableaux, placer chaque volume entier dans un BLOB imposerait de définir l’accès aux sous-régions, la compression et les mises à jour partielles. Une table de blocs binaires est possible, mais demanderait de maintenir une couche de stockage de tableaux supplémentaire.

HDF5 fournit déjà le découpage en blocs, la compression et la lecture de sous-ensembles. Conserver ces ressources paraît donc un meilleur point de départ pour DetecDiv. Voir les [datasets h5py](https://docs.h5py.org/en/stable/high/dataset.html).

Le nombre de fichiers peut être réduit indépendamment de SQL : regrouper les images par FOV, lot ou sortie de run serait une option à comparer au stockage par ROI. Un fichier HDF5 unique pour tout le projet pourrait cependant concentrer les écritures. Le mode SWMR autorise un écrivain et plusieurs lecteurs sous des conditions précises ; il ne fournit pas des écritures concurrentes arbitraires. Voir [SWMR](https://docs.h5py.org/en/stable/swmr.html).

Zarr est une autre option pour les tableaux découpés en blocs. Sur un système de fichiers, le nombre de fichiers et la forme des blocs restent importants. Le regroupement de blocs en shards peut réduire ce nombre ; l’unité de lecture et l’unité d’écriture doivent être choisies ensemble. La compatibilité des lecteurs et codecs doit être vérifiée. Voir le [guide de performance Zarr](https://zarr.readthedocs.io/en/stable/user-guide/performance/).

## Sauvegarde automatique et points de reprise

L’objectif fonctionnel devrait être : **l’application persiste les modifications validées et les traitements publient leurs résultats à des points de reprise définis**. Une action « enregistrer toutes les ROI » deviendrait inutile dans le nouveau parcours.

Cela ne justifie pas une transaction ouverte pendant tout un calcul ni une sauvegarde seulement à la fin du projet. Les calculs produiraient leurs résultats par unités bornées : ROI, lot de ROI ou bloc de frames selon le module. Une courte transaction enregistrerait ensuite les lignes et références correspondantes.

La granularité logique d’une reprise peut rester la ROI même si les écritures SQL sont groupées. Une transaction par frame ou par mesure n’est pas requise. Les politiques `replace`, `append`, `skip`, `error` et `upsert` doivent conserver leur sens au niveau des sorties nommées.

Une transaction SQL ne rend pas atomique une écriture simultanée dans HDF5. Le protocole proposé est de préparer une ressource externe dans un emplacement de staging, vérifier ses données et son intégrité, l’installer dans une destination propre à cette sortie, puis publier sa référence et son état dans une transaction courte. Le calcul reste hors de la transaction SQL.

En cas d’interruption, un résultat préparé mais non publié peut subsister ; il doit être détectable et récupérable. Une sortie ne doit être déclarée terminée qu’après vérification des données. Les reprises doivent identifier sans ambiguïté le run, le nœud, la ressource et la portion traitée. Les sauvegardes du projet doivent couvrir ensemble la base et les ressources qu’elle référence ; l’[API de sauvegarde SQLite](https://sqlite.org/backup.html) ne sauvegarde pas ces dernières.

## Une base par projet en local et sur le Hub

SQLite est adapté au format d’une application locale et permet plusieurs lecteurs, mais un seul écrivain à un instant donné. Les commits doivent rester courts et coordonnés. Des requêtes sur plusieurs projets peuvent passer par un catalogue de résumés, puis par les bases concernées ; une base par projet ne fournit pas automatiquement une recherche globale. Voir les [usages recommandés de SQLite](https://sqlite.org/whentouse.html).

Dans l’environnement DetecDiv, les workers Linux et Windows et les clients ne devraient pas ouvrir et modifier directement le même fichier SQLite sur SMB/NFS. Le mode WAL ne fonctionne pas comme une base partagée entre machines sur un système de fichiers réseau. Une option serait un service, sur la machine qui héberge la base localement, recevant les publications des workers. Un moteur client-serveur devient pertinent si les écritures concurrentes ou les besoins d’administration l’exigent. Voir [SQLite WAL](https://sqlite.org/wal.html).

Le Hub conserverait la responsabilité de la file et des jobs ; la persistance du projet décrirait les données scientifiques et leurs sorties validées. Le contrat d’échange doit distinguer ces responsabilités. Il faut éviter de maintenir deux états scientifiques indépendamment modifiables dans le Hub et dans chaque projet.

## Pipelines et interface Python

Les templates de pipelines resteraient indépendants des projets. Une base projet conserverait leurs références et le snapshot exact utilisé par chaque exécution. Elle pourrait alors relier une mesure ou un masque au module, à ses paramètres et aux entrées utilisés.

La description d’un module devrait alimenter l’éditeur et le moteur : paramètres, entrées, sorties, contraintes, ressources et politiques d’exécution. Les règles ne devraient pas être dupliquées dans les callbacks Qt. Cette approche prolonge le [contrat des modules](pipeline_module_contract.md) et le [contrat des runs](pipeline_run_contract.md).

L’interface visée relierait la sélection d’une ROI ou cellule, l’image courante, ses courbes et le nœud producteur du résultat. Une prévisualisation sur quelques frames serait distinguée d’un résultat publié. Le premier éditeur Python pourrait soumettre une exécution au moteur MATLAB actuel ; la persistance et le portage des traitements n’ont pas besoin de basculer simultanément.

L’API de stockage exposerait des opérations métier indépendantes du support : lire une région, obtenir des mesures, enregistrer une annotation et publier une sortie de nœud. `@shallow`, `@fov`, `@roi` et `@dataseries` resteraient utilisables comme représentation mémoire et interface de compatibilité. Leurs méthodes pourraient déléguer au stockage sélectionné pour le projet.

## Migration et critères de décision

1. **Établir la référence actuelle.** Mesurer le JSON léger, les `.h5` et les `.mat` de résultats : ouverture, requêtes, sauvegarde, nombre d’opérations de fichiers et volumes transférés.
2. **Indexer sans conversion destructive.** Sur une copie ou un échantillon représentatif, créer une base dérivée des métadonnées et mesures existantes ; référencer les images en place. À ce stade, les données existantes restent la référence et la base est reconstruisible.
3. **Valider une interface utile.** Afficher une ROI avec ses masques et courbes, rechercher un événement et retrouver le run producteur ; mesurer la latence et la mémoire.
4. **Tester la publication et la reprise.** Produire une nouvelle sortie Python, interrompre puis reprendre un traitement, et vérifier l’absence de résultats doublés ou déclarés complets à tort.
5. **Décider la bascule de persistance.** Définir explicitement le format autoritatif pour chaque projet migré, les migrations de schéma et le retour arrière. Les exports JSON/MAT deviennent alors des vues ou snapshots, sans deux sources simultanément éditables.
6. **Regrouper les images seulement si les mesures le justifient.** Comparer HDF5 par ROI, HDF5 regroupé et une variante Zarr compatible avec les lecteurs retenus.

Les essais doivent couvrir un petit projet, un projet avec beaucoup de ROI et un projet volumineux utilisé avec des workers. Comparer les temps à froid et à chaud, les latences de navigation, les écritures d’un lot de mesures, la taille totale, la charge réseau et la restauration après interruption. Inclure la recherche transversale, les réexécutions partielles et deux producteurs concurrents. Un stockage intégral en BLOB reste un candidat de comparaison s’il répond à une contrainte concrète de livraison en fichier unique ; aucun gain de performance n’est présumé.

La validation scientifique doit préserver identifiants, canaux, frames, unités, valeurs numériques, masques, lignées et provenance. Le passage à SQL doit apporter un bénéfice mesuré de navigation et de gestion des résultats, sans dégrader la lecture d’images ni la reprise des traitements.

## Stratégie de reprise de pyDetecDiv

Le dépôt dédié [napari_detecdiv](../../napari_detecdiv/README.md), créé le 17 octobre 2026 dans `C:\Users\Gilles\Documents\MATLAB\napari_detecdiv`, accueille désormais le prototype Python, ses adaptateurs et ses services. Le dépôt DetecDiv reste la référence pour le moteur MATLAB et ses contrats de données et de pipelines. Le dépôt de Fred reste une source amont identifiable ; chaque composant repris doit conserver sa provenance, son commit d’origine et ses mentions de licence.

La reprise commencerait par une version figée déjà examinée, puis par une vérification de son démarrage et de ses dépendances sous Windows. Les changements de `develop` seraient examinés selon les besoins du prototype. L’environnement retenu et les versions installées seraient enregistrés avec la procédure de lancement.

| Élément | Stratégie proposée |
| --- | --- |
| Fenêtres, onglets et arbres FOV/ROI | Reprendre les widgets Qt utiles dans les panneaux napari et adapter leur source de données |
| Lecteur vidéo, couches d’images et courbes | Évaluer napari pour les images et réutiliser les courbes et adaptateurs compatibles ; garder les viewers de Fred comme référence de comparaison |
| Annotation | Reprendre les interactions utiles et confier la persistance à un service de projet explicite |
| Classification PyTorch | Examiner les modules au moment de leur intégration ; conserver leur calcul hors de la GUI |
| Classes métier et persistance de Fred | Réutiliser les abstractions compatibles ; établir la correspondance avec les identifiants et concepts actuels avant de reprendre leur schéma |
| Pipelines | Conserver la définition JSON et les contrats actuels ; commencer par une passerelle d’exécution MATLAB |
| Futur moteur Python | Construire progressivement validation, contexte et publication des sorties à partir des mêmes contrats |

Les widgets ne devraient pas dépendre d’un projet global pour lire ou enregistrer les données. Les appels à l’état global de l’application et aux sessions SQL seraient remplacés, sur le chemin repris, par des services injectés. Un calcul aujourd’hui présent dans un callback serait extrait avant d’être proposé comme module de pipeline.

Cette séparation permettrait de tester une lecture d’image ou une annotation sans démarrer toute l’application, et de réutiliser les services dans une autre interface. Le premier prototype évaluerait napari avec des panneaux de projet et de pipelines. La reprise des viewers de Fred resterait une alternative si les essais montrent des limites concrètes de cet assemblage.

## Premier prototype

Le [périmètre concret du premier jalon napari](napari_first_prototype.md) précise l’ouverture des projets, l’exploration des bruts et des ROI HDF5, le pipeline consultable et les composants repris de Fred. Ce jalon valide les lecteurs et la navigation avant d’étendre le parcours aux annotations et à l’exécution décrites ici.

### Parcours et périmètre

Le parcours de démonstration serait le suivant : ouvrir un projet existant, sélectionner une ROI, parcourir ses images avec un masque superposé et une courbe synchronisée, enregistrer une annotation, charger un pipeline JSON, modifier un paramètre, valider puis lancer une courte exécution MATLAB, et retrouver son résultat dans l’interface.

La première exécution serait locale, sur une copie de travail. Elle utiliserait un pipeline déterministe court déjà disponible dans DetecDiv, choisi pour produire une sortie nommée inspectable sur les données retenues. L’entraînement de modèles, le portage complet des traitements et la soumission au Hub viendraient ensuite. Le prototype ne convertirait pas les volumes d’images en base ni dans un nouveau format.

L’échantillon de référence serait issu d’un projet réel avec plusieurs canaux, un masque et une série quantitative. Une sélection indicative serait de 1 à 3 FOV, 10 à 20 ROI et une centaine de frames, avec des frames absolues non consécutives si le projet en contient. Les identifiants, la sélection et les valeurs attendues seraient enregistrés pour rendre les essais reproductibles.

Les sources d’acquisition pourraient rester référencées en lecture. Toutes les métadonnées et ressources que le pipeline peut modifier seraient réadressées vers la copie de travail. Ce contrôle inclurait les chemins des ROI et des sorties de nœuds ; changer seulement le dossier du run ne suffit pas à isoler une écriture historique. Les modèles seraient référencés conformément à leurs contrats existants, sans copie de leurs arbres de développement ou d’entraînement.

### Étapes et livrables

| Étape | Travail à réaliser | Livrable et condition de passage |
| --- | --- | --- |
| P1 Reprise minimale | Figer la provenance des composants de Fred, préparer un environnement local et ouvrir napari avec un panneau de projet | Commande de lancement reproductible et inventaire des composants repris, adaptés ou écartés |
| P2 Accès aux données | Lire le manifeste JSON et ses éventuels fichiers de métadonnées associés, indexer FOV/ROI et ressources, adapter la lecture des `.h5`, importer une série de mesures | Base locale reconstruisible, lecteur partiel et comparaison numérique avec MATLAB sur l’échantillon |
| P3 Navigation synchronisée | Relier arbre, images, masques, canaux, frame et courbe dans le même espace de travail ; charger les données à la demande | Sélection d’une ROI et navigation temporelle cohérentes, contexte visuel conservé entre tâches, mémoire bornée et latences mesurées |
| P4 Annotation persistante | Ajouter dans cette interface une annotation simple par ROI et frame, avec auteur et révision, puis la relire après fermeture | Une annotation validée survit au redémarrage ; une erreur d’enregistrement reste visible dans l’UI |
| P5 Pipeline et passerelle | Charger un graphe existant, sélectionner un nœud et ses paramètres dans un panneau contextuel, inspecter ses entrées/sorties dans le viewer, sauvegarder une copie du template, valider puis lancer MATLAB | Requête conservée, résultat structuré et contexte image maintenu ; template d’origine préservé |
| P6 Retour des résultats | Relire les sorties publiées, actualiser l’index dérivé et afficher le résultat lié à son run ; exercer échec et reprise | Démonstration complète, rapport de validation et bilan du coût de réutilisation de pyDetecDiv |

P2 inclurait un export MATLAB explicite des mesures nécessaires si leurs `.mat` ne disposent pas d’un lecteur Python validé. Le prototype ne reposerait pas sur un décodage supposé universel des objets MATLAB. Les axes, types numériques, noms de canaux et correspondances de frames seraient vérifiés indépendamment de l’apparence des images.

P5 proposerait une construction guidée à partir d’un pipeline existant : visualisation des nœuds et connexions, édition des paramètres pris en charge et enregistrement d’une copie indépendante. Les champs non édités seraient conservés. Un type de module inconnu serait signalé. La bibliothèque complète de modules et l’édition libre de toutes les connexions appartiendraient à l’étape suivante.

### Contrats minimaux du prototype

Les opérations ci-dessous sont des interfaces à implémenter, avec des noms indicatifs :

- **Ouvrir et indexer un projet** : fournir un manifeste et obtenir les identifiants durables des FOV, ROI et ressources. Une réindexation ne doit pas créer de nouvelles identités pour les mêmes objets.
- **Lire une région** : fournir ROI, canal et frame absolue ; obtenir le tableau demandé et ses métadonnées d’axes et de coordonnées, sans charger toute la séquence.
- **Lire une mesure** : fournir ROI, nom de série et référence de sortie ; obtenir valeurs, frames et unités, avec la provenance disponible explicitement indiquée.
- **Enregistrer une annotation** : fournir objet, frame, valeur et révision attendue ; obtenir une révision confirmée ou une erreur. Une modification concurrente doit être détectée.
- **Valider et lancer un pipeline** : fournir référence du template, snapshot, sélection et paramètres ; obtenir un identifiant de run, ses événements et un résultat structuré.

La base serait locale à la machine du prototype. Les métadonnées et résultats historiques importés y formeraient un index dérivé ; les nouvelles annotations du prototype seraient autoritatives dans leurs propres tables. Une réindexation préserverait ces annotations. L’interface distinguerait les annotations importées et celles enregistrées dans le prototype ; leur réécriture vers les formats historiques serait une étape ultérieure explicite.

Les quelques tables nécessaires couvriraient les identités et correspondances de sources, FOV, ROI, ressources, séries et valeurs, annotations révisées, ainsi que les références des runs et sorties. Les relations cellule/trajectoire seraient ajoutées quand un cas du prototype les exige. Un nom de sortie historique sans provenance retrouvée resterait identifié comme tel ; l’import ne fabriquerait pas de run producteur.

### Exécution MATLAB depuis Python

La passerelle réutiliserait le [contrat de run](pipeline_run_contract.md). Python préparerait une requête sérialisable contenant les références du projet et du template, le snapshot exécuté, la sélection et les paramètres. Il ne tenterait pas de sérialiser un objet `shallow` ou des handles MATLAB dans son propre contexte.

Le dépôt dispose déjà de `detecdiv_pipeline_cli` avec une option de simulation `--dry-run`, ainsi que de `detecdiv_run_pipeline_job` et de son wrapper `detecdiv_run_pipeline_job_guarded` pour les payloads de jobs. Le travail du prototype serait d’adapter l’UI à ces points d’entrée, de vérifier leur résultat et de normaliser les erreurs. La validation s’appuierait d’abord sur MATLAB ; elle ne serait pas réimplémentée partiellement dans Qt.

MATLAB serait lancé dans un processus séparé. La GUI resterait utilisable, afficherait les événements disponibles et demanderait l’annulation via le mécanisme coopératif du moteur. Un code de sortie de processus ne suffirait pas à déclarer le run réussi : la passerelle vérifierait aussi le résultat structuré et les sorties annoncées.

Le processus MATLAB écrirait dans la copie de travail selon les conventions actuelles. Après publication, le service Python importerait les résultats dans son index. MATLAB n’écrirait pas directement dans la base du prototype. Pour un run incomplet, l’interface n’exposerait que les sorties dont l’état validé est établi par le moteur. La reprise conserverait la politique et l’identité de run requises par ce dernier.

### Critères de réussite et décision de suite

Le prototype serait considéré comme réussi lorsque les conditions suivantes seraient vérifiées :

1. Les identifiants, canaux, coordonnées, frames, masques et mesures de l’échantillon correspondent aux données de référence MATLAB, avec une tolérance explicitée pour les valeurs flottantes.
2. La sélection d’une ROI et le déplacement temporel restent synchronisés entre image, masque et courbe. Cliquer une mesure retrouve sa frame absolue.
3. Les annotations confirmées sont conservées après réouverture et réindexation. Une erreur de transaction ne produit pas un faux état « enregistré ».
4. Le template copié, les paramètres et la sélection transmis à MATLAB correspondent à ceux présentés par l’UI. Une connexion invalide est rapportée par la validation avant exécution.
5. Un run terminé affiche sa sortie et sa provenance. Un échec, une annulation et une reprise sont distingués ; la reprise ne duplique pas les résultats validés.
6. Les fichiers du projet source sont inchangés ; les écritures scientifiques restent dans la copie de travail et les annotations nouvelles dans la base locale.
7. Le rapport contient les temps à froid et à chaud d’ouverture et de sélection, la latence de changement de frame, la mémoire maximale et le coût d’import d’un lot de mesures, sur un matériel et un stockage identifiés.

La décision suivante porterait sur les composants de Fred réellement conservés, les couplages restant à extraire, le bénéfice de la base et les limites du viewer. Si cette tranche est concluante, la suite prioritaire serait l’éditeur complet de modules et de connexions, puis un premier nœud Python exécuté sous le même contrat. La généralisation du stockage et l’intégration Hub suivraient les mesures et les essais de reprise.

Le bilan architectural est favorable à une base par projet pour les données structurées et à une persistance automatique par actions et lots. Le stockage physique des images mérite une décision séparée. La cible serait un **projet cohérent piloté par sa couche de stockage**, dont la ROI reste une unité scientifique et de reprise, sans être une opération de sauvegarde imposée à l’utilisateur.
