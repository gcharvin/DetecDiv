function p = defaultTrainingParam()
%CELLLATENTMODEL.UTILS.DEFAULTTRAININGPARAM ROI formatting/training defaults.
spec = { ...
    'trainingObjective',{{'relation_ensemble','continuous_lineage','relation_ensemble'}}, 'Train the legacy relation ensemble or a continuous physical-time lineage head.'
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
    'seedCount',5, 'Number of independently initialized ensemble members.'
    'device','cuda', 'cuda uses the GPU when available and otherwise falls back to CPU.'
    'targetAutoPrecision',0.98, 'OOF precision target for automatic lineage links.'
    'modelName','cell_latent_relation_v001', 'Trained checkpoint folder name.'
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
