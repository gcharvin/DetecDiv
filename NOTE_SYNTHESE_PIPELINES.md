# Synthese pipelines DetecDiv

Date de redaction: 2026-04-01

## Objet

Cette note synthetise les derniers commits lies aux pipelines, principalement entre le 2026-02-04 et le 2026-03-09, pour reprendre le developpement avec une vue claire de ce qui est deja en place.

Le fil conducteur est net: DetecDiv a maintenant les briques principales pour definir un pipeline editable, le valider, preparer un `pipelineRun`, et executer les noeuds avec un `ctx` de plus en plus normalise. La derniere vague de commits a surtout servi a consolider l'execution, la validation semantique et l'UI de creation de runs.

## Commits relus

- `f571723` - 2026-02-04 - `implemented the pipelinebuilding blocks`
- `93cc0fb` - 2026-02-11 - `added pipeline structure`
- `bac9cc0` - 2026-02-11 - `updated pipeline files`
- `e10d310` - 2026-02-27 - `major change pipeline`
- `5720ba8` - 2026-03-06 - `bug fix pipeline run`
- `d4397b3` - 2026-03-07 - `pipeline run update`
- `e93d1c9` - 2026-03-07 - `updated overwrite policy for pipeline runs`
- `3fbcf2a` - 2026-03-07 - `update pipeline run`
- `f7bed06` - 2026-03-09 - `store pipeline modifications`

## 1. Ce qui a ete pose en fevrier

### 2026-02-04: premiers building blocks

Le commit `f571723` pose la logique initiale de pipeline sous forme de helpers separes:

- construction de `ctx`
- initialisation des sorties
- application de patches au projet et aux ROI
- premiere version de `runPipeline`
- premiers tests de sequence extraction -> segmentation -> metrics

En pratique, c'est le point de depart du modele "pipeline + contexte d'execution", mais encore hors de l'architecture actuelle `structure/io`.

### 2026-02-11: passage a une structure persistante

Le commit `93cc0fb` introduit la vraie structure pipeline persistable:

- classe `@pipeline`
- helpers `pipelineNew`, `pipelineLoad`, `pipelineSave`
- `pipeline_schema.json`
- integration de `runPipeline` et `validatePipeline`
- premiers modules de dataloading / ROI identification / ROI extraction branches pour le pipeline

Le commit `bac9cc0` ajoute ensuite la notion de `pipelineRun` et son rattachement au projet:

- classe `@pipelineRun`
- helpers `pipelineRunNew`, `pipelineRunLoad`, `pipelineRunSave`
- integration dans `@shallow`
- premiers points d'entree GUI dans `detecdiv`

Conclusion de cette phase: la distinction template / execution est deja clairement engagee, et reste coherente avec la direction actuelle.

## 2. Le tournant de fin fevrier

### 2026-02-27: maturation du pipeline builder

Le commit `e10d310` est moins centre sur le runner que sur l'outillage GUI:

- evolution importante de `pipelineGUI`
- integration plus explicite avec les GUI process / classifier
- renforcement du role du pipeline comme orchestrateur transverse

Ce commit marque le passage d'une simple structure enregistrable a un vrai editeur de pipeline exploitable dans l'application.

## 3. La grosse consolidation des 2026-03-06 au 2026-03-09

### 2026-03-06: meilleure erreur d'execution

Le commit `5720ba8` corrige surtout la qualite du debugging dans `runPipeline`:

- les erreurs de noeuds embarquent maintenant le message, l'identifiant MATLAB et le haut de stack
- le diagnostic d'echec d'un noeud devient nettement plus exploitable

C'est un petit commit, mais utile pour auditer les runs et debugger les modules backend.

### 2026-03-07: run id, policies et reporting de run

Les commits `d4397b3`, `e93d1c9` et `3fbcf2a` forment un bloc coherent. Le runner a franchi un cap sur quatre sujets.

#### A. Un vrai contexte d'execution normalise

