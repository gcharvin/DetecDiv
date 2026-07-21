function [jsonPath, project] = shallowProjectExportLight(shallowObj, jsonPath)
%SHALLOWPROJECTEXPORTLIGHT Save a lightweight DetecDiv project manifest.

if nargin < 1 || isempty(shallowObj) || ~isa(shallowObj, 'shallow')
    error('shallowProjectExportLight:InvalidProject', 'A shallow project object is required.');
end

[projectPath, projectFile] = shallowObj.getPath();
if nargin < 2 || isempty(jsonPath)
    jsonPath = fullfile(projectPath, [projectFile '.json']);
end
jsonPath = char(string(jsonPath));

project = shallowProjectToStruct(shallowObj);
localAssertSafeManifestOverwrite(jsonPath, project);

jsonText = jsonencode(project, 'PrettyPrint', true);
targetDir = fileparts(jsonPath);
if ~isempty(targetDir) && ~isfolder(targetDir)
    mkdir(targetDir);
end

tmpUuid = char(java.util.UUID.randomUUID);
tmpPath = [jsonPath '.tmp.' tmpUuid];
fid = fopen(tmpPath, 'w', 'n', 'UTF-8');
if fid < 0
    error('shallowProjectExportLight:OpenFailed', 'Could not open temp JSON file: %s', tmpPath);
end
cleanup = onCleanup(@() localCloseAndDelete(fid, tmpPath));
fprintf(fid, '%s\n', jsonText);
fclose(fid);

localVerifyJson(tmpPath);
movefile(tmpPath, jsonPath, 'f');
delete(cleanup);

fprintf('Light project manifest saved: %s\n', jsonPath);
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

existingPopulation = localManifestPopulation(existing);
incomingPopulation = localManifestPopulation(incoming);
existingId = localManifestText(existing, 'projectId');
incomingId = localManifestText(incoming, 'projectId');
idMismatch = ~isempty(existingId) && ~isempty(incomingId) && ...
    ~strcmp(existingId, incomingId);

if existingPopulation > 0 && (incomingPopulation == 0 || idMismatch)
    error('shallowProjectExportLight:UnsafeOverwrite', ...
        ['Refusing to overwrite populated project manifest "%s" with a different or empty shallow object. ' ...
         'Load the existing project before saving, or choose a new project name.'], jsonPath);
end
end

function count = localManifestPopulation(project)
count = 0;
if ~isstruct(project) || ~isfield(project, 'fovs') || isempty(project.fovs)
    return;
end
for i = 1:numel(project.fovs)
    f = project.fovs(i);
    hasId = ~isempty(strtrim(localManifestText(f, 'id')));
    hasRois = isfield(f, 'rois') && ~isempty(f.rois);
    hasSources = false;
    if isfield(f, 'srcpath') && ~isempty(f.srcpath)
        try
            sourceText = cellstr(string(f.srcpath));
            hasSources = any(~cellfun(@(x)isempty(strtrim(x)), sourceText));
        catch
        end
    end
    count = count + double(hasId || hasRois || hasSources);
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
