function ctx = ui(ctx)
% roiExtract.ui  Launch ROI extraction parameter editor and persist settings.

    if nargin < 1 || isempty(ctx)
        ctx = struct();
    end

    if isa(ctx,'shallow')
        ctx = struct('shallow', ctx);
    end
    if ~isstruct(ctx)
        error('roiExtract.ui:InvalidInput','Input must be a ctx struct or shallow object.');
    end

    shallowObj = [];
    if isfield(ctx,'shallow')
        shallowObj = ctx.shallow;
    end

    p = roiExtract.setparam(struct());

    if ~isempty(shallowObj)
        try
            if isfield(shallowObj.runProfiles,'dataloading') && isfield(shallowObj.runProfiles.dataloading,'roiExtract')
                stored = shallowObj.runProfiles.dataloading.roiExtract;
                if isstruct(stored)
                    p = mergeStructOverride(p, stored);
                end
            end
        catch
        end
    end

    if isfield(ctx,'roiExtract') && isstruct(ctx.roiExtract) && ~isempty(ctx.roiExtract)
        p = mergeStructOverride(p, ctx.roiExtract);
    elseif isfield(ctx,'params') && isstruct(ctx.params) && ~isempty(ctx.params)
        p = mergeStructOverride(p, ctx.params);
    end

    p = inferSuggestedParams(ctx, shallowObj, p);
    fovMeta = buildFovMeta(shallowObj, p);

    app = roiExtractGUI(p, fovMeta);
    try
        uiwait(app.UIFigure);
    catch
    end

    cancelled = true;
    try
        cancelled = app.Cancelled;
    catch
    end
    if cancelled
        ctx.cancelled = true;
        try
            delete(app);
        catch
        end
        return;
    end

    p = app.Result;
    try
        ctx.runNow = logical(app.RunNow);
    catch
        ctx.runNow = false;
    end
    try
        delete(app);
    catch
    end

    ctx.roiExtract = p;
    ctx.params = p;

    if ~isempty(shallowObj)
        try
            if ~isfield(shallowObj.runProfiles,'dataloading') || isempty(shallowObj.runProfiles.dataloading)
                shallowObj.runProfiles.dataloading = struct();
            end
        catch
            shallowObj.runProfiles = struct('dataloading', struct());
        end
        shallowObj.runProfiles.dataloading.roiExtract = p;
        try
            shallowSave(shallowObj);
        catch
        end
        ctx.shallow = shallowObj;
    end
end

function p = inferSuggestedParams(ctx, shallowObj, p)
if isempty(shallowObj) || ~isa(shallowObj, 'shallow')
    return;
end

fov = pickReferenceFov(ctx, shallowObj);
if isempty(fov)
    return;
end

if (~isfield(p,'frames') || isempty(p.frames))
    frames = inferFrameList(fov);
    if ~isempty(frames)
        p.frames = frames;
    end
end

if (~isfield(p,'channels') || isempty(p.channels))
    chans = inferChannelList(fov);
    if ~isempty(chans)
        p.channels = chans;
    end
end

if (~isfield(p,'fovIndex') || isempty(p.fovIndex))
    idx = inferDefaultFovSelection(shallowObj);
    if ~isempty(idx)
        p.fovIndex = idx;
    end
end
end

function fov = pickReferenceFov(ctx, shallowObj)
fov = [];
if ~isprop(shallowObj, 'fov') || isempty(shallowObj.fov)
    return;
end

idx = [];
if isfield(ctx,'fovIndex') && ~isempty(ctx.fovIndex)
    idx = ctx.fovIndex(1);
elseif isfield(ctx,'roiExtract') && isstruct(ctx.roiExtract) && isfield(ctx.roiExtract,'fovIndex') && ~isempty(ctx.roiExtract.fovIndex)
    idx = ctx.roiExtract.fovIndex(1);
