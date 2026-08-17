function name = annotationChannelName(classif)
%SAM31.ANNOTATIONCHANNELNAME Canonical GT name with legacy preservation.
name=classifierBinding.groundTruthChannelName(classif, ...
    'stable_tracks','cell',{'groundTruthChannelName'});
end
