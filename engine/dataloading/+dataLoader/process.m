function ctx = process(ctx)
% dataLoader.process  Parse input data and attach to project.

    if nargin < 1 || isempty(ctx)
        ctx = struct();
    end
    detecdiv_check_cancel(ctx, 'dataLoader start');

    p = dataLoader.setparam(struct());
    if isfield(ctx,'dataLoader') && isstruct(ctx.dataLoader) && ~isempty(ctx.dataLoader)
        p = mergeStructOverride(p, ctx.dataLoader);
    elseif isfield(ctx,'params') && isstruct(ctx.params) && ~isempty(ctx.params)
        p = mergeStructOverride(p, ctx.params);
    end

    if isfield(ctx,'path') && ~isempty(ctx.path)
        p.path = ctx.path;
    end
    if isfield(ctx,'projectPath') && ~isempty(ctx.projectPath)
        p.projectPath = char(string(ctx.projectPath));
    elseif isfield(ctx,'run') && isstruct(ctx.run) && isfield(ctx.run,'projectPath') && ~isempty(ctx.run.projectPath)
        p.projectPath = char(string(ctx.run.projectPath));
    elseif isfield(ctx,'io') && isstruct(ctx.io) && isfield(ctx.io,'projectPath') && ~isempty(ctx.io.projectPath)
        p.projectPath = char(string(ctx.io.projectPath));
    end
    if isfield(ctx,'projectName') && ~isempty(ctx.projectName)
        p.projectName = char(string(ctx.projectName));
    end
    if ~isfield(p,'write'), p.write = true; end
    if ~isfield(p,'interactive'), p.interactive = false; end
    try
        if isfield(ctx,'io') && isstruct(ctx.io) && isfield(ctx.io,'persistOutputs') && ...
                ~isempty(ctx.io.persistOutputs) && ~logical(ctx.io.persistOutputs)
            p.write = false;
        end
    catch
    end
    if isfield(ctx,'interactive') && ctx.interactive
        p.interactive = true;
    end

    if p.interactive
        ctx = dataLoader.ui(ctx);
        if isfield(ctx,'cancelled') && ctx.cancelled
            return;
        end
        if isfield(ctx,'dataLoader') && isstruct(ctx.dataLoader)
            p = mergeStructOverride(p, ctx.dataLoader);
        end
    end

    if isfield(p, 'useExistingProjectSources') && ~isempty(p.useExistingProjectSources) && logical(p.useExistingProjectSources)
        detecdiv_check_cancel(ctx, 'dataLoader use existing project sources');
        if ~isfield(ctx, 'shallow') || isempty(ctx.shallow) || ~isa(ctx.shallow, 'shallow')
            error('dataLoader.process:NoProject', ...
                'useExistingProjectSources requires ctx.shallow to be a loaded shallow project.');
        end
        ctx.fovList = ctx.shallow.fov;
        ctx.images = ctx.fovList;
        if ~isempty(ctx.fovList)
            try
                fovChannels = ctx.fovList(1).channel;
                if ~isempty(fovChannels)
                    ctx.channels = fovChannels;
                elseif ~isfield(ctx,'channels') || isempty(ctx.channels)
                    ctx.channels = {};
                end
            catch
            end
        end
        if isprop(ctx.shallow,'runProfiles')
            rp = ctx.shallow.runProfiles;
            if ~isfield(rp,'dataloading') || isempty(rp.dataloading)
                rp.dataloading = struct();
            end
            rp.dataloading.dataLoader = p;
            ctx.shallow.runProfiles = rp;
        end
        return;
    end

    out = [];
    if isfield(ctx,'dataOutput') && ~isempty(ctx.dataOutput)
        out = ctx.dataOutput;
    end

    if isempty(out)
        if ~isfield(p,'path') || isempty(p.path)
            error('dataLoader.process:NoPath','No input path provided.');
        end

        args = {};
        if isfield(p,'positionFilter') && ~isempty(p.positionFilter)
            args = [args {'positionfilter'} {p.positionFilter}];
        end
        if isfield(p,'channelFilter') && ~isempty(p.channelFilter)
            args = [args {'channelfilter'} {p.channelFilter}];
        end
        if isfield(p,'stackFilter') && ~isempty(p.stackFilter)
            args = [args {'stackfilter'} {p.stackFilter}];
        end
        if isfield(p,'positionIdx') && ~isempty(p.positionIdx)
            args = [args {'phylocellpositionidx'} {p.positionIdx}];
        end
        if isfield(p,'progress') && ~isempty(p.progress)
            args = [args {'progress'} {p.progress}];
        end
        if isfield(p,'phyloCellIncludeContours') && ~isempty(p.phyloCellIncludeContours)
            args = [args {'phylocellcontours'} {logical(p.phyloCellIncludeContours)}];
        elseif isfield(p,'includeContours') && ~isempty(p.includeContours)
            args = [args {'phylocellcontours'} {logical(p.includeContours)}];
        else
            args = [args {'phylocellcontours'} {false}];
        end
        tokenFile = cancelTokenFileFromCtx(ctx);
        if ~isempty(tokenFile)
            args = [args {'canceltokenfile'} {tokenFile}];
        end
        detecdiv_check_cancel(ctx, 'dataLoader before parseInputData');
        out = parseInputData(p.path, args{:});
        detecdiv_check_cancel(ctx, 'dataLoader after parseInputData');
    end

    positionSelectionAlreadyApplied = false;
    try
        positionSelectionAlreadyApplied = isfield(out, 'datatype') && strcmpi(out.datatype, 'phylocell');
    catch
    end
    if isfield(p,'positionIdx') && ~isempty(p.positionIdx) && isfield(out,'pos') && ~isempty(out.pos) && ...
            ~positionSelectionAlreadyApplied
        detecdiv_check_cancel(ctx, 'dataLoader before position selection');
        idx = p.positionIdx(:)';
        idx = idx(idx >= 1 & idx <= numel(out.pos));
        if ~isempty(idx)
            out.pos = out.pos(idx);
        else
            out.pos = out.pos([]);
        end
    end

    if isfield(p,'label') && ~isempty(p.label) && isfield(out,'pos')
        lab = char(string(p.label));
        for i = 1:numel(out.pos)
            if isfield(out.pos(i),'name') && ~isempty(out.pos(i).name)
                out.pos(i).name = [lab '_' out.pos(i).name];
            end
        end
    end

    ctx.dataOutput = out;
    detecdiv_check_cancel(ctx, 'dataLoader before addData');

    if ~isfield(ctx,'shallow') || isempty(ctx.shallow)
        ctx.shallow = shallow();
        [projectFolder, projectName] = projectTargetFromParams(p, 'detecdiv_project');
        if ~isempty(projectFolder) && ~isempty(projectName)
            if exist(projectFolder, 'dir') ~= 7
                mkdir(projectFolder);
            end
            ctx.shallow.setPath(projectFolder, projectName);
        end
    end

    ctx.shallow.addData(out);
    ctx.shallow = syncPhyloCellAnnotationsFromParsed(ctx.shallow, out);
    detecdiv_check_cancel(ctx, 'dataLoader after addData');
    if p.write
        try
            shallowSave(ctx.shallow);
        catch
        end
    end

    ctx.fovList = ctx.shallow.fov;
    ctx.annotations = annotationInventoryFromParsed(ctx.shallow, out);
    % Keep a contract-level alias used by pipeline contracts.
    ctx.images = ctx.fovList;
    if ~isempty(ctx.fovList)
        try
            fovChannels = ctx.fovList(1).channel;
            if ~isempty(fovChannels)
                ctx.channels = fovChannels;
            elseif ~isfield(ctx,'channels') || isempty(ctx.channels)
                ctx.channels = {};
            end
        catch
        end
    end
    if isfield(p,'positionIdx') && ~isempty(p.positionIdx)
        ctx.positionIdx = p.positionIdx;
    end
    if isfield(p,'channelIdx') && ~isempty(p.channelIdx)
        ctx.channelIdx = p.channelIdx;
    end
    if isfield(p,'frameRange') && ~isempty(p.frameRange)
        ctx.frameRange = p.frameRange;
    end

    if isprop(ctx.shallow,'runProfiles')
        rp = ctx.shallow.runProfiles;
        if ~isfield(rp,'dataloading') || isempty(rp.dataloading)
            rp.dataloading = struct();
        end
        rp.dataloading.dataLoader = p;
        ctx.shallow.runProfiles = rp;
    end
