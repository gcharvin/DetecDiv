function report = score_syncCellModelFrame(roiobj, channelName, frame)
%SCORE_SYNCCELLMODELFRAME Reconcile model references with one mask frame.

report = struct('status', 'no_model');
reports = score_syncCellModelFrames(roiobj, channelName, frame);
if ~isempty(reports), report = reports(1); end
end
