# Partial pipeline run bindings

`ctx.run.selectedNodes` defines the modules that will execute. Selecting a
subset does not import the outputs or resource identities of excluded modules.

For an input provided by an excluded module, the user must select an explicit
existing channel, dataseries, family, or other resource from the current project.
Validation rejects symbolic references to excluded modules, including optional
inputs, even when a previous run has persisted a resource with the expected name.
An unconfigured required external input also blocks the partial run; validation
does not choose an existing input automatically. The same validation is used by
the frontend, dry runs, local execution, and Hub execution.

Symbolic bindings between modules included in the run remain supported. The
resolver translates those bindings according to the producer's output contract.
Users can either replace an excluded producer's symbolic binding with an explicit
existing resource, or include that producer in the execution selection.

Explicit per-run bindings take precedence over symbolic template defaults. An
explicit empty value is also preserved and, for a required input, blocks the run
until the user makes a choice. The frontend and backend apply the same override
rules before rebuilding the active module contract.

Only inputs declared by the active module contract are checked. For
`cellLatentModel` with `backend=causal_composite`, the required inputs are the
frame-local instance masks and, when the promoted BF state component is active,
the brightfield observation. Stable tracks are outputs; the legacy
`trackChannelName` field is not a composite input. Optional fluorescence inputs
remain optional.

Example: when CellposeSAM is excluded and only the composite latent model is
selected, use `instanceChannelName=results_pred_cellposesam_cell` and an explicit
brightfield channel such as `brightfieldChannelName=channel000_z001`.
`instanceChannelName=@resource:segmentation:classifier_cellposesam_4` blocks that
partial run. It is valid when the CellposeSAM producer is also selected.
