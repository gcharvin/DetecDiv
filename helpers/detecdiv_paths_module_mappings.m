function mappings = detecdiv_paths_module_mappings(ctx)
% detecdiv_paths_module_mappings  Central local<->server path mappings.
%
% Mappings are ordered by specificity at use time. Sources, in priority order:
% worker-host mappings, ctx.hub preferred root, explicit mappings, run
% mappings, persisted Hub settings, and deployment defaults. Windows aliases
% share the same identity.

    if nargin < 1 || isempty(ctx) || ~isstruct(ctx)
        ctx = struct();
    end

    mappings = struct('remoteRoot', {}, 'localRoot', {});
    % A Hub worker's mappings describe this execution host and take priority
    % over drive letters recorded by the submitting client.
    mappings = appendWorkerMappings(mappings, ...
        nestedField(ctx, {'execution','worker_path_mappings'}, []));
    localRoot = nestedField(ctx, {'hub','defaultLocalProjectRoot'}, '');
    remoteRoot = nestedField(ctx, {'hub','defaultRemoteProjectRoot'}, '');
    mappings = appendMapping(mappings, localRoot, remoteRoot);
    mappings = appendMappings(mappings, nestedField(ctx, {'hub','pathMappings'}, []));
    mappings = appendPrefixMappings(mappings, nestedField(ctx, {'hub','pathPrefixMap'}, struct()));
    mappings = detecdiv_paths_expand_windows_aliases(mappings);
    % A recorded run may come from another workstation. Its drive letters
    % must not acquire aliases from this workstation's SMB connections.
    mappings = appendMappings(mappings, nestedField(ctx, {'run','paths','path_mappings'}, []));

    try
        if exist('detecdiv_hub_settings_get', 'file') == 2
            hub = detecdiv_hub_settings_get();
            settingsMappings = struct('remoteRoot', {}, 'localRoot', {});
            settingsMappings = appendMapping(settingsMappings, ...
                nestedField(hub, {'defaultLocalProjectRoot'}, ''), ...
                nestedField(hub, {'defaultRemoteProjectRoot'}, ''));
            settingsMappings = appendMappings(settingsMappings, nestedField(hub, {'pathMappings'}, []));
            settingsMappings = appendPrefixMappings(settingsMappings, nestedField(hub, {'pathPrefixMap'}, struct()));
            mappings = appendMappings(mappings, detecdiv_paths_expand_windows_aliases(settingsMappings));
        end
    catch
    end

    % The legacy X: fallback is not an explicit storage identity. Do not
    % infer new UNC aliases from it when X: may name another share here.
    mappings = appendDeploymentDefaultMappings(mappings);
    mappings = uniqueMappings(mappings);
end

function mappings = appendWorkerMappings(mappings, workerMappings)
    if isempty(workerMappings) || ~isstruct(workerMappings)
        return;
    end
    for i = 1:numel(workerMappings)
        item = workerMappings(i);
        if isfield(item, 'source') && isfield(item, 'target')
            mappings = appendMapping(mappings, item.target, item.source);
        end
    end
end

function mappings = appendPrefixMappings(mappings, prefixMap)
    if ~isstruct(prefixMap), return; end
    names = fieldnames(prefixMap);
    for i = 1:numel(names)
        item = prefixMap.(names{i});
        if isstruct(item) && isfield(item, 'localPrefix') && isfield(item, 'remotePrefix')
            mappings = appendMapping(mappings, item.localPrefix, item.remotePrefix);
        end
    end
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
    if isempty(localRoot) || isempty(remoteRoot) || ~looksLikeServerRoot(remoteRoot)
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
        if isWindowsRoot(mappings(i).localRoot), localRoot = lower(localRoot); end
        if isWindowsRoot(remoteRoot), remoteRoot = lower(remoteRoot); end
        key = [localRoot '|' remoteRoot];
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

function tf = isWindowsRoot(path)
    path = char(string(path));
    tf = ~isempty(regexp(path, '^[A-Za-z]:', 'once')) || startsWith(path, '\\') || startsWith(path, '//');
end

function out = normalizeLocalRoot(value)
    out = regexprep(strrep(char(string(value)), '/', '\'), '[\\\/]+$', '');
end

function out = normalizeRemoteRoot(value)
    out = regexprep(strrep(char(string(value)), '\', '/'), '[\/]+$', '');
end

function tf = looksLikeServerRoot(value)
    txt = regexprep(strrep(char(string(value)), '\', '/'), '[\/]+$', '');
    tf = startsWith(txt, '/');
end
