function report = score_applySelectedTrackPaint( ...
        app, roiobj, channelName, frame, maskLabel, trackId)
%SCORE_APPLYSELECTEDTRACKPAINT Bind a newly painted mask to the selected track.

report = struct('status', 'not_applied', 'frames', double(frame), ...
    'mask_label', double(maskLabel), 'track_id', double(trackId));
if ~isscalar(maskLabel) || ~isfinite(maskLabel) || maskLabel < 1 || ...
        ~isscalar(trackId) || ~isfinite(trackId) || trackId < 1
    return;
end

[model, status] = score_getCellModel(roiobj);
if ~strcmp(status, 'ok'), return; end
cfg = score_getObjectDisplayConfig(roiobj, channelName);
[~, familyId] = score_resolveCellModelFamily(model, cfg, channelName);
if isempty(familyId), return; end

instance = cellModel.findInstance(model, familyId, frame, maskLabel);
if isempty(instance)
    error('score:PaintedTrackInstanceMissing', ...
        'The painted mask label %u was not synchronized at frame %u.', ...
        uint32(maskLabel), uint32(frame));
end
if instance.track_id ~= uint64(trackId)
    [model, reassignment] = cellModel.reassignTrack(model, familyId, ...
        frame, maskLabel, trackId, 'frame', 'Fast', true);
    report.frames = reassignment.frames;
end
roiobj.cellModel = model;

app.SelectedObjectLabel = double(maskLabel);
app.SelectedObjectLabelCell = double(maskLabel);
app.SelectedTrackIDCell = double(trackId);
app.SelectedObjectRoiId = string(roiobj.id);
report.status = 'propagated';
end
