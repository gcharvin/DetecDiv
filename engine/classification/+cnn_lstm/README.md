# CNN/LSTM classifiers

The historical CNN/LSTM training and inference paths remain the default.

## Frozen feature encoder and ROI-disjoint head

Enable `frozen_encoder_head` in Classifier GUI training parameters to use a
checksum-pinned CNN as a feature extractor and fit only the temporal LSTM.
Set `train_CNN_classifier=false`, `classifier_output=sequence-to-one`, a
positive `LSTM_sequence_length`, and an explicit disjoint train/val/test ROI
split. Install the source CNN as `netCNN_<classifier-id>.mat`. Select the image
channels in order in the existing input binding editor; they must supply the
CNN's input component count. No upstream classification probabilities are
consumed by this mode.

`frozen_encoder_layer` identifies a CNN feature layer before the class head.
Formatting uses ROI image preprocessing, resizing and uint8 conversion as in
the existing image framework, then inference-mode CNN activations. The CNN
weights are never updated. Only complete, reviewed, uniformly annotated
windows inside the ROI bounds are formatted. Mixed source labels must first
be grouped under an explicit annotation policy in a separate classifier.

`frozen_encoder_dataset.mat` records raw features, exact ROI/frame identities,
the encoder checksum, ordered image bindings and feature layer. No test ROI
is formatted. Training rejects stale encoder identities, class lists, windows
and partitions. Feature normalization, missing-value handling, class weighting,
optimizer and checkpoint selection share `lstm_timeseries.fitSequences` with
numeric classifiers. `LSTM_dropout`, `LSTM_l2_regularization`,
`LSTM_class_weighting`, `LSTM_validation_patience` and
`LSTM_return_best_validation` configure this opt-in head; the historical path
keeps its existing behavior.

The saved `<classifier-id>.mat` contains the temporal head and metadata. It is
used together with the checksum-verified frozen CNN artifact. Inference returns
the ordinary classifier dataseries patch and preserves GT fields. Classifier
GUI's Validate action opens Pipeline 2 as usual; Display classifier statistics
uses the shared reviewed-window evaluator, counting one observation per window.
