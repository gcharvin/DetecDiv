function [jsonPath, project] = shallowProjectExportLight(shallowObj, jsonPath)
%SHALLOWPROJECTEXPORTLIGHT Save the project inventory and FOV metadata files.

if nargin < 1 || isempty(shallowObj) || ~isa(shallowObj, 'shallow')
    error('shallowProjectExportLight:InvalidProject', 'A shallow project object is required.');
end

[projectPath, projectFile] = shallowObj.getPath();
if nargin < 2 || isempty(jsonPath)
    jsonPath = fullfile(projectPath, [projectFile '.json']);
end
jsonPath = char(string(jsonPath));

[project, details] = shallowProjectToStruct(shallowObj);
localAssertSafeManifestOverwrite(jsonPath, project);

targetDir = fileparts(jsonPath);
if ~isempty(targetDir) && ~isfolder(targetDir)
    mkdir(targetDir);
end
projectDir = fullfile(targetDir, project.projectName);
metadataDir = fullfile(projectDir, 'project_metadata');
if ~isfolder(metadataDir)
    mkdir(metadataDir);
end

for i = 1:numel(project.fovs)
    detailPath = fullfile(projectDir, project.fovs(i).metadataPath);
    localWriteJson(detailPath, details.fovs(i), false);
end
localWriteJson(fullfile(projectDir, project.runProfilesPath), details.runProfiles, false);
localWriteJson(jsonPath, project, true);

fprintf('Light project manifest saved: %s\n', jsonPath);
end

function localWriteJson(pathText, value, pretty)
if pretty
    jsonText = jsonencode(value, 'PrettyPrint', true);
else
    jsonText = jsonencode(value);
end
tmpUuid = char(java.util.UUID.randomUUID);
tmpPath = [pathText '.tmp.' tmpUuid];
fid = fopen(tmpPath, 'w', 'n', 'UTF-8');
if fid < 0
    error('shallowProjectExportLight:OpenFailed', 'Could not open temp JSON file: %s', tmpPath);
end
cleanup = onCleanup(@() localCloseAndDelete(fid, tmpPath));
fprintf(fid, '%s\n', jsonText);
fclose(fid);

localVerifyJson(tmpPath);
movefile(tmpPath, pathText, 'f');
delete(cleanup);
end

function localAssertSafeManifestOverwrite(jsonPath, incoming)
% Never let a newly-created/default shallow placeholder silently replace a
% populated project manifest.  This can otherwise happen when a run is
% opened without successfully binding its project first.
if ~isfile(jsonPath)
    return;
end
try
    existing = jsondecode(fileread(jsonPath));
catch
    return;
end

existingPopulation = localManifestPopulation(existing, jsonPath, true);
incomingPopulation = localManifestPopulation(incoming, jsonPath, false);
existingId = localManifestText(existing, 'projectId');
incomingId = localManifestText(incoming, 'projectId');
idMismatch = ~isempty(existingId) && ~isempty(incomingId) && ...
    ~strcmp(existingId, incomingId);

if existingPopulation > 0 && (incomingPopulation == 0 || idMismatch)
    error('shallowProjectExportLight:UnsafeOverwrite', ...
        ['Refusing to overwrite populated project manifest "%s" with a different or empty shallow object. ' ...
         'The existing FOV sidecars were included in this check. Load the complete project before saving, ' ...
         'or choose a new project name.'], jsonPath);
end
end

function count = localManifestPopulation(project, jsonPath, includeSidecars)
count = 0;
if ~isstruct(project) || ~isfield(project, 'fovs') || isempty(project.fovs)
    if isfield(project, 'rawSources') && ~isempty(project.rawSources)
        count = 1;
    end
    return;
