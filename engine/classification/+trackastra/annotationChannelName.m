function channelName = annotationChannelName(classif)
%TRACKASTRA.ANNOTATIONCHANNELNAME Reviewed stable-track GT channel.
channelName=classifierBinding.groundTruthChannelName( ...
    classif,'stable_tracks','tracklet',{'groundTruthChannelName'});
end
