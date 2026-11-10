function exportCellFateSummary(summary,prefix)
%EXPORTCELLFATESUMMARY Preserve ROI identities, observation bounds and policy.
folder=fileparts(prefix);if ~isempty(folder)&&~isfolder(folder),mkdir(folder);end
writetable(summary.rois,[prefix '_fate_rois.csv']);writetable(summary.counts,[prefix '_fate_counts.csv']);
writetable(summary.classes,[prefix '_fate_classes.csv']);writematrix(summary.confusion,[prefix '_fate_confusion.csv']);
save([prefix '_fate_summary.mat'],'summary');
end
