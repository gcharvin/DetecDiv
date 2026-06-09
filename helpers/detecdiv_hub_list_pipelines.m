function pipelines = detecdiv_hub_list_pipelines(hubSettings, varargin)
% detecdiv_hub_list_pipelines  Fetch pipeline registry entries and optionally observed pipelines.

    if nargin < 1 || isempty(hubSettings)
        hubSettings = detecdiv_hub_settings_get();
    end

    ip = inputParser;
    ip.addParameter('Search', '', @(x)ischar(x) || isstring(x));
    ip.addParameter('RuntimeKind', '', @(x)ischar(x) || isstring(x));
    ip.addParameter('IncludeObserved', true, @(x)islogical(x) || isnumeric(x));
    ip.parse(varargin{:});
    opts = ip.Results;

    params = strings(0, 1);
    search = strtrim(char(string(opts.Search)));
    runtimeKind = strtrim(char(string(opts.RuntimeKind)));
    if ~isempty(search)
        params(end + 1, 1) = "search=" + string(urlencode(search)); %#ok<AGROW>
    end
    if ~isempty(runtimeKind)
        params(end + 1, 1) = "runtime_kind=" + string(urlencode(runtimeKind)); %#ok<AGROW>
    end

    query = '';
    if ~isempty(params)
        query = ['?' strjoin(cellstr(params), '&')];
    end

    registry = detecdiv_hub_request_json(['/pipelines' query], hubSettings);
    registry = localNormalizePipelineList(registry, 'registry');

    observed = struct([]);
    if logical(opts.IncludeObserved)
        observed = detecdiv_hub_request_json(['/pipelines/observed' query], hubSettings);
        observed = localNormalizePipelineList(observed, 'observed');
    end

    if isempty(registry)
        pipelines = observed;
    elseif isempty(observed)
        pipelines = registry;
    else
        pipelines = [registry(:); observed(:)];
    end
end

function items = localNormalizePipelineList(items, defaultSource)
    if isempty(items)
        items = repmat(localEmptyPipeline(), 0, 1);
        return;
    end
    if iscell(items)
        items = [items{:}];
    end

    normalized = repmat(localEmptyPipeline(), numel(items), 1);
    for i = 1:numel(items)
        src = defaultSource;
        if isfield(items(i), 'source') && ~isempty(items(i).source)
            src = char(string(items(i).source));
        end
        normalized(i).id = localStructText(items(i), 'id');
        normalized(i).identity = localStructText(items(i), 'identity');
        normalized(i).display_name = localStructText(items(i), 'display_name');
        normalized(i).pipeline_key = localStructText(items(i), 'pipeline_key');
        normalized(i).version = localStructText(items(i), 'version');
        normalized(i).runtime_kind = localStructText(items(i), 'runtime_kind');
        normalized(i).source = src;
        normalized(i).metadata_json = localStructStruct(items(i), 'metadata_json');
        normalized(i).project_count = localStructNumeric(items(i), 'project_count');
        normalized(i).latest_run_at = localStructText(items(i), 'latest_run_at');
    end
    items = normalized;
end

function item = localEmptyPipeline()
    item = struct( ...
        'id', '', ...
        'identity', '', ...
        'display_name', '', ...
        'pipeline_key', '', ...
        'version', '', ...
        'runtime_kind', '', ...
        'source', '', ...
        'metadata_json', struct(), ...
        'project_count', 0, ...
        'latest_run_at', '');
end

function out = localStructText(s, fieldName)
    out = '';
    if isstruct(s) && isfield(s, fieldName) && ~isempty(s.(fieldName))
        out = char(string(s.(fieldName)));
    end
end

function out = localStructNumeric(s, fieldName)
    out = 0;
    if isstruct(s) && isfield(s, fieldName) && ~isempty(s.(fieldName))
        out = double(s.(fieldName));
    end
end

function out = localStructStruct(s, fieldName)
    out = struct();
    if isstruct(s) && isfield(s, fieldName) && isstruct(s.(fieldName))
        out = s.(fieldName);
    end
end
