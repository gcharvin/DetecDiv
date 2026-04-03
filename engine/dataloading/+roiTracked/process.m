function ctx = process(ctx)
% roiTracked.process  Create moving ROIs from tracked-mask labels.

    if nargin < 1 || isempty(ctx)
        ctx = struct();
    end

    if isfield(ctx, 'interactive') && ctx.interactive
        ctx = roiTracked.ui(ctx);
        if isfield(ctx, 'cancelled') && ctx.cancelled
            return;
        end
    end

    if ~isfield(ctx, 'shallow') || isempty(ctx.shallow) || ~isa(ctx.shallow, 'shallow')
        error('roiTracked.process:ProjectRequired', 'Tracked ROI generation requires a shallow project context.');
    end

    shallowObj = ctx.shallow;

    p = roiTracked.setparam(struct());

    try
        if isfield(shallowObj.runProfiles, 'dataloading') && isfield(shallowObj.runProfiles.dataloading, 'roiTracked')
            stored = shallowObj.runProfiles.dataloading.roiTracked;
            if isstruct(stored)
                p = mergeStructOverrideLocal(p, stored);
            end
        end
    catch
    end

    if isfield(ctx, 'roiTracked') && isstruct(ctx.roiTracked) && ~isempty(ctx.roiTracked)
        p = mergeStructOverrideLocal(p, ctx.roiTracked);
    elseif isfield(ctx, 'params') && isstruct(ctx.params) && ~isempty(ctx.params)
        p = mergeStructOverrideLocal(p, ctx.params);
    end

    p = roiTracked.setparam(p);

    existingPolicy = 'upsert';
    if isfield(ctx, 'executionPolicy') && isstruct(ctx.executionPolicy) && isfield(ctx.executionPolicy, 'existingPolicy') ...
            && ~isempty(ctx.executionPolicy.existingPolicy)
        existingPolicy = normalizeExistingPolicyLocal(ctx.executionPolicy.existingPolicy, 'upsert');
    elseif isfield(p, 'existingPolicy') && ~isempty(p.existingPolicy)
        existingPolicy = normalizeExistingPolicyLocal(p.existingPolicy, 'upsert');
    elseif isfield(ctx, 'io') && isstruct(ctx.io) && isfield(ctx.io, 'effectiveExistingPolicy') && ~isempty(ctx.io.effectiveExistingPolicy)
        existingPolicy = normalizeExistingPolicyLocal(ctx.io.effectiveExistingPolicy, 'upsert');
    end

    outputName = '';
    if isfield(ctx, 'names') && isstruct(ctx.names) && isfield(ctx.names, 'outputName') && ~isempty(ctx.names.outputName)
        outputName = char(string(ctx.names.outputName));
    elseif isfield(p, 'outputName') && ~isempty(p.outputName)
        outputName = char(string(p.outputName));
    end

    if strcmp(existingPolicy, 'append') && isempty(strtrim(outputName))
        outputName = char(string(getRunIdLocal(ctx)));
    end

    if isfield(ctx, 'fovIndex') && ~isempty(ctx.fovIndex)
        p.fovIndex = round(double(ctx.fovIndex(:)'));
        p.fovIndex = p.fovIndex(isfinite(p.fovIndex) & p.fovIndex >= 1);
        p.fovIndex = unique(p.fovIndex, 'stable');
    end

    callArgs = {};
    if ~isempty(p.fovIndex)
        callArgs = [callArgs, {'FOV', p.fovIndex}]; %#ok<AGROW>
    end
    if ~isempty(p.roiIndex)
        callArgs = [callArgs, {'ROI', p.roiIndex}]; %#ok<AGROW>
    end
    if ~isempty(p.channel)
        callArgs = [callArgs, {'Channel', p.channel}]; %#ok<AGROW>
    end
    if ~isempty(p.margin)
        callArgs = [callArgs, {'Margin', p.margin}]; %#ok<AGROW>
    end

    callArgs = [callArgs, {'Extract', logical(p.extract)}]; %#ok<AGROW>
    callArgs = [callArgs, {'ExistingPolicy', existingPolicy}]; %#ok<AGROW>
    if ~isempty(outputName)
        callArgs = [callArgs, {'IdPrefix', outputName}]; %#ok<AGROW>
    end

    if ~isempty(p.extractFrames)
        callArgs = [callArgs, {'ExtractFrames', p.extractFrames}]; %#ok<AGROW>
    end
    if ~isempty(p.extractChannels)
        callArgs = [callArgs, {'ExtractChannels', p.extractChannels}]; %#ok<AGROW>
    end
    if ~isempty(p.saveArgs)
        callArgs = [callArgs, {'SaveArgs', p.saveArgs}]; %#ok<AGROW>
    end

    created = roiTracked.createTrackedCellROIs(shallowObj, callArgs{:});

    try
        if ~isfield(shallowObj.runProfiles, 'dataloading') || isempty(shallowObj.runProfiles.dataloading)
            shallowObj.runProfiles.dataloading = struct();
        end
        shallowObj.runProfiles.dataloading.roiTracked = p;
    catch
    end

    ctx.shallow = shallowObj;
    ctx.roiTracked = p;
    ctx.params = p;
    ctx.executionPolicy.existingPolicy = existingPolicy;
    if ~isempty(outputName)
        ctx.names.outputName = outputName;
    end
    ctx.createdTracked = created;
    ctx.roiList = collectROIsLocal(shallowObj.fov);
end

function out = mergeStructOverrideLocal(base, override)
out = base;
if isempty(override)
    return;
end
fn = fieldnames(override);
for i = 1:numel(fn)
    out.(fn{i}) = override.(fn{i});
end
end

function roiList = collectROIsLocal(fovList)
roiList = [];
for i = 1:numel(fovList)
    try
        r = fovList(i).roi;
        if ~isempty(r)
            roiList = [roiList r(:)']; %#ok<AGROW>
        end
    catch
    end
end
end

function out = normalizeExistingPolicyLocal(policy, fallback)
out = char(string(policy));
out = lower(strtrim(out));
switch out
    case {'', 'default'}
        out = fallback;
    case {'replace', 'overwrite', 'reset'}
        out = 'replace';
    case {'append', 'add'}
        out = 'append';
    case {'skip', 'resume'}
        out = 'skip';
    case {'error', 'fail'}
        out = 'error';
    case {'upsert', 'merge'}
        out = 'upsert';
    otherwise
        out = fallback;
end
end

function runId = getRunIdLocal(ctx)
runId = 'run';
if isfield(ctx, 'runId') && ~isempty(ctx.runId)
    runId = char(string(ctx.runId));
elseif isfield(ctx, 'run') && isstruct(ctx.run) && isfield(ctx.run, 'id') && ~isempty(ctx.run.id)
    runId = char(string(ctx.run.id));
end
runId = regexprep(runId, '[^A-Za-z0-9_]', '_');
if isempty(runId)
    runId = 'run';
end
end

