function prepared = prepareRuntime(classif,ctx)
%PREPARERUNTIME Freeze the current selection without importing Python/models.
if nargin < 1, classif = []; end
if nargin < 2 || isempty(ctx), ctx = struct(); end
spec = cellposesam.executionSpec(classif);
p = spec.defaults;
if isfield(ctx,'params') && isstruct(ctx.params) && isscalar(ctx.params)
    keys = fieldnames(ctx.params);
    for i = 1:numel(keys), p.(keys{i}) = ctx.params.(keys{i}); end
end
% These values are historically read from trainingParam, then ctx.params.
keys = {'diameter','flow_threshold','min_size','cell_prob_threshold','trackInstances'};
fallbacks = {NaN,0.4,10,0,true};
for i = 1:numel(keys)
    value = fallbacks{i};
    try
        raw = classif.trainingParam;
        if isstruct(raw) && isfield(raw,keys{i}) && ~isempty(raw.(keys{i}))
            value = raw.(keys{i});
        end
    catch
    end
    if isfield(ctx,'params') && isstruct(ctx.params) && ...
            isfield(ctx.params,keys{i}) && ~isempty(ctx.params.(keys{i}))
        value = ctx.params.(keys{i});
    end
    p.(keys{i}) = value;
end
mode = propertyText(classif,'outputType');
if isempty(mode), mode = 'segmentation'; end
if isfield(ctx,'params') && isstruct(ctx.params)
    if isfield(ctx.params,'outputType') && ~isempty(ctx.params.outputType)
        mode = ctx.params.outputType;
    elseif isfield(ctx.params,'outputMode') && ~isempty(ctx.params.outputMode)
        mode = ctx.params.outputMode;
    end
end
p.outputType = mode;
id = propertyText(classif,'strid');
outputName = id;
try
    if ~isempty(ctx.names.outputName), outputName = ctx.names.outputName; end
catch
end
p.outputName = outputName;
diagnostics = cellposesam.validateModule(p);
packageRoot = fileparts(mfilename('fullpath'));
runner = pipelineModuleFileIdentity(fullfile(packageRoot,'py','cellposesam_runner.py'));
script = pipelineModuleFileIdentity(fullfile(packageRoot,'py','classify_cellposesam.py'));
if ~runner.exists || ~script.exists
    diagnostics(end+1,1) = diagnostic('error','MissingPythonEntryPoint', ...
        'The installed CellposeSAM adapter is missing its Python runner or script.','');
end
modelPath = 'sam';
classifierPath = propertyText(classif,'path');
if ~isempty(classifierPath) && ~isempty(id)
    candidate = fullfile(classifierPath,'models',id);
    if isfile(candidate)
        modelPath = candidate;
    elseif isfile([candidate '.pth'])
        modelPath = [candidate '.pth'];
    end
end
model = struct('source','backend_managed','selection',modelPath, ...
    'identity',pipelineModuleFileIdentity(''),'verification','deferred');
if ~strcmp(modelPath,'sam')
    model.source = 'classifier_local';
    model.identity = pipelineModuleFileIdentity(modelPath);
    model.verification = 'sha256';
else
    diagnostics(end+1,1) = diagnostic('warning','BackendManagedModel', ...
        ['The sam alias is resolved by Cellpose during execution; no weight ' ...
         'file was loaded or downloaded during preparation.'],'model');
end
environment = struct('status','deferred','pythonExecutable','','pythonVersion','');
try
    pe = pyenv;
    if ~strcmp(string(pe.Status),'NotLoaded') && isfile(char(pe.Executable))
        environment.status = 'observed';
        environment.pythonExecutable = char(pe.Executable);
        environment.pythonVersion = char(pe.Version);
    end
catch
end
% The historical selector still owns environment choice/bootstrap at execution.
% Observing a loaded pyenv is not proof that a custom run selects that env.
environment.selection = 'execution_selector';
environment.dependencies = 'unverified';
prepared = struct('format','detecdiv.module_runtime.v1','parameters',p, ...
    'diagnostics',diagnostics,'provenance',struct( ...
        'engine',struct('package','cellpose','version','','runner',runner,'script',script), ...
        'model',model,'environment',environment), ...
    'context',struct('cellposeModelPath',modelPath));
end

function value = propertyText(obj,name)
value = '';
try, value = strtrim(char(string(obj.(name)))); catch, end
end

function value = diagnostic(severity,code,message,parameter)
value = struct('severity',severity,'code',code,'message',message,'parameter',parameter);
end
