function p = defaultExecutionParam()
% trackastra.utils.defaultExecutionParam  User-facing inference defaults.

p = struct();
p.imageChannelName = '';
p.instanceChannelName = '';
p.outputName = 'trackastra';
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
p.normalizeImages = true;
p.pythonExecutable = '';
end
