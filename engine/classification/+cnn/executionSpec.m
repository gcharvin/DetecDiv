function spec = executionSpec(classif)
%CNN.EXECUTIONSPEC Image-classifier inference contract.
if nargin<1,classif=[];end
spec=struct();
spec.summary='CNN image classifier: writes prediction scores/classes to a dataseries.';
spec.staticKeys={'executionEnvironment'};
spec.outputKeys={'outputName'};
spec.defaultImportKeys={'executionEnvironment'};
spec.outputProvenance=struct('quality','pred','producer','cnn', ...
    'semantic','image_or_sequence_class','template','<outputName>');
spec.defaults=struct('outputName','pred_cnn_image_class', ...
    'executionEnvironment','module_default');
spec.labels=struct('outputName','[PRED] Classification output name', ...
    'executionEnvironment','Execution environment');
spec.tips=struct('outputName',['Dataseries prediction group. Existing classifiers ' ...
        'retain their historical classifier ID; new pipeline nodes use pred_cnn_image_class.'], ...
    'executionEnvironment','module_default keeps the run-level CPU/GPU policy.');
spec.choices=struct('executionEnvironment',{{'module_default','cpu','gpu'}});
spec.defaults=mergeDefaults(spec.defaults,classif);
end

function defaults=mergeDefaults(defaults,classif)
if isempty(classif),return;end
explicit=false;
try
    if (isobject(classif)&&isprop(classif,'executionParam'))|| ...
            (isstruct(classif)&&isfield(classif,'executionParam'))
        p=classif.executionParam;
        if isstruct(p)
            if isfield(p,'outputName')&&~isempty(p.outputName)
                defaults.outputName=p.outputName;explicit=true;
            end
            if isfield(p,'executionEnvironment')&&~isempty(p.executionEnvironment)
                defaults.executionEnvironment=p.executionEnvironment;
            end
        end
    end
catch
end
if ~explicit
    try
        id=char(string(classif.strid));
        if ~isempty(id),defaults.outputName=id;end
    catch
    end
end
try
    tp=classif.trainingParam;
    if isstruct(tp)&&isfield(tp,'execution_environment')
        value=tp.execution_environment;while iscell(value),value=value{end};end
        defaults.executionEnvironment=char(string(value));
    end
catch
end
end
