function [obj, report] = detecdiv_hub_relink_raw_project(obj, hub, detail)
% Resolve missing raw pointers using this project's linked Hub datasets.
% Changes are in memory only. Existing paths and ambiguous matches are kept.
    report = struct('changedCount', 0, 'unresolved', {{}}, 'message', '');
    if nargin < 2 || isempty(hub), hub = detecdiv_hub_settings_get(); end
    id = '';
    if nargin < 3
        meta = obj.runProfiles;
        if ~isfield(meta, 'hub'), return; end
        for key = {'hub_project_id','project_id'}
            if isfield(meta.hub, key{1}) && ~isempty(meta.hub.(key{1}))
                id = char(string(meta.hub.(key{1}))); break;
            end
        end
        if isempty(id), return; end
    end
    seen = containers.Map('KeyType', 'char', 'ValueType', 'logical');
    missing = false;
    for i = 1:numel(obj.fov)
        detecdiv_paths_map_fov_sources(obj.fov(i), @checkMissing);
    end
    if ~missing, return; end
    try
        if nargin < 3
            hub.timeout = min(hub.timeout, 5);
            hub.timeoutSeconds = hub.timeout;
            detail = detecdiv_hub_get_project(id, hub);
        end
        roots = struct('remote', {}, 'local', {}, 'label', {}, 'preferred', {});
        if ~isfield(detail, 'raw_datasets'), return; end
        for i = 1:numel(detail.raw_datasets)
            raw = detail.raw_datasets(i);
            if ~isfield(raw, 'locations')
                raw = detecdiv_hub_request_json(['/raw-datasets/' char(string(raw.id))], hub);
            end
            for j = 1:numel(raw.locations)
                loc = raw.locations(j);
                remote = strrep(fullfile(loc.storage_root.path_prefix, loc.relative_path), '\', '/');
                if isfield(loc, 'absolute_path') && ~isempty(loc.absolute_path)
                    remote = char(string(loc.absolute_path));
                end
                target = detecdiv_paths_prefer_local(remote, hub);
                if isfield(hub, 'storageRootMap') && isfield(hub.storageRootMap, loc.storage_root.name)
                    candidate = fullfile(hub.storageRootMap.(loc.storage_root.name), loc.relative_path);
                    if isfolder(candidate), target = candidate; end
                end
                roots(end+1) = struct('remote', normPath(remote), ...
                    'local', target, 'label', char(string(raw.acquisition_label)), ...
                    'preferred', isfield(loc, 'is_preferred') && logical(loc.is_preferred)); %#ok<AGROW>
            end
        end
        cache = containers.Map('KeyType', 'char', 'ValueType', 'char');
        for i = 1:numel(obj.fov)
            [~, count] = detecdiv_paths_map_fov_sources(obj.fov(i), @resolve);
            report.changedCount = report.changedCount + count;
        end
        report.unresolved = unique(report.unresolved, 'stable');
    catch ME
        % Offline/private/missing catalog entries must never block project load.
        report.message = ME.message;
    end
    if ~isfield(obj.runProfiles, 'hub'), obj.runProfiles.hub = struct(); end
    obj.runProfiles.hub.raw_path_resolution = report;
    if report.changedCount > 0
        fprintf('[Hub raw paths] Resolved %d raw path references in memory.\n', report.changedCount);
    end
    if ~isempty(report.unresolved)
        fprintf('[Hub raw paths] %d source path(s) remain missing or ambiguous in the catalog.\n', ...
            numel(report.unresolved));
    elseif ~isempty(report.message)
        fprintf('[Hub raw paths] Catalog lookup unavailable: %s\n', report.message);
    end

    function value = checkMissing(value)
        if isKey(seen, value), return; end
        seen(value) = true;
        if ~isfolder(value) && ~isfile(value), missing = true; end
    end

    function value = resolve(value)
        if isKey(cache, value), value = cache(value); return; end
        before = value;
        if isfolder(value) || isfile(value), cache(before) = value; return; end
        value = detecdiv_paths_prefer_local(value, hub);
        if ~isfolder(value) && ~isfile(value)
            matches = {};
            preferredMatches = {};
            source = normPath(before);
            for a = 1:numel(roots)
                suffixes = {};
                % Historical locations retain the exact original dataset root.
                for b = 1:numel(roots)
                    if ~strcmp(roots(a).label, roots(b).label), continue; end
                    prefix = [roots(b).remote '/'];
                    if strcmp(source, roots(b).remote)
                        suffixes{end+1} = ''; %#ok<AGROW>
                    elseif startsWith(source, prefix)
                        suffixes{end+1} = source(numel(prefix)+1:end); %#ok<AGROW>
                    end
                end
                % A moved dataset can have only its new location in the Hub.
                % Match its exact acquisition folder component, never PosN alone.
                token = ['/' roots(a).label '/'];
                hits = strfind([source '/'], token);
                if numel(hits) == 1
                    suffixes{end+1} = source(min(numel(source)+1, hits+numel(token)):end); %#ok<AGROW>
                end
                for b = 1:numel(suffixes)
                    suffix = suffixes{b};
                    if any(strcmp(strsplit(suffix, '/'), '..')), continue; end
                    candidate = fullfile(roots(a).local, suffix);
                    if isfolder(candidate) || isfile(candidate)
                        matches{end+1} = candidate; %#ok<AGROW>
                        if roots(a).preferred, preferredMatches{end+1} = candidate; end %#ok<AGROW>
                    end
                end
            end
            if ~isempty(preferredMatches), matches = preferredMatches; end
            matches = unique(matches, 'stable');
            if numel(matches) == 1, value = matches{1}; else, value = before; end
        end
        if ~isfolder(value) && ~isfile(value)
            report.unresolved{end+1} = before;
        end
        cache(before) = value;
    end
end

function value = normPath(value)
    value = regexprep(strrep(char(string(value)), '\', '/'), '/+$', '');
end
