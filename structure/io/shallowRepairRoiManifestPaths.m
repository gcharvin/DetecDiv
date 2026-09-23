function report = shallowRepairRoiManifestPaths(jsonPath, varargin)
%SHALLOWREPAIRROIMANIFESTPATHS Repair broken ROI paths in v2/v3 metadata.
%   report = shallowRepairRoiManifestPaths(jsonPath, 'Apply', true)
% rewrites only ROI path/file references whose expected H5 exists in the
% project FOV directory. The modified JSON files are backed up and replaced
% atomically. In v3 the ROI metadata lives in per-FOV sidecars.

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
    'applied', false, 'backupPath', '', 'backupPaths', {{}});
if ~isfield(project, 'fovs') || isempty(project.fovs)
    return;
end

fovs = project.fovs;
detailPaths = cell(numel(fovs), 1);
changedFovs = false(numel(fovs), 1);
if isfield(fovs, 'metadataPath')
    detailFovs = cell(numel(fovs), 1);
    for fi = 1:numel(fovs)
        detailPaths{fi} = fullfile(physicalProjectDir, fovs(fi).metadataPath);
        if ~isfile(detailPaths{fi})
            error('shallowRepairRoiManifestPaths:MissingMetadata', ...
                'FOV metadata file is missing: %s', detailPaths{fi});
        end
        detailFovs{fi} = jsondecode(fileread(detailPaths{fi}));
    end
    fovs = vertcat(detailFovs{:});
end

for fi = 1:numel(fovs)
    if ~isfield(fovs(fi), 'rois') || isempty(fovs(fi).rois)
        continue;
    end
    fovId = localFieldText(fovs(fi), 'id', sprintf('FOV_%d', fi));
    for ri = 1:numel(fovs(fi).rois)
        report.roiCount = report.roiCount + 1;
        roiId = localFieldText(fovs(fi).rois(ri), 'id', '');
        relDir = fovId;
        expectedH5 = fullfile(physicalProjectDir, relDir, ['im_' roiId '.h5']);
        if ~isfile(expectedH5)
            report.missingH5Count = report.missingH5Count + 1;
            continue;
        end
        oldPath = localFieldText(fovs(fi).rois(ri), 'path', '');
        imageRel = fullfile(relDir, ['im_' roiId '.h5']);
        dataRel = fullfile(relDir, ['data_' roiId '.mat']);
        oldImage = '';
        oldData = '';
        if isfield(fovs(fi).rois(ri), 'files') && ...
                isstruct(fovs(fi).rois(ri).files)
            oldImage = localFieldText(fovs(fi).rois(ri).files, 'imageH5', '');
            oldData = localFieldText(fovs(fi).rois(ri).files, 'dataMat', '');
        end
        if ~strcmp(localComparable(oldPath), localComparable(relDir)) || ...
                ~strcmp(localComparable(oldImage), localComparable(imageRel)) || ...
                ~strcmp(localComparable(oldData), localComparable(dataRel))
            report.changedCount = report.changedCount + 1;
            changedFovs(fi) = true;
        end
        fovs(fi).rois(ri).path = relDir;
        fovs(fi).rois(ri).files = struct( ...
            'imageH5', imageRel, 'dataMat', dataRel);
    end
end

if ~doApply || report.changedCount == 0
    return;
end

stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
if isempty(detailPaths{1})
    project.fovs = fovs;
    report.backupPath = localWriteRepairedJson(jsonPath, project, stamp, true);
    report.backupPaths = {report.backupPath};
else
    for fi = find(changedFovs(:))'
        report.backupPaths{end + 1} = localWriteRepairedJson( ...
            detailPaths{fi}, fovs(fi), stamp, false); %#ok<AGROW>
    end
    report.backupPath = report.backupPaths{1};
end
report.applied = true;
end

function backupPath = localWriteRepairedJson(pathText, value, stamp, pretty)
backupPath = [pathText '.pre-roi-path-repair.' stamp '.bak'];
copyfile(pathText, backupPath, 'f');
tmpPath = [pathText '.tmp.' char(java.util.UUID.randomUUID)];
cleanup = onCleanup(@() localDeleteIfPresent(tmpPath));
fid = fopen(tmpPath, 'w', 'n', 'UTF-8');
if fid < 0
    error('shallowRepairRoiManifestPaths:OpenFailed', 'Could not write %s.', tmpPath);
end
closeFile = onCleanup(@() fclose(fid));
if pretty
    encoded = jsonencode(value, 'PrettyPrint', true);
else
    encoded = jsonencode(value);
end
fprintf(fid, '%s\n', encoded);
delete(closeFile);
jsondecode(fileread(tmpPath));
movefile(tmpPath, pathText, 'f');
delete(cleanup);
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
