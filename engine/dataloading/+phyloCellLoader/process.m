function ctx = process(ctx)
% phyloCellLoader.process  Import a legacy phyloCell project as DetecDiv FOVs.

if nargin < 1 || isempty(ctx)
    ctx = struct();
end
detecdiv_check_cancel(ctx, 'phyloCellLoader start');

p = phyloCellLoader.setparam(struct());
if isfield(ctx, 'dataLoader') && isstruct(ctx.dataLoader) && ~isempty(ctx.dataLoader)
    p = mergeStructOverride(p, ctx.dataLoader);
end
if isfield(ctx, 'phyloCellLoader') && isstruct(ctx.phyloCellLoader) && ~isempty(ctx.phyloCellLoader)
    p = mergeStructOverride(p, ctx.phyloCellLoader);
elseif isfield(ctx, 'params') && isstruct(ctx.params) && ~isempty(ctx.params)
    p = mergeStructOverride(p, ctx.params);
end
if (~isfield(p, 'path') || isempty(p.path)) && isfield(ctx, 'path') && ~isempty(ctx.path)
    p.path = char(string(ctx.path));
end
if isfield(ctx, 'projectPath') && ~isempty(ctx.projectPath)
    p.projectPath = char(string(ctx.projectPath));
elseif isfield(ctx, 'run') && isstruct(ctx.run) && isfield(ctx.run, 'projectPath') && ~isempty(ctx.run.projectPath)
    p.projectPath = char(string(ctx.run.projectPath));
elseif isfield(ctx, 'io') && isstruct(ctx.io) && isfield(ctx.io, 'projectPath') && ~isempty(ctx.io.projectPath)
    p.projectPath = char(string(ctx.io.projectPath));
end
if ~isfield(p, 'includeContours') || isempty(p.includeContours)
    p.includeContours = false;
end

if isTrueScalar(getStructFieldLocal(p, 'useExistingProjectSources', false))
    ctx = useExistingDetecDivProjectSources(ctx, p);
    return;
end

if ~isfield(p, 'path') || isempty(p.path)
    error('phyloCellLoader:NoPath', 'No phyloCell project path provided.');
end

[parsePath, projectFile, prefix] = normalizePhyloCellPath(p.path);
if isempty(parsePath) || exist(parsePath, 'dir') ~= 7
    error('phyloCellLoader:MissingFolder', ...
        'Cannot find phyloCell project folder for "%s".', char(string(p.path)));
end

if ~isfield(ctx, 'shallow') || isempty(ctx.shallow)
    ctx.shallow = shallow();
    [projectPath, projectName] = defaultDetecDivProjectTarget(p, parsePath, prefix);
    if exist(projectPath, 'dir') ~= 7
        mkdir(projectPath);
    end
    ctx.shallow.setPath(projectPath, projectName);
end

args = {'phylocellcontours', logical(p.includeContours)};
if isfield(p, 'positionFilter') && ~isempty(p.positionFilter)
    args = [args {'positionfilter'} {p.positionFilter}];
end
if isfield(p, 'channelFilter') && ~isempty(p.channelFilter)
    args = [args {'channelfilter'} {p.channelFilter}];
end
if isfield(p, 'stackFilter') && ~isempty(p.stackFilter)
    args = [args {'stackfilter'} {p.stackFilter}];
end
if isfield(p, 'positionIdx') && ~isempty(p.positionIdx)
    args = [args {'phylocellpositionidx'} {p.positionIdx}];
end
if isfield(p, 'progress') && ~isempty(p.progress)
    args = [args {'progress'} {p.progress}];
end
tokenFile = cancelTokenFileFromCtx(ctx);
if ~isempty(tokenFile)
    args = [args {'canceltokenfile'} {tokenFile}];
end

detecdiv_check_cancel(ctx, 'phyloCellLoader before parseInputData');
out = parseInputData(parsePath, args{:});
detecdiv_check_cancel(ctx, 'phyloCellLoader after parseInputData');
ctx.dataOutput = out;

ctx.dataLoader = p;
ctx.phyloCellLoader = p;
ctx = dataLoader.process(ctx);

ctx.phyloCell = struct();
ctx.phyloCell.projectRoot = parsePath;
ctx.phyloCell.projectFile = projectFile;
ctx.phyloCell.prefix = prefix;
ctx.phyloCell.includeContours = logical(p.includeContours);

if isfield(ctx, 'shallow') && ~isempty(ctx.shallow) && isprop(ctx.shallow, 'runProfiles')
    rp = ctx.shallow.runProfiles;
    if ~isfield(rp, 'dataloading') || isempty(rp.dataloading)
        rp.dataloading = struct();
    end
    p.projectRoot = parsePath;
    p.projectFile = projectFile;
    p.prefix = prefix;
    rp.dataloading.phyloCellLoader = p;
    ctx.shallow.runProfiles = rp;
end
end

function ctx = useExistingDetecDivProjectSources(ctx, p)
detecdiv_check_cancel(ctx, 'phyloCellLoader use existing project sources');

projectObj = [];
if isfield(ctx, 'shallow') && ~isempty(ctx.shallow) && isa(ctx.shallow, 'shallow')
    projectObj = ctx.shallow;
elseif isfield(ctx, 'shallowObj') && ~isempty(ctx.shallowObj) && isa(ctx.shallowObj, 'shallow')
    projectObj = ctx.shallowObj;
end

if isempty(projectObj)
    error('phyloCellLoader:ExistingProjectRequiresLoadedProject', ...
        ['The phyloCell dataloader is configured to reuse an existing DetecDiv project, ' ...
         'but no DetecDiv project is loaded in the pipeline run context. ' ...
         'Open/select the existing DetecDiv project before running, or switch the runtime input ' ...
         'to "Parse raw images into project" and set the phyloCell path to the *-project.mat file ' ...
         'or to its parent folder.']);
