function obj = detecdiv_paths_localize_project(obj, hub)
% Normalize legacy MAT raw pointers to the current client's storage view.
% JSON imports normalize the same fields while reconstructing the FOVs.
    if nargin < 2, hub = detecdiv_hub_settings_get(); end
    cache = containers.Map('KeyType', 'char', 'ValueType', 'char');
    for i = 1:numel(obj.fov)
        detecdiv_paths_map_fov_sources(obj.fov(i), @localize);
    end
    if isfield(obj.processing, 'pipelineRun')
        for i = 1:numel(obj.processing.pipelineRun)
            detecdiv_paths_localize_run(obj.processing.pipelineRun(i), hub);
        end
    end

    function value = localize(value)
        if iscell(value)
            for j = 1:numel(value), value{j} = localize(value{j}); end
        elseif ischar(value) || (isstring(value) && isscalar(value))
            key = char(string(value));
            if isKey(cache, key)
                value = cache(key);
            else
                value = detecdiv_paths_prefer_local(key, hub);
                cache(key) = value;
            end
        end
    end
end
