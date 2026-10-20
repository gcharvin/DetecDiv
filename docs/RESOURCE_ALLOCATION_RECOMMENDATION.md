# Allocation de mémoire et parallélisation des jobs Hub

Date : 15 octobre 2026. Proposition d’évolution issue d’une étude hors production.

## Recommandation

Garantir à chaque job une allocation minimale adaptée à son module, puis lui
prêter la mémoire libre lorsqu’elle permet une accélération mesurable. Restituer
ce surplus à un point de reprise sûr lorsqu’un autre job en a besoin. Répartir
les ressources entre utilisateurs en tenant compte ensemble de la RAM, des CPU,
du GPU et du stockage.

Passer tous les jobs de 24 à 48 ou 96 Gio peut réduire la concurrence et augmenter
le temps moyen entre soumission et fin. Une réservation élevée n’est utile que
si le module exploite effectivement cette mémoire. Le taux de remplissage de la
RAM ne constitue pas à lui seul un objectif de performance.

## Situation actuelle

Le Hub permet déjà une demande explicite supérieure à 24 Gio. Ce chiffre est le
profil par défaut des jobs MATLAB ; l’allocation accordée reste fixe pendant
une tentative. L’admission considère les CPU, la RAM, la réservation GPU et des
unités relatives d’accès disque, avec protection des ressources nécessaires à
une demande prioritaire bloquée.

Lors de l’étude, la cible Linux dispose d’un budget de calcul de 96 Gio et
36 CPU. La politique réserve 512 Mio par worker potentiel ; le plafond de
36 workers soustrait donc 18 Gio et laisse 78 Gio pour les jobs, même avec six
pollers souhaités. Toute réduction de cette réserve exige une admission atomique
coordonnée avec l’autoscaler. Les réservations GPU peuvent également bloquer
l’admission indépendamment de la RAM disponible.

L’élasticité en cours de job et le protocole de restitution décrit ci-dessous
restent à implémenter. Windows ne dispose pas actuellement des mêmes protections
dynamiques que Linux ; prévoir une protection et une validation propres à cette
plateforme. Le pool des runs locaux suit une politique distincte, documentée
dans [LOCAL_FOV_POOL.md](LOCAL_FOV_POOL.md).

## Contrat proposé entre modules et ordonnanceur

1. Chaque module décrit ses besoins minimaux, utiles et maximaux, son plafond
   de parallélisation, ainsi que ses points de reprise supportés. Les estimations
   incluent le coordinateur MATLAB, les buffers, les copies sérialisées vers les
   processus de pool et les modèles chargés. Un besoin minimal réel supérieur à
   24 Gio reste légitime.
2. Le Hub accorde le minimum puis un surplus utile selon la capacité libre,
   les demandes en attente et le partage par utilisateur. Les CPU et le débit
   stockage bornent le nombre de lecteurs ; davantage de RAM ne les remplace pas.
3. Lorsqu’une demande concurrente exige une restitution, le Hub émet un nouveau
   budget identifié par une génération. Le module termine une unité sûre,
   sauvegarde durablement sa progression, libère ou réduit buffers et pool,
   puis accuse réception de cette génération.
4. Le Hub vérifie la libération effective avant de compter les ressources comme
   disponibles et d’appliquer une limite inférieure. Un accusé périmé, une absence
   de réponse ou de la mémoire encore occupée n’autorise aucune réattribution.
   Réduire directement le quota d’un MATLAB chargé risquerait de le tuer.
5. Si les bibliothèques conservent leur mémoire, reprendre depuis un checkpoint
   validé dans un processus neuf constitue une solution de repli. Un module
   historique non coopératif conserve son allocation jusqu’à sa fin ou jusqu’à
   un point de reprise explicitement pris en charge.

Un point de reprise ne doit pas imposer un redémarrage systématique de MATLAB,
du pool ou des modèles. Déclencher la restitution en présence d’une demande
concurrente évite de payer ces coûts lorsqu’un job travaille seul. La suspension
d’un processus ne libère pas sa RAM.

