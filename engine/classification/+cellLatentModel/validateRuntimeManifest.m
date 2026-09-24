function report = validateRuntimeManifest(bundleRoot)
%VALIDATERUNTIMEMANIFEST Verify an exported v1 latent-model runtime bundle.

bundleRoot = char(string(bundleRoot));
% uigetfile returns a folder with a trailing separator. Normalize it before
% comparing recursive dir() entries with manifest-relative paths below.
bundleRoot = regexprep(bundleRoot,'[\\/]+$','');
manifestPath = fullfile(bundleRoot,'runtime_manifest.json');
if ~isfolder(bundleRoot) || ~isfile(manifestPath)
    error('cellLatentModel:InvalidRuntimeBundle', ...
        'Runtime bundle manifest is missing: %s',manifestPath);
end
manifest = readJson(manifestPath);
requireText(manifest,'format','detecdiv.cell_latent_model.runtime_bundle.v1');
requireText(manifest,'profile','pipeline');
if ~isfield(manifest,'schemaVersion') || double(manifest.schemaVersion) ~= 1
    invalid('schemaVersion must be 1.');
end
classifierId = textField(manifest,'classifierId');
releaseId = textField(manifest,'releaseId');
if isempty(regexp(classifierId,'^[A-Za-z0-9][A-Za-z0-9._-]*$','once')) || ...
        isempty(regexp(releaseId,'^[A-Za-z0-9][A-Za-z0-9._-]*$','once'))
    invalid('classifierId and releaseId are required.');
end
files = manifest.files;
if ~isstruct(files) || isempty(files),invalid('files must be a non-empty list.');end
seen = strings(0,1);
totalBytes = 0;
for i = 1:numel(files)
    rel = textField(files(i),'path');
    if ~safeRelativePath(rel),invalid('Unsafe file path in manifest: %s',rel);end
    key = lower(normalizePath(rel));
    if any(seen == key),invalid('Duplicate file path in manifest: %s',rel);end
    seen(end+1,1) = key; %#ok<AGROW>
    path = fullfile(bundleRoot,strrep(rel,'/',filesep));
    assertInsideRoot(bundleRoot,path);
    if ~isfile(path),invalid('Bundle file is missing: %s',rel);end
    assertRuntimeFilePath(rel,classifierId,releaseId);
    expectedBytes = numericField(files(i),'bytes',-1);
    expectedHash = lower(textField(files(i),'sha256'));
    info = dir(path);
    if expectedBytes < 0 || double(info.bytes) ~= expectedBytes
        invalid('Byte count mismatch for bundle file: %s',rel);
    end
    if isempty(expectedHash) || ~strcmpi(sha256File(path),expectedHash)
        invalid('SHA-256 mismatch for bundle file: %s',rel);
    end
    totalBytes = totalBytes + double(info.bytes);
end

pointer = fullfile(bundleRoot,'releases','detecdiv_stable.json');
if ~isfile(pointer),invalid('Stable release pointer is missing.');end
channel = readJson(pointer);
requireText(channel,'format','detecdiv.cell_latent_model.channel.v1');
requireText(channel,'channel','stable');
if ~strcmp(textField(channel,'releaseId'),releaseId)
    invalid('Stable pointer and runtime manifest release IDs differ.');
end
relativeRelease = textField(channel,'releaseManifest');
if ~safeRelativePath(relativeRelease),invalid('Unsafe release-manifest pointer.');end
releasePath = fullfile(fileparts(pointer),strrep(relativeRelease,'/',filesep));
assertInsideRoot(bundleRoot,releasePath);
expectedReleaseHash = lower(textField(channel,'releaseManifestSha256'));
if ~isfile(releasePath) || ~strcmpi(sha256File(releasePath),expectedReleaseHash)
    invalid('Promoted release manifest is missing or has a checksum mismatch.');
end
release = readJson(releasePath);
if ~strcmp(textField(release,'releaseId'),releaseId)
    invalid('Release manifest and runtime manifest IDs differ.');
end
assertNoAbsolutePaths(release,releasePath);
verifyReleaseArtifacts(release,fileparts(releasePath),bundleRoot);

classifierSnapshot = fullfile(bundleRoot,'classifier',classifierId, ...
    [classifierId '_classification.mat']);
if ~isfile(classifierSnapshot)
    invalid('Reduced runtime classifier snapshot is missing.');
end
verifyReducedClassifierSnapshot(classifierSnapshot);
loadedClassifier = load(classifierSnapshot,'classiObj');
% Resolve from the bundle root being validated. During export this may be the
% staging directory, while the embedded classifier path already names the
% final destination that will receive the staged bundle.
loadedClassifier.classiObj.path = fullfile(bundleRoot,'classifier',classifierId);
try
    resolvedClassifier = cellLatentModel.resolvePromotedRelease( ...
        loadedClassifier.classiObj,loadedClassifier.classiObj.executionParam);
catch ME
    invalid('Runtime classifier cannot resolve its packaged release: %s', ...
        ME.message);
