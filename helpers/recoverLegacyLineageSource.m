function summary = recoverLegacyLineageSource(oldClassifierDir, targetClassifierDir, varargin)
%RECOVERLEGACYLINEAGESOURCE Import old-format GT lineage into current ROIs.
%
% The legacy format stores lineage directly in
% cell_information.userData.motherOf / birthOf. Current ROIs can store
% multiple lineage sources in userData.lineageSources. This helper copies the
% legacy lineage as the GT source for the target mask channel, while preserving
% an existing prediction source under its own channel key.

p = inputParser();
p.addRequired('oldClassifierDir', @(x) ischar(x) || isstring(x));
p.addRequired('targetClassifierDir', @(x) ischar(x) || isstring(x));
p.addParameter('OldChannelName', 'celltracktr_5_cell', @(x) ischar(x) || isstring(x));
p.addParameter('TargetGTChannelName', 'sam31_1_cell', @(x) ischar(x) || isstring(x));
p.addParameter('TargetPredChannelName', 'results_sam31_1_cell', @(x) ischar(x) || isstring(x));
p.addParameter('GTSourceKey', 'sam31_1', @(x) ischar(x) || isstring(x));
p.addParameter('PredSourceKey', 'results_sam31_1_cell', @(x) ischar(x) || isstring(x));
p.addParameter('BackupRoot', '', @(x) ischar(x) || isstring(x));
p.addParameter('DryRun', false, @(x) islogical(x) || isnumeric(x));
p.parse(oldClassifierDir, targetClassifierDir, varargin{:});
opt = p.Results;

oldClassifierDir = char(oldClassifierDir);
targetClassifierDir = char(targetClassifierDir);
oldChannelName = char(opt.OldChannelName);
targetGTChannelName = char(opt.TargetGTChannelName);
targetPredChannelName = char(opt.TargetPredChannelName);
gtSourceKey = matlab.lang.makeValidName(char(opt.GTSourceKey));
predSourceKey = matlab.lang.makeValidName(char(opt.PredSourceKey));
dryRun = logical(opt.DryRun);

if strlength(string(opt.BackupRoot)) == 0
    stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
    backupRoot = fullfile(targetClassifierDir, 'backups', ['legacy_lineage_recovery_' stamp]);
else
    backupRoot = char(opt.BackupRoot);
end

oldFiles = dir(fullfile(oldClassifierDir, 'data_Pos*.mat'));
rows = repmat(emptySummaryRow(), numel(oldFiles), 1);

if ~dryRun && ~exist(backupRoot, 'dir')
    mkdir(backupRoot);
end

