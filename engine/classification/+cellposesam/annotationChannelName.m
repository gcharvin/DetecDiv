function name = annotationChannelName(classif)
%CELLPOSESAM.ANNOTATIONCHANNELNAME Reviewed instance-mask GT channel.
name=classifierBinding.groundTruthChannelName( ...
    classif,'instances','cell',{'groundTruthChannelName'});
end
