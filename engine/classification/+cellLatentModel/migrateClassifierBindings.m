function report = migrateClassifierBindings(classif)
%MIGRATECLASSIFIERBINDINGS Separate reviewed GT from runtime mask input.
report=struct('changed',false,'trainingInstanceBefore','', ...
    'trainingInstanceAfter','','executionInstanceBefore','', ...
    'executionInstanceAfter','');
if isempty(classif),return;end

tp=struct();try tp=classif.trainingParam;catch,end
if ~isstruct(tp),tp=struct();end
architecture=fieldText(tp,'architectureVersion');
ep=struct();try ep=classif.executionParam;catch,end
if ~isstruct(ep),ep=struct();end
backend=fieldText(ep,'backend');
trainingComposite=strcmpi(architecture,'detecdiv_composite_v1');
executionComposite=strcmpi(backend,'causal_composite')|| ...
    (isempty(backend)&&trainingComposite);
if ~trainingComposite&&~executionComposite,return;end
gt=fieldText(tp,'trackChannelName');
before=fieldText(tp,'instanceChannelName');
after=before;
if trainingComposite
    [after,~]=cellLatentModel.utils.resolveFrameLocalInstanceChannel( ...
        classif,before,gt,struct());
    tp.instanceChannelName=after;
    try classif.trainingParam=tp;catch,end
end
report.trainingInstanceBefore=before;
report.trainingInstanceAfter=after;

beforeExecution=fieldText(ep,'instanceChannelName');
afterExecution=beforeExecution;
if executionComposite
    [afterExecution,~]=cellLatentModel.utils.resolveFrameLocalInstanceChannel( ...
        classif,beforeExecution,gt,struct());
    ep.instanceChannelName=afterExecution;
    ep.trackChannelName='';
    try classif.executionParam=ep;catch,end
end
report.executionInstanceBefore=beforeExecution;
report.executionInstanceAfter=afterExecution;
report.changed=~strcmp(before,after)|| ...
    ~strcmp(beforeExecution,afterExecution);
end

function value=fieldText(container,field)
value='';
try
    if ~isstruct(container)||~isfield(container,field),return;end
    value=container.(field);
    while iscell(value)
        if isempty(value),value='';return;end
        value=value{end};
    end
    value=strtrim(char(string(value)));
catch
end
end
