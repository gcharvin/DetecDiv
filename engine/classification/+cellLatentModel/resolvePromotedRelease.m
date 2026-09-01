function params = resolvePromotedRelease(classif,params)
%RESOLVEPROMOTEDRELEASE Resolve and verify the stable latent-model channel.
% The mutable channel selects one immutable release manifest. All artifacts
% are checksum-verified before the caller pins this resolved parameter view
% for the complete multi-ROI operation.

if nargin<2||~isstruct(params),params=struct();end
policy=lower(textField(params,'modelUpdatePolicy'));
if isempty(policy)||strcmp(policy,'pinned'),return;end
if ~strcmp(policy,'follow_promoted')
    error('cellLatentModel:InvalidModelUpdatePolicy', ...
        'modelUpdatePolicy must be pinned or follow_promoted.');
end

channelPath=textField(params,'modelReleaseChannelPath');
if isempty(channelPath)
    channelPath=strtrim(getenv('CELL_LATENT_MODEL_RELEASE_CHANNEL'));
end
if isempty(channelPath),channelPath=conventionalChannel(classif);end
channelPath=resolvePath(channelPath,classifierPath(classif));
if ~isfile(channelPath)
    error('cellLatentModel:MissingModelReleaseChannel', ...
        'The promoted latent-model release channel was not found: %s', ...
        channelPath);
end
channel=readJson(channelPath,'channel');
requireText(channel,'format','detecdiv.cell_latent_model.channel.v1');
requireText(channel,'channel','stable');
releasePath=resolvePath(textField(channel,'releaseManifest'), ...
    fileparts(channelPath));
verifyFile(releasePath,lower(textField(channel, ...
    'releaseManifestSha256')),'release manifest');

release=readJson(releasePath,'release');
requireText(release,'format','detecdiv.cell_latent_model.release.v1');
requireText(release,'status','promoted');
releaseId=textField(release,'releaseId');
if isempty(releaseId)
    error('cellLatentModel:InvalidModelRelease','Release ID is missing.');
end
if ~isfield(release,'executionDefaults')|| ...
        ~isstruct(release.executionDefaults)|| ...
        ~isscalar(release.executionDefaults)
    error('cellLatentModel:InvalidModelRelease', ...
        'Release executionDefaults are missing.');
end
resolved=release.executionDefaults;
if ~strcmpi(textField(resolved,'modelSource'),'trained')
    error('cellLatentModel:InvalidModelRelease', ...
        'A promoted release must declare modelSource=trained.');
end
if ~isfield(release,'artifacts')||~isstruct(release.artifacts)
    error('cellLatentModel:InvalidModelRelease', ...
        'Release artifact checksums are missing.');
end
artifacts=release.artifacts;
for i=1:numel(artifacts)
    parameter=textField(artifacts(i),'parameter');
    artifactPath=resolvePath(textField(artifacts(i),'path'), ...
        fileparts(releasePath));
    verifyFile(artifactPath,lower(textField(artifacts(i),'sha256')),parameter);
    kind=lower(textField(artifacts(i),'kind'));
    if strcmp(kind,'directory_manifest')
        value=fileparts(artifactPath);
        if strcmp(parameter,'runtimeCodeRoot')
            verifyDirectoryManifest(artifactPath,value);
        end
    elseif strcmp(kind,'file')
        value=artifactPath;
    else
        error('cellLatentModel:InvalidModelRelease', ...
            'Artifact "%s" has unsupported kind "%s".',parameter,kind);
    end
    if ~any(strcmp(parameter,{'modelPath','compositeManifestPath', ...
            'trackingCheckpointDir','stateRuntimeConfigPath', ...
            'sceneParentRuntimeManifestPath','runtimeCodeRoot', ...
            'adaptiveMarkerModelPath'}))
        error('cellLatentModel:InvalidModelRelease', ...
            'Artifact parameter "%s" is not deployable.',parameter);
    end
    resolved.(parameter)=value;
end

required={'modelPath','compositeManifestPath','trackingCheckpointDir'};
for i=1:numel(required)
    if isempty(textField(resolved,required{i}))
        error('cellLatentModel:InvalidModelRelease', ...
            'Promoted release lacks %s.',required{i});
    end
