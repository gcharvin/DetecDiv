function p = defaultExecutionParam()
% trackastra.utils.defaultExecutionParam  User-facing inference defaults.

p = struct();
p.imageChannelName = '';
p.instanceChannelName = '';
p.outputName = 'pred_trackastra_tracks';
p.modelSource = 'pretrained';
p.pretrainedModel = 'general_2d';
p.customModelPath = '';
p.checkpointPath = '';
p.trackingMode = 'greedy';
p.device = 'automatic';
p.batchSize = 0;
p.nWorkers = 0;
p.maxDistance = 0;
p.maxFrameGap = 1;
p.divisionIdentityMode = 'continuing_parent';
p.jointDecoder = false;
p.buddingProposal = false;
p.jointOutputFamilyName = 'pred_trackastra_joint_lineage';
p.jointOverwriteOutputFamily = true;
p.normalizeImages = true;
p.pythonExecutable = '';
end
