function out = mergePipelineRuntimeConfig(baseConfig, overrideConfig)
% mergePipelineRuntimeConfig  Recursively merge runtime config structs.

    if nargin < 1 || isempty(baseConfig)
        baseConfig = struct();
    end
    if nargin < 2 || isempty(overrideConfig)
        out = baseConfig;
        return;
    end

    if ~isstruct(baseConfig) || ~isstruct(overrideConfig)
        out = overrideConfig;
        return;
    end

    out = baseConfig;
    overrideFields = fieldnames(overrideConfig);
    for i = 1:numel(overrideFields)
        name = overrideFields{i};
        value = overrideConfig.(name);
        if isempty(value)
            continue;
        end
        if isfield(out, name) && isstruct(out.(name)) && isstruct(value)
            out.(name) = mergePipelineRuntimeConfig(out.(name), value);
        else
            out.(name) = value;
        end
    end
end