end
for i = 1:numel(project.fovs)
    f = project.fovs(i);
    roiCount = 0;
    if isfield(f, 'rois') && ~isempty(f.rois)
        roiCount = numel(f.rois);
    end
    if isfield(f, 'roiCount') && isnumeric(f.roiCount) && ...
            isscalar(f.roiCount) && isfinite(f.roiCount)
        roiCount = max(roiCount, double(f.roiCount));
    end
    hasSources = localManifestHasSource(f);

    if includeSidecars
        sidecar = localManifestSidecar(project, jsonPath, f, i);
        if ~isempty(sidecar)
            sidecarId = localManifestText(sidecar, 'id');
            fovId = localManifestText(f, 'id');
            if ~isempty(fovId) && strcmp(sidecarId, fovId)
                if isfield(sidecar, 'rois') && ~isempty(sidecar.rois)
                    roiCount = max(roiCount, numel(sidecar.rois));
                end
                hasSources = hasSources || localManifestHasSource(sidecar);
            end
        end
    end
    count = count + double(roiCount > 0 || hasSources);
end
if count == 0 && isfield(project, 'rawSources') && ~isempty(project.rawSources)
    count = 1;
end
end

function sidecar = localManifestSidecar(project, jsonPath, fov, index)
sidecar = [];
[manifestDir, manifestName, ~] = fileparts(jsonPath);
projectName = localManifestText(project, 'projectName');
if isempty(projectName)
    projectDir = fullfile(manifestDir, manifestName);
else
    projectDir = fullfile(manifestDir, projectName);
end
detailPath = localManifestText(fov, 'metadataPath');
if isempty(detailPath)
    fovIndex = index;
    if isfield(fov, 'index') && isnumeric(fov.index) && isscalar(fov.index) && ...
            isfinite(fov.index) && fov.index >= 1 && fov.index == fix(fov.index)
        fovIndex = double(fov.index);
    end
    detailPath = fullfile('project_metadata', sprintf('fov_%05d.json', fovIndex));
end
if isfile(detailPath)
    resolvedPath = detailPath;
elseif startsWith(detailPath, filesep) || ...
        ~isempty(regexp(detailPath, '^[A-Za-z]:[\\/]|^\\\\', 'once'))
    resolvedPath = detailPath;
else
    resolvedPath = fullfile(projectDir, detailPath);
end
if isfile(resolvedPath)
    try
        sidecar = jsondecode(fileread(resolvedPath));
    catch
        sidecar = [];
    end
end
end

function tf = localManifestHasSource(fov)
tf = false;
if isstruct(fov) && isfield(fov, 'srcpath') && localManifestHasText(fov.srcpath)
    tf = true;
    return;
end
if ~isstruct(fov) || ~isfield(fov, 'raw') || ~isstruct(fov.raw)
    return;
end
raw = fov.raw;
pathFields = {'tiffSource','ndtiffPath','omeZarrPath'};
for i = 1:numel(pathFields)
    if isfield(raw, pathFields{i}) && localManifestHasText(raw.(pathFields{i}))
        tf = true;
        return;
    end
end
flagFields = {'isMultiTiff','isStackSeries','isNDTiff','isOMEZarr'};
for i = 1:numel(flagFields)
    if isfield(raw, flagFields{i}) && isequal(raw.(flagFields{i}), true)
        tf = true;
        return;
    end
end
end

function tf = localManifestHasText(value)
tf = false;
if ischar(value) || isstring(value)
    values = cellstr(string(value));
elseif iscell(value)
    values = value;
else
    return;
end
for i = 1:numel(values)
    item = values{i};
    if (ischar(item) || isstring(item)) && ~isempty(strtrim(char(string(item))))
        tf = true;
        return;
    end
end
end

function text = localManifestText(S, name)
text = '';
if isstruct(S) && isfield(S, name) && ~isempty(S.(name))
    try
        text = char(string(S.(name)));
    catch
    end
end
end

function localVerifyJson(pathText)
try
    jsondecode(fileread(pathText));
catch ME
    error('shallowProjectExportLight:VerifyFailed', ...
        'Written JSON manifest could not be decoded: %s', ME.message);
end
end

function localCloseAndDelete(fid, pathText)
try
    if fid >= 0
        fclose(fid);
    end
catch
end
try
    if exist(pathText, 'file') == 2
        delete(pathText);
    end
catch
end
end
