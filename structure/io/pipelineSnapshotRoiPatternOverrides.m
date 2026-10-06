function overrides = pipelineSnapshotRoiPatternOverrides(nodes, overrides)
% Pin the selected pattern in the job, even if its shared template changes.
for i = 1:numel(nodes)
    if ~any(strcmpi(nodes(i).type, {'roiPattern','roiIdentify'}))
        continue;
    end
    key = matlab.lang.makeValidName(nodes(i).id);
    params = nodes(i).params;
    if isfield(overrides, key) && isstruct(overrides.(key))
        fields = fieldnames(overrides.(key));
        for j = 1:numel(fields)
            params.(fields{j}) = overrides.(key).(fields{j});
        end
    end
    pinned = pipelineRoiPatternPreviewConfig(params);
    if isfield(params,'patternPreset')
        pinned.patternPreset = params.patternPreset;
    end
    if ~isfield(overrides, key)
        overrides.(key) = struct();
    end
    fields = fieldnames(pinned);
    for j = 1:numel(fields)
        overrides.(key).(fields{j}) = pinned.(fields{j});
    end
end
end