end

ctx.shallow = projectObj;
ctx.shallowObj = projectObj;
ctx.fovList = projectObj.fov;
ctx.images = ctx.fovList;
ctx.dataLoader = p;
ctx.phyloCellLoader = p;

if ~isempty(ctx.fovList)
    try
        fovChannels = ctx.fovList(1).channel;
        if ~isempty(fovChannels)
            ctx.channels = fovChannels;
        elseif ~isfield(ctx, 'channels') || isempty(ctx.channels)
            ctx.channels = {};
        end
    catch
    end
end

if isfield(ctx, 'pipeline') && isstruct(ctx.pipeline)
    ctx.pipeline.nodeStatusOverride = 'skipped_existing';
    ctx.pipeline.nodeMessage = 'Reused the loaded DetecDiv project; phyloCell raw parsing was not run.';
end

if isprop(projectObj, 'runProfiles')
    rp = projectObj.runProfiles;
    if ~isfield(rp, 'dataloading') || isempty(rp.dataloading)
        rp.dataloading = struct();
    end
    rp.dataloading.phyloCellLoader = p;
    projectObj.runProfiles = rp;
end
end

function [parsePath, projectFile, prefix] = normalizePhyloCellPath(pathIn)
pathIn = char(string(pathIn));
parsePath = pathIn;
projectFile = '';
prefix = '';

if exist(pathIn, 'file') == 2
    [folder, name, ext] = fileparts(pathIn);
    if strcmpi(ext, '.mat') && endsWith([name ext], '-project.mat', 'IgnoreCase', true)
        parsePath = folder;
        projectFile = pathIn;
        fname = [name ext];
        prefix = regexprep(fname, '-project\.mat$', '', 'ignorecase');
    else
        [parsePath, projectFile, prefix] = findAncestorPhyloCellProject(folder);
        if isempty(parsePath)
            parsePath = folder;
            prefix = name;
        end
    end
elseif exist(pathIn, 'dir') == 7
    files = dir(fullfile(pathIn, '*-project.mat'));
    files = files(~contains({files.name}, 'BK-project.mat') & ~contains({files.name}, '-project.mat.bk'));
    if ~isempty(files)
        [~, idx] = max([files.datenum]);
        projectFile = fullfile(files(idx).folder, files(idx).name);
        prefix = regexprep(files(idx).name, '-project\.mat$', '', 'ignorecase');
    else
        [ancestorPath, ancestorProjectFile, ancestorPrefix] = findAncestorPhyloCellProject(pathIn);
        if ~isempty(ancestorPath)
            parsePath = ancestorPath;
            projectFile = ancestorProjectFile;
            prefix = ancestorPrefix;
        else
            [~, prefix] = fileparts(pathIn);
        end
    end
end

if isempty(prefix)
    [~, prefix] = fileparts(parsePath);
end
prefix = regexprep(prefix, '[<>:"/\\|?*]', '_');
if isempty(prefix)
    prefix = 'phylocell_project';
end
end

function [parsePath, projectFile, prefix] = findAncestorPhyloCellProject(startPath)
parsePath = '';
projectFile = '';
prefix = '';

cur = char(string(startPath));
if isempty(cur)
    return;
end
cur = char(java.io.File(cur).getCanonicalPath());

for depth = 1:8
    files = dir(fullfile(cur, '*-project.mat'));
    files = files(~contains({files.name}, 'BK-project.mat') & ~contains({files.name}, '-project.mat.bk'));
    if ~isempty(files)
        [~, idx] = max([files.datenum]);
        parsePath = cur;
        projectFile = fullfile(files(idx).folder, files(idx).name);
        prefix = regexprep(files(idx).name, '-project\.mat$', '', 'ignorecase');
        return;
    end
    parent = fileparts(cur);
    if isempty(parent) || strcmp(parent, cur)
        return;
    end
    cur = parent;
end
end

function [projectPath, projectName] = defaultDetecDivProjectTarget(p, parsePath, prefix)
projectName = '';
if isfield(p, 'projectName') && ~isempty(p.projectName)
    projectName = char(string(p.projectName));
end

if isfield(p, 'projectPath') && ~isempty(p.projectPath)
    target = char(string(p.projectPath));
    [pth, name, ext] = fileparts(target);
    if strcmpi(ext, '.mat')
        projectPath = pth;
        if isempty(projectName)
            projectName = name;
        end
    else
        projectPath = target;
    end
else
    projectPath = fullfile(parsePath, ['detecdiv_' prefix]);
end

if isempty(projectName)
    projectName = [prefix '_detecdiv'];
end
projectName = regexprep(projectName, '\.mat$', '', 'ignorecase');
end

function tokenFile = cancelTokenFileFromCtx(ctx)
tokenFile = '';
try
    if isfield(ctx, 'cancel') && isstruct(ctx.cancel) && ...
            isfield(ctx.cancel, 'tokenFile') && ~isempty(ctx.cancel.tokenFile)
        tokenFile = char(string(ctx.cancel.tokenFile));
    end
catch
    tokenFile = '';
end
end

function value = getStructFieldLocal(s, name, defaultValue)
value = defaultValue;
try
    if isstruct(s) && isfield(s, name) && ~isempty(s.(name))
        value = s.(name);
    end
catch
    value = defaultValue;
end
end

function tf = isTrueScalar(value)
tf = false;
try
    if islogical(value) || isnumeric(value)
        tf = isscalar(value) && logical(value);
    elseif ischar(value) || (isstring(value) && isscalar(value))
        txt = strtrim(char(string(value)));
        tf = any(strcmpi(txt, {'1','true','yes','on'}));
    end
catch
    tf = false;
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