for i = 1:numel(oldFiles)
    roiName = stripDataPrefix(oldFiles(i).name);
    oldDataFile = fullfile(oldClassifierDir, oldFiles(i).name);
    targetDataFile = fullfile(targetClassifierDir, oldFiles(i).name);
    oldH5File = fullfile(oldClassifierDir, ['im_' roiName '.h5']);
    targetH5File = fullfile(targetClassifierDir, ['im_' roiName '.h5']);

    row = emptySummaryRow();
    row.roi = string(roiName);
    row.oldPairs = 0;
    row.predPairs = 0;
    row.gtEvents = 0;
    row.backupFile = "";

    if ~isfile(targetDataFile)
        row.status = "missing_target_data";
        rows(i) = row;
        continue;
    end
    if ~isfile(oldH5File) || ~isfile(targetH5File)
        row.status = "missing_h5";
        rows(i) = row;
        continue;
    end

    try
        oldMask = h5read(oldH5File, ['/' oldChannelName]);
        targetMask = h5read(targetH5File, ['/' targetGTChannelName]);
    catch ME
        row.status = "mask_read_failed: " + string(ME.identifier);
        rows(i) = row;
        continue;
    end

    if ~isequal(oldMask, targetMask)
        row.status = "mask_mismatch";
        row.pixelAgreement = mean(oldMask(:) == targetMask(:));
        rows(i) = row;
        continue;
    end
    row.pixelAgreement = 1;

    oldS = load(oldDataFile, 'data');
    targetS = load(targetDataFile, 'data');
    oldIdx = findCellInformation(oldS.data);
    targetIdx = findCellInformation(targetS.data);
    if isempty(oldIdx) || isempty(targetIdx)
        row.status = "missing_cell_information";
        rows(i) = row;
        continue;
    end

    oldUserData = oldS.data(oldIdx).userData;
    if ~isstruct(oldUserData) || ~isfield(oldUserData, 'motherOf') || ...
            ~isa(oldUserData.motherOf, 'containers.Map')
        row.status = "missing_legacy_motherOf";
        rows(i) = row;
        continue;
    end
    row.oldPairs = double(oldUserData.motherOf.Count);

    targetData = targetS.data;
    userData = targetData(targetIdx).userData;
    if ~isstruct(userData)
        userData = struct();
    end
    if ~isfield(userData, 'lineageSources') || ~isstruct(userData.lineageSources)
        userData.lineageSources = struct();
    end

    [userData, predPairs] = preservePredictionSource( ...
        userData, predSourceKey, targetPredChannelName, gtSourceKey);
    row.predPairs = predPairs;

    gtEvents = inferBirthEvents(targetMask, oldUserData.motherOf);
    row.gtEvents = numel(gtEvents);
    gtSource = buildGTSource(oldUserData, gtEvents, targetGTChannelName, ...
        gtSourceKey, oldClassifierDir);
    userData.lineageSources.(gtSourceKey) = gtSource;

    % Keep the legacy/canonical fields as GT for old readers.
    userData.motherOf = oldUserData.motherOf;
    if isfield(oldUserData, 'birthOf') && isa(oldUserData.birthOf, 'containers.Map')
        userData.birthOf = oldUserData.birthOf;
    end
    userData.events = gtEvents;
    userData.version = 1;
    userData.note = "legacy GT lineage recovered from celltracktr_5; prediction stored in lineageSources";
    userData.lineageChannelName = string(targetGTChannelName);
    userData.lineageChannelPix = h5DatasetIndex(targetH5File, targetGTChannelName);
    userData.motherOfSourceKey = gtSourceKey;
    userData.motherOfSourceChannelName = targetGTChannelName;
    userData.activeLineageSource = gtSourceKey;
    userData.activeLineageChannelName = targetGTChannelName;

    targetData(targetIdx).userData = userData;

    if dryRun
        row.status = "dry_run_ok";
    else
        backupFile = fullfile(backupRoot, oldFiles(i).name);
        copyfile(targetDataFile, backupFile);
        data = targetData;
        save(targetDataFile, 'data');
        row.status = "updated";
        row.backupFile = string(backupFile);
    end
    rows(i) = row;
end

summary = struct2table(rows);
summary.Properties.UserData.BackupRoot = string(backupRoot);
end

function row = emptySummaryRow()
row = struct( ...
    'roi', "", ...
    'status', "", ...
    'oldPairs', 0, ...
    'predPairs', 0, ...
    'gtEvents', 0, ...
    'pixelAgreement', NaN, ...
    'backupFile', "");
end

function roiName = stripDataPrefix(fileName)
roiName = erase(fileName, 'data_');
roiName = erase(roiName, '.mat');
end

function idx = findCellInformation(data)
idx = [];
for k = 1:numel(data)
    try
        if isprop(data(k), 'groupid') && strcmp(char(data(k).groupid), 'cell_information')
            idx = k;
            return;
        end
    catch
    end
end
end

function [userData, predPairs] = preservePredictionSource(userData, predSourceKey, predChannelName, gtSourceKey)
predPairs = 0;
fields = fieldnames(userData.lineageSources);
predSource = [];
predField = "";

for i = 1:numel(fields)
    src = userData.lineageSources.(fields{i});
    if isstruct(src) && isfield(src, 'channelName') && strcmp(string(src.channelName), string(predChannelName))
        predSource = src;
        predField = string(fields{i});
        break;
    end
end

