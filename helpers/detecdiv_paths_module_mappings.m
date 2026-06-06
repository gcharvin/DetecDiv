function mappings = detecdiv_paths_module_mappings(ctx)
% detecdiv_paths_module_mappings  Central local<->server path mappings.
%
% Mappings are ordered by specificity at use time. Sources, in priority order:
% ctx.hub.pathMappings, ctx.run.paths.path_mappings, ctx.hub defaults,
% persisted Hub settings, and deployment defaults.

    if nargin < 1 || isempty(ctx) || ~isstruct(ctx)
        ctx = struct();
    end

    mappings = struct('remoteRoot', {}, 'localRoot', {});
    mappings = appendMappings(mappings, nestedField(ctx, {'hub','pathMappings'}, []));
    mappings = appendMappings(mappings, nestedField(ctx, {'run','paths','path_mappings'}, []));

    localRoot = nestedField(ctx, {'hub','defaultLocalProjectRoot'}, '');
    remoteRoot = nestedField(ctx, {'hub','defaultRemoteProjectRoot'}, '');
    mappings = appendMapping(mappings, localRoot, remoteRoot);

    try
        if exist('detecdiv_hub_settings_get', 'file') == 2
            hub = detecdiv_hub_settings_get();
            mappings = appendMappings(mappings, nestedField(hub, {'pathMappings'}, []));
            mappings = appendMapping(mappings, ...
                nestedField(hub, {'defaultLocalProjectRoot'}, ''), ...
                nestedField(hub, {'defaultRemoteProjectRoot'}, ''));
        end
    catch
    end

    mappings = appendDeploymentDefaultMappings(mappings);
    mappings = uniqueMappings(mappings);
end

function mappings = appendDeploymentDefaultMappings(mappings)
    mappings = appendMapping(mappings, 'X:\', '/data');
end

function mappings = appendMappings(mappings, extra)
    if isempty(extra) || ~isstruct(extra)
        return;
    end
    for i = 1:numel(extra)
        if isfield(extra(i), 'localRoot') && isfield(extra(i), 'remoteRoot')
            mappings = appendMapping(mappings, extra(i).localRoot, extra(i).remoteRoot);
        end
    end
end

function mappings = appendMapping(mappings, localRoot, remoteRoot)
    localRoot = char(string(localRoot));
    remoteRoot = char(string(remoteRoot));
    if isempty(localRoot) || isempty(remoteRoot)
        return;
    end
    mappings(end+1).localRoot = localRoot; %#ok<AGROW>
    mappings(end).remoteRoot = remoteRoot;
end

function mappings = uniqueMappings(mappings)
    if isempty(mappings)
        return;
    end
    keep = true(1, numel(mappings));
    seen = {};
    for i = 1:numel(mappings)
        localRoot = normalizeLocalRoot(mappings(i).localRoot);
        remoteRoot = normalizeRemoteRoot(mappings(i).remoteRoot);
        key = [lower(localRoot) '|' lower(remoteRoot)];
        if isempty(localRoot) || isempty(remoteRoot) || any(strcmp(seen, key))
            keep(i) = false;
        else
            seen{end+1} = key; %#ok<AGROW>
        end
    end
    mappings = mappings(keep);
end

function value = nestedField(S, pathParts, defaultValue)
    value = defaultValue;
    cur = S;
    for i = 1:numel(pathParts)
        if ~isstruct(cur) || ~isfield(cur, pathParts{i})
            return;
        end
        cur = cur.(pathParts{i});
    end
    if ~isempty(cur)
        value = cur;
    end
end

function out = normalizeLocalRoot(value)
    out = regexprep(strrep(char(string(value)), '/', '\'), '[\\\/]+$', '');
end

function out = normalizeRemoteRoot(value)
    out = regexprep(strrep(char(string(value)), '\', '/'), '[\/]+$', '');
end
