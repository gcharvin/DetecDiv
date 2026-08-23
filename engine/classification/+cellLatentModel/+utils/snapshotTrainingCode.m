function record = snapshotTrainingCode(bundleDir,varargin)
%SNAPSHOTTRAININGCODE Freeze the exact training source beside a model.
%   The snapshot contains source/configuration only: no Git internals,
%   caches, tests, weights, model artifacts or scientific data.  It is
%   published atomically and an existing snapshot is never overwritten.

options = parseOptions(varargin{:});
bundleDir = char(string(bundleDir));
if ~isfolder(bundleDir)
    error('cellLatentModel:MissingBundleDirectory', ...
        'Cannot snapshot training code below missing bundle %s.',bundleDir);
end
detecdivRoot = options.DetecDivRepo;
if isempty(detecdivRoot), detecdivRoot = detecdivRepoRoot(); end
cellRepo = options.CellLatentModelRepo;
if isempty(cellRepo), cellRepo = resolveCellRepo(options.Context,detecdivRoot); end
assertRepository(cellRepo,'cell_latent_model', ...
    fullfile('src','cell_latent_model'));
assertRepository(detecdivRoot,'DetecDiv', ...
    fullfile('engine','classification','+cellLatentModel'));

snapshotDir = fullfile(bundleDir,'code_snapshot');
if isfolder(snapshotDir) || isfile(snapshotDir)
    error('cellLatentModel:CodeSnapshotExists', ...
        'The immutable code snapshot already exists: %s',snapshotDir);
end
stageDir = fullfile(bundleDir, ...
    ['.cs_' char(java.util.UUID.randomUUID)]);
mkdir(stageDir);
cleanup = onCleanup(@()removeFolder(stageDir));

before = [gitMetadata(cellRepo,'cell_latent_model'); ...
    gitMetadata(detecdivRoot,'detecdiv')];
specs = [cellModelFiles(cellRepo); detecdivFiles(detecdivRoot)];
specs = sortSpecs(specs);
files = repmat(fileRecord(),0,1);
for index = 1:numel(specs)
    source = fullfile(specs(index).repo_root, ...
        strrep(specs(index).source_relative_path,'/',filesep));
    destination = fullfile(stageDir, ...
        strrep(specs(index).snapshot_relative_path,'/',filesep));
    if ispc && numel(destination) >= 248
        error('cellLatentModel:CodeSnapshotPathTooLong', ...
            'Snapshot path exceeds the safe Windows limit (%d): %s', ...
            numel(destination),destination);
    end
    parent = fileparts(destination);
    if ~isfolder(parent), mkdir(parent); end
    sourceHash = fileSha256(source);
    [ok,message] = copyfile(source,destination);
    if ~ok
        error('cellLatentModel:CodeSnapshotCopyFailed', ...
            'Cannot copy %s: %s',source,message);
    end
    copiedHash = fileSha256(destination);
    if isempty(sourceHash) || ~strcmp(sourceHash,copiedHash)
        error('cellLatentModel:CodeSnapshotHashMismatch', ...
            'Source changed while copying %s.',source);
    end
    info = dir(destination);
    row = fileRecord();
    row.repository = specs(index).repository;
    row.role = specs(index).role;
    row.source_relative_path = specs(index).source_relative_path;
    row.snapshot_relative_path = specs(index).snapshot_relative_path;
    row.sha256 = copiedHash;
    row.bytes = double(info.bytes);
    files(end+1,1) = row; %#ok<AGROW>
end

after = [gitMetadata(cellRepo,'cell_latent_model'); ...
    gitMetadata(detecdivRoot,'detecdiv')];
for index = 1:numel(before)
    if ~strcmp(before(index).git_head,after(index).git_head) || ...
            ~strcmp(before(index).git_status_sha256, ...
                after(index).git_status_sha256)
        error('cellLatentModel:CodeChangedDuringSnapshot', ...
            'Repository %s changed while its code was being snapshotted.', ...
            before(index).repository);
    end
end