elseif isfield(ctx,'params') && isstruct(ctx.params) && isfield(ctx.params,'fovIndex') && ~isempty(ctx.params.fovIndex)
    idx = ctx.params.fovIndex(1);
end

if isempty(idx) || ~isscalar(idx) || ~isfinite(idx) || idx < 1 || idx > numel(shallowObj.fov)
    idx = 1;
end

fov = shallowObj.fov(idx);
end

function frames = inferFrameList(fov)
frames = [];
try
    if isprop(fov,'frames') && ~isempty(fov.frames)
        val = double(fov.frames);
        if isscalar(val) && isfinite(val) && val >= 1
            frames = 1:floor(val);
            return;
        end
        if isnumeric(val) && isvector(val)
            val = reshape(val, 1, []);
            isIntLike = all(isfinite(val)) && all(abs(val - round(val)) < eps(max(1, max(abs(val)))));
            if isIntLike && all(val >= 1)
                expected = 1:numel(val);
                if isequal(val, expected)
                    frames = val;
                else
                    frames = 1:floor(max(val));
                end
                return;
            end
            frames = val;
            return;
        end
    end
catch
end

try
    if isprop(fov,'srclist') && iscell(fov.srclist) && ~isempty(fov.srclist) && ~isempty(fov.srclist{1})
        frames = 1:numel(fov.srclist{1});
    end
catch
end
end

function chans = inferChannelList(fov)
chans = {};
try
    if isprop(fov,'channel') && ~isempty(fov.channel)
        vals = fov.channel;
        if isstring(vals)
            vals = cellstr(vals(:)');
        end
        if ischar(vals)
            vals = {vals};
        end
        if iscell(vals)
            vals = vals(~cellfun('isempty', vals));
            if ~isempty(vals)
                chans = vals;
            end
        end
    end
catch
end
end

function idx = inferDefaultFovSelection(shallowObj)
idx = [];
if isempty(shallowObj) || ~isa(shallowObj, 'shallow') || ~isprop(shallowObj, 'fov') || isempty(shallowObj.fov)
    return;
end

allIdx = 1:numel(shallowObj.fov);
roiIdx = [];
for i = allIdx
    try
        r = shallowObj.fov(i).roi;
        if isempty(r)
            continue;
        end
        if numel(r) == 1 && isempty(r(1).id)
            continue;
        end
        roiIdx(end+1) = i; %#ok<AGROW>
    catch
    end
end

if ~isempty(roiIdx)
    idx = roiIdx;
else
    idx = allIdx;
end
end

function meta = buildFovMeta(shallowObj, p)
meta = struct('index',{},'label',{},'roiCount',{},'selected',{},'hasRoi',{});
if isempty(shallowObj) || ~isa(shallowObj, 'shallow') || ~isprop(shallowObj, 'fov') || isempty(shallowObj.fov)
    return;
end

selected = [];
if nargin >= 2 && isstruct(p) && isfield(p, 'fovIndex') && ~isempty(p.fovIndex)
    selected = reshape(double(p.fovIndex), 1, []);
end
for i = 1:numel(shallowObj.fov)
    label = sprintf('%d', i);
    try
        if isprop(shallowObj.fov(i), 'id') && ~isempty(shallowObj.fov(i).id)
            label = sprintf('%d - %s', i, char(string(shallowObj.fov(i).id)));
        end
    catch
    end
    count = 0;
    try
        r = shallowObj.fov(i).roi;
        if ~isempty(r)
            if ~(numel(r) == 1 && isempty(r(1).id))
                count = numel(r);
            end
        end
    catch
    end
    meta(end+1) = struct( ...
        'index', i, ...
        'label', label, ...
        'roiCount', count, ...
        'selected', isempty(selected) || any(selected == i), ...
        'hasRoi', count > 0); %#ok<AGROW>
end
end

function out = mergeStructOverride(base, override)
out = base;
if isempty(override)
    return;
end
fn = fieldnames(override);
for i = 1:numel(fn)
    out.(fn{i}) = override.(fn{i});
end
end
