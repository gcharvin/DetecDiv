function reports = score_syncCellModelFrames(roiobj, channelName, frames)
%SCORE_SYNCCELLMODELFRAMES Reconcile several authoritative mask frames once.

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
if ~isempty(frames)
    roiobj.saveCellModel(model);
end
end
