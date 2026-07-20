function report = shallowRepairRoiManifestPaths(jsonPath, varargin)
%SHALLOWREPAIRROIMANIFESTPATHS Repair broken ROI paths in a light manifest.
%   report = shallowRepairRoiManifestPaths(jsonPath, 'Apply', true)
% rewrites only ROI path/file references whose expected H5 exists in the
% project FOV directory.  The original JSON is retained as a timestamped
% backup and the replacement is atomic.

ip = inputParser;
ip.addParameter('Apply', false, @(x)islogical(x) || isnumeric(x));
ip.parse(varargin{:});
doApply = logical(ip.Results.Apply);

jsonPath = char(string(jsonPath));
if ~isfile(jsonPath)
    error('shallowRepairRoiManifestPaths:MissingFile', 'Manifest not found: %s', jsonPath);
end
project = jsondecode(fileread(jsonPath));
[jsonFolder, jsonName] = fileparts(jsonPath);
projectName = localFieldText(project, 'projectName', jsonName);
physicalProjectDir = fullfile(jsonFolder, projectName);

report = struct('jsonPath', jsonPath, 'projectDir', physicalProjectDir, ...
    'roiCount', 0, 'changedCount', 0, 'missingH5Count', 0, ...
    'applied', false, 'backupPath', '');
if ~isfield(project, 'fovs') || isempty(project.fovs)
    return;
end

for fi = 1:numel(project.fovs)
    if ~isfield(project.fovs(fi), 'rois') || isempty(project.fovs(fi).rois)
        continue;
    end
    fovId = localFieldText(project.fovs(fi), 'id', sprintf('FOV_%d', fi));
    for ri = 1:numel(project.fovs(fi).rois)
        report.roiCount = report.roiCount + 1;
        roiId = localFieldText(project.fovs(fi).rois(ri), 'id', '');
        relDir = fovId;
        expectedH5 = fullfile(physicalProjectDir, relDir, ['im_' roiId '.h5']);
        if ~isfile(expectedH5)
            report.missingH5Count = report.missingH5Count + 1;
            continue;
        end
        oldPath = localFieldText(project.fovs(fi).rois(ri), 'path', '');
        imageRel = fullfile(relDir, ['im_' roiId '.h5']);
        dataRel = fullfile(relDir, ['data_' roiId '.mat']);
        oldImage = '';
        oldData = '';
        if isfield(project.fovs(fi).rois(ri), 'files') && ...
                isstruct(project.fovs(fi).rois(ri).files)
            oldImage = localFieldText(project.fovs(fi).rois(ri).files, 'imageH5', '');
            oldData = localFieldText(project.fovs(fi).rois(ri).files, 'dataMat', '');
        end
        if ~strcmp(localComparable(oldPath), localComparable(relDir)) || ...
                ~strcmp(localComparable(oldImage), localComparable(imageRel)) || ...
                ~strcmp(localComparable(oldData), localComparable(dataRel))
            report.changedCount = report.changedCount + 1;
        end
        project.fovs(fi).rois(ri).path = relDir;
        project.fovs(fi).rois(ri).files = struct( ...
            'imageH5', imageRel, 'dataMat', dataRel);
    end
end

if ~doApply || report.changedCount == 0
    return;
end

stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
backupPath = [jsonPath '.pre-roi-path-repair.' stamp '.bak'];
copyfile(jsonPath, backupPath, 'f');
tmpPath = [jsonPath '.tmp.' char(java.util.UUID.randomUUID)];
cleanup = onCleanup(@() localDeleteIfPresent(tmpPath));
fid = fopen(tmpPath, 'w', 'n', 'UTF-8');
if fid < 0
    error('shallowRepairRoiManifestPaths:OpenFailed', 'Could not write %s.', tmpPath);
end
closeFile = onCleanup(@() fclose(fid));
fprintf(fid, '%s\n', jsonencode(project, 'PrettyPrint', true));
delete(closeFile);
jsondecode(fileread(tmpPath));
movefile(tmpPath, jsonPath, 'f');
delete(cleanup);
report.applied = true;
report.backupPath = backupPath;
end

function text = localFieldText(S, name, defaultValue)
text = defaultValue;
if isstruct(S) && isfield(S, name) && ~isempty(S.(name))
    text = char(string(S.(name)));
end
end

function text = localComparable(value)
text = lower(regexprep(char(string(value)), '[\\/]+', '/'));
text = regexprep(text, '^/|/$', '');
end

function localDeleteIfPresent(pathText)
if isfile(pathText)
    delete(pathText);
end
end
