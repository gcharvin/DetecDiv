function p = defaultTrainingParam()
%CELLLATENTTRACKER.UTILS.DEFAULTTRAININGPARAM Training defaults.
spec = { ...
    'instanceChannelName','', 'Frame-local instance-mask channel.'
    'groundTruthChannelName','', 'Reviewed stable tracking-ID GT channel.'
    'brightfieldChannelName','', 'Optional brightfield image channel.'
    'validationFraction',0.2, 'ROI fraction held out for validation.'
    'frameIntervalMinutes',1, 'Physical minutes between frames.'
    'trainingDomain','mother_cells_cavity_budding', 'Audited acquisition domain.'
    'topK',8, 'Nearest predecessor candidates from frame t-1.'
    'minimumTruthOverlap',0.5, 'Minimum instance fraction assigned to one GT ID.'
    'minimumDetectionCoverage',0.8, 'Required fraction of instances mapped to GT.'
    'initialModelSource',{{'promoted_cross_domain','checkpoint','random','promoted_cross_domain'}}, 'Initial tracker weights.'
    'initialCheckpoint','', 'Optional custom tracking-edge checkpoint directory.'
    'epochs',30, 'Training epochs.'
    'learningRate',0.002, 'AdamW learning rate.'
    'weightDecay',0.0001, 'AdamW weight decay.'
    'hiddenDim',32, 'Latent hidden dimension.'
    'dropout',0, 'Training dropout.'
    'associationLossWeight',1, 'EDGE association loss weight.'
    'appearanceLossWeight',0.5, 'APPEAR action loss weight.'
    'endLossWeight',0.5, 'END action loss weight.'
    'successorLossWeight',0, ['Auxiliary grouped EDGE-versus-END successor ' ...
        'loss weight; zero disables it.']
    'device','automatic', 'automatic, cuda, or cpu.'
    'modelName','model_latent_tracker_cavity_budding_v001', 'Immutable EDGE/APPEAR/END model version folder.'
    };
p = struct(); tips = cell(size(spec,1),1);
for i = 1:size(spec,1)
    p.(spec{i,1}) = spec{i,2};
    tips{i} = spec{i,3};
end
p.tip = {tips};
end