end
if ~strcmp(textField(resolvedClassifier,'resolvedModelReleaseId'),releaseId)
    invalid('Runtime classifier resolves a different promoted release.');
end
required = {'releases/detecdiv_stable.json', ...
    ['releases/' strrep(relativeRelease,'\','/')], ...
    ['classifier/' classifierId '/' classifierId '_classification.mat']};
for i = 1:numel(required)
    if ~any(seen == lower(normalizePath(required{i})))
        invalid('Required runtime file is absent from manifest: %s',required{i});
    end
end
verifyNoUnlistedFiles(bundleRoot,seen);
report = struct('valid',true,'bundleRoot',string(bundleRoot), ...
    'classifierId',string(classifierId),'releaseId',string(releaseId), ...
    'fileCount',numel(files),'totalBytes',totalBytes);
end

function assertRuntimeFilePath(rel,classifierId,releaseId)
parts = lower(string(strsplit(strrep(rel,'\','/'),'/')));
forbidden = ["trainingdataset","training_data","training-data","datasets", ...
    "detecdiv_projects","annotations","roi","rois","ground_truth"];
if any(ismember(parts,forbidden))
    invalid('Training or annotation payload is forbidden in runtime bundle: %s',rel);
end
[~,~,ext] = fileparts(rel);
normalized = lower(strrep(normalizePath(rel),'\','/'));
parts = strsplit(normalized,'/');
isReleaseArtifact = numel(parts) >= 4 && ...
    strcmp(parts{1},'releases') && strcmpi(parts{2},releaseId) && ...
    strcmp(parts{3},'artifacts');
if strcmpi(ext,'.mat')
    expected = ['classifier/' classifierId '/' classifierId '_classification.mat'];
    if ~strcmpi(normalizePath(rel),normalizePath(expected)) && ...
            ~isReleaseArtifact
        invalid(['MAT files are allowed only for the reduced classifier ' ...
            'snapshot or an explicit release artifact: %s'],rel);
    end
elseif strcmpi(ext,'.npz')
    if ~isReleaseArtifact
        invalid('NPZ files are allowed only as explicit release artifacts: %s',rel);
    end
elseif ~any(strcmpi(ext,{'.json','.py','.pt','.pth','.pkl','.pickle', ...
        '.yaml','.yml','.toml','.ini','.txt','.md','.cfg','.joblib'}))
    invalid('Unsupported file type in runtime bundle: %s',rel);
end
end

function verifyReleaseArtifacts(release,releaseRoot,bundleRoot)
if ~isfield(release,'artifacts') || ~isstruct(release.artifacts)
    invalid('Runtime release has no artifacts list.');
end
for i = 1:numel(release.artifacts)
    artifact = release.artifacts(i);
    rel = textField(artifact,'path');
    if ~safeRelativePath(rel)
        invalid('Release artifact path is not bundle-relative: %s',rel);
    end
    path = fullfile(releaseRoot,strrep(rel,'/',filesep));
    assertInsideRoot(bundleRoot,path);
    if ~isfile(path) || ~strcmpi(sha256File(path), ...
            lower(textField(artifact,'sha256')))
        invalid('Runtime release artifact is missing or changed: %s',rel);
    end
    kind = lower(textField(artifact,'kind'));
    if strcmp(kind,'directory_manifest')
        payload = readJson(path);
        if strcmp(textField(artifact,'parameter'),'runtimeCodeRoot')
            if ~isfield(payload,'generated_files') || ~isstruct(payload.generated_files)
                invalid('Runtime code manifest has no generated_files list.');
            end
            files = payload.generated_files;
            for j = 1:numel(files)
                relative = textField(files(j),'path');
                verifyManifestFile(path,relative,textField(files(j),'sha256'),bundleRoot);
            end
        elseif strcmp(textField(artifact,'parameter'),'trackingCheckpointDir')
            [names,hashes] = readFlatHashMap(path,'files');
            if isempty(names)
                invalid('Tracking manifest has no runtime files map.');
            end
            for j = 1:numel(names)
                verifyManifestFile(path,names{j},hashes{j},bundleRoot);
            end
        else
            invalid('Unsupported directory-manifest artifact: %s', ...
                textField(artifact,'parameter'));
        end
    elseif ~strcmp(kind,'file')
        invalid('Unsupported artifact kind: %s',kind);
    end
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

function verifyManifestFile(manifestPath,relative,expected,bundleRoot)
if ~safeRelativePath(relative),invalid('Unsafe nested artifact path: %s',relative);end
path = fullfile(fileparts(manifestPath),strrep(relative,'/',filesep));
assertInsideRoot(bundleRoot,path);
if ~isfile(path) || ~strcmpi(sha256File(path),lower(char(string(expected))))
    invalid('Nested runtime artifact is missing or changed: %s',relative);
end
end

function verifyReducedClassifierSnapshot(path)
loaded = load(path,'classiObj');
if ~isfield(loaded,'classiObj') || ~isa(loaded.classiObj,'classi')
    invalid('Runtime classifier snapshot is malformed.');
end
classif = loaded.classiObj;
try
    if ~isempty(classif.trainingset) || ~isempty(classif.trainingParam)
        invalid('Runtime classifier snapshot contains training state.');
    end
    if isstruct(classif.run) && ...
            ((isfield(classif.run,'active') && logical(classif.run.active)) || ...
             (isfield(classif.run,'runDir') && ~isempty(classif.run.runDir)) || ...
             (isfield(classif.run,'runDirAbs') && ~isempty(classif.run.runDirAbs)))
        invalid('Runtime classifier snapshot contains a training-run reference.');
    end
    if isstruct(classif.dataset) && isfield(classif.dataset,'split')
        split = classif.dataset.split;
        if (isfield(split,'train') && ~isempty(split.train)) || ...
                (isfield(split,'val') && ~isempty(split.val)) || ...
                (isfield(split,'test') && ~isempty(split.test))
            invalid('Runtime classifier snapshot contains dataset splits.');
        end
    end
    for i = 1:numel(classif.roi)
        if ~isempty(classif.roi(i).id)
            invalid('Runtime classifier snapshot contains ROI records.');
        end
    end
catch ME
    if strcmp(ME.identifier,'cellLatentModel:InvalidRuntimeBundle'),rethrow(ME);end
    invalid('Could not verify reduced classifier snapshot: %s',ME.message);
end
end

function verifyNoUnlistedFiles(root,listed)
entries = dir(fullfile(root,'**','*'));
actual = strings(0,1);
for i = 1:numel(entries)
    if entries(i).isdir,continue;end
    absolute = fullfile(entries(i).folder,entries(i).name);
    rel = erase(absolute,[root filesep]);
    rel = strrep(rel,'\','/');
    if strcmpi(rel,'runtime_manifest.json'),continue;end
    actual(end+1,1) = lower(normalizePath(rel)); %#ok<AGROW>
end
if numel(actual) ~= numel(listed) || any(~ismember(actual,listed))
    invalid('Runtime bundle contains files not represented by its manifest.');
end
end

function assertInsideRoot(root,path)
try
    canonicalRoot = char(java.io.File(root).getCanonicalPath());
    canonicalPath = char(java.io.File(path).getCanonicalPath());
catch
    canonicalRoot = root;
    canonicalPath = path;
end
prefix = [canonicalRoot filesep];
if ~startsWith(lower(canonicalPath),lower(prefix))
    invalid('Bundle path escapes its root: %s',path);
end
end

function assertNoAbsolutePaths(value,label)
if isstruct(value)
    for i = 1:numel(value)
        keys = fieldnames(value(i));
        for j = 1:numel(keys)
            assertNoAbsolutePaths(value(i).(keys{j}),label);
        end
    end
elseif iscell(value)
    for i = 1:numel(value)
        assertNoAbsolutePaths(value{i},label);
    end
elseif ischar(value) || (isstring(value) && isscalar(value))
    text = char(string(value));
    if ~isempty(regexp(text,'(^|[\s=:])([A-Za-z]:[\\/]|\\\\|/(?!/))', ...
            'once'))
        invalid('Absolute host path remains in runtime release %s: %s', ...
            label,text);
    end
end
end

function tf = safeRelativePath(value)
value = strrep(char(string(value)),'\','/');
tf = ~isempty(value) && ~startsWith(value,'/') && ...
    isempty(regexp(value,'^[A-Za-z]:','once')) && ...
    ~any(strcmp(strsplit(value,'/'),'..')) && ~contains(value,':');
end

function digest = sha256File(path)
engine = java.security.MessageDigest.getInstance('SHA-256');
file = java.io.File(path);
content = javaMethod('readAllBytes','java.nio.file.Files',file.toPath());
bytes = typecast(engine.digest(content),'uint8');
digest = lower(reshape(dec2hex(bytes,2).',1,[]));
end

function payload = readJson(path)
try
    payload = jsondecode(fileread(path));
catch ME
    invalid('Could not parse JSON file %s: %s',path,ME.message);
end
if ~isstruct(payload) || ~isscalar(payload)
    invalid('JSON file must contain one object: %s',path);
end
end

function requireText(source,key,expected)
if ~strcmp(textField(source,key),expected)
    invalid('Expected %s="%s".',key,expected);
end
end

function value = textField(source,key)
value = '';
try
    if isstruct(source) && isfield(source,key)
        value = strtrim(char(string(source.(key))));
    end
catch
end
end

function value = numericField(source,key,fallback)
value = fallback;
try
    raw = source.(key);
    if isnumeric(raw) && isscalar(raw) && isfinite(raw),value = double(raw);end
catch
end
end

function value = normalizePath(value)
value = strrep(char(string(value)),'\','/');
value = regexprep(value,'/+', '/');
end

function invalid(varargin)
error('cellLatentModel:InvalidRuntimeBundle',varargin{:});
end