`runPipeline` normalise maintenant explicitement:

- `ctx.run`
- `ctx.io`
- `ctx.store`
- `ctx.names`
- `ctx.sel`
- `ctx.runId`

Le `runId` est auto-genere par invocation si absent. C'est important: cela evite qu'une reprise reutilise silencieusement des checkpoints d'une execution precedente.

#### B. Des politiques d'execution plus explicites

Le runner distingue maintenant au moins trois niveaux de politique:

- `runPolicy`: `resume` ou `restart`
- `existingPolicy`: `replace`, `append`, `skip`, `error`, `upsert`
- `cachePolicy`: `auto`, `memory`, `disk`

Ces politiques sont injectees dans le `ctx` et aussi projetees vers les params des noeuds quand c'est necessaire:

- `keepExisting`, `skipExisting`, `errorOnExisting` pour les noeuds ROI
- `outputName` pour processor / classifier

Pour les processors et classifiers, le runner gere aussi les cas "sortie deja presente":

- `skip` saute le noeud si la sortie existe deja
- `error` fait echouer le run
- `append` force un nom de sortie distinct si besoin

#### C. Des `pipelineRun` plus auditables

Le runner construit maintenant un rapport d'execution detaille:

- heure de debut et de fin
- statut par noeud
- duree par noeud
- politiques appliquees
- compteurs avant / apres execution
- resume global

Ce rapport est conserve dans `DetecDivLastPipelineReport` et alimente aussi la persistance du `pipelineRun` via `pipelineRunSave` avec:

- `run.json`
- `run_summary.txt`

Le `pipelineRun` devient donc une vraie trace d'execution et pas seulement un conteneur de parametres.

#### D. Propagation du contexte vers les modules backend

Les processors et classifiers recoivent maintenant plus proprement:

- `ctx.run`
- `ctx.io`
- `ctx.store`
- `ctx.executionPolicy`
- `ctx.names.outputName`

Cela rapproche le backend du contrat cible "module pipeline callable sans GUI".

### 2026-03-09: gros saut UI/UX et validation

Le commit `f7bed06` est le plus structurant de la serie recente. Il touche a la fois l'editeur de pipeline, la GUI de creation de run, la validation et la persistance des modules.

#### A. `pipelineGUI` devient beaucoup plus riche

Les apports visibles sont:

- ports d'entree / sortie affiches par noeud
- connexions par ports et non plus seulement entre blocs
- connect / disconnect plus explicite
- bibliotheque de modules visible dans l'UI
- sauvegarde de noeuds dans une "offline library"
- lien d'un noeud du pipeline vers une definition de reference
- ouverture d'un noeud pour edition
- creation directe d'un run depuis le builder

En pratique, `pipelineGUI` n'est plus seulement un canvas de dessin. Il devient un editeur de workflow avec notions de contrat, de reference de module et de validation.

#### B. `pipelineRunGUI` devient le vrai point d'entree pour preparer un run

Les nouveaux points importants sont:

- choix du `runPolicy`
- choix du `existingPolicy`
- choix du `cachePolicy`
- choix de la source d'entree du run
- selection optionnelle des FOV du projet
- surcharge de params par noeud au niveau du run
- ouverture du GUI d'un noeud pour completer ses params

Le choix de la source d'entree est notable. Un run peut maintenant partir de:

- `Pipeline start (dataloader)`
- `Existing project FOVs`
- `Existing ROIs`
- `Existing masks`
- `Existing dataSeries`

Cela va dans la bonne direction pour des workflows partiels, de reprise ou de post-processing.

#### C. La validation est beaucoup plus semantique

`validatePipeline.m` ne se limite plus a:

- verifier qu'il y a des noeuds
- verifier qu'il n'y a pas de cycle
- verifier des params obligatoires basiques

La validation ajoute maintenant:

