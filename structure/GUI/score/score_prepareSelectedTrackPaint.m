function [maskLabel, trackId] = score_prepareSelectedTrackPaint( ...
        app, roiobj, channelName, channelIdx, pix, frame)
%SCORE_PREPARESELECTEDTRACKPAINT Choose a free provider label for a track.
% The selected track is persistent across frames; mask labels are only
% frame-local storage and may already belong to another track.

maskLabel = NaN;
trackId = NaN;
try
    trackId = double(app.SelectedTrackIDCell);
    sameRoi = app.SelectedObjectRoiId == string(roiobj.id);
    sameChannel = double(app.SelectedObjectChannelIdx) == double(channelIdx);
catch
    return;
end
if ~sameRoi || ~sameChannel || ~isscalar(trackId) || ...
        ~isfinite(trackId) || trackId < 1 || trackId ~= round(trackId)
    trackId = NaN;
    return;
end

[model, status] = score_getCellModel(roiobj);
if ~strcmp(status, 'ok'), trackId = NaN; return; end
cfg = score_getObjectDisplayConfig(roiobj, channelName);
[~, familyId] = score_resolveCellModelFamily(model, cfg, channelName);
if isempty(familyId), trackId = NaN; return; end

trackRows = find(model.instances.family_id == familyId & ...
    model.instances.track_id == uint64(trackId));
if isempty(trackRows), trackId = NaN; return; end

current = trackRows(model.instances.frame(trackRows) == uint32(frame));
if ~isempty(current)
    maskLabel = double(model.instances.mask_label(current(1)));
    return;
end

maskFrame = double(roiobj.image(:,:,pix,frame));
used = unique(maskFrame(maskFrame > 0));
distances = abs(double(model.instances.frame(trackRows)) - double(frame));
[~, order] = sortrows([distances(:), ...
    -double(model.instances.frame(trackRows))], [1 2]);
candidates = double(model.instances.mask_label(trackRows(order)));
candidates = [candidates(:); trackId];
candidates = unique(candidates(candidates > 0 & isfinite(candidates)), 'stable');

maxLabel = providerMaximum(roiobj.image);
candidates = candidates(candidates <= maxLabel & ~ismember(candidates, used));
if ~isempty(candidates)
    maskLabel = candidates(1);
    return;
end

maskLabel = 1;
while maskLabel <= maxLabel && ismember(maskLabel, used)
    maskLabel = maskLabel + 1;
end
if maskLabel > maxLabel
    maskLabel = NaN;
    trackId = NaN;
end
end

function value = providerMaximum(imageData)
if isinteger(imageData)
    value = double(intmax(class(imageData)));
else
    value = flintmax;
end
end
