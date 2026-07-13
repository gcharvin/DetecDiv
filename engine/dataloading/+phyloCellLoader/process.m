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
if isfield(ctx, 'path') && ~isempty(ctx.path)
    p.path = char(string(ctx.path));
end
if ~isfield(p, 'includeContours') || isempty(p.includeContours)
    p.includeContours = false;
end

if ~isfield(p, 'path') || isempty(p.path)
    error('phyloCellLoader.process:NoPath', 'No phyloCell project path provided.');
end

[parsePath, projectFile, prefix] = normalizePhyloCellPath(p.path);
if isempty(parsePath) || exist(parsePath, 'dir') ~= 7
    error('phyloCellLoader.process:MissingFolder', ...
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
    args = [args {'positionfilter'} {p.positionFilter}]; %#ok<AGROW>
end
if isfield(p, 'channelFilter') && ~isempty(p.channelFilter)
    args = [args {'channelfilter'} {p.channelFilter}]; %#ok<AGROW>
end
if isfield(p, 'stackFilter') && ~isempty(p.stackFilter)
    args = [args {'stackfilter'} {p.stackFilter}]; %#ok<AGROW>
end
if isfield(p, 'progress') && ~isempty(p.progress)
    args = [args {'progress'} {p.progress}]; %#ok<AGROW>
end
tokenFile = cancelTokenFileFromCtx(ctx);
if ~isempty(tokenFile)
    args = [args {'canceltokenfile'} {tokenFile}]; %#ok<AGROW>
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

function [parsePath, projectFile, prefix] = normalizePhyloCellPath(pathIn)
pathIn = char(string(pathIn));
parsePath = pathIn;
projectFile = '';
prefix = '';

if exist(pathIn, 'file') == 2
    [folder, name, ext] = fileparts(pathIn);
    parsePath = folder;
    projectFile = pathIn;
    fname = [name ext];
    prefix = regexprep(fname, '-project\.mat$', '', 'ignorecase');
elseif exist(pathIn, 'dir') == 7
    files = dir(fullfile(pathIn, '*-project.mat'));
    files = files(~contains({files.name}, 'BK-project.mat') & ~contains({files.name}, '-project.mat.bk'));
    if ~isempty(files)
        [~, idx] = max([files.datenum]);
        projectFile = fullfile(files(idx).folder, files(idx).name);
        prefix = regexprep(files(idx).name, '-project\.mat$', '', 'ignorecase');
    else
        [~, prefix] = fileparts(pathIn);
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

function [projectPath, projectName] = defaultDetecDivProjectTarget(p, parsePath, prefix)
if isfield(p, 'projectPath') && ~isempty(p.projectPath)
    projectPath = char(string(p.projectPath));
else
    projectPath = fullfile(parsePath, ['detecdiv_' prefix]);
end

if isfield(p, 'projectName') && ~isempty(p.projectName)
    projectName = char(string(p.projectName));
else
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
