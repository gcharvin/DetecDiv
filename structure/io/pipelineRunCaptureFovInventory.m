function ctx = pipelineRunCaptureFovInventory(ctx, phase, nodeId)
%PIPELINERUNCAPTUREFOVINVENTORY Persist project and effective FOV snapshots.
% The run context keeps the initial project inventory, the latest inventory,
% the FOVs selected for execution, and the FOVs added since run start.

if nargin < 1 || ~isstruct(ctx)
    ctx = struct();
end
if nargin < 2 || isempty(phase)
    phase = 'snapshot';
end
if nargin < 3 || isempty(nodeId)
    nodeId = '';
end
if ~isfield(ctx, 'run') || ~isstruct(ctx.run)
    ctx.run = struct();
end
if ~isfield(ctx.run, 'fovTrace') || ~isstruct(ctx.run.fovTrace)
    ctx.run.fovTrace = struct();
end

fovs = [];
project = [];
try
    if isfield(ctx, 'shallow') && isa(ctx.shallow, 'shallow')
        project = ctx.shallow;
    elseif isfield(ctx, 'shallowObj') && isa(ctx.shallowObj, 'shallow')
        project = ctx.shallowObj;
    end
    if ~isempty(project)
        fovs = project.fov;
    elseif isfield(ctx, 'fovList')
        fovs = ctx.fovList;
    end
catch
    fovs = [];
end

snapshot = struct('index', {}, 'id', {}, 'number', {}, 'roiCount', {});
for i = 1:numel(fovs)
    fovId = '';
    fovNumber = i;
    roiCount = 0;
    try
        fovId = char(string(fovs(i).id));
    catch
    end
    try
        fovNumber = double(fovs(i).number);
    catch
    end
    try
        roiCount = numel(fovs(i).roi);
    catch
    end
    snapshot(end+1) = struct('index', i, 'id', fovId, ...
        'number', fovNumber, 'roiCount', roiCount); %#ok<AGROW>
end

selection = [];
try
    if isfield(ctx, 'sel') && isstruct(ctx.sel) && isfield(ctx.sel, 'fovs')
        selection = ctx.sel.fovs;
    elseif isfield(ctx.run, 'fovIndex')
        selection = ctx.run.fovIndex;
    end
catch
    selection = [];
end
if isempty(selection)
    effectiveIndices = 1:numel(snapshot);
else
    effectiveIndices = round(double(selection(:)'));
    effectiveIndices = effectiveIndices(isfinite(effectiveIndices) & ...
        effectiveIndices >= 1 & effectiveIndices <= numel(snapshot));
    effectiveIndices = unique(effectiveIndices, 'stable');
end
effectiveFovs = snapshot(effectiveIndices);

trace = ctx.run.fovTrace;
phase = char(string(phase));
if strcmpi(phase, 'run_start') || ~isfield(trace, 'initialFovs')
    trace.initialFovs = snapshot;
    trace.startedAt = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end
initialFovs = trace.initialFovs;
createdFovs = struct('index', {}, 'id', {}, 'number', {}, 'roiCount', {});
for i = 1:numel(snapshot)
    currentId = strtrim(snapshot(i).id);
    if isempty(currentId)
        existed = any([initialFovs.index] == snapshot(i).index);
    else
        existed = any(strcmpi({initialFovs.id}, currentId));
    end
    if ~existed
        createdFovs(end+1) = snapshot(i); %#ok<AGROW>
    end
end

trace.projectFovs = snapshot;
trace.effectiveFovs = effectiveFovs;
trace.createdFovs = createdFovs;
trace.effectiveIndices = effectiveIndices;
trace.phase = phase;
trace.nodeId = char(string(nodeId));
trace.capturedAt = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
ctx.run.fovTrace = trace;

pipelineRunEvent(ctx, 'fov_inventory', ...
    'Phase', phase, 'NodeId', char(string(nodeId)), ...
    'ProjectFovCount', numel(snapshot), ...
    'EffectiveFovs', effectiveFovs, 'CreatedFovs', createdFovs);
end
