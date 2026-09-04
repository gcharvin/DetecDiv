function score_configureLatentSignalControls(app)
%SCORE_CONFIGURELATENTSIGNALCONTROLS Adapt managed Score controls to a head.
try
    session=app.AnnotationSession;
    if isempty(session)||~isvalid(session), return; end
    components=session.Spec.components;
    scalar=find(ismember({components.kind}, ...
        {'object_classification','object_regression'}),1,'first');
    segmentation=find(strcmp({components.kind},'semantic_mask'),1,'first');
    isSignal=strcmpi(char(string(session.Spec.package)),'cellLatentSignal');
    if ~isSignal, return; end
    app.StartBlankGTButton.Visible='on';
    app.CreateFromPredictionButton.Visible='off';
    app.CensorSelectedTrackButton.Visible='off';
    app.CensorStatusLabel.Visible='off';
    app.LineageTreeButton.Visible='off';
    if ~isempty(segmentation), return; end
    if isempty(scalar), return; end
    task=char(extractAfter(string(components(scalar).kind),'object_'));
    app.SelectedObjectIDLabel.Visible='on';
    app.SelectedObjectIDEditField.Visible='on';
    app.SelectedObjectIDLabel.Text='Object ID:';
    app.SelectedObjectIDEditField.Enable='off';
    app.SelectedTrackIDEditFieldLabel.Visible='on';
    app.SelectedTrackIDEditField.Visible='on';
    app.SelectedTrackIDEditField.Enable='off';
    app.SelectedTrackIDEditFieldLabel.Text='Track ID:';
    if strcmp(task,'classification')
        app.SelectedCellStateDropDownLabel.Visible='on';
        app.SelectedCellStateDropDown.Visible='on';
        app.SelectedCellStateDropDownLabel.Text='Signal class:';
        app.MasklabelEditFieldLabel.Visible='off';
        app.MasklabelEditField.Visible='off';
    else
        app.SelectedCellStateDropDownLabel.Visible='off';
        app.SelectedCellStateDropDown.Visible='off';
        app.MasklabelEditFieldLabel.Visible='on';
        app.MasklabelEditField.Visible='on';
        app.MasklabelEditFieldLabel.Text='Signal value:';
        app.MasklabelEditField.Enable='off';
    end
    app.CellModelStatusLabel.Text='Select an object in the read-only mask.';
    app.AnnotationTargetLabel.Tooltip=[ ...
        'Click or double-click a cell in the read-only mask, then assign ' ...
        'its signal target with the object controls.'];
catch ME
    warning('score:LatentSignalControls','Could not configure signal controls: %s',ME.message);
end
end
