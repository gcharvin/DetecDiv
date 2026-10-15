# Numeric dataseries LSTM

`lstm_timeseries` classifies cell states from an ordered set of scalar numeric
traces. It does not use images, a CNN, or upstream classifier weights. It can
consume upstream predicted probabilities, cell geometry, fluorescence metrics,
or any other numeric temporal ROI table variable.

## Classifier GUI

Select the `lstm_timeseries` classifier type. **Configure inputs in Pipeline2...**
opens the normal binding editor, from either classifier parameters or the
training tab. Add/remove inputs in its binding list, select the dataseries and
variable, then **Apply inputs**. This edits the classifier in memory; save it
in Classifier GUI. Applying bindings never submits a pipeline or training job.

Scalar inputs have no component selector. Matrix-valued variables expose a
component selector only when the ROI inventory reports several columns.
Input order is significant. New selections are stored in
`classif.dataset.inputBindings`, separately from optimizer parameters.
Legacy `trainingParam.featureN`/`featureColumnN` files remain readable and are
migrated only when bindings are applied. Input changes require reformatting
and retraining; an existing trained network is never silently adapted.

In **Training parameters**:
- Choose `outputMode`: `frame`, `window`, or `video`.
- `windowLength` is the fixed number of frames for `window`; in `frame` mode it
  is the maximum contiguous sequence length, with a state reset between chunks
  (0 uses the complete contiguous run). `video` uses the whole bounded sequence.

Import ROI as usual. Open annotation from the ROI table: the dedicated trace
editor plots all selected inputs and the managed state labels. Click a trace or
select a frame. **Assign** writes one frame/range in frame mode, one complete
fixed window in window mode, or the whole bounded video in video mode. Clearing
a label also clears its review coverage. **Reviewed**, **Unreview** and
**Validate** use the shared annotation lifecycle. No image store is required.
Score also dispatches to the package's window selector when images are present.

Set classes and ROI bounds before annotation. GT is stored under the classifier
ID as `labels_training` plus `id_training`, independently from input series.
Annotation of selected windows is allowed; only reviewed, known labels are
exported. Window/video labels must be constant; conflicting labels fail rather
than being reduced to a majority. Incomplete windows are not exported. Frame
sequences never bridge gaps in reviewed frames.

Format the dataset, preview numeric sequences, then train. Explicit train,
validation and test ROI must be disjoint. If validation ROI are unspecified,
`validationFraction` reserves a reproducible subset of the selected training
ROI. Test ROI are never formatted. Every class must occur in the actual training
subset. The exported dataset records the exact split and sequence frames.

## Pipeline

The node exposes `featureCount` input bindings of type `dataSeriesVariable`.
Each binding has a series selector and a variable selector. Resources from
preceding classification/metrics modules and existing ROI are available.
The add/remove controls determine the count. The optional component selector
writes `featureColumnN`; `outputName` names the prediction. These are bindings,
not entries in the static/execution parameter dialog.
For example:

```matlab
node.params.featureCount = 3;
node.params.feature1 = '@resource:classification:division / prob_small';
node.params.feature2 = 'channel_quantification / Mean_GFP_cell';
node.params.feature3 = 'mask_quantification / area';
node.params.featureColumn1 = 1;
node.params.featureColumn2 = 1;
node.params.featureColumn3 = 1;
node.params.outputName = 'pred_cell_state';
```

The symbolic source node and concrete variable names must exist in the actual
pipeline/project; the names above are examples. Unexecuted upstream classifiers
expose probability variables from their declared class list. A linked, trained
classifier is required for inference. Training mode/window length and the
ordered variable/component schema are frozen in the model. Input *groups* may
be rebound to equivalent upstream outputs. Changing variables, components or
class names requires reformatting/retraining.

Prediction returns a standard ROI dataseries patch, with `frame`, `id`, `labels`
and `prob_<class>` columns. Window/video scores are broadcast to their frames.
Unselected frames remain undefined (`id=0`, probabilities NaN). Prediction
preserves existing training columns if its output group is also the GT group.

## Numeric and persistence contract

Inputs must be real numeric/logical variables in temporal dataseries. Table rows
represent frames, or a `frame` column supplies unique increasing absolute,
one-based frame IDs. Long per-object or generation tables must be aggregated
into a scalar trace first. Training fields and the classifier's own output are
forbidden inputs. Missing/nonfinite inputs fail by default.
Scalar-cell metrics from `computeMetrics` are accepted directly: one measured
object per frame, with empty cells treated as missing. Cell vectors containing
multiple objects are rejected; select/aggregate the desired object upstream.
Classification probabilities/IDs with an upstream prediction `id=0` are treated
as missing rather than as measured zeros. Optional
`training-median` imputation uses only medians fitted on training ROI.

The same `transform` function standardizes training and inference using frozen
training means/scales. Neither validation nor test features influence these
statistics. No temporal interpolation or test-set threshold selection occurs.

`trackMotherLineageViterbi` exposes `<outputChannelName>_areas / Area_Mother`
and `Area_Bud`, measured in pixels from its separate assigned binary masks.
Only the bud associated with the tracked mother contributes. When a tracked
mother has no bud, bud area is zero; when the mother is missing, both areas are
NaN. Selected-frame updates preserve existing areas outside the selection and
leave never-processed frames missing. The read-only `areaSeries` helper can
also measure previously computed masks without rerunning tracking.

Training exposes `hiddenUnits`, `dropout`, `l2Regularization` and
`classWeighting` (`none` or `inverse-frequency`). Class weights use only the
actual training labels, just as normalization uses only training inputs.
`returnBestValidation=true` returns the checkpoint with lowest validation
loss. `validationPatience` stops after that many validation checks without
improvement (0 disables stopping). With no validation samples, training always
returns the final iteration. Model metadata records class counts, weights,
the checkpoint policy and all hyperparameters. Frozen datasets remain usable
when only these optimizer/regularization settings change.

- `trainingdataset/lstm_timeseries_dataset.mat`: reviewed raw features, labels,
  frame identities, split and parameter snapshot.
- `<classifier-id>.mat`: deployable `classifier` network, frozen `model` metadata
  (features, normalization, classes, modes, split) and training `info`.
- `create(parent,name,id,classes)`: initialize an independent classifier without
  legacy CNN/ImageNet parameter initialization.

Entrypoints `format`, `train`, `classify`, annotation contracts, execution
contracts and training bindings are callable without GUI. Tests include actual
CPU training/reloading/inference in all three modes, data-only ROI dispatch,
GT preservation, ROI split/normalization isolation, symbolic upstream binding,
dynamic Classifier GUI bindings and trace-editor assignment.
