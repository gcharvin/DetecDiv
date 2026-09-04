function [out, report] = link(source, family, metrics, varargin)
%CELLMETRICS.LINK Join computeMetrics vectors to cell-model object IDs.
%   T = cellMetrics.link(ROI, FAMILY, GROUPID) resolves a computeMetrics
%   dataseries stored on ROI and returns one row per cell-model instance.
%   T = cellMetrics.link(MODEL, FAMILY, DATASERIES) is the pure in-memory
%   form. The join key is (absolute frame, mask_label); object_id is never
%   inferred from row order.

p = inputParser;
p.addParameter('MaskIndexVariable', '', @(x)ischar(x)||isstring(x));
p.addParameter('MaskChannel', '', @(x)ischar(x)||isstring(x));
p.addParameter('Frames', [], @isnumeric);
p.addParameter('AllowProviderMismatch', false, @(x)islogical(x)&&isscalar(x));
p.parse(varargin{:});

[model, ds] = resolveInputs(source, metrics);
model = cellModel.normalize(model);
[familyIndex, familyId] = cellModel.familyIndex(model, family);
if isempty(familyIndex)
    error('cellMetrics:UnknownFamily', 'Cell-model family "%s" was not found.', char(string(family)));
end
provider = char(string(model.families.mask_provider{familyIndex}));
[tbl, userData, groupId] = seriesParts(ds);
frames = sourceFrames(tbl, userData);
if ~isempty(p.Results.Frames)
    selected = unique(round(double(p.Results.Frames(:))), 'stable');
else
    selected = [];
end

[indexVariable, binding] = resolveBinding(tbl, userData, provider, ...
    char(string(p.Results.MaskIndexVariable)), char(string(p.Results.MaskChannel)));
if ~p.Results.AllowProviderMismatch && ~isempty(binding.mask_channel) && ...
        ~strcmpi(binding.mask_channel, provider)
    error('cellMetrics:MaskProviderMismatch', ...
        ['Metrics use mask channel "%s", but family "%s" uses "%s". ' ...
         'Provide the matching binding or explicitly allow a reviewed mapping.'], ...
        binding.mask_channel, model.families.name{familyIndex}, provider);
end

metricVariables = variablesForBinding(tbl, indexVariable, binding);
rows = model.instances.family_id == familyId;
if ~isempty(selected)
    rows = rows & ismember(double(model.instances.frame), selected);
end
instanceRows = find(rows);
[~, order] = sortrows([double(model.instances.track_id(instanceRows)), ...
    double(model.instances.frame(instanceRows)), double(model.instances.mask_label(instanceRows))]);
instanceRows = instanceRows(order);
n = numel(instanceRows);

out = table( ...
    model.instances.family_id(instanceRows), ...
    model.instances.object_id(instanceRows), ...
    model.instances.track_id(instanceRows), ...
    model.instances.frame(instanceRows), ...
    model.instances.mask_label(instanceRows), ...
    model.instances.state_id(instanceRows), ...
    zeros(n,1,'uint64'), ...
    'VariableNames', {'FamilyId','ObjectId','TrackId','Frame','MaskLabel','StateId','ParentTrackId'});
out.ParentTrackId = parentTracks(model, familyId, out.TrackId);
for v = 1:numel(metricVariables)
    out.(metricVariables{v}) = nan(n,1);
end

missingFrame = false(n,1);
missingLabel = false(n,1);
for r = 1:n
    tableRow = find(frames == double(out.Frame(r)), 1, 'first');
    if isempty(tableRow)
        missingFrame(r) = true;
        continue;
    end
    labels = numericVector(tbl.(indexVariable)(tableRow,:));
    hit = find(labels == double(out.MaskLabel(r)), 1, 'first');
    if isempty(hit)
        missingLabel(r) = true;
        continue;
    end
    for v = 1:numel(metricVariables)
        values = numericVector(tbl.(metricVariables{v})(tableRow,:));
        if numel(values) ~= numel(labels)
            error('cellMetrics:MetricLengthMismatch', ...
                'Frame %d field "%s" has %d values for %d mask labels.', ...
                out.Frame(r), metricVariables{v}, numel(values), numel(labels));
        end
        out.(metricVariables{v})(r) = values(hit);
    end
end

report = struct( ...
    'group_id', groupId, ...
    'family_id', familyId, ...
    'family_name', char(string(model.families.name{familyIndex})), ...
    'mask_provider', provider, ...
    'mask_index_variable', indexVariable, ...
    'source_frames', uint32(frames(:)), ...
    'metric_variables', {metricVariables}, ...
    'object_count', n, ...
    'matched_count', n - nnz(missingFrame | missingLabel), ...
    'missing_frame_object_ids', out.ObjectId(missingFrame), ...
    'missing_mask_object_ids', out.ObjectId(missingLabel));
end

function [model, ds] = resolveInputs(source, metrics)
if isobject(source) && isa(source, 'roi')
    [model, ~] = source.loadCellModel('MigrateLegacy', true);
    if ischar(metrics) || isstring(metrics)
        if isempty(source.data) || (numel(source.data)==1 && isempty(source.data(1).data))
            source.load('Data','Silent');
        end
        hit = find(arrayfun(@(x)strcmp(char(string(x.groupid)),char(string(metrics))),source.data),1);
        if isempty(hit)
            error('cellMetrics:MissingDataseries', 'Dataseries "%s" was not found.', char(string(metrics)));
        end
        ds = source.data(hit);
    else
        ds = metrics;
    end
