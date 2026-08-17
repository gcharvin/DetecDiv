function p = defaultExecutionParam()
%CELLLATENTTRACKER.UTILS.DEFAULTEXECUTIONPARAM Inference defaults.
p = struct();
p.imageChannelName = '';
p.instanceChannelName = '';
p.outputName = 'pred_latent_tracker_tracks';
p.checkpointDir = '';
p.topK = 8;
p.frameIntervalMinutes = 1;
p.device = 'automatic';
p.solverTimeLimitSeconds = 30;
p.debug = false;
end
