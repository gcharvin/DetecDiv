function ctx = ui(ctx)
% roiIdentify.ui  Launch ROIextracterGUI and persist calibration into ctx/node params.

    if nargin < 1 || isempty(ctx)
        ctx = struct();
    end

    if isa(ctx,'shallow')
        ctx = struct('shallow', ctx);
    elseif isa(ctx,'fov')
        try
            sh = ctx.flaggedROIs;
        catch
            sh = [];
        end
        fovId = '';
        try
            fovId = ctx.id;
        catch
        end
        ctx = struct('shallow', sh, 'fovId', fovId);
    end

    if ~isstruct(ctx)
        error('roiIdentify.ui:InvalidInput','Input must be a ctx struct, shallow, or fov.');
    end
    if ~isfield(ctx,'shallow') || isempty(ctx.shallow)
        error('roiIdentify.ui:NoProject','shallow project required for ROIextracterGUI.');
    end

    shallowObj = ctx.shallow;

    p = roiIdentify.setparam(struct());

    if isprop(shallowObj,'runProfiles') && isstruct(shallowObj.runProfiles)
        try
            if isfield(shallowObj.runProfiles,'dataloading') && isfield(shallowObj.runProfiles.dataloading,'roiIdentify')
                stored = shallowObj.runProfiles.dataloading.roiIdentify;
                if isstruct(stored)
                    p = mergeStructOverride(p, stored);
                end
            end
        catch
        end
    end

    if isfield(ctx,'roiIdentify') && isstruct(ctx.roiIdentify) && ~isempty(ctx.roiIdentify)
        p = mergeStructOverride(p, ctx.roiIdentify);
    elseif isfield(ctx,'params') && isstruct(ctx.params) && ~isempty(ctx.params)
        p = mergeStructOverride(p, ctx.params);
    end

    patList = struct([]);
    if isfield(p,'patternList') && ~isempty(p.patternList)
        patList = p.patternList;
    else
        try
            pat = loadPattern(shallowObj);
            if isstruct(pat) && ~isempty(fieldnames(pat))
                patList = pat;
            end
        catch
        end
    end
    p.patternList = patList;

    refIdx = resolveReferenceFovIndex(shallowObj, ctx, p.patternList);
    if refIdx < 1 || refIdx > numel(shallowObj.fov)
        refIdx = 1;
    end

    fovobj = shallowObj.fov(refIdx);

    app = ROIextracterGUI(fovobj);
    try
        if isfield(p,'referenceFrame') && ~isempty(p.referenceFrame)
            app.ReferenceframeEditField.Value = p.referenceFrame;
        end
    catch
    end
    try
        if isfield(p,'threshold') && ~isempty(p.threshold)
            app.ThresholdEditField.Value = p.threshold;
        end
    catch
    end
    try
        if isfield(p,'channel') && ~isempty(p.channel)
            app.channelnameEditField.Value = char(string(p.channel));
        end
    catch
    end

    origClose = [];
    try, origClose = app.ROIidentifierUIFigure.CloseRequestFcn; catch, end
    app.ROIidentifierUIFigure.CloseRequestFcn = @(src,evt)onClose(src,evt,origClose);

    origBtn = [];
    try, origBtn = app.CloseButton.ButtonPushedFcn; catch, end
    try
        app.CloseButton.ButtonPushedFcn = @(src,evt)onClose(src,evt,origBtn);
    catch
    end

    try
        waitfor(app.ROIidentifierUIFigure);
    catch
    end

    ctx.shallow = shallowObj;
    ctx.fovList = shallowObj.fov;
    ctx.roiList = collectROIs(ctx.fovList);

    function onClose(src, evt, origFcn)
        try
            if isempty(shallowObj)
                return;
            end

            pat = struct();
            try, pat.rect = fovobj.pattern; catch, pat.rect = []; end
            try, pat.crop = fovobj.crop; catch, pat.crop = []; end
            try, pat.fovId = fovobj.id; catch, pat.fovId = ''; end
            pat.fovIndex = refIdx;
            try, pat.frame = app.ReferenceframeEditField.Value; catch, pat.frame = 1; end
            try, pat.channel = app.channelnameEditField.Value; catch, pat.channel = ''; end
            try
                if isprop(fovobj,'channel')
                    pix = find(matches(fovobj.channel, pat.channel),1);
                    if ~isempty(pix)
                        pat.channelIndex = pix;
                    end
                end
            catch
            end

            if isfield(p,'patternList') && ~isempty(p.patternList)
                patListLocal = p.patternList;
            else
                patListLocal = struct([]);
            end
            if ~isempty(pat.rect)
                patListLocal = upsertPattern(patListLocal, pat);
            end

            try
                if ~isfield(shallowObj.runProfiles,'dataloading') || isempty(shallowObj.runProfiles.dataloading)
                    shallowObj.runProfiles.dataloading = struct();
                end
            catch
                shallowObj.runProfiles = struct('dataloading', struct());
            end

            p.referenceFrame = safeNumeric(app.ReferenceframeEditField.Value, p.referenceFrame);
            p.threshold = safeNumeric(app.ThresholdEditField.Value, p.threshold);
            p.channel = char(string(app.channelnameEditField.Value));
            if isfield(pat,'channelIndex') && ~isempty(pat.channelIndex)
                p.channelIndex = pat.channelIndex;
            end
            if isfield(pat,'crop')
                p.crop = pat.crop;
            end
            p.patternList = patListLocal;

            shallowObj.runProfiles.dataloading.roiIdentify = p;
            if ~isempty(pat.rect)
                storePattern(shallowObj, pat); % legacy single-pattern storage
            end

            ctx.roiIdentify = p;
            ctx.params = p;
            if ~isempty(pat.rect)
                ctx.pattern = pat;
            end
            ctx.patternList = patListLocal;

            try, shallowSave(shallowObj); catch, end
        catch
        end

        if ~isempty(origFcn)
            try
                feval(origFcn, src, evt);
            catch
                try
                    origFcn(src, evt);
                catch
                end
            end
        end
    end
