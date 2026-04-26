function hub = detecdiv_hub_upsert_path_mapping(hub, remoteRoot, localRoot)
% detecdiv_hub_upsert_path_mapping  Add or update a server/local path mapping.

    if nargin < 1 || ~isstruct(hub)
        hub = detecdiv_hub_settings_get();
    end
    if nargin < 3
        error('detecdiv_hub_upsert_path_mapping:MissingArgs', 'remoteRoot and localRoot are required.');
    end

    remoteRoot = localNormalizeRoot(remoteRoot, '/');
    localRoot = localNormalizeRoot(localRoot, filesep);
    if ~isfield(hub, 'pathMappings') || isempty(hub.pathMappings)
        hub.pathMappings = struct('remoteRoot', {}, 'localRoot', {});
    end

    idx = [];
    for i = 1:numel(hub.pathMappings)
        if strcmp(localNormalizeRoot(hub.pathMappings(i).remoteRoot, '/'), remoteRoot)
            idx = i;
            break;
        end
    end

    if isempty(idx)
        hub.pathMappings(end+1).remoteRoot = remoteRoot;
        hub.pathMappings(end).localRoot = localRoot;
    else
        hub.pathMappings(idx).localRoot = localRoot;
    end
end

function out = localNormalizeRoot(value, sep)
    out = char(string(value));
    if isempty(out)
        return;
    end
    out = strrep(out, '\', sep);
    out = strrep(out, '/', sep);
    while numel(out) > 1 && endsWith(out, sep)
        out(end) = [];
    end
end
