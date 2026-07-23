function p = defaultExecutionParam()
%BUDMOTHERLINKER.UTILS.DEFAULTEXECUTIONPARAM Inference defaults.
p = struct();
p.trackChannelName = '';
p.inputFamily = '<auto>';
p.outputFamilyName = 'Bud mother boosted16';
p.frameEnd = -1;
p.minLifetime = 5;
p.maxBirthArea = 400;
p.minParentAge = 2;
p.maxParentCentroidDistance = 60;
p.maxParentContourDistance = 20;
p.maxCandidates = 4;
p.rankMarginThreshold = -1;
p.trackingLoadGuard = true;
p.maxNewTracksPerFrame = 7;
p.overwriteOutputFamily = true;
p.modelSource = 'builtin';
p.modelPath = '';
p.debug = false;
end
