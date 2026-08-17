function channelName = annotationChannelName(classif)
%CELLLATENTTRACKER.ANNOTATIONCHANNELNAME Reviewed stable-ID GT channel.
channelName=classifierBinding.groundTruthChannelName( ...
    classif,'stable_tracks','tracklet',{'groundTruthChannelName'});
end
