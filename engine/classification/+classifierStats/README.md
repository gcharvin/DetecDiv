# Classifier statistics

`classi.stats` dispatches saved mask and discrete-label annotations to this
shared backend. Package-specific output-unit statistics (numeric LSTM windows)
and legacy regression/statistics paths retain their own implementation.
No inference, training, probability thresholding, or ROI persistence occurs.

Bindings come from `annotationManager.specForClassifier`: GT assets are never
substituted with predictions. `PredictionChannel` and `PredictionGroup` select
pipeline outputs with independent names; each accepts a name or a struct keyed
by annotation component ID. The GUI lets the user choose when several saved
outputs exist. A missing selected asset is an error, not a fallback to another
classifier. An explicit instance-mask contract is required for object matching;
legacy semantic masks are not reinterpreted as instance IDs.

Evaluation intersects selected frames, classifier ROI bounds, and the reviewed
mask for each evaluated component. Disjoint reviewed frames are valid for
frame-local evaluation even when a model needs contiguous training sequences.
Stale approved GT is rejected. Legacy annotations without a manifest retain a
documented fallback: only frames with nonempty GT masks/defined labels are
eligible, with ROI indices recorded in `legacyRois`. Empty reviewed managed
masks are evaluated normally, including false positive and false negative cases.
Sequence-label contracts count one observation per ROI and reject inconsistent
labels. Other structured annotations (lineage relations, tracking identities)
are not claimed to be evaluated by frame-local mask metrics. Tracked-instance
mask components can be evaluated frame by frame, without claiming identity or
lineage quality. Semantic GT uses declared class IDs 1..K; zero means unlabelled
and is ignored. A prediction of zero on labelled GT is penalized, not excluded.
Semantic background must be a declared class, as in DeepLab's training contract.

Mask results include a pixel confusion matrix, per-class precision, recall,
Dice/F1 and IoU. Instance masks additionally use one-to-one matching at IoU >=
0.5 (configurable in `(0,1]`): first maximum cardinality, then maximum summed IoU.
IDs are compacted per frame, so numeric identities and their temporal reuse
cannot bias the score. Reports include TP/FP/FN, precision/recall/F1, matched
mean IoU and panoptic quality `sum(matched IoU)/(TP + .5 FP + .5 FN)`.
Metrics aggregate counts across frames before division. Undefined denominators
are NaN, including object F1/PQ when both masks are empty; pixel accuracy still
includes background pixels. Matching requires MATLAB `matchpairs`, already in
the statistics toolbox used by legacy statistics.

The versioned report (`detecdiv.classifier_statistics.v1`) stores ratios in
`components` in `[0,1]`, per-frame source bindings, and instance IoU threshold.
Top-level compatibility fields consumed by historical run summaries remain in
percent and describe `primaryComponent`; per-class `accuracy` remains the old
precision alias. `classif.score` changes only after successful evaluation.
`Export` writes JSON, per-component frame CSVs, and PNGs when plotting is
requested. `Silent` keeps exports headless. Missing data fails before creating
figures; rendering failures close partially created windows.

```matlab
report = classifierStats.statistics(classif, 'Rois', 2, ...
    'PredictionChannel', 'results_custom_instances', ...
    'IoUThreshold', 0.5, 'Export', fullfile(outputFolder,'validation'), ...
    'Confusion', 'Classes', 'Silent');
```

All regression tests are in `tests/testClassifierStatistics.m` and run without
a model, GPU, or changes to real annotations. Scientific project validation and
release verification should execute on a DetecDiv Hub compute target.