payload = struct( ...
    'schema_version',1, ...
    'format','detecdiv_training_code_snapshot_v1', ...
    'created_at',char(datetime('now','TimeZone','UTC', ...
        'Format','yyyy-MM-dd''T''HH:mm:ss.SSSXXX')), ...
    'repositories',before, ...
    'files',files, ...
    'file_count',double(numel(files)), ...
    'total_bytes',sum([files.bytes]), ...
    'content_tree_sha256',treeSha256(files), ...
    'selection_policy',struct( ...
        'cell_latent_model', ...
            'src/**/*.py + pyproject.toml + uv.lock + configs/*', ...
        'detecdiv', ...
            ['+cellLatentModel/**/*.m + +cellLatentTracker/**/*.m + ' ...
             '+classifierBinding/**/*.m + selected persistence IO'], ...
        'excluded',{{'.git','cache','__pycache__','*.pyc','tests', ...
            'weights','models','artifacts','scientific data'}}));
manifest = fullfile(stageDir,'manifest.json');
writeJson(manifest,payload);
try
    jsondecode(fileread(manifest));
catch ME
    error('cellLatentModel:InvalidCodeSnapshotManifest', ...
        'Cannot validate code snapshot manifest %s: %s',manifest,ME.message);
end
if isfolder(snapshotDir) || isfile(snapshotDir)
    error('cellLatentModel:CodeSnapshotExists', ...
        'The immutable code snapshot already exists: %s',snapshotDir);
end
[ok,message] = movefile(stageDir,snapshotDir);
if ~ok
    error('cellLatentModel:CodeSnapshotPublishFailed', ...
        'Cannot publish code snapshot %s: %s',snapshotDir,message);
end
clear cleanup;

manifest = fullfile(snapshotDir,'manifest.json');
record = struct( ...
    'schema_version',1, ...
    'format','detecdiv_training_code_snapshot_v1', ...
    'root',normalizedPath(snapshotDir), ...
    'manifest',normalizedPath(manifest), ...
    'manifest_sha256',fileSha256(manifest), ...
    'content_tree_sha256',payload.content_tree_sha256, ...
    'file_count',payload.file_count, ...
    'total_bytes',payload.total_bytes, ...
    'repositories',before);
end

function options = parseOptions(varargin)
context = struct();
if ~isempty(varargin) && isstruct(varargin{1})
    context = varargin{1};
    varargin(1) = [];
end
parser = inputParser;
parser.addParameter('Context',context,@isstruct);
parser.addParameter('CellLatentModelRepo','',@(x)ischar(x)||isstring(x));
parser.addParameter('DetecDivRepo','',@(x)ischar(x)||isstring(x));
parser.parse(varargin{:});
options = parser.Results;
options.CellLatentModelRepo = char(string(options.CellLatentModelRepo));
options.DetecDivRepo = char(string(options.DetecDivRepo));
end

function root = resolveCellRepo(context,detecdivRoot)
root = '';
try root = char(string(context.repositoryRoot)); catch, end
if isempty(root)
    try root = char(string(context.resolvedPythonRuntime.repositoryRoot)); catch, end
end
if isempty(root), root = strtrim(getenv('CELL_LATENT_MODEL_REPO_ROOT')); end
if isempty(root)
    candidate = fullfile(fileparts(detecdivRoot),'cell_latent_model');
    if isfolder(fullfile(candidate,'src','cell_latent_model')), root=candidate; end
end
end

function root = detecdivRepoRoot()
root = mfilename('fullpath');
for index = 1:5, root = fileparts(root); end
end

function assertRepository(root,label,requiredRelative)
root = char(string(root));
if isempty(root) || ~isfolder(fullfile(root,requiredRelative))
    error('cellLatentModel:CodeRepositoryUnavailable', ...
        'Cannot locate the %s source repository (received "%s").',label,root);
end
end

function specs = cellModelFiles(root)
specs = repmat(fileSpec(),0,1);
pythonRoot = fullfile(root,'src');
entries = dir(fullfile(pythonRoot,'**','*.py'));
for index = 1:numel(entries)
    if entries(index).isdir, continue; end
    source = fullfile(entries(index).folder,entries(index).name);
    relative = relativePath(root,source);
    if hasExcludedPart(relative), continue; end
    packageRelative = relativePath(fullfile(root,'src'),source);
    specs(end+1,1) = makeSpec('cell_latent_model',root,relative, ...
        ['clm/s/' packageRelative],'python_training_source'); %#ok<AGROW>
