function [mappedPath, mapped, status] = detecdiv_paths_map_module_path(pathIn, ctx, direction)
% detecdiv_paths_map_module_path  Map module paths between local and server roots.
%
% direction:
%   'server' maps local/client paths to server-visible paths.
%   'local'  maps server paths to local/client mirror paths.

    if nargin < 2 || isempty(ctx) || ~isstruct(ctx)
        ctx = struct();
    end
    if nargin < 3 || isempty(direction)
        direction = 'server';
    end

    mappedPath = char(string(pathIn));
    mapped = false;
    status = 'unmapped';
    if isempty(mappedPath)
        status = 'empty';
        return;
    end

    mappings = detecdiv_paths_module_mappings(ctx);
    if isempty(mappings)
        return;
    end

    switch lower(char(string(direction)))
        case {'server','remote'}
            [mappedPath, mapped] = mapLocalToRemote(mappedPath, mappings);
            if mapped, status = 'mapped_to_server'; end
        case {'local','client'}
            [mappedPath, mapped] = mapRemoteToLocal(mappedPath, mappings);
            if mapped, status = 'mapped_to_local'; end
        otherwise
            error('detecdiv_paths_map_module_path:BadDirection', ...
                'Unknown mapping direction: %s.', char(string(direction)));
    end
end

function [out, mapped] = mapLocalToRemote(pathIn, mappings)
    out = char(string(pathIn));
    mapped = false;
    localComparable = regexprep(strrep(out, '/', '\'), '[\\\/]+$', '');
    bestLen = 0;
    bestRemote = '';
    bestSuffix = '';
    for i = 1:numel(mappings)
        localRoot = normalizeLocalRoot(mappings(i).localRoot);
        remoteRoot = normalizeRemoteRoot(mappings(i).remoteRoot);
        if isempty(localRoot) || isempty(remoteRoot)
            continue;
        end
        if startsWith(lower(localComparable), lower(localRoot)) && ...
                (numel(localComparable) == numel(localRoot) || any(localComparable(numel(localRoot)+1) == ['\' '/']))
            if numel(localRoot) > bestLen
                bestLen = numel(localRoot);
                bestRemote = remoteRoot;
                bestSuffix = localComparable(numel(localRoot)+1:end);
            end
        end
    end
    if bestLen > 0
        out = [bestRemote strrep(bestSuffix, '\', '/')];
        mapped = true;
    end
end

function [out, mapped] = mapRemoteToLocal(pathIn, mappings)
    out = char(string(pathIn));
    mapped = false;
    remoteComparable = regexprep(strrep(out, '\', '/'), '[\/]+$', '');
    bestLen = 0;
    bestLocal = '';
    bestSuffix = '';
    for i = 1:numel(mappings)
        localRoot = normalizeLocalRoot(mappings(i).localRoot);
        remoteRoot = normalizeRemoteRoot(mappings(i).remoteRoot);
        if isempty(localRoot) || isempty(remoteRoot)
            continue;
        end
        if startsWith(lower(remoteComparable), lower(remoteRoot)) && ...
                (numel(remoteComparable) == numel(remoteRoot) || remoteComparable(numel(remoteRoot)+1) == '/')
            if numel(remoteRoot) > bestLen
                bestLen = numel(remoteRoot);
                bestLocal = localRoot;
                bestSuffix = remoteComparable(numel(remoteRoot)+1:end);
            end
        end
    end
    if bestLen > 0
        out = [bestLocal strrep(bestSuffix, '/', filesep)];
        mapped = true;
    end
end

function out = normalizeLocalRoot(value)
    out = regexprep(strrep(char(string(value)), '/', '\'), '[\\\/]+$', '');
end

function out = normalizeRemoteRoot(value)
    out = regexprep(strrep(char(string(value)), '\', '/'), '[\/]+$', '');
end
