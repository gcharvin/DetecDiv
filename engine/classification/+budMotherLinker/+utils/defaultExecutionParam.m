function p = defaultExecutionParam()
%BUDMOTHERLINKER.UTILS.DEFAULTEXECUTIONPARAM Inference defaults.
p = struct();
p.trackChannelName = '';
p.inputFamily = '<auto>';
p.outputFamilyName = 'pred_bud_mother_lineage';
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
p.globalSolver = true;
p.motherRefractoryFrames = 8;
p.youngMotherFrames = 8;
p.solverBeamSize = 128;
p.reviewGlobalReassignments = true;
p.overwriteOutputFamily = true;
p.modelSource = 'builtin';
p.modelPath = '';
p.debug = false;
end
