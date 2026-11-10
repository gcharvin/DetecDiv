# Numeric dataseries LSTM

`sequenceScope=trajectory` is an opt-in causal sequence-to-sequence LSTM. It
processes each entire contiguous bounded ROI run without resetting at window
boundaries, while annotations, loss targets and published predictions remain
one per `windowLength` frames. Complete reviewed windows are joined only within
one ROI/split and never over a review gap. Inputs outside configured bounds are
excluded. At inference, a partial output request still processes preceding
bounded history; future frames cannot influence earlier outputs.

The native `trainNetwork` optimizer/checkpoint machinery is retained. A small
custom output loss (`WindowEndpointLoss`) computes weighted cross entropy only
at window endpoints. Other frames carry no direct loss, but gradients propagate
through their recurrent states. Duplicated per-frame labels satisfy MATLAB's
sequence target shape; they do not multiply supervised targets or class counts.
Padding endpoints have zero targets and are excluded from the loss denominator.
The native progress accuracy is frame-based; the authoritative output-window
metrics remain Classifier GUI statistics. This mode requires LSTM, window
output and `contextWindowLength=0`. Default window scope and old models retain
their existing behavior; changing scope requires reformatting and retraining.

For budget comparisons, record sequence size and supervised targets per update,
not just update count. With 15 training ROI x49 frames, batch1 and80epochs give
1200updates x7 target windows =8400 target presentations. The independent
window reference used1040updates x8 =8320. Both process almost the same number
of input frames and use the same16-unit network (1395 parameters for4 inputs
and3 classes), optimizer, class weights and train-only normalization.

The existing numeric module also supports an opt-in small TCN for window
classification: set the static `networkArchitecture` parameter to `tcn`.
Default `lstm` and historical saved LSTM models retain their behavior. The TCN
uses two causal dilated convolutions per residual block (dilations 1, 2, ...),
ReLU/dropout, a 1x1 skip projection when channel counts change, and global
temporal average pooling before the same weighted classification head.
`tcnChannels`, `tcnBlocks`, and `tcnKernelSize` configure its size; `hiddenUnits`
applies only to LSTM. Defaults 10/2/3 give 1,143 trainable parameters with four
inputs and three classes, versus 1,395 for a 16-unit LSTM. The maximum causal
receptive field before pooling is 13 frames; seven-frame inputs use causal
zero padding within the same window, without reading neighboring frames.

Both architectures share formatting, train-only normalization, loss weights,
optimizer, best-validation checkpoint selection, ROI prediction patches and
Classifier GUI statistics. Input selectors remain bindings, separately from
these static architecture/training controls. Saved model metadata freezes the
architecture; changing the selector after training cannot silently switch it.

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
Classifier-scoped training and validation import the complete saved binding
set (count, order and components). Removed slots are not restored from defaults
or older execution settings. Logical `group / variable` selectors remain
unchanged by worker path translation; whitespace around `/` is normalized
when comparing them with legacy formatted datasets.
Legacy Windows run snapshots whose selector separator was rewritten to `\`
are also read as logical bindings, without requiring another dataset export.

The ROI annotation window shows the full ordered model binding list and its
global scope. **Configure inputs in Pipeline2...** opens the same input editor
used by Classifier GUI, and **Apply inputs** refreshes the ROI summary. The
**Show** checkboxes control curve visibility only. Hiding a curve never removes
a model input.

A classifier-scoped training pipeline imports those bindings and displays them
read-only under **Bindings**. Reopen the training pipeline after applying a new
selection in the classifier input editor. **Training parameters...** imports
the classifier's static architecture, optimizer, and formatting settings for
the run. Input count, selectors, order and components are excluded from that
static dialog. Inference keeps its separate execution parameter contract.
The existing launch confirmation also lists effective model bindings,
including any per-run overrides, before submission.

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

The numeric editor shares Score's class-key preferences (by default `a z e r t
y u i`, in class order). Left/right arrows move to the previous/next complete
annotation unit, staying inside the ROI's training bounds; frame mode advances
one frame. The current unit is shaded gray in every visible trace and the label
plot. Click a trace to select it, then press its class key to assign/save the
whole current unit. Numeric input fields retain their ordinary editing keys;
Ctrl/Alt/Command shortcuts never assign labels. Checkboxes show/hide individual
input traces, with Show all/Hide all controls; visibility survives ROI changes
and never changes the input bindings, training features, or annotations.

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

After training, check **Select for testing** on the held-out ROI, then use
**Validate classifier** to open and run the inference pipeline. Finally,
**Display classifier statistics** compares its stored predictions with reviewed
GT on those test ROI. Filtering/reordering the ROI table preserves ROI identity.
Formatting reports training and validation *sequence* counts, rather than an
image count; its output is one MAT dataset.

Statistics count one example per frame, complete fixed window, or bounded
video, according to `outputMode`. Repeated per-frame window predictions count
only once. Unreviewed/undefined GT and incomplete units are excluded. Missing
predictions produce an instruction to run validation first. The display includes
the confusion matrix and per-class precision, recall, F1 and support; exported
reports also retain ROI IDs and absolute frame bounds for every evaluated unit.
For headless evaluation/export use:

```matlab
[score, fig] = lstm_timeseries.statistics(classif, 'Rois', testRoiIndices, ...
    'Confusion', 'Classes', 'Silent', 'Export', fullfile(reportFolder, 'validation'));
```

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
# Optional context around window targets

`windowLength` remains the annotation and prediction unit. In window mode,
`contextWindowLength=21` with `windowLength=7` observes seven preceding and
seven following frames while learning only the original seven-frame label.
The default `0` preserves existing behavior and existing models. Context is a
static training parameter; ordered feature selectors remain dataset bindings.
This symmetric context is intended for retrospective analysis, not online detection.

Formatting and inference share `contextFrames`; context never crosses ROI bounds
or gaps. At an acquisition/bounds edge, the nearest valid frame is repeated so
the target always occupies the central positions. Samples retain target `frames`
and separate `inputFrames`. Normalization counts each training ROI/frame once,
avoiding overlap and padding weights; validation/test ROI never fit normalization.
Saved models freeze context length. Statistics continue to score target windows
through Classifier GUI, without merging their labels or counting context as targets.
