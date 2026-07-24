function p = defaultExecutionParam()
%CELLLATENTMODEL.UTILS.DEFAULTEXECUTIONPARAM Inference defaults.
p = struct();
p.trackChannelName = '';
p.gfpChannelName = '';
p.inputFamily = '<auto>';
p.outputFamilyName = 'Cell latent lineage GFP v001';
p.frameEnd = -1;
p.minLifetime = 5;
p.maxBirthArea = 400;
p.minParentAge = 2;
p.maxParentCentroidDistance = 60;
p.maxParentContourDistance = 20;
p.maxCandidates = 4;
p.overwriteOutputFamily = true;
p.modelSource = 'builtin';
p.modelPath = '';
p.device = 'auto';
p.debug = false;
end