end
params=overlay(params,resolved);
params.modelUpdatePolicy='follow_promoted';
params.modelReleaseChannelPath=channelPath;
params.resolvedModelReleaseId=releaseId;
params.resolvedModelReleaseManifestPath=releasePath;
end

function verifyDirectoryManifest(manifestPath,root)
manifest=readJson(manifestPath,'runtime code directory manifest');
if ~isfield(manifest,'generated_files')||~isstruct(manifest.generated_files)
    error('cellLatentModel:InvalidModelRelease', ...
        'Runtime code manifest has no generated_files contract.');
end
files=manifest.generated_files;
for j=1:numel(files)
    relative=textField(files(j),'path');
    candidate=resolvePath(relative,root);
    expected=lower(textField(files(j),'sha256'));
    try
        canonicalRoot=char(java.io.File(root).getCanonicalPath());
        canonicalFile=char(java.io.File(candidate).getCanonicalPath());
    catch
        canonicalRoot=root;canonicalFile=candidate;
    end
    prefix=[canonicalRoot filesep];
    if ~startsWith(lower(canonicalFile),lower(prefix))
        error('cellLatentModel:InvalidModelRelease', ...
            'Runtime code manifest escapes its release root.');
    end
    verifyFile(candidate,expected,['runtime code ' relative]);
end
if ~isfolder(fullfile(root,'src','cell_latent_model'))
    error('cellLatentModel:InvalidModelRelease', ...
        'Runtime code snapshot has no src/cell_latent_model package.');
end
end

function value=conventionalChannel(classif)
root=classifierPath(classif);
% Classifiers normally live at <external-root>/classifier/<id>.
if ~isempty(root),root=fileparts(fileparts(root));end
if isempty(root)
    value='';
else
    value=fullfile(root,'releases','detecdiv_stable.json');
end
end

function value=classifierPath(classif)
value='';try,value=char(string(classif.path));catch,end
end

function payload=readJson(path,label)
try,payload=jsondecode(fileread(path));catch ME
    error('cellLatentModel:InvalidModelRelease', ...
        'Could not read %s JSON %s: %s',label,path,ME.message);
end
if ~isstruct(payload)||~isscalar(payload)
    error('cellLatentModel:InvalidModelRelease', ...
        'The %s JSON must contain one object.',label);
end
end

function requireText(payload,key,expected)
actual=textField(payload,key);
if ~strcmp(actual,expected)
    error('cellLatentModel:InvalidModelRelease', ...
        'Expected %s="%s", observed "%s".',key,expected,actual);
end
end

function verifyFile(path,expected,label)
if isempty(path)||~isfile(path)||isempty(expected)||numel(expected)~=64
    error('cellLatentModel:ModelReleaseChecksumMismatch', ...
        'Missing path or SHA-256 for release artifact "%s".',label);
end
observed=sha256(path);
if ~strcmpi(observed,expected)
    error('cellLatentModel:ModelReleaseChecksumMismatch', ...
        'SHA-256 mismatch for release artifact "%s": %s.',label,path);
end
end

function digest=sha256(path)
engine=java.security.MessageDigest.getInstance('SHA-256');
file=java.io.File(path);
content=javaMethod('readAllBytes','java.nio.file.Files',file.toPath());
bytes=typecast(engine.digest(content),'uint8');
digest=lower(reshape(dec2hex(bytes,2).',1,[]));
end

function value=resolvePath(value,root)
value=strtrim(char(string(value)));
if isempty(value),return;end
if isempty(regexp(value,'^[A-Za-z]:[\\/]|^[/\\]{2}|^/','once'))
    value=fullfile(root,value);
end
end

function value=textField(source,key)
value='';try
    if isstruct(source)&&isfield(source,key)
        value=source.(key);
        while iscell(value)
            if isempty(value),value='';return;end
            value=value{end};
        end
        value=strtrim(char(string(value)));
    end
catch,value='';end
end

function out=overlay(out,source)
keys=fieldnames(source);
for i=1:numel(keys),out.(keys{i})=source.(keys{i});end
end