end

function [projectFolder, projectName] = projectTargetFromParams(p, defaultName)
    projectFolder = '';
    projectName = '';
    if nargin < 2 || isempty(defaultName)
        defaultName = 'detecdiv_project';
    end

    if isfield(p, 'projectName') && ~isempty(p.projectName)
        projectName = char(string(p.projectName));
    end
    if isfield(p, 'projectPath') && ~isempty(p.projectPath)
        target = char(string(p.projectPath));
        [pth, name, ext] = fileparts(target);
        if strcmpi(ext, '.mat')
            projectFolder = pth;
            if isempty(projectName)
                projectName = name;
            end
        else
            projectFolder = target;
        end
    end
    if isempty(projectName)
        projectName = defaultName;
    end
end

function shallowObj = syncPhyloCellAnnotationsFromParsed(shallowObj, out)
    if isempty(shallowObj) || ~isa(shallowObj, 'shallow') || ~isfield(out, 'pos') || isempty(out.pos)
        return;
    end

    for i = 1:numel(out.pos)
        pos = out.pos(i);
        segFile = segmentationFileFromParsedPos(pos);
        if isempty(segFile)
            continue;
        end
        idx = findMatchingFovForParsedPos(shallowObj, pos, i);
        if isempty(idx) || idx < 1 || idx > numel(shallowObj.fov)
            continue;
        end
        try
            contours = shallowObj.fov(idx).contours;
            if ~isstruct(contours)
                contours = struct();
            end
            if ~isfield(contours, 'phyloCell') || ~isstruct(contours.phyloCell)
                contours.phyloCell = struct();
            end
            parsedPhylo = struct();
            if isfield(pos, 'contours') && isstruct(pos.contours) && ...
                    isfield(pos.contours, 'phyloCell') && isstruct(pos.contours.phyloCell)
                parsedPhylo = pos.contours.phyloCell;
            end
            contours.phyloCell = mergeStructOverride(contours.phyloCell, parsedPhylo);
            contours.phyloCell.segmentationFile = segFile;
            shallowObj.fov(idx).contours = contours;
        catch
        end
    end
