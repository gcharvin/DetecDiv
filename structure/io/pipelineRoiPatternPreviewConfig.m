function config = pipelineRoiPatternPreviewConfig(params)
% Only settings that determine pattern detections, independent of UI state.
config = struct();
keys = {'pattern','patternList','activePatternIndex','referenceFrame', ...
    'threshold','channel','channelIndex'};
for i = 1:numel(keys)
    if isfield(params, keys{i})
        config.(keys{i}) = params.(keys{i});
    end
end
end