elseif isstruct(source) && isfield(source, 'instances')
    model = source;
    ds = metrics;
else
    error('cellMetrics:InvalidSource', 'Source must be a roi or a cell-model struct.');
end
end

function [tbl, userData, groupId] = seriesParts(ds)
userData = struct(); groupId = '';
if istable(ds)
    tbl = ds;
elseif isobject(ds) && isa(ds,'dataseries')
    tbl = ds.data; userData = ds.userData; groupId = char(string(ds.groupid));
elseif isstruct(ds) && isfield(ds,'data')
    tbl = ds.data;
    if isfield(ds,'userData'), userData=ds.userData; end
    if isfield(ds,'groupid'), groupId=char(string(ds.groupid)); end
else
    error('cellMetrics:InvalidDataseries', 'Metrics must be a table or dataseries.');
end
if ~istable(tbl), error('cellMetrics:InvalidMetricTable','Metrics data must be a table.'); end
if ~isstruct(userData), userData=struct(); end
end

function frames = sourceFrames(tbl, userData)
if isfield(userData,'source_frames') && ~isempty(userData.source_frames)
    frames = double(userData.source_frames(:));
elseif ismember('Frame',tbl.Properties.VariableNames)
    frames = double(tbl.Frame(:));
else
    % Backward compatibility is safe only for legacy full-range tables.
    frames = (1:height(tbl)).';
end
if numel(frames) ~= height(tbl) || any(~isfinite(frames)) || ...
        any(frames < 1) || numel(unique(frames)) ~= numel(frames)
    error('cellMetrics:InvalidSourceFrames', ...
        'computeMetrics source_frames must contain one unique absolute frame per table row.');
end
end

function [indexVariable, binding] = resolveBinding(tbl,userData,provider,indexRequested,channelRequested)
binding = struct('index_variable','','mask_channel','','mask_label','');
bindings = repmat(binding,0,1);
if isfield(userData,'mask_bindings') && isstruct(userData.mask_bindings)
    raw = userData.mask_bindings;
    for i=1:numel(raw)
        b=binding;
        for f={'index_variable','mask_channel','mask_label'}
            if isfield(raw(i),f{1}), b.(f{1})=char(string(raw(i).(f{1}))); end
        end
        bindings(end+1,1)=b; %#ok<AGROW>
    end
elseif isfield(userData,'mask_index_variable')
    binding.index_variable=char(string(userData.mask_index_variable));
    if isfield(userData,'mask_channel'), binding.mask_channel=char(string(userData.mask_channel)); end
    if isfield(userData,'mask_label'), binding.mask_label=char(string(userData.mask_label)); end
    bindings=binding;
end
if ~isempty(indexRequested)
    indexVariable=indexRequested;
    hit=find(strcmp({bindings.index_variable},indexVariable),1);
elseif ~isempty(channelRequested)
    hit=find(strcmpi({bindings.mask_channel},channelRequested),1);
    if isempty(hit), error('cellMetrics:UnknownMaskBinding','No metrics binding uses mask channel "%s".',channelRequested); end
    indexVariable=bindings(hit).index_variable;
else
    hit=find(strcmpi({bindings.mask_channel},provider),1);
    if isempty(hit) && numel(bindings)==1, hit=1; end
    if ~isempty(hit)
        indexVariable=bindings(hit).index_variable;
    else
        candidates=tbl.Properties.VariableNames(startsWith(tbl.Properties.VariableNames,'MaskIdx_'));
        if numel(candidates)~=1
            error('cellMetrics:AmbiguousMaskBinding', ...
                'Specify MaskIndexVariable because the metrics table has %d mask bindings.',numel(candidates));
        end
        indexVariable=candidates{1}; hit=[];
    end
end
if ~ismember(indexVariable,tbl.Properties.VariableNames)
    error('cellMetrics:MissingMaskIndex','Mask index field "%s" does not exist.',indexVariable);
end
if ~isempty(hit), binding=bindings(hit); else, binding.index_variable=indexVariable; end
end

function names = variablesForBinding(tbl,indexVariable,binding)
allNames=tbl.Properties.VariableNames;
names=allNames(~startsWith(allNames,'MaskIdx_'));
names=names(~strcmp(names,'Frame'));
indexNames=allNames(startsWith(allNames,'MaskIdx_'));
if numel(indexNames)>1
    suffix='';
    if ~isempty(binding.mask_label)
        suffix=['_' matlab.lang.makeValidName(binding.mask_label)];
    elseif startsWith(indexVariable,'MaskIdx_')
        suffix=['_' extractAfter(indexVariable,'MaskIdx_')];
    end
    names=names(endsWith(names,suffix));
end
for i=1:numel(names)
    if ~(iscell(tbl.(names{i})) || isnumeric(tbl.(names{i})))
        error('cellMetrics:UnsupportedMetric','Metric field "%s" must be numeric or cell-valued numeric.',names{i});
    end
end
end

function values = numericVector(value)
if iscell(value)
    if isempty(value), values=[]; else, values=value{1}; end
else
    values=value;
end
values=double(values(:));
end

function parent = parentTracks(model,familyId,tracks)
parent=zeros(size(tracks),'uint64');
rows=find(model.relations.family_id==familyId & model.relations.type_id==uint8(1));
for i=1:numel(rows)
    match=tracks==model.relations.child_track_id(rows(i));
    parent(match)=model.relations.parent_track_id(rows(i));
end
end