end

function annotations = annotationInventoryFromParsed(shallowObj, out)
    annotations = struct();
    annotations.phyloCell = struct('segmentationFiles', {{}}, 'fovIndex', [], 'fovIds', {{}});
    if isempty(shallowObj) || ~isa(shallowObj, 'shallow') || ~isfield(out, 'pos') || isempty(out.pos)
        return;
    end

    files = {};
    fovIndex = [];
    fovIds = {};
    for i = 1:numel(out.pos)
        pos = out.pos(i);
        segFile = segmentationFileFromParsedPos(pos);
        if isempty(segFile)
            continue;
        end
        idx = findMatchingFovForParsedPos(shallowObj, pos, i);
        if isempty(idx)
            continue;
        end
        files{end+1} = segFile; %#ok<AGROW>
        fovIndex(end+1) = idx; %#ok<AGROW>
        try
            fovIds{end+1} = char(string(shallowObj.fov(idx).id)); %#ok<AGROW>
        catch
            fovIds{end+1} = sprintf('FOV_%d', idx); %#ok<AGROW>
        end
    end

    annotations.phyloCell.segmentationFiles = files;
    annotations.phyloCell.fovIndex = fovIndex;
    annotations.phyloCell.fovIds = fovIds;
end

function segFile = segmentationFileFromParsedPos(pos)
    segFile = '';
    try
        if isfield(pos, 'contours') && isstruct(pos.contours) && ...
                isfield(pos.contours, 'phyloCell') && isstruct(pos.contours.phyloCell) && ...
                isfield(pos.contours.phyloCell, 'segmentationFile') && ~isempty(pos.contours.phyloCell.segmentationFile)
            segFile = char(string(pos.contours.phyloCell.segmentationFile));
        end
    catch
        segFile = '';
    end
