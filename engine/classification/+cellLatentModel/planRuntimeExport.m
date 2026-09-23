function plan = planRuntimeExport(classif)
%PLANRUNTIMEEXPORT Audit a promoted release for a deterministic runtime export.
% The release must declare every file in runtimePackage.files. This function
% never scans or copies classifier, dataset, project, or experiment folders.

plan = struct('canExport',false,'classifierId','','releaseId','', ...
    'releasePath','','channelPath','','totalBytes',0,'files',struct([]), ...
    'artifactTargets',struct(),'blockers',{{}},'warnings',{{}});

try
    validateClassifier(classif);
    plan.classifierId = char(string(classif.strid));
    sourceSnapshot = fullfile(char(string(classif.path)), ...
        [plan.classifierId '_classification.mat']);
    if ~isfile(sourceSnapshot)
        addBlocker('The source classifier snapshot is missing: %s',sourceSnapshot);
    end

    params = struct();
    try
        if isstruct(classif.executionParam), params = classif.executionParam; end
    catch
    end
    params.modelUpdatePolicy = 'follow_promoted';
    params = cellLatentModel.resolvePromotedRelease(classif,params);
    plan.releasePath = char(string(params.resolvedModelReleaseManifestPath));
    plan.channelPath = char(string(params.modelReleaseChannelPath));
    plan.releaseId = char(string(params.resolvedModelReleaseId));
    if isempty(regexp(plan.releaseId,'^[A-Za-z0-9][A-Za-z0-9._-]*$','once'))
        addBlocker('The promoted release ID is not a portable folder name.');
        plan = finish();
        return;
    end
    if isempty(plan.releasePath) || ~isfile(plan.releasePath)
        addBlocker('The promoted release manifest cannot be resolved.');
        plan = finish();
        return;
    end

    release = jsondecode(fileread(plan.releasePath));
    if ~isfield(release,'runtimePackage') || ...
            ~isstruct(release.runtimePackage) || ...
            ~isscalar(release.runtimePackage)
        addBlocker(['Release %s has no runtimePackage declaration. ' ...
            'Promote it again with the v1 explicit runtime file allowlist.'], ...
            plan.releaseId);
        plan = finish();
        return;
    end
    declaration = release.runtimePackage;
    requireText(declaration,'format', ...
        'detecdiv.cell_latent_model.runtime_package.v1');
    requireText(declaration,'profile','pipeline');
    if ~isfield(declaration,'schemaVersion') || ...
            double(declaration.schemaVersion) ~= 1
        addBlocker('runtimePackage.schemaVersion must be 1.');
    end
    if ~isfield(declaration,'files') || ...
            ~(isstruct(declaration.files) || iscell(declaration.files)) || ...
            isempty(declaration.files)
        addBlocker('runtimePackage.files must list every runtime file.');
    end
    if ~isfield(declaration,'artifactTargets') || ...
            ~isstruct(declaration.artifactTargets)
        addBlocker('runtimePackage.artifactTargets is missing.');
    end
    if ~isempty(plan.blockers), plan = finish(); return; end

    releaseRoot = fileparts(plan.releasePath);
    files = declaration.files;
    plan.artifactTargets = declaration.artifactTargets;
    sourceKeys = strings(0,1);
    targetKeys = strings(0,1);
    planned = repmat(emptyFile(),0,1);
    for i = 1:numel(files)
        if iscell(files)
            entry = files{i};
            if ~isstruct(entry) || ~isscalar(entry)
                addBlocker('runtimePackage.files{%d} must be one object.',i);
                continue;
            end
        else
            entry = files(i);
        end
        sourceRel = textField(entry,'sourcePath');
        targetRel = textField(entry,'targetPath');
        expected = lower(textField(entry,'sha256'));
        if isempty(sourceRel) || isempty(targetRel)
            addBlocker('runtimePackage.files(%d) needs sourcePath and targetPath.',i);
            continue;
        end
        if ~safeRelativePath(targetRel)
            addBlocker('Unsafe runtime target path: %s',targetRel);
            continue;
        end
        if reservedTargetPath(targetRel,plan.releaseId)
            addBlocker('Runtime target uses a reserved bundle path: %s',targetRel);
            continue;
        end
        source = resolveSource(sourceRel,releaseRoot);
        if ~isfile(source)
            addBlocker('Runtime source file does not exist: %s',source);
            continue;
        end
        [~,~,ext] = fileparts(source);
        if ~allowedRuntimeExtension(ext)
            addBlocker('File type is not allowed in a pipeline runtime: %s',sourceRel);
            continue;
        end
        if isTrainingPayloadPath(sourceRel)
            addBlocker('Training/ROI payload cannot be exported: %s',sourceRel);
            continue;
        end
        observedBytes = fileBytes(source);
        expectedBytes = numericField(entry,'bytes',-1);
        if expectedBytes < 0 || observedBytes ~= expectedBytes
            addBlocker('Byte count mismatch for runtime file: %s',sourceRel);
            continue;
        end
        observedHash = sha256File(source);
        if isempty(expected) || ~strcmpi(observedHash,expected)
            addBlocker('SHA-256 mismatch for runtime file: %s',sourceRel);
            continue;
        end
        sourceKey = lower(normalizePath(source));
        targetKey = lower(normalizePath(targetRel));
        if any(sourceKeys == sourceKey)
            addBlocker('Duplicate runtime source file: %s',sourceRel);
            continue;
        end
        if any(targetKeys == targetKey)
            addBlocker('Duplicate runtime target path: %s',targetRel);
            continue;
        end
        sourceKeys(end+1,1) = sourceKey; %#ok<AGROW>
        targetKeys(end+1,1) = targetKey; %#ok<AGROW>
        item = emptyFile();
        item.sourcePath = source;
        item.sourceRelativePath = sourceRel;
        item.targetPath = strrep(targetRel,'\','/');
        item.sha256 = expected;
        item.bytes = observedBytes;
        item.rewrites = getStructArray(entry,'rewrites');
        item.hashes = getStructArray(entry,'hashes');
        item.removeJsonPointers = getCellText(entry,'removeJsonPointers');
        validateJsonOperations(item);
        planned(end+1,1) = item; %#ok<AGROW>
    end

    validateRewriteTargets(planned,plan.artifactTargets);
    validateArtifactCoverage(release,plan.artifactTargets,planned, ...
        plan.releasePath,plan.releaseId);
    validateDirectoryManifestCoverage(release,planned, ...
        plan.artifactTargets,plan.releasePath);
    plan.files = planned;
    plan.totalBytes = sum([planned.bytes]);
catch ME
    addBlocker('%s',ME.message);
end
plan = finish();

    function addBlocker(varargin)
        plan.blockers{end+1,1} = sprintf(varargin{:});
    end

    function value = finish()
        plan.canExport = isempty(plan.blockers) && ~isempty(plan.files);
        value = plan;
    end
end

function validateClassifier(classif)
if ~isa(classif,'classi')
    error('cellLatentModel:InvalidRuntimeExportSource', ...
        'Runtime export requires a classi object.');
end
pkg = '';
try, pkg = char(string(classif.classifierPkg)); catch, end
if ~strcmpi(pkg,'cellLatentModel')
    error('cellLatentModel:InvalidRuntimeExportSource', ...
        'Export Runtime is available only for the cellLatentModel package.');
end
if isempty(strtrim(char(string(classif.strid)))) || ...
        isempty(strtrim(char(string(classif.path))))
    error('cellLatentModel:InvalidRuntimeExportSource', ...
        'Classifier ID and source folder are required.');
end
if isempty(regexp(char(string(classif.strid)), ...
        '^[A-Za-z0-9][A-Za-z0-9._-]*$','once'))
    error('cellLatentModel:InvalidRuntimeExportSource', ...
        'Classifier ID must be a simple portable folder name.');
end
end

function validateArtifactCoverage(release,targets,files,releasePath,releaseId)
if ~isfield(release,'artifacts') || ~isstruct(release.artifacts)
    error('cellLatentModel:InvalidRuntimePackage', ...
        'The promoted release has no artifact list.');
end
for i = 1:numel(release.artifacts)
    entry = release.artifacts(i);
    key = textField(entry,'parameter');
    if isempty(key) || ~isfield(targets,key)
        error('cellLatentModel:InvalidRuntimePackage', ...
            'runtimePackage.artifactTargets must map release artifact "%s".',key);
    end
    target = char(string(targets.(key)));
    requiredPrefix = ['releases/' lower(releaseId) '/artifacts/'];
    if ~safeRelativePath(target) || ...
            ~startsWith(lower(strrep(target,'\','/')),requiredPrefix)
        error('cellLatentModel:InvalidRuntimePackage', ...
            'Artifact target must stay under %s: %s',requiredPrefix,target);
    end
    source = lower(string(normalizePath(resolveSource( ...
        textField(entry,'path'),fileparts(releasePath)))));
    targetKey = lower(string(normalizePath(target)));
    found = false;
    for j = 1:numel(files)
        if strcmpi(normalizePath(files(j).sourcePath),char(source)) && ...
                strcmpi(normalizePath(files(j).targetPath),char(targetKey))
            found = true;
            break;
        end
    end
    if ~found
        error('cellLatentModel:InvalidRuntimePackage', ...
            'Artifact "%s" is not included in runtimePackage.files.',key);
    end
end
end

function validateRewriteTargets(files,targets)
known = lower(string({files.targetPath}));
targetKeys = fieldnames(targets);
for i = 1:numel(targetKeys)
    target = char(string(targets.(targetKeys{i})));
    if ~any(known == lower(string(normalizePath(target))))
        error('cellLatentModel:InvalidRuntimePackage', ...
            'Artifact target is not in runtimePackage.files: %s',target);
    end
end
for i = 1:numel(files)
    rewrites = files(i).rewrites;
    for j = 1:numel(rewrites)
        target = textField(rewrites(j),'targetPath');
        if ~any(known == lower(string(normalizePath(target)))) && ...
                ~isAllowlistedDirectory(files,target)
            error('cellLatentModel:InvalidRuntimePackage', ...
                'JSON rewrite target is not an allowlisted file or directory: %s', ...
                target);
        end
    end
end
for i = 1:numel(files)
    hashes = files(i).hashes;
    for j = 1:numel(hashes)
        target = textField(hashes(j),'targetPath');
        if ~any(known == lower(string(normalizePath(target))))
            error('cellLatentModel:InvalidRuntimePackage', ...
                'JSON hash target is not an allowlisted file: %s',target);
        end
    end
end
end

function tf = isAllowlistedDirectory(files,target)
target = lower(strrep(normalizePath(target),'\','/'));
prefix = string([target '/']);
known = lower(string({files.targetPath}));
tf = any(startsWith(known,prefix));
end

function validateDirectoryManifestCoverage(release,files,targets,releasePath)
if ~isfield(release,'artifacts') || ~isstruct(release.artifacts),return;end
for i = 1:numel(release.artifacts)
    artifact = release.artifacts(i);
    if ~strcmpi(textField(artifact,'kind'),'directory_manifest'),continue;end
    key = textField(artifact,'parameter');
    if ~any(strcmp(key,{'runtimeCodeRoot','trackingCheckpointDir'}))
        error('cellLatentModel:InvalidRuntimePackage', ...
            'Unsupported directory manifest artifact: %s',key);
    end
    key = textField(artifact,'parameter');
    if ~isfield(targets,key)
        error('cellLatentModel:InvalidRuntimePackage', ...
            'Directory-manifest artifact %s is not explicitly included.',key);
    end
    targetManifest = char(string(targets.(key)));
    manifestPath = resolveSource(textField(artifact,'path'),fileparts(releasePath));
    requireListedFile(files,manifestPath,targetManifest);
    payload = jsondecode(fileread(manifestPath));
    if strcmp(key,'runtimeCodeRoot')
        if ~isfield(payload,'generated_files') || ~isstruct(payload.generated_files)
            error('cellLatentModel:InvalidRuntimePackage', ...
                'runtimeCodeRoot manifest has no generated_files list.');
        end
        list = payload.generated_files;
        manifestIndex = find(strcmpi({files.targetPath},targetManifest),1,'first');
        removals = files(manifestIndex).removeJsonPointers;
        removalIndices = validateGeneratedFileRemovals(removals,numel(list));
        for j = 1:numel(list)
            rel = textField(list(j),'path');
            sourceChild = fullfile(fileparts(manifestPath),rel);
            targetChild = fullfile(fileparts(targetManifest),rel);
            listed = isListedFile(files,sourceChild,targetChild);
            removed = any(removalIndices == j-1);
            if listed && removed
                error('cellLatentModel:InvalidRuntimePackage', ...
                    'A runtime code file cannot be both included and removed: %s',rel);
            elseif listed
                requireListedFile(files,sourceChild,targetChild, ...
                    textField(list(j),'sha256'));
            elseif ~removed
                error('cellLatentModel:InvalidRuntimePackage', ...
                    ['Runtime code manifest entry is neither allowlisted nor ' ...
                    'explicitly removed: %s'],rel);
            end
        end
    else
        [names,hashes] = readFlatHashMap(manifestPath,'files');
        if isempty(names)
            error('cellLatentModel:InvalidRuntimePackage', ...
                'Tracking checkpoint manifest has no explicit files map.');
        end
        for j = 1:numel(names)
            requireListedFile(files,fullfile(fileparts(manifestPath),names{j}), ...
                fullfile(fileparts(targetManifest),names{j}),hashes{j});
        end
    end
end
end

function requireListedFile(files,source,target,expectedHash)
if nargin < 4,expectedHash='';end
source = lower(normalizePath(source));
target = lower(normalizePath(target));
found = false;
for i = 1:numel(files)
    if strcmp(lower(normalizePath(files(i).sourcePath)),source) && ...
            strcmp(lower(normalizePath(files(i).targetPath)),target)
        if ~isempty(expectedHash) && ...
                ~strcmpi(textField(files(i),'sha256'),expectedHash)
            error('cellLatentModel:InvalidRuntimePackage', ...
                'Declared file checksum differs from source manifest: %s',source);
        end
        found = true;
        break;
    end
end

function found = isListedFile(files,source,target)
source = lower(normalizePath(source));
target = lower(normalizePath(target));
found = false;
for i = 1:numel(files)
    if strcmp(lower(normalizePath(files(i).sourcePath)),source) && ...
            strcmp(lower(normalizePath(files(i).targetPath)),target)
        found = true;
        return;
    end
end
end

function indices = validateGeneratedFileRemovals(removals,count)
indices = zeros(0,1);
for i = 1:numel(removals)
    pointer = char(string(removals{i}));
    if ~startsWith(pointer,'/generated_files/'),continue;end
    token = regexp(pointer,'^/generated_files/(\d+)$','tokens','once');
    if isempty(token)
        error('cellLatentModel:InvalidRuntimePackage', ...
            'Invalid runtime-code manifest removal pointer: %s',pointer);
    end
    index = str2double(token{1});
    if ~isfinite(index) || index < 0 || index >= count || index ~= floor(index)
        error('cellLatentModel:InvalidRuntimePackage', ...
            'Runtime-code manifest removal index is out of range: %s',pointer);
    end
    indices(end+1,1) = index; %#ok<AGROW>
end
if any(diff(indices) >= 0)
    error('cellLatentModel:InvalidRuntimePackage', ...
        'generated_files array removals must be unique and descending.');
end
end
if ~found
    error('cellLatentModel:InvalidRuntimePackage', ...
        'Manifest-listed runtime file is absent from allowlist: %s',source);
end
end

function [names,hashes] = readFlatHashMap(path,key)
raw = fileread(path);
pattern = ['"' regexptranslate('escape',key) '"\s*:\s*\{([^}]*)\}'];
token = regexp(raw,pattern,'tokens','once');
names = {};
hashes = {};
if isempty(token),return;end
pairs = regexp(token{1},'"([^"]+)"\s*:\s*"([A-Fa-f0-9]{64})"', ...
    'tokens');
for i = 1:numel(pairs)
    names{end+1} = pairs{i}{1}; %#ok<AGROW>
    hashes{end+1} = lower(pairs{i}{2}); %#ok<AGROW>
end
end

function validateJsonOperations(item)
[~,~,ext] = fileparts(item.targetPath);
if (~isempty(item.rewrites) || ~isempty(item.hashes) || ...
        ~isempty(item.removeJsonPointers)) && ...
        ~strcmpi(ext,'.json')
    error('cellLatentModel:InvalidRuntimePackage', ...
        'JSON rewrites can only target JSON files: %s',item.targetPath);
end

for i = 1:numel(item.hashes)
    hashPointer = textField(item.hashes(i),'jsonPointer');
    target = textField(item.hashes(i),'targetPath');
    if isempty(hashPointer) || hashPointer(1) ~= '/' || ...
            ~safeRelativePath(target)
        error('cellLatentModel:InvalidRuntimePackage', ...
            'Invalid JSON hash reference in %s.',item.targetPath);
    end
end

for i = 1:numel(item.rewrites)
    rewrite = item.rewrites(i);
    pointer = textField(rewrite,'jsonPointer');
    target = textField(rewrite,'targetPath');
    if isempty(pointer) || ~safeRelativePath(target)
        error('cellLatentModel:InvalidRuntimePackage', ...
            'Invalid JSON rewrite in %s.',item.targetPath);
    end
end
for i = 1:numel(item.removeJsonPointers)
    if isempty(item.removeJsonPointers{i}) || ...
            item.removeJsonPointers{i}(1) ~= '/'
        error('cellLatentModel:InvalidRuntimePackage', ...
            'Invalid JSON pointer removal in %s.',item.targetPath);
    end
end
end

function item = emptyFile()
item = struct('sourcePath','','sourceRelativePath','','targetPath','', ...
    'sha256','','bytes',0,'rewrites',struct([]),'hashes',struct([]), ...
    'removeJsonPointers',{{}});
end

function value = resolveSource(value,root)
value = strtrim(char(string(value)));
if isempty(value),return;end
if isempty(regexp(value,'^[A-Za-z]:[\\/]|^[/\\]{2}|^/','once'))
    value = fullfile(root,value);
end
end

function tf = safeRelativePath(value)
value = strrep(char(string(value)),'\','/');
tf = ~isempty(value) && ~startsWith(value,'/') && ...
    isempty(regexp(value,'^[A-Za-z]:','once')) && ...
    ~any(strcmp(strsplit(value,'/'),'..')) && ...
    ~contains(value,':') && ~contains(value,char(0));
end

function tf = reservedTargetPath(value,releaseId)
value = lower(strrep(char(string(value)),'\','/'));
artifactPrefix = ['releases/' lower(char(string(releaseId))) '/artifacts/'];
isReleasePayload = startsWith(value,artifactPrefix);
tf = startsWith(value,'classifier/') || ...
    (startsWith(value,'releases/') && ~isReleasePayload) || ...
    strcmp(value,'runtime_manifest.json');
end

function tf = allowedRuntimeExtension(ext)
allowed = {'.json','.py','.pt','.pth','.pkl','.pickle','.yaml','.yml', ...
    '.toml','.ini','.txt','.md','.cfg','.npz','.mat','.joblib'};
tf = any(strcmpi(ext,allowed));
end

function tf = isTrainingPayloadPath(path)
parts = lower(string(strsplit(strrep(char(string(path)),'\','/'),'/')));
denied = ["trainingdataset","training_data","training-data","roi","rois", ...
    "datasets","annotations","gt","ground_truth"];
tf = any(ismember(parts,denied));
end

function n = fileBytes(path)
info = dir(path);
n = double(info.bytes);
end

function digest = sha256File(path)
engine = java.security.MessageDigest.getInstance('SHA-256');
file = java.io.File(path);
content = javaMethod('readAllBytes','java.nio.file.Files',file.toPath());
bytes = typecast(engine.digest(content),'uint8');
digest = lower(reshape(dec2hex(bytes,2).',1,[]));
end

function value = numericField(source,key,fallback)
value = fallback;
try
    raw = source.(key);
    if isnumeric(raw) && isscalar(raw) && isfinite(raw),value = double(raw);end
catch
end
end

function value = textField(source,key)
value = '';
try
    if isstruct(source) && isfield(source,key)
        raw = source.(key);
        while iscell(raw)
            if isempty(raw),return;end
            raw = raw{end};
        end
        value = strtrim(char(string(raw)));
    end
catch
end
end

function values = getCellText(source,key)
values = {};
try
    raw = source.(key);
    if iscell(raw),values = cellfun(@(x)char(string(x)),raw,'UniformOutput',false);
    elseif isstring(raw),values = cellstr(raw(:));
    elseif ischar(raw),values = {raw};
    end
catch
end
end

function values = getStructArray(source,key)
values = struct([]);
try
    if isfield(source,key) && isstruct(source.(key)),values = source.(key);end
catch
end
end

function requireText(payload,key,expected)
actual = textField(payload,key);
if ~strcmp(actual,expected)
    error('cellLatentModel:InvalidRuntimePackage', ...
        'Expected runtimePackage.%s="%s", observed "%s".', ...
        key,expected,actual);
end
end

function value = normalizePath(value)
value = strrep(char(string(value)),'\','/');
value = regexprep(value,'/+', '/');
end
