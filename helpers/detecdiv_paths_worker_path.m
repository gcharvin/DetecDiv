function pathOut = detecdiv_paths_worker_path(pathIn, payload)
% Resolve client -> canonical -> execution-host path using the job snapshot.
% OS drive aliases and client preferences must not replace worker policy.
    clientMappings = field(field(field(payload, 'run_request', struct()), ...
        'paths', struct()), 'path_mappings', []);
    workerMappings = field(field(payload, 'execution', struct()), 'worker_path_mappings', []);
    pathOut = apply(char(string(pathIn)), clientMappings, ...
        {'localRoot', 'local_root'}, {'remoteRoot', 'remote_root'});
    pathOut = apply(pathOut, workerMappings, {'source'}, {'target'});
    if ispc, pathOut = strrep(pathOut, '/', '\'); end
end

function out = apply(path, mappings, sourceKeys, targetKeys)
    out = path;
    if iscell(mappings), mappings = [mappings{:}]; end
    if ~isstruct(mappings), return; end
    normalized = regexprep(strrep(path, '\', '/'), '/+$', '');
    bestLen = -1;
    for i = 1:numel(mappings)
        source = root(mappings(i), sourceKeys);
        target = root(mappings(i), targetKeys);
        if isempty(source) || isempty(target), continue; end
        ignoreCase = ~isempty(regexp(source, '^[A-Za-z]:', 'once')) || startsWith(source, '//');
        matches = startsWith(normalized, source, 'IgnoreCase', ignoreCase) && ...
            (numel(normalized) == numel(source) || normalized(numel(source)+1) == '/');
        if matches && numel(source) > bestLen
            bestLen = numel(source);
            out = [target normalized(numel(source)+1:end)];
            if ~isempty(regexp(out, '^[A-Za-z]:$', 'once')), out = [out '/']; end
        end
    end
end

function value = root(mapping, names)
    value = '';
    for i = 1:numel(names)
        if isfield(mapping, names{i}) && ~isempty(mapping.(names{i}))
            value = regexprep(strrep(char(string(mapping.(names{i}))), '\', '/'), '/+$', '');
            return;
        end
    end
end

function value = field(s, key, fallback)
    value = fallback;
    if isstruct(s) && isfield(s, key), value = s.(key); end
end
