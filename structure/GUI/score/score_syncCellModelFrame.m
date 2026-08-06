function report = score_syncCellModelFrame(roiobj, channelName, frame, varargin)
%SCORE_SYNCCELLMODELFRAME Reconcile model references with one mask frame.

report = struct('status', 'no_model');
reports = score_syncCellModelFrames(roiobj, channelName, frame, varargin{:});
if ~isempty(reports), report = reports(1); end
end