end
rootFiles = {'pyproject.toml','uv.lock'};
for index = 1:numel(rootFiles)
    source = fullfile(root,rootFiles{index});
    if isfile(source)
        specs(end+1,1) = makeSpec('cell_latent_model',root, ...
            rootFiles{index},['clm/' rootFiles{index}], ...
            'python_environment_config'); %#ok<AGROW>
    end
end
configRoot = fullfile(root,'configs');
if isfolder(configRoot)
    entries = dir(fullfile(configRoot,'**','*'));
    allowed = {'.json','.yaml','.yml','.toml'};
    for index = 1:numel(entries)
        if entries(index).isdir, continue; end
        source = fullfile(entries(index).folder,entries(index).name);
        [~,~,extension] = fileparts(source);
        if ~ismember(lower(extension),allowed), continue; end
        relative = relativePath(root,source);
        configRelative = relativePath(configRoot,source);
        specs(end+1,1) = makeSpec('cell_latent_model',root,relative, ...
            ['clm/c/' configRelative],'python_training_config'); %#ok<AGROW>
    end
end
end

function specs = detecdivFiles(root)
specs = repmat(fileSpec(),0,1);
groups = { ...
    fullfile('engine','classification','+cellLatentModel'),'dd/lm', ...
        'detecdiv_latent_model'; ...
    fullfile('engine','classification','+cellLatentTracker'),'dd/lt', ...
        'detecdiv_latent_tracker'; ...
    fullfile('engine','classification','+classifierBinding'),'dd/cb', ...
        'detecdiv_classifier_binding'};
for groupIndex = 1:size(groups,1)
    sourceRoot = fullfile(root,groups{groupIndex,1});
    entries = dir(fullfile(sourceRoot,'**','*.m'));
    for index = 1:numel(entries)
        if entries(index).isdir, continue; end
        source = fullfile(entries(index).folder,entries(index).name);
        relative = relativePath(root,source);
        if hasExcludedPart(relative), continue; end
        packageRelative = relativePath(sourceRoot,source);
        specs(end+1,1) = makeSpec('detecdiv',root,relative, ...
            [groups{groupIndex,2} '/' packageRelative], ...
            groups{groupIndex,3}); %#ok<AGROW>
    end
end
ioFiles = { ...
    'classifierApplyTrainingExecutionDefaults.m', ...
    'classifierPersistTrainingExecutionDefaults.m', ...
    'classifierPersistTrainingResult.m', ...
    'classifierTrainingExecutionDefaults.m'};
for index = 1:numel(ioFiles)
    relative = normalizedPath(fullfile('structure','io',ioFiles{index}));
    source = fullfile(root,strrep(relative,'/',filesep));
    if ~isfile(source)
        error('cellLatentModel:CodeSnapshotSourceMissing', ...
            'Required training persistence source is missing: %s',source);
    end
    specs(end+1,1) = makeSpec('detecdiv',root,relative, ...
        ['dd/io/' ioFiles{index}],'detecdiv_training_persistence'); %#ok<AGROW>
end
end

function tf = hasExcludedPart(relative)
parts = lower(split(string(normalizedPath(relative)),'/'));
tf = any(ismember(parts,[".git",".cache","__pycache__", ...
    ".pytest_cache",".ruff_cache",".venv","build", ...
    "cell_latent_model.egg-info","tests","artifacts","data", ...
    "models","weights","checkpoints"]));
end

function value = relativePath(root,path)
root = normalizedPath(root);
path = normalizedPath(path);
prefix = [regexprep(root,'/+$','') '/'];
if ispc
    below = startsWith(path,prefix,'IgnoreCase',true);
else
    below = startsWith(path,prefix);
end
if ~below
    error('cellLatentModel:CodeSnapshotSourceEscapesRepository', ...
        'Source %s is outside repository %s.',path,root);
end
value = path(numel(prefix)+1:end);
end

