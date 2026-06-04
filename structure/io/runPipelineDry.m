function [ok, report] = runPipelineDry(pipe, ctx, opts)
% runPipelineDry  Validate prerequisites without executing nodes.

    if nargin < 2 || isempty(ctx)
        ctx = struct();
    end
    if nargin < 3 || isempty(opts)
        opts = struct();
    end

    ctx = seedDryRunContextFromProject(ctx);

    allowGui = true;
    if isfield(opts,'allowGui') && ~isempty(opts.allowGui)
        allowGui = logical(opts.allowGui);
    end

    [pipeResolved, bindingResolution] = pipelineResolveBindings(pipe, ctx, struct('allowGui', allowGui));
    [okV, report] = validatePipeline(pipeResolved, ctx, struct('allowGui', allowGui));
    report.bindingResolution = bindingResolution;

    % strict ok if any missing params (even if GUI could fill them)
    ok = okV;
    if isfield(report,'missingParams') && ~isempty(report.missingParams)
        ok = false;
    end

    report.dryRun = true;
    report.okStrict = ok;
    report.ok = okV;
end

function ctx = seedDryRunContextFromProject(ctx)
    if ~isstruct(ctx)
        ctx = struct();
        return;
    end
    if isfield(ctx,'shallowObj') && ~isfield(ctx,'shallow')
        ctx.shallow = ctx.shallowObj;
    elseif isfield(ctx,'shallow') && ~isfield(ctx,'shallowObj')
        ctx.shallowObj = ctx.shallow;
    end

    shallowObj = [];
    if isfield(ctx,'shallowObj') && ~isempty(ctx.shallowObj)
        shallowObj = ctx.shallowObj;
    elseif isfield(ctx,'shallow') && ~isempty(ctx.shallow)
        shallowObj = ctx.shallow;
    end
    if isempty(shallowObj)
        return;
    end

    if ~isfield(ctx,'fovList') || isempty(ctx.fovList)
        try
            fovs = shallowObj.fov;
            selected = [];
            if isfield(ctx,'sel') && isstruct(ctx.sel) && isfield(ctx.sel,'fovs') && ~isempty(ctx.sel.fovs)
                selected = normalizeDryIndexVector(ctx.sel.fovs);
            elseif isfield(ctx,'run') && isstruct(ctx.run) && isfield(ctx.run,'fovIndex') && ~isempty(ctx.run.fovIndex)
                selected = normalizeDryIndexVector(ctx.run.fovIndex);
            end
            if ~isempty(selected)
                selected = selected(selected >= 1 & selected <= numel(fovs));
                fovs = fovs(selected);
            end
            ctx.fovList = fovs;
        catch
        end
    end

    if (~isfield(ctx,'channels') || isempty(ctx.channels)) && isfield(ctx,'fovList') && ~isempty(ctx.fovList)
        try
            ctx.channels = ctx.fovList(1).channel;
        catch
        end
    end

    if (~isfield(ctx,'roiList') || isempty(ctx.roiList)) && isfield(ctx,'fovList') && ~isempty(ctx.fovList)
        roiSel = [];
        try
            if isfield(ctx,'sel') && isstruct(ctx.sel) && isfield(ctx.sel,'rois') && ~isempty(ctx.sel.rois)
                roiSel = normalizeDryIndexVector(ctx.sel.rois);
            elseif isfield(ctx,'run') && isstruct(ctx.run) && isfield(ctx.run,'rois') && ~isempty(ctx.run.rois)
                roiSel = normalizeDryIndexVector(ctx.run.rois);
            end
        catch
            roiSel = [];
        end
        ctx.roiList = collectDryRoisFromFovs(ctx.fovList, roiSel);
        ctx.rois = ctx.roiList;
    end

    if (~isfield(ctx,'dataSeries') || isempty(ctx.dataSeries)) && isfield(ctx,'roiList') && ~isempty(ctx.roiList)
        ctx.dataSeries = inferDryDataSeriesNames(ctx.roiList);
    end
end

function idx = normalizeDryIndexVector(v)
    idx = [];
    try
        if isnumeric(v) || islogical(v)
            idx = double(v(:))';
        elseif isstring(v) || ischar(v)
            idx = str2num(char(string(v))); %#ok<ST2NM>
        end
        idx = idx(isfinite(idx) & idx == round(idx));
    catch
        idx = [];
    end
end

function rois = collectDryRoisFromFovs(fovList, roiSel)
    if nargin < 2
        roiSel = [];
    end
    rois = [];
    for i = 1:numel(fovList)
        try
            r = fovList(i).roi;
            if isempty(r)
                continue;
            end
            if ~isempty(roiSel)
                idx = roiSel(roiSel >= 1 & roiSel <= numel(r));
                r = r(idx);
            end
            if isempty(rois)
                rois = r;
            else
                rois = [rois r]; %#ok<AGROW>
            end
        catch
        end
    end
end

function names = inferDryDataSeriesNames(roiList)
    names = {};
    try
        if isempty(roiList) || isempty(roiList(1).data)
            return;
        end
        for i = 1:numel(roiList(1).data)
            ds = roiList(1).data(i);
            if isprop(ds,'groupid') && ~isempty(ds.groupid)
                names{end+1} = char(string(ds.groupid)); %#ok<AGROW>
            elseif isfield(ds,'groupid') && ~isempty(ds.groupid)
                names{end+1} = char(string(ds.groupid)); %#ok<AGROW>
            elseif isprop(ds,'id') && ~isempty(ds.id)
                names{end+1} = char(string(ds.id)); %#ok<AGROW>
            end
        end
        names = unique(names, 'stable');
    catch
        names = {};
    end
end