if isempty(predSource) && isfield(userData, 'motherOf') && isa(userData.motherOf, 'containers.Map')
    if legacyChannelLooksLike(userData, predChannelName)
        predSource = struct();
        predSource.motherOf = userData.motherOf;
        if isfield(userData, 'birthOf'), predSource.birthOf = userData.birthOf; end
        if isfield(userData, 'events'), predSource.events = userData.events; end
        predSource.channelName = predChannelName;
    end
end

if ~isempty(predSource)
    predSource.channelName = predChannelName;
    predSource.displayName = predChannelName;
    if ~isfield(predSource, 'outputName') || isempty(predSource.outputName)
        predSource.outputName = erase(predChannelName, '_cell');
    end
    if ~isfield(predSource, 'sourceClassifierStrid') || isempty(predSource.sourceClassifierStrid)
        predSource.sourceClassifierStrid = erase(predChannelName, 'results_');
        predSource.sourceClassifierStrid = erase(predSource.sourceClassifierStrid, '_cell');
    end
    if ~isfield(predSource, 'version'), predSource.version = 1; end
    if ~isfield(predSource, 'mode'), predSource.mode = 'preserved_prediction'; end
    if ~isfield(predSource, 'createdAt')
        predSource.createdAt = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
    end
    userData.lineageSources.(predSourceKey) = predSource;
    if isfield(predSource, 'motherOf') && isa(predSource.motherOf, 'containers.Map')
        predPairs = double(predSource.motherOf.Count);
    end
end

if strlength(predField) > 0 && strcmp(predField, string(gtSourceKey)) && ...
        ~strcmp(string(gtSourceKey), string(predSourceKey))
    userData.lineageSources = rmfield(userData.lineageSources, char(gtSourceKey));
end
end

function tf = legacyChannelLooksLike(userData, channelName)
tf = false;
fields = {'motherOfSourceChannelName', 'lineageChannelName', 'activeLineageChannelName'};
for i = 1:numel(fields)
    if isfield(userData, fields{i}) && strcmp(string(userData.(fields{i})), string(channelName))
        tf = true;
        return;
    end
end
end

function gtSource = buildGTSource(oldUserData, gtEvents, targetGTChannelName, gtSourceKey, oldClassifierDir)
gtSource = struct();
gtSource.motherOf = oldUserData.motherOf;
if isfield(oldUserData, 'birthOf') && isa(oldUserData.birthOf, 'containers.Map')
    gtSource.birthOf = oldUserData.birthOf;
end
gtSource.events = gtEvents;
gtSource.channelName = targetGTChannelName;
gtSource.outputName = erase(targetGTChannelName, '_cell');
gtSource.sourceClassifierStrid = 'celltracktr_5';
gtSource.displayName = [char(gtSourceKey) ' GT lineage'];
gtSource.show = true;
gtSource.version = 1;
gtSource.mode = 'legacy_celltracktr_5_gt';
gtSource.createdAt = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
gtSource.sourcePath = oldClassifierDir;
end

function events = inferBirthEvents(mask, motherOf)
events = struct('childId', {}, 'motherId', {}, 'startFrame', {}, ...
    'areaAtBirth', {}, 'motherAreaAtBirth', {}, 'mode', {});
keysD = motherOf.keys;
for k = 1:numel(keysD)
    childId = int32(keysD{k});
    motherId = double(motherOf(childId));
    present = squeeze(any(any(any(mask == childId, 1), 2), 3));
    frame = find(present(:), 1, 'first');
    if isempty(frame)
        continue;
    end
    frameMask = squeeze(mask(:, :, :, frame));
    events(end + 1).childId = double(childId); %#ok<AGROW>
    events(end).motherId = motherId;
    events(end).startFrame = double(frame);
    events(end).areaAtBirth = double(nnz(frameMask == childId));
    events(end).motherAreaAtBirth = double(nnz(frameMask == int32(motherId)));
    events(end).mode = 'legacy_gt_first_presence';
end
end

function idx = h5DatasetIndex(h5File, datasetName)
idx = NaN;
try
    info = h5info(h5File);
    names = string({info.Datasets.Name});
    found = find(names == string(datasetName), 1, 'first');
    if ~isempty(found)
        idx = double(found);
    end
catch
end
end
