function tf=supports(classif)
%SUPPORTS Statistics for declared masks and discrete labels; no model dispatch.
tf=false;
if contains(lower(strjoin(string(classif.category),' ')),'regression'),return;end
if strcmpi(char(string(classif.classifierPkg)),'lstm_timeseries'),return;end
spec=annotationManager.specForClassifier(classif);
for c=spec.components(:).'
    tf=tf || (strcmp(c.storage,'channel') && any(strcmp(c.kind,{'instance_mask','tracked_instances','semantic_mask'}))) || ...
        (strcmp(c.storage,'dataseries') && any(strcmp(c.kind,{'frame_labels','sequence_label'})));
end
end