## Blocs de frames et stockage ROI

Réduire les blocs peut permettre davantage de lecteurs parallèles, mais augmente
le nombre de sauvegardes. Dans l’extraction historique d’Alex, le MAT complet
d’une ROI est relu et réécrit à chaque bloc, sans compression dans le chemin
testé. Des blocs plus petits peuvent donc amplifier fortement les entrées et
sorties.

Le stockage HDF5 des ROI permet des écritures partielles. Étendre les backends
standardisés pour exploiter leur mécanisme de streaming et des checkpoints
idempotents est préférable à des copies complètes supplémentaires. Préserver le
contrat universel de `roi.save` et le rechargement dans `roi.results`.

La lecture et l’inférence ont aussi des besoins différents. Une réservation GPU
par étape pourrait éviter d’immobiliser la VRAM pendant une longue extraction,
mais nécessite une admission à chaque transition et un état sauvegardé avant
toute attente. Ne pas libérer prématurément une réservation GPU sans ce protocole.

## Résultats des essais et portée

L’étude comporte 1 680 simulations synthétiques, avec budgets de 78 et 96 Gio,
arrivées concurrentes, charges hétérogènes et deux hypothèses de contention
stockage. Les temps simulés ne prédisent pas la durée des jobs réels.

- Sur la charge hétérogène à 78 Gio sans plafond supplémentaire de stockage,
  48 Gio fixes augmentent le délai moyen d’environ 65 % face à 24 Gio.
- L’élasticité avec équité réduit dans ce scénario la durée globale et l’attente
  initiale maximale, mais augmente le délai moyen. Débit, réactivité et équité
  doivent donc être évalués séparément.
- Dans le modèle de lecture étudié, 48 et 96 Gio donnent le même plafond de
  huit lecteurs : allouer le maximum ne crée pas nécessairement de gain.
- Un essai MATLAB local sur deux petites ROI synthétiques confirme des pixels
  identiques et moins de réécritures en HDF5. HDF5 y est cependant plus lent,
  car le coût des nombreux petits appels domine. Mesurer une charge dédiée sur
  NAS reste nécessaire avant d’annoncer une accélération.

Dix tests du simulateur et deux tests existants du streaming ROI ont réussi.
Dix-neuf tests ciblés Hub et sondes locales ont réussi ; un test historique a
été exclu après diagnostic d’une fixture incomplète (`params_json` absent).
Cela ne constitue pas une validation complète de la suite Hub. Aucun job actif,
quota, service ou résultat scientifique n’a été modifié pour ces essais.

Les scripts, données synthétiques de mesure, résultats et observations avant/après
sont conservés dans le dépôt compagnon `detecdiv-hub`, sous
`reports/resource-allocation-study-20261015/`, avec `report.html` comme synthèse.

## Ordre de mise en œuvre

Commencer par les mesures et profils par module, puis la fiabilité des checkpoints
et des écritures partielles. Ajouter ensuite l’admission équitable et les prêts
de ressources, enfin la négociation de restitution sur Linux et Windows.

Évaluer sur une charge dédiée : ROI par heure, délai moyen soumission-fin,
attente p95 et maximale, partage entre utilisateurs, pics RAM et VRAM, swap,
erreurs mémoire, débit NAS et coûts de démarrage/reprise. Conserver une politique
uniquement si les gains et la qualité de service sont établis sur ces mesures.

## Références

- [Dominant Resource Fairness, NSDI 2011](https://www.usenix.org/conference/nsdi11/dominant-resource-fairness-fair-allocation-multiple-resource-types) : partage équitable entre ressources. Le prototype étudié s’en inspire sans en reproduire les garanties formelles.
- [Slurm Scheduling Configuration](https://slurm.schedmd.com/sched_config.html) : backfill temporel, sous réserve d’estimations de durée raisonnables.
- [Slurm Preemption](https://slurm.schedmd.com/preempt.html) : la suspension conserve la mémoire et ne remplace pas une restitution coopérative.
