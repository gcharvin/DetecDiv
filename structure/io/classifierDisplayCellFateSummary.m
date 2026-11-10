function [summary,fig]=classifierDisplayCellFateSummary(classif,roiIndices,varargin)
%CLASSIFIERDISPLAYCELLFATESUMMARY Use saved predictions; never train or infer.
summary=lstm_timeseries.cellFateSummary(classif,'Rois',roiIndices,varargin{:});
fig=lstm_timeseries.displayCellFateSummary(summary);
end