function row = makeSpec(repository,root,sourceRelative,targetRelative,role)
row = fileSpec();
row.repository = repository;
row.repo_root = char(string(root));
row.source_relative_path = normalizedPath(sourceRelative);
row.snapshot_relative_path = normalizedPath(targetRelative);
row.role = role;
end

function value = fileSpec()
value = struct('repository','','repo_root','', ...
    'source_relative_path','','snapshot_relative_path','','role','');
end

function specs = sortSpecs(specs)
if isempty(specs), return; end
[~,order] = sort(lower(string({specs.snapshot_relative_path})));
specs = specs(order);
targets = string({specs.snapshot_relative_path});
if numel(unique(lower(targets))) ~= numel(targets)
    error('cellLatentModel:CodeSnapshotCollision', ...
        'Two source files map to the same snapshot path.');
end
end

function row = fileRecord()
row = struct('repository','','role','','source_relative_path','', ...
    'snapshot_relative_path','','sha256','','bytes',0);
end

function metadata = gitMetadata(root,repository)
metadata = struct('repository',repository, ...
    'source_root',normalizedPath(root), ...
    'git_available',false,'git_head','', ...
    'working_tree_dirty',false,'git_status_porcelain',{{}}, ...
    'git_status_sha256','');
[status,head] = gitCommand(root,'rev-parse HEAD');
if status ~= 0, return; end
[status,statusText] = gitCommand(root, ...
    'status --porcelain=v1 --untracked-files=all');
if status ~= 0, return; end
statusText = strrep(statusText,[char(13) char(10)],newline);
statusText = regexprep(statusText,'\n+$','');
entries = {};
if ~isempty(statusText), entries=cellstr(splitlines(string(statusText))); end
metadata.git_available = true;
metadata.git_head = strtrim(head);
metadata.working_tree_dirty = ~isempty(entries);
metadata.git_status_porcelain = entries(:).';
metadata.git_status_sha256 = sha256Text(statusText);
end

function [status,output] = gitCommand(root,arguments)
root = strrep(char(string(root)),'"','');
command = sprintf('git -C "%s" %s 2>&1',root,arguments);
[status,output] = system(command);
end

function value = treeSha256(files)
lines = strings(numel(files),1);
for index = 1:numel(files)
    lines(index) = string(files(index).snapshot_relative_path) + "|" + ...
        string(files(index).sha256) + "|" + string(files(index).bytes);
end
value = sha256Text(char(strjoin(lines,newline)));
end

function value = sha256Text(text)
bytes = unicode2native(char(string(text)),'UTF-8');
digest = java.security.MessageDigest.getInstance('SHA-256');
if isempty(bytes)
    hash = typecast(digest.digest(),'uint8');
else
    hash = typecast(digest.digest(uint8(bytes)),'uint8');
end
value = lower(reshape(dec2hex(hash,2).',1,[]));
end

function value = fileSha256(filename)
fid = fopen(filename,'r');
if fid < 0, value=''; return; end
cleanup = onCleanup(@()fclose(fid));
bytes = fread(fid,Inf,'*uint8');
digest = java.security.MessageDigest.getInstance('SHA-256');
if isempty(bytes)
    hash = typecast(digest.digest(),'uint8');
else
    hash = typecast(digest.digest(bytes),'uint8');
end
value = lower(reshape(dec2hex(hash,2).',1,[]));
end

function writeJson(filename,value)
fid = fopen(filename,'w','n','UTF-8');
if fid < 0
    error('cellLatentModel:CodeSnapshotManifestWriteFailed', ...
        'Cannot write snapshot manifest %s.',filename);
end
cleanup = onCleanup(@()fclose(fid));
encoded=jsonencode(value,'PrettyPrint',true);
written=fwrite(fid,encoded,'char');
if written~=numel(encoded)
    error('cellLatentModel:CodeSnapshotManifestWriteFailed', ...
        'Incomplete snapshot manifest write (%d/%d characters).', ...
        written,numel(encoded));
end
end

function value = normalizedPath(value)
value = strrep(char(string(value)),'\','/');
while numel(value)>3 && endsWith(value,'/'), value(end)=[]; end
end

function removeFolder(folder)
if isfolder(folder), try rmdir(folder,'s'); catch, end, end
end
