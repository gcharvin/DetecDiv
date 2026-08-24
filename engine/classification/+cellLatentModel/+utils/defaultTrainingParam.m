function p = defaultTrainingParam()
%CELLLATENTMODEL.UTILS.DEFAULTTRAININGPARAM ROI formatting/training defaults.
spec = { ...
    'architectureVersion',{{'detecdiv_composite_v1','lineage_only_v1','detecdiv_composite_v1'}}, 'Composite architecture exposed by this classifier.'
    'trainTrackingActions',true, 'Train the existing EDGE/APPEAR/END tracking-action head.'
    'trainMotherNull',true, 'Train the existing physical-time mother-versus-NULL head.'
    'stateUpdateMode',{{'promoted_frozen_bf','none','promoted_frozen_bf'}}, 'Use the promoted frozen BF/geometry biological-state student or disable state updates.'
    'instanceChannelName','', 'Frame-local instance masks consumed by the tracking head.'
    'trainingObjective',{{'relation_ensemble','continuous_lineage','continuous_lineage'}}, 'Train the legacy relation ensemble or a continuous physical-time lineage head.'
    'trackChannelName','', 'Tracked indexed-mask channel; empty uses the classifier inputs.'
    'gfpChannelName','', 'Optional nuclear GFP channel used for axis and brightness observations.'
    'brightfieldChannelName','', 'Optional brightfield channel for continuous lineage training.'
    'nucleusChannelName','', 'Optional explicitly typed nuclear/division marker channel.'
    'budneckChannelName','', 'Optional explicitly typed bud-neck marker channel.'
    'frameIntervalMinutes',[], 'Physical acquisition interval; mandatory for continuous lineage training.'
    'trainingDomain','detecdiv_reviewed', 'Audited acquisition domain label; Project47 weak data cannot be fitted.'
    'continuousVariant',{{'all_observed','geometry','delayed_marker_relation','all_observed'}}, 'Continuous observation architecture trained from the reviewed ROIs.'
    'decisionLatencyMinutes',40, 'Physical-time latency at which the parent decision is trained.'
    'temporalWindowMinutes',180, 'Maximum future marker horizon exported in physical minutes.'
    'temporalSampleStepMinutes',5, 'Physical-time sampling step for temporal relation observations.'
    'continuousMaxCandidates',8, 'Maximum candidate mothers in the continuous candidate set.'
    'continuousCentroidPrefilter',24, 'Nearest centroids retained before contour-distance ranking.'
    'continuousMaxContourDistanceRadii',4, 'Maximum contour distance in child-radius units.'
    'continuousStateDim',40, 'Dimension of the recurrent per-cell memory.'
    'continuousBlockEmbeddingDim',16, 'Dimension of each observation-block encoder.'
    'continuousAttentionDim',32, 'Dimension of local cell/event attention.'
    'maxEventHistoryTokens',8, 'Maximum predicted event tokens retained per cell.'
    'timeScaleMinutes',10, 'Time scale used by continuous memory decay.'
    'continuousCausalFeedback',false, 'Feed prior predicted lineage events into the continuous memory.'
    'groundTruthFamily','<auto>', 'Reviewed lineage family used as training truth.'
    'validationFraction',0.2, 'Fraction held out by ROI when no validation split exists.'
    'trackingTopK',8, 'Nearest predecessor candidates retained by the tracking head.'
    'trackingMinimumTruthOverlap',0.5, 'Minimum instance fraction assigned to one reviewed track ID.'
    'trackingMinimumDetectionCoverage',0.8, 'Required fraction of instances mapped to reviewed tracking GT.'
    'trackingInitialModelSource',{{'promoted_cross_domain','checkpoint','random','promoted_cross_domain'}}, 'Initialization for the EDGE/APPEAR/END head.'
    'trackingInitialCheckpoint','', 'Optional custom initial tracking checkpoint.'
    'trackingEpochs',30, 'Training epochs for the EDGE/APPEAR/END head.'
    'trackingLearningRate',0.002, 'AdamW learning rate for the tracking head.'
    'trackingWeightDecay',0.0001, 'AdamW weight decay for the tracking head.'
    'trackingHiddenDim',32, 'Tracking latent hidden dimension.'
    'trackingDropout',0, 'Tracking-head dropout.'
    'trackingAssociationLossWeight',1, 'EDGE/predecessor loss weight.'
    'trackingAppearanceLossWeight',0.5, 'APPEAR/new-track loss weight.'
    'trackingEndLossWeight',0.5, 'END/termination loss weight.'
    'trackingSuccessorLossWeight',0, ['Auxiliary grouped EDGE-versus-END ' ...
        'successor loss weight; zero disables it.']
    'minLifetime',5, 'Minimum lifetime of a new bud track.'
    'maxBirthArea',400, 'Maximum bud area at first appearance.'
    'minParentAge',2, 'Minimum candidate-mother age in frames.'
    'maxParentCentroidDistance',60, 'Maximum candidate centroid distance in pixels.'
    'maxParentContourDistance',20, 'Maximum candidate contour distance in pixels.'
    'maxCandidates',4, 'Maximum mother candidates per bud.'
    'latentDim',32, 'Latent relation-token dimension.'
    'hiddenDim',64, 'Hidden dimension of each observation encoder.'
    'dropout',0.1, 'Training dropout.'
    'epochs',300, 'Training epochs (per ensemble member for the legacy objective).'
    'learningRate',0.001, 'AdamW learning rate.'
    'weightDecay',0.0001, 'AdamW weight decay.'
    'motherNullEarlyStoppingPatience',30, 'Stop the mother/NULL head after this many epochs without a meaningful validation improvement.'
    'motherNullEarlyStoppingMinDelta',0.0001, 'Minimum validation-NLL decrease that resets mother/NULL early-stopping patience.'
    'seedCount',5, 'Number of independently initialized ensemble members.'
    'device','cuda', 'cuda uses the GPU when available and otherwise falls back to CPU.'
    'targetAutoPrecision',0.98, 'OOF precision target for automatic lineage links.'
    'modelName','model_cell_latent_composite_v001', 'Immutable composite model-bundle folder name.'
    'transfer_learning',{{'builtin'}}, 'Start a new relation ensemble from formatted observations.'
    };
p = struct();
tips = cell(size(spec,1),1);
for i = 1:size(spec,1)
    p.(spec{i,1}) = spec{i,2};
    tips{i} = spec{i,3};
end
p.tip = {tips};
end
