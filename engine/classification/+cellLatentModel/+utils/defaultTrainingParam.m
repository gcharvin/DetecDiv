function p = defaultTrainingParam()
%CELLLATENTMODEL.UTILS.DEFAULTTRAININGPARAM ROI formatting/training defaults.
spec = { ...
    'trackChannelName','', 'Tracked indexed-mask channel; empty uses the classifier inputs.'
    'gfpChannelName','', 'Optional nuclear GFP channel used for axis and brightness observations.'
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
    'epochs',300, 'Training epochs per ensemble member.'
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
