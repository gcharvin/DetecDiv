# Guidelines UX de la nouvelle interface

Référence : discussion avec Gilles du 4 novembre 2026 et `DETECTIVE_UI_ROADMAP.md`.
Ce document fixe les orientations retenues ; les détails d'implémentation restent évolutifs.

## Priorité confirmée

**Image centrale et outils contextuels.** Choix explicite de Gilles le 4 novembre 2026.

L'image occupe la plus grande surface disponible. Les panneaux de données et d'outils sont repliables. Le parcours guide sans occuper une grande partie de l'écran ni imposer un assistant modal.

## Principes d'interaction

1. **Partir d'une intention.** Présenter « Examiner une zone », « Segmenter les cellules », « Corriger un résultat » ou « Mesurer une fluorescence ». Les noms des classes et fonctions internes ne structurent pas le parcours courant.
2. **Garder une fenêtre principale.** Explorer une position, entrer dans une zone et revenir au champ dans la même vue. Les outils apparaissent autour de cette vue.
3. **Savoir où l'on est.** Le fil d'Ariane indique expérience, position et zone, avec leurs noms lorsque disponibles. Le retour au niveau précédent reste visible et ne ferme pas le projet.
4. **Savoir quoi faire ensuite.** Une indication courte dépend de la sélection et de la disponibilité des données. Ne pas présenter comme accomplie une étape dont l'état n'a pas été vérifié.
5. **Révéler progressivement.** Afficher d'abord une configuration pertinente et ses réglages essentiels. Donner accès aux détails et au pipeline dans l'outil concerné, sans mode expert global obligatoire.
6. **Préserver la continuité.** Conserver le temps et le canal nommé si possible entre champ et zone. Conserver le zoom lors du parcours temporel d'une même vue. Un changement de contexte incompatible réajuste la vue.
7. **Distinguer observation et modification.** Naviguer et régler l'affichage ne sauvegarde pas de nouvelles données scientifiques. Une action de traitement décrit sa portée et les résultats créés ou remplacés avant exécution.
8. **Éviter les ambiguïtés scientifiques.** Indiquer brut, extraction ou résultat dérivé. Les contours de référence ne sont pas présentés comme des trajectoires corrigées dans le temps. Un échec de lecture efface les anciens pixels.
9. **Respecter les données existantes.** Masquer les placeholders historiques sans supprimer d'objets ni renuméroter les références internes. Afficher les canaux logiques nommés et conserver l'intégrité des sous-canaux RGB.
10. **Rendre l'exécution explicable.** L'utilisateur lance une action simple ; il peut inspecter le pipeline, les paramètres effectifs, l'avancement, les erreurs et la provenance.

## Structure visuelle de départ

- En-tête sobre : identité de l'application, ouverture d'expérience et contrôle des panneaux.
- Navigation : retour au champ et fil d'Ariane, immédiatement au-dessus de l'image.
- Gauche : positions et zones, avec les noms des données ; gestion étendue des projets à intégrer progressivement.
- Centre : image et outils natifs de zoom/déplacement ; navigation temporelle directement sous l'image.
- Droite : affichage et actions adaptées au contexte courant.
- Bas : origine des pixels, temps et canal, ou message d'erreur utile.

Le prototype utilise un fond d'image sombre et des panneaux clairs. La palette définitive, les espacements et les composants App Designer seront stabilisés après essai sur données réelles. La couleur ne doit pas constituer le seul indice d'état.

## Comportements déjà matérialisés

- Repli des panneaux Données et Outils.
- Ouverture d'une zone par sa liste ou un clic sur son contour de référence.
- Retour au champ, maintien du temps lorsque compatible et du canal si son nom correspond.
- Navigation temporelle par numéro, curseur et boutons précédent/suivant.
- Masquage des objets vides et erreurs sans conservation d'une ancienne image.

## Points à préciser avec les essais

- Organisation de plusieurs expériences et accès aux modèles et pipelines sans détourner la vue centrale.
- Simple clic pour sélectionner et double clic pour ouvrir, si des opérations groupées rendent cette distinction nécessaire. Le prototype ouvre directement au clic.
- Raccourcis clavier et arbitrage entre sélection, zoom, déplacement et édition.
- Présentation de plusieurs couches, contrastes, couleurs et masques.
- Indication de l'état réel des étapes et choix des configurations proposées.
- Taille minimale utilisable et dispositions mémorisées par activité.
- Langue et vocabulaire définitifs. Le prototype utilise le français pour les libellés utilisateur.

## Vérification à chaque tranche

L'utilisateur peut identifier ce qu'il regarde, revenir au contexte précédent et comprendre l'action suivante. Aucun nouveau panneau ne doit obliger à connaître la hiérarchie des objets MATLAB. Les améliorations doivent être vérifiées sur les pixels affichés et les parcours réels, puis sur une acquisition représentative avant adoption.
