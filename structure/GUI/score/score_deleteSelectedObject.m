function score_deleteSelectedObject(app)
%SCORE_DELETESELECTEDOBJECT Delete the selected contour or its whole track.
% Invoked by the Delete key and usable by future Score controls.

if isempty(app.content.ROIList) || isempty(app.SelectedObjectLabelCell) || ...
        ~isfinite(app.SelectedObjectLabelCell) || app.SelectedObjectLabelCell < 1
    warndlg('Select a contour first (double-click it).', 'Delete contour');
    return;
end

selectedRoi = find(cell2mat(app.UIROITable.Data(:,1)), 1);
if isempty(selectedRoi), return; end
roi = app.content.ROIList{selectedRoi};
if string(roi.id) ~= string(app.SelectedObjectRoiId)
    warndlg('The selected contour belongs to another ROI.', 'Delete contour');
    return;
end

[channelName, ~, pix] = localSelectedMaskChannel(app, roi);
if isempty(pix)
    warndlg('Select a valid annotation channel first.', 'Delete contour');
    return;
end
frame = roi.display.frame;
maskLabel = double(app.SelectedObjectLabelCell);
mask = roi.image(:,:,pix,frame);
if ~any(mask(:) == maskLabel)
    warndlg('The selected contour is not present on this frame.', 'Delete contour');
    return;
end

[model, modelStatus] = score_getCellModel(roi);
familyId = [];
trackId = NaN;
if strcmp(modelStatus, 'ok')
    cfg = score_getObjectDisplayConfig(roi, channelName);
    [~, familyId] = score_resolveCellModelFamily(model, cfg, channelName);
    if ~isempty(familyId)
        instance = cellModel.findInstance(model, familyId, frame, maskLabel);
        if ~isempty(instance) && instance.track_id > 0
            trackId = double(instance.track_id);
        end
    end
end

if isfinite(trackId)
    choice = questdlg(sprintf([ ...
        'Delete selected contour from Track %u.\n\n' ...
        'Choose the scope of this deletion:'], uint64(trackId)), ...
        'Delete track contour', 'This frame', 'Entire track', 'Cancel', 'This frame');
else
    choice = questdlg(sprintf('Delete selected contour #%d on this frame?', maskLabel), ...
        'Delete contour', 'Delete', 'Cancel', 'Delete');
    if strcmp(choice, 'Delete'), choice = 'This frame'; end
end
if isempty(choice) || strcmp(choice, 'Cancel'), return; end

relationsRemoved = 0;
if strcmp(choice, 'This frame')
    mask(mask == maskLabel) = 0;
    roi.image(:,:,pix,frame) = mask;
    score_syncCellModelFrame(roi, channelName, frame, 'Save', false);
    affectedFrames = frame;
    message = sprintf('Contour #%d deleted on frame %d (unsaved masks).', ...
        maskLabel, frame);
else
    [model, report] = cellModel.removeTrack(model, familyId, trackId, 'Fast', true);
    relationsRemoved = report.relations_removed;
    affectedFrames = unique(double(report.frames(:)))';
    for i = 1:numel(report.instance_frames)
        f = double(report.instance_frames(i));
        label = double(report.mask_labels(i));
        if f < 1 || f > size(roi.image,4), continue; end
        frameMask = roi.image(:,:,pix,f);
        frameMask(frameMask == label) = 0;
        roi.image(:,:,pix,f) = frameMask;
    end
    roi.saveCellModel(model);
    message = sprintf('Track %u deleted on %d frame(s) (unsaved masks).', ...
        uint64(trackId), numel(affectedFrames));
end

app.notifyAnnotationChanged(channelName, affectedFrames, 'Save', false);
if strcmp(choice, 'Entire track')
    % A mask-channel notification updates tracking review state, but the
    % open lineage tree only rebuilds for an explicit model-level event.
    % Parentage is the most precise event when links were removed; a
    % relation-free track still needs a tracking event so it disappears
    % from the tree immediately.
    if relationsRemoved > 0
        app.notifyAnnotationChanged('parentage', affectedFrames, 'Save', false);
    else
        app.notifyAnnotationChanged('tracking', affectedFrames, 'Save', false);
    end
end
try
    app.SelectedObjectLabelCell = NaN;
    app.SelectedTrackIDCell = NaN;
    app.SelectedObjectChannelIdx = NaN;
    app.SelectedObjectRoiId = "";
    if ~isempty(app.SelectedObjectRectangle) && isgraphics(app.SelectedObjectRectangle)
        delete(app.SelectedObjectRectangle);
    end
catch
end
score_updateSelectedObjectFields(app);
score_display(app, 'fast');
try app.StatusLabel.Text = message; catch, end
end

function [channelName, channelIdx, pix] = localSelectedMaskChannel(app, roi)
channelName = '';
channelIdx = [];
pix = [];
selection = app.UIAnnotationTable.Selection;
if isempty(selection), return; end
annotation = app.UIAnnotationTable.Data{selection(1), 2};
classification = app.UIAnnotationTable.Data{selection(1), 3};
if isempty(classification)
    channelName = char(string(annotation));
else
    channelName = [char(string(annotation)), '_', char(string(classification))];
end
[channelName, channelIdx, pix] = score_resolveMaskProvider(roi, channelName);
end