- des contrats d'I/O par type de noeud
- une verification des ports d'edges
- des warnings separes des erreurs
- des parametres "deferred" acceptes au niveau template et attendus au niveau run
- une validation semantique progressive de l'etat du workflow

Exemples de points maintenant pris en compte:

- presence d'images avant ROI ID
- presence de ROI avant extraction / processor / classifier
- presence de masks avant `roiTracked`
- nombre minimal de channels dans certains cas

#### D. Le contrat des noeuds commence a etre formalise

`pipelineNodeContract.m` formalise pour chaque famille de noeuds:

- ports d'entree
- ports de sortie
- selectors
- requirements
- capabilities
- resume textuel

Les familles couvertes explicitement sont:

- dataloader
- roiidentify / roipattern
- roimanual
- roigrid
- roitracked
- roiextract
- processor
- classifier

Le cas `cellposeSAM` est traite specifiquement comme classifier producteur de masks.

Conclusion: on n'est plus sur une simple orchestration imperative, mais sur le debut d'un systeme de contrats de noeuds.

## 4. Etat actuel du coeur pipeline

Au 2026-04-01, l'etat du systeme peut se resumer comme suit.

### Ce qui est deja bien en place

- `@pipeline` joue bien le role de template editable
- `pipelineRun` joue bien le role d'instance d'execution
- `runPipeline` porte deja la logique centrale d'orchestration
- le `ctx` a une structure de plus en plus stable
- la validation est deja suffisante pour detecter beaucoup d'erreurs de composition
- l'UI sait creer un run avec des surcharges et des politiques d'execution
- la persistance des runs et des templates existe deja

### Ce qui apparait comme la direction retenue par le code

- le pipeline doit rester independant de `@shallow`
- le run est l'objet qui relie pipeline et projet
- la reutilisation passera par des noeuds types avec contrat explicite
- le runner doit pouvoir lancer les backends sans logique GUI embarquee
- l'UX vise clairement des runs partiels, rejouables et auditables

## 5. Points de vigilance pour la suite

Les derniers commits reglant beaucoup de structure, les prochains tests UI/UX devraient surtout verifier les zones de jonction.

### A tester en priorite

- creation d'un pipeline simple dataloader -> roipattern -> roiextract
- validation avant run avec modules incomplets
- completion de params via GUI depuis `pipelineRunGUI`
- run partiel en repartant de `Existing ROIs`
- comportement reel de `replace` / `append` / `skip` / `error`
- nommage des sorties processor / classifier en append
- compatibilite de `roiTracked` avec les masks exposes par classifier
- qualite du `run_summary.txt` comme support d'audit
- robustesse de la bibliotheque offline dans `pipelineGUI`

### Points probablement encore fragiles

- coherence exacte entre contrats declares et comportements reels de certains modules backend legacy
- normalisation des outputs quand un module ecrit directement dans les ROI sans reflet complet dans le `ctx`
- semantics des sources de run existantes (`Existing masks`, `Existing dataSeries`) selon l'etat reel du projet
- UX des policies quand plusieurs noeuds manipulent des outputs deja presents

## 6. Fichiers de reference pour reprendre le dev

- `structure/io/runPipeline.m`
- `structure/io/validatePipeline.m`
- `structure/io/pipelineNodeContract.m`
- `structure/io/pipelineRunSave.m`
- `structure/classes/@pipeline/pipeline.m`
- `structure/GUI/pipelineGUI_extracted.m`
- `structure/GUI/pipelineRunGUI_extracted.m`

## 7. Lecture generale

Le coeur pipeline n'est plus a concevoir: il est deja la. Le vrai enjeu de la reprise est maintenant de finir l'alignement entre:

- contrats de noeuds
- comportements reels des backends
- creation et relance de `pipelineRun`
- UX du builder et du run editor

Autrement dit, la prochaine phase n'est plus "inventer l'architecture pipeline", mais la rendre fiable, lisible et comfortable a utiliser dans les cas reels DetecDiv.
