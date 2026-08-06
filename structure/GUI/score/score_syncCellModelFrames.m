function reports = score_syncCellModelFrames(roiobj, channelName, frames, varargin)
%SCORE_SYNCCELLMODELFRAMES Reconcile several authoritative mask frames once.

p = inputParser;
p.addParameter('Save', true, @(x) islogical(x) && isscalar(x));
p.parse(varargin{:});

reports = struct([]);
[model, status] = score_getCellModel(roiobj);
if ~strcmp(status, 'ok')
    return;
end
cfg = score_getObjectDisplayConfig(roiobj, channelName);
[~, familyId, ~, provider] = ...
    score_resolveCellModelFamily(model, cfg, channelName);
if isempty(familyId)
    return;
end
try
    pix = roiobj.findChannelID(provider);
    pix = pix(1);
catch
    return;
end

frames = unique(round(double(frames(:).')), 'stable');
frames = frames(frames >= 1 & frames <= size(roiobj.image,4));
for frame = frames
    [model, report] = cellModel.syncFrame(model, familyId, frame, ...
        roiobj.image(:,:,pix,frame), 'TrackPolicy', 'preserve_or_label');
    report.status = 'ok';
    if isempty(reports), reports = report; else, reports(end+1) = report; end %#ok<AGROW>
end
if ~isempty(frames) && p.Results.Save
    roiobj.saveCellModel(model);
elseif ~isempty(frames)
    % Keep rendering and subsequent edits on the reconciled model while
    % deferring the objects_<roi>.h5 rewrite to explicit Save.
    roiobj.cellModel = model;
end
end
