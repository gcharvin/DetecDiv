function [changed, checked] = score_refreshCellModelCache(roiobj, app, forceCheck)
%SCORE_REFRESHCELLMODELCACHE Poll the sidecar at Score interaction boundaries.
% Rendering keeps using score_getCellModel without filesystem access. Check
% at most once a second per ROI, and read/validate only a changed sidecar.
% Missing/unreadable files and unsaved Score edits retain the in-memory model.

if nargin < 2, app = []; end
if nargin < 3, forceCheck = false; end
changed = false;
checked = false;
if isempty(roiobj), return; end
if ~isempty(app) && any(string(app.ModifiedRoiIds) == string(roiobj.id))
    return;
end
filename = cellModel.pathForROI(roiobj);
if isempty(filename), return; end
info = roiobj.cellModelInfo;
if ~isstruct(info), info = struct(); end
if ~forceCheck && isfield(info,'scoreCheckClock') && ...
        isfield(info,'scoreCheckFilename') && ...
        strcmp(info.scoreCheckFilename,filename) && toc(info.scoreCheckClock) < 1
    return;
end

info.scoreCheckClock = tic;
info.scoreCheckFilename = filename;
roiobj.cellModelInfo = info;
checked = true;
try
    file = dir(filename);
    if isempty(file) || file.isdir, return; end
    hasCache = isfield(info,'loaded') && info.loaded && ...
        isstruct(roiobj.cellModel) && isfield(roiobj.cellModel,'schema_version');
    current = hasCache && isfield(info,'filename') && ...
        strcmp(info.filename,filename) && isfield(info,'datenum') && ...
        isequal(info.datenum,file.datenum);
    if current && isfield(info,'bytes')
        current = isequal(info.bytes,file.bytes);
    end
    if current
        info.bytes = file.bytes;
        roiobj.cellModelInfo = info;
        return;
    end

    % readH5 validates before loadCellModel replaces the cached model. An
    % external writer may be replacing the file; leave the old cache on error.
    roiobj.loadCellModel('Force',true,'MigrateLegacy',false);
    freshInfo = roiobj.cellModelInfo;
    freshInfo.scoreCheckClock = tic;
    freshInfo.scoreCheckFilename = filename;
    roiobj.cellModelInfo = freshInfo;
    changed = true;
catch ME
    warning('score:CellModelRefresh', ...
        'Could not refresh objects for ROI %s; retaining its cache: %s', ...
        char(string(roiobj.id)), ME.message);
    return;
end

% Single-mask rendering also needs its display binding rebuilt: a family
% which was absent when the channel was selected may now have lineage.
channelName = '';
showBud = false;
showGenealogy = false;
if isfield(roiobj.display,'lineage')
    binding = roiobj.display.lineage;
    if isfield(binding,'channelName'), channelName = binding.channelName; end
    showBud = isfield(binding,'showBudPairing') && binding.showBudPairing;
    showGenealogy = isfield(binding,'showGenealogy') && binding.showGenealogy;
end
if ~isempty(app) && isprop(app,'LineageDisplayButtonGroup')
    [~,selectedChannel] = score_selectedObjectChannel(app);
    if ~isempty(selectedChannel), channelName = selectedChannel; end
    options = score_lineageDisplayOptions(app);
    showBud = options.showBudPairing;
    showGenealogy = options.showGenealogy;
end
if ~isempty(channelName)
    cfg = score_getObjectDisplayConfig(roiobj,channelName);
    pix = [];
    try pix = roiobj.findChannelID(channelName); catch, end
    roiobj.display.lineage = score_resolveLineageDisplayConfig( ...
        roiobj,channelName,pix,cfg,showBud,showGenealogy);
end
end
