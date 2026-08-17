function name = annotationChannelName(classif)
% Return canonical semantic-mask GT while preserving existing legacy data.
name=classifierBinding.groundTruthChannelName(classif, ...
    'semantic_mask',{''},{'groundTruthChannelName'});
end