end

function idx = findMatchingFovForParsedPos(shallowObj, pos, fallbackIdx)
    idx = [];
    parsedKey = parsedPosSourceKey(pos);
    if ~isempty(parsedKey)
        for k = 1:numel(shallowObj.fov)
            if strcmp(parsedKey, fovSourceKey(shallowObj.fov(k)))
                idx = k;
                return;
            end
        end
    end

    parsedName = '';
    try
        if isfield(pos, 'name') && ~isempty(pos.name)
            parsedName = char(string(pos.name));
        end
    catch
        parsedName = '';
    end
    if ~isempty(parsedName)
        for k = 1:numel(shallowObj.fov)
            try
                fovId = char(string(shallowObj.fov(k).id));
                if strcmp(fovId, parsedName) || startsWith(fovId, [parsedName '_'])
                    idx = k;
                    return;
                end
            catch
            end
        end
    end

    if nargin >= 3 && fallbackIdx >= 1 && fallbackIdx <= numel(shallowObj.fov)
        idx = fallbackIdx;
    end
end

function key = parsedPosSourceKey(pos)
    key = '';
    try
        if isfield(pos, 'pathlist') && ~isempty(pos.pathlist)
            pathVal = firstNonEmptyCellLocal(pos.pathlist);
            fileVal = '';
            if isfield(pos, 'filelist') && ~isempty(pos.filelist)
                fileVal = firstFileNameFromListLocal(pos.filelist);
            end
            key = lower([normalizePathLocal(pathVal) '|' normalizePathLocal(fileVal)]);
        end
    catch
        key = '';
    end
end

function key = fovSourceKey(f)
    key = '';
    try
        pathVal = firstNonEmptyCellLocal(f.srcpath);
        fileVal = firstFileNameFromListLocal(f.srclist);
        key = lower([normalizePathLocal(pathVal) '|' normalizePathLocal(fileVal)]);
    catch
        key = '';
    end
end

function value = firstNonEmptyCellLocal(values)
    value = '';
    if ischar(values) || isstring(values)
        value = char(string(values));
        return;
    end
    if ~iscell(values)
        return;
    end
    for i = 1:numel(values)
        if ~isempty(values{i})
            value = char(string(values{i}));
            return;
        end
    end
end

function name = firstFileNameFromListLocal(filelist)
    name = '';
    try
        if iscell(filelist)
            item = filelist{1};
        else
            item = filelist(1);
        end
        if isstruct(item) && isfield(item, 'name') && ~isempty(item(1).name)
            name = char(string(item(1).name));
        elseif ischar(item) || isstring(item)
            name = char(string(item));
        end
    catch
        name = '';
    end
end

function p = normalizePathLocal(p)
    p = char(string(p));
    p = strrep(p, '\', '/');
    p = regexprep(p, '/+', '/');
    p = regexprep(p, '/$', '');
end

function tokenFile = cancelTokenFileFromCtx(ctx)
    tokenFile = '';
    try
        if isfield(ctx,'cancel') && isstruct(ctx.cancel) ...
                && isfield(ctx.cancel,'tokenFile') && ~isempty(ctx.cancel.tokenFile)
            tokenFile = char(string(ctx.cancel.tokenFile));
        end
    catch
        tokenFile = '';
    end
end

function out = mergeStructOverride(base, patch)
    out = base;
    if nargin < 2 || ~isstruct(patch) || isempty(patch)
        return;
    end
    fn = fieldnames(patch);
    for i = 1:numel(fn)
        out.(fn{i}) = patch.(fn{i});
    end
end
