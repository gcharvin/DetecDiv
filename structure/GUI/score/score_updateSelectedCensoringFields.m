function score_updateSelectedCensoringFields(app)
%SCORE_UPDATESELECTEDCENSORINGFIELDS Refresh explicit censoring UI state.

try
    button = app.CensorSelectedTrackButton;
    label = app.CensorStatusLabel;
catch
    return;
end
button.Enable = 'off';
button.Text = 'Censor selected track...';
label.Text = 'Censoring: select a tracked cell';
label.FontColor = [0.35 0.35 0.35];

[roiObj, channelName] = score_selectedObjectChannel(app);
[model, status] = score_getCellModel(roiObj);
if ~strcmp(status, 'ok'), return; end
trackId = NaN;
try
    trackId = double(app.SelectedTrackIDCell);
catch
end
if ~isscalar(trackId) || ~isfinite(trackId) || trackId < 1, return; end
cfg = score_getObjectDisplayConfig(roiObj, channelName);
[~, familyId] = score_resolveCellModelFamily(model, cfg, channelName);
if isempty(familyId), return; end
trackRows = model.instances.family_id == familyId & ...
    model.instances.track_id == uint64(trackId);
if ~any(trackRows), return; end

button.Enable = 'on';
records = model.censoring.family_id == familyId & ...
    model.censoring.track_id == uint64(trackId);
if ~any(records)
    label.Text = 'Usable GT (edge contact alone is not censoring)';
    label.FontColor = [0 0.45 0.1];
    return;
end
button.Text = 'Edit / remove track censoring...';
frame = uint32(roiObj.display.frame);
active = records & model.censoring.frame_start <= frame & ...
    model.censoring.frame_end >= frame;
if any(active)
    row = find(active, 1, 'first');
    reason = reasonName(model, model.censoring.reason_id(row));
    scopes = scopeText(model.censoring.scope_flags(row));
    label.Text = sprintf('CENSORED here [%s]: %s', scopes, ...
        strrep(reason, '_', ' '));
    label.FontColor = [0.75 0.05 0.05];
else
    label.Text = sprintf('Usable here; %d censor interval(s) elsewhere', ...
        nnz(records));
    label.FontColor = [0.55 0.3 0];
end
end

function value = scopeText(flags)
scope = cellModel.censorScope();
ordered = {'segmentation','tracking','appearance','end','parentage','state'};
names = ordered(cellfun(@(name) ...
    bitand(uint16(flags),scope.(name)) ~= 0,ordered));
if numel(names) == numel(ordered)
    value = 'all tasks';
else
    value = strjoin(names, '+');
end
end

function name = reasonName(model, reasonId)
index = find(uint16([model.censor_reasons.reason_id]) == reasonId, 1);
if isempty(index)
    name = 'documented reason';
else
    name = model.censor_reasons(index).name;
end
end
