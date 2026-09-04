function score_updateSelectedSignalFields(app)
%SCORE_UPDATESELECTEDSIGNALFIELDS Show the selected object's custom target.
context=score_latentSignalContext(app);
if ~context.enabled, return; end
try
    if context.objectId==0
        app.SelectedObjectIDEditField.Value='';
        app.SelectedTrackIDEditField.Value='';
        app.SelectedCellStateDropDown.Enable='off';
        app.MasklabelEditField.Enable='off';
        app.CellModelStatusLabel.Text='Select an object in the read-only mask.';
        return;
    end
    app.SelectedObjectIDEditField.Value=char(string(context.objectId));
    app.SelectedTrackIDEditField.Value=char(string(context.trackId));
    if strcmp(context.task,'classification')
        classes=context.definition.classes;
        app.SelectedCellStateDropDown.Items=[{'<undefined>'} classes];
        app.SelectedCellStateDropDown.ItemsData=0:numel(classes);
        value=0;
        if context.hasTarget
            hit=find(strcmp(classes,char(string(context.value))),1,'first');
            if ~isempty(hit), value=hit; end
        end
        app.SelectedCellStateDropDown.Value=value;
        app.SelectedCellStateDropDown.Enable='on';
        shown=app.SelectedCellStateDropDown.Items{value+1};
    else
        if context.hasTarget, value=double(context.value); else, value=NaN; end
        app.MasklabelEditField.Value=value;
        app.MasklabelEditField.Enable='on';
        if isfinite(value), shown=sprintf('%g',value); else, shown='<undefined>'; end
    end
    app.CellModelStatusLabel.Text=sprintf('Object %s | %s', ...
        char(string(context.objectId)),shown);
catch ME
    app.CellModelStatusLabel.Text=ME.message;
end
end
