function changed = score_editSelectedTrackCensoring(app)
%SCORE_EDITSELECTEDTRACKCENSORING Explicitly censor/restore selected GT.
% Merely touching the ROI boundary is never sufficient.  The reviewer must
% decide that the cell/mask is visibly truncated or otherwise unusable.

changed = false;
[roiObj, channelName] = score_selectedObjectChannel(app);
[model, status] = score_getCellModel(roiObj);
if ~strcmp(status, 'ok')
    error('score:CensoringUnavailable', ...
        'No cellular object model is available for this ROI.');
end
trackId = selectedTrack(app);
cfg = score_getObjectDisplayConfig(roiObj, channelName);
[~, familyId] = score_resolveCellModelFamily(model, cfg, channelName);
if isempty(familyId)
    error('score:CensoringFamily', ...
        'The selected GT object family cannot be resolved.');
end
trackRows = model.instances.family_id == familyId & ...
    model.instances.track_id == trackId;
trackFrames = double(model.instances.frame(trackRows));
if isempty(trackFrames)
    error('score:CensoringTrack', ...
        'Select a tracked cell before editing censoring.');
end
currentFrame = double(roiObj.display.frame);
records = model.censoring.family_id == familyId & ...
    model.censoring.track_id == trackId;

if any(records)
    action = uiconfirm(app.ScoreAppUIFigure, sprintf([ ...
        'Track %u already has %d explicit censor interval(s).\n\n' ...
        'Remove restores all of its observations to ordinary GT.'], ...
        trackId, nnz(records)), 'Edit cell censoring', ...
        'Options', {'Add interval','Remove all censoring','Cancel'}, ...
        'DefaultOption', 'Add interval', 'CancelOption', 'Cancel');
    if strcmp(action, 'Cancel'), return; end
    if strcmp(action, 'Remove all censoring')
        affectedFrames = unique([ ...
            double(model.censoring.frame_start(records)); ...
            double(model.censoring.frame_end(records))]).';
        [model, ~] = cellModel.removeCensoring( ...
            model, familyId, trackId, 'Fast', true);
        persistChange(app, roiObj, model, affectedFrames);
        changed = true;
        return;
    end
end

reasonChoice = uiconfirm(app.ScoreAppUIFigure, [ ...
    'Choose a documented reason. A cell that merely touches the ROI edge ' ...
    'must remain usable; choose boundary truncation only when the cell or ' ...
    'its mask is visibly cut.'], 'Censoring reason', ...
    'Options', {'Clearly truncated at ROI boundary', ...
        'Ambiguous identity','Ambiguous parentage', ...
        'Unusable segmentation','Other','Cancel'}, ...
    'DefaultOption', 'Clearly truncated at ROI boundary', ...
    'CancelOption', 'Cancel');
if strcmp(reasonChoice, 'Cancel'), return; end
reason = reasonName(reasonChoice);

scopeChoices = {'Parentage only at birth', ...
    'Segmentation only: current frame', ...
    'Tracking identity only: current frame', ...
    'Appearance only at birth', ...
    'END only at last observation', ...
    'All tasks...'};
[scopeIndex,accepted] = listdlg( ...
    'PromptString',sprintf([ ...
        'Select exactly what is unusable for Track %u. ' ...
        'Task-specific censorship preserves the other GT heads.'],trackId), ...
    'SelectionMode','single','ListString',scopeChoices, ...
    'InitialValue',defaultScopeIndex(reason), ...
    'ListSize',[430 190],'Name','Censoring scope');
if ~accepted || isempty(scopeIndex), return; end
scopeChoice = scopeChoices{scopeIndex};

switch scopeChoice
    case 'Parentage only at birth'
        frameStart = min(trackFrames);
        frameEnd = frameStart;
        scope = 'parentage';
    case 'Segmentation only: current frame'
        frameStart = currentFrame;
        frameEnd = currentFrame;
        scope = 'segmentation';
    case 'Tracking identity only: current frame'
        frameStart = currentFrame;
        frameEnd = currentFrame;
        scope = 'tracking';
    case 'Appearance only at birth'
        frameStart = min(trackFrames);
        frameEnd = frameStart;
        scope = 'appearance';
    case 'END only at last observation'
        frameStart = max(trackFrames);
        frameEnd = frameStart;
        scope = 'end';
    otherwise
        intervalChoice = uiconfirm(app.ScoreAppUIFigure, ...
            'Choose the interval excluded from every training/evaluation head.', ...
            'All-task censoring interval', ...
            'Options',{'Current frame','Current to track end', ...
                'Whole track','Cancel'}, ...
            'DefaultOption','Current frame','CancelOption','Cancel');
        if strcmp(intervalChoice,'Cancel'), return; end
        switch intervalChoice
            case 'Current frame'
                frameStart = currentFrame;
                frameEnd = currentFrame;
            case 'Current to track end'
                frameStart = currentFrame;
                frameEnd = max(trackFrames);
            otherwise
                frameStart = min(trackFrames);
                frameEnd = max(trackFrames);
        end
        scope = 'all';
end

[model, report] = cellModel.setCensoring(model, familyId, trackId, ...
    frameStart, frameEnd, 'Scope', scope, 'Reason', reason, ...
    'Source', 'human_review', 'Fast', true);
persistChange(app, roiObj, model, ...
    double(report.frame_start):double(report.frame_end));
changed = true;
end

function trackId = selectedTrack(app)
trackId = NaN;
try
    trackId = double(app.SelectedTrackIDCell);
catch
end
if ~isscalar(trackId) || ~isfinite(trackId) || trackId < 1 || ...
        trackId ~= round(trackId)
    error('score:CensoringSelection', ...
        'Select a tracked cell before editing censoring.');
end
trackId = uint64(trackId);
end

function value = reasonName(choice)
switch choice
    case 'Clearly truncated at ROI boundary'
        value = 'truncated_at_roi_boundary';
    case 'Ambiguous identity'
        value = 'ambiguous_identity';
    case 'Ambiguous parentage'
        value = 'ambiguous_parentage';
    case 'Unusable segmentation'
        value = 'unusable_segmentation';
    otherwise
        value = 'other';
end
end

function value = defaultScopeIndex(reason)
if strcmp(reason, 'ambiguous_parentage')
    value = 1;
elseif strcmp(reason, 'unusable_segmentation') || ...
        strcmp(reason, 'truncated_at_roi_boundary')
    value = 2;
elseif strcmp(reason, 'ambiguous_identity')
    value = 3;
else
    value = 6;
end
end

function persistChange(app, roiObj, model, frames)
roiObj.saveCellModel(model);
app.notifyAnnotationChanged('censoring', unique(round(double(frames))), ...
    'Save', false);
score_updateSelectedCensoringFields(app);
end
