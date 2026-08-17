function scope = trainingScopeSpec(classif)
%CLASSIFIERBINDING.TRAININGSCOPESPEC Resolve package-owned training scope.
scope=classifierBinding.newTrainingScope();
if nargin<1||isempty(classif),return;end
pkg='';
try pkg=strtrim(char(string(classif.classifierPkg)));catch,end
if isempty(pkg)
    try
        fun=char(string(classif.trainingFun)); dot=strfind(fun,'.');
        if ~isempty(dot),pkg=fun(1:dot(1)-1);end
    catch
    end
end
if isempty(pkg),return;end
fun=[pkg '.trainingScopeSpec'];
if isempty(which(fun))
    scope.module=pkg; scope.displayName=pkg;
    scope.objective='Package-defined classifier training.';
    return;
end
try raw=feval(fun,classif);catch ME
    warning('classifierBinding:TrainingScopeSpec', ...
        'Could not read %s: %s',fun,ME.message);
    return;
end
if ~isstruct(raw)||numel(raw)~=1
    warning('classifierBinding:InvalidTrainingScopeSpec', ...
        '%s must return one scalar struct.',fun);
    return;
end
names=fieldnames(scope);
for i=1:numel(names)
    if isfield(raw,names{i})&&~isempty(raw.(names{i}))
        scope.(names{i})=raw.(names{i});
    end
end
scope.schemaVersion=uint16(1);
for name={'module','displayName','objective','datasetUnit','splitPolicy', ...
        'outputParameter','outputQuality','outputSemantic','outputTemplate', ...
        'canonicalOutput'}
    scope.(name{1})=strtrim(char(string(scope.(name{1}))));
end
scope.outputQuality=lower(scope.outputQuality);
scope.trainedComponents=asCellstr(scope.trainedComponents);
scope.frozenComponents=asCellstr(scope.frozenComponents);
scope.notes=asCellstr(scope.notes);
if ~any(strcmp(scope.outputQuality,{'pred','gt','input','derived'}))
    error('classifierBinding:InvalidOutputQuality', ...
        '%s declares unsupported output quality "%s".',fun,scope.outputQuality);
end
end

function values=asCellstr(value)
if isempty(value),values={};elseif ischar(value)||isstring(value),values=cellstr(string(value));else,values=cellfun(@(x)char(string(x)),value,'UniformOutput',false);end
values=values(~cellfun(@isempty,values));
end
