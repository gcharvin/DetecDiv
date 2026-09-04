function tf = score_isLatentSignalObjectSession(app)
%SCORE_ISLATENTSIGNALOBJECTSESSION True for read-only mask selection mode.
tf=false;
try
    session=app.AnnotationSession;
    if isempty(session)||~isvalid(session)|| ...
            ~strcmpi(char(string(session.Spec.package)),'cellLatentSignal')
        return;
    end
    tf=any(ismember({session.Spec.components.kind}, ...
        {'object_classification','object_regression'}));
catch
    tf=false;
end
end
