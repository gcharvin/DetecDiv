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
