function [mappedPath, method] = detecdiv_hub_apply_path_mapping(pathIn, hubSettings)
% detecdiv_hub_apply_path_mapping  Remap a server path to a local client path.

    mappedPath = '';
    method = '';

    if nargin < 2 || isempty(hubSettings)
        hubSettings = detecdiv_hub_settings_get();
    end

    pathIn = char(string(pathIn));
    if isempty(pathIn)
        return;
    end

    entries = localCollectEntries(hubSettings);
    if isempty(entries)
        return;
    end

    normInput = localNormalizePath(pathIn);
    bestLen = -1;
    bestPath = '';
    for i = 1:numel(entries)
        remotePrefix = localNormalizePath(entries(i).remotePrefix);
        if isempty(remotePrefix)
            continue;
        end
        if startsWith(normInput, remotePrefix, 'IgnoreCase', ispc)
            suffix = extractAfter(normInput, strlength(remotePrefix));
            suffix = char(suffix);
            if ~isempty(suffix) && any(suffix(1) == ['/' '\'])
                suffix = suffix(2:end);
            end
            candidate = fullfile(entries(i).localPrefix, localSuffixToFilesep(suffix));
            if ispc
                candidate = strrep(candidate, '/', '\');
            else
                candidate = strrep(candidate, '\', '/');
            end
            if strlength(string(remotePrefix)) > bestLen
                bestLen = strlength(string(remotePrefix));
                bestPath = candidate;
                method = entries(i).method;
            end
        end
    end

    mappedPath = bestPath;
end

function entries = localCollectEntries(hubSettings)
    entries = struct('remotePrefix', {}, 'localPrefix', {}, 'method', {});

    if isfield(hubSettings, 'pathPrefixMap') && isstruct(hubSettings.pathPrefixMap)
        names = fieldnames(hubSettings.pathPrefixMap);
        for i = 1:numel(names)
            item = hubSettings.pathPrefixMap.(names{i});
            if ~isstruct(item)
                continue;
            end
            if ~isfield(item, 'remotePrefix') || ~isfield(item, 'localPrefix')
                continue;
            end
            entries(end+1) = struct( ... %#ok<AGROW>
                'remotePrefix', char(string(item.remotePrefix)), ...
                'localPrefix', char(string(item.localPrefix)), ...
                'method', ['pathPrefixMap:' names{i}]);
        end
    end
end

function out = localNormalizePath(pathIn)
    out = char(string(pathIn));
    if isempty(out)
        return;
    end
    out = strrep(out, '\', '/');
    out = regexprep(out, '/+$', '');
    if ispc
        out = lower(out);
    end
end

function out = localSuffixToFilesep(pathIn)
    out = strrep(pathIn, '/', filesep);
    out = strrep(out, '\', filesep);
end