end

function idx = resolveReferenceFovIndex(shallowObj, ctx, patList)
idx = 1;

try
    if isfield(ctx,'fovIndex') && ~isempty(ctx.fovIndex)
        idx = ctx.fovIndex(1);
        return;
    end
catch
end

try
    if isfield(ctx,'fovId') && ~isempty(ctx.fovId)
        wanted = char(string(ctx.fovId));
        for i = 1:numel(shallowObj.fov)
            if isprop(shallowObj.fov(i),'id') && strcmp(shallowObj.fov(i).id, wanted)
                idx = i;
                return;
            end
        end
    end
catch
end

if isstruct(patList) && ~isempty(patList)
    try
        if isfield(patList(1),'fovIndex') && ~isempty(patList(1).fovIndex)
            idx = patList(1).fovIndex;
            return;
        end
    catch
    end
end
end

function roiList = collectROIs(fovList)
roiList = [];
for i = 1:numel(fovList)
    r = fovList(i).roi;
    if ~isempty(r)
        roiList = [roiList r(:)']; %#ok<AGROW>
    end
end
end

function out = mergeStructOverride(base, override)
out = base;
if isempty(override), return; end
fn = fieldnames(override);
for i = 1:numel(fn)
    out.(fn{i}) = override.(fn{i});
end
end

function pats = upsertPattern(pats, pat)
if isempty(pats)
    pats = pat;
    return;
end
for i = 1:numel(pats)
    try
        sameFov = isfield(pats(i),'fovId') && strcmp(char(string(pats(i).fovId)), char(string(pat.fovId)));
    catch
        sameFov = false;
    end
    if sameFov
        pats(i) = pat;
        return;
    end
end
pats(end+1) = pat;
end

function v = safeNumeric(val, fallback)
v = fallback;
try
    if ~isempty(val)
        v = val;
    end
catch
end
end
