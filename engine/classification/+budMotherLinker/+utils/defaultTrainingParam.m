function p = defaultTrainingParam()
%BUDMOTHERLINKER.UTILS.DEFAULTTRAININGPARAM Dataset and training defaults.

spec = { ...
    'trackChannelName','', 'Tracked indexed-mask channel; empty uses the first classifier input.'
    'groundTruthFamily','<auto>', 'Cell-model family containing reviewed mother-bud relations.'
    'groundTruthSource','', 'Optional reviewed .sqlite database or accepted_lineage.csv; empty uses the imported ROI cell model.'
    'validationFraction',0.2, 'Fraction of training ROIs held out when no validation split is defined.'
    'minLifetime',5, 'Minimum bud lifetime in frames.'
    'maxBirthArea',400, 'Maximum area of a bud at first appearance.'
    'minParentAge',2, 'Minimum candidate-mother age in frames.'
    'maxParentCentroidDistance',60, 'Maximum centroid distance in pixels.'
    'maxParentContourDistance',20, 'Maximum contour distance in pixels.'
    'maxCandidates',4, 'Maximum candidate mothers retained per event.'
    'maxIter',200, 'Number of sklearn HistGradientBoosting iterations.'
    'learningRate',0.05, 'HistGradientBoosting learning rate.'
    'maxLeafNodes',15, 'Maximum leaves in each HistGradientBoosting tree.'
    'minSamplesLeaf',20, 'Minimum observations in a HistGradientBoosting leaf.'
    'l2Regularization',0.01, 'L2 regularization applied to leaf weights.'
    'randomState',23, 'Deterministic sklearn random seed.'
    'targetAutoPrecision',0.95, 'Target precision used to calibrate the automatic-link margin.'
    'modelName','model_bud_mother_linker_v001', 'Versioned boosted-tree mother-linker artifact folder.'
    'transfer_learning',{{'builtin'}}, 'Initialize a new boosted-tree ranker from formatted data.'
    };
p = struct();
tips = cell(size(spec,1),1);
for i = 1:size(spec,1)
    p.(spec{i,1}) = spec{i,2};
    tips{i} = spec{i,3};
end
p.tip = {tips};
end
