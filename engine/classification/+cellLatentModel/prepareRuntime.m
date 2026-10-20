function prepared = prepareRuntime(classif,ctx)
%PREPARERUNTIME Resolve a read-only, immutable model view for one run.
if nargin < 1, classif = []; end
if nargin < 2 || isempty(ctx), ctx = struct(); end
diagnostics = cellLatentModel.validateModule(struct());
p = cellLatentModel.utils.defaultExecutionParam();
try
    p = cellLatentModel.resolveInferenceParam(classif,ctx);
catch ME
    diagnostics(end+1,1) = diagnostic('error',ME.identifier,ME.message,'model');
end
diagnostics = [diagnostics; cellLatentModel.validateModule(p)];
backend = text(p,'backend');
backend = lower(strrep(strrep(backend,'-','_'),' ','_'));
if any(strcmp(backend,{'relation_ensemble','relationensemble',''})), backend = 'legacy'; end
if strcmp(backend,'continuouscellstate'), backend = 'continuous_cell_state'; end
if any(strcmp(backend,{'causalcomposite','composite','cell_latent_composite'}))
    backend = 'causal_composite';
end
classifierRoot = propertyText(classif,'path');
artifactKeys = {'modelPath','compositeManifestPath','trackingCheckpointDir', ...
    'stateRuntimeConfigPath','sceneParentRuntimeManifestPath', ...
    'annotationParentRerankerManifestPath','annotationBudneckModelManifestPath', ...
    'runtimeCodeRoot','adaptiveMarkerModelPath'};
artifacts = repmat(struct('parameter','','kind','','identity',struct()),0,1);
for i = 1:numel(artifactKeys)
    key = artifactKeys{i};
    selected = text(p,key);
    if isempty(selected) && strcmp(key,'modelPath') && strcmp(backend,'legacy') && ...
            strcmpi(text(p,'modelSource'),'trained')
        candidate = fullfile(classifierRoot,'models','latest','ensemble.pt');
        if isfile(candidate), selected = candidate; end
    end
    if ~isempty(selected) && ~isfile(selected) && ~isfolder(selected)
        candidate = fullfile(classifierRoot,selected);
        if isfile(candidate) || isfolder(candidate), selected = candidate; end
    end
    if ~isempty(selected), p.(key) = selected; end
    kind = 'file';
    if any(strcmp(key,{'trackingCheckpointDir','runtimeCodeRoot'}))
        kind = 'directory_manifest';
        if ~isempty(selected), selected = fullfile(selected,'manifest.json'); end
    end
    if ~isempty(selected)
        artifacts(end+1,1) = struct('parameter',key,'kind',kind, ...
            'identity',pipelineModuleFileIdentity(selected)); %#ok<AGROW>
    end
end
required = {};
if (strcmp(backend,'legacy') && strcmpi(text(p,'modelSource'),'trained')) || ...
        any(strcmp(backend,{'continuous_cell_state','causal_composite'}))
    required{end+1} = 'modelPath';
end
if strcmp(backend,'causal_composite')
    required = [required {'compositeManifestPath','trackingCheckpointDir'}];
    if strcmpi(text(p,'stateUpdateMode'),'promoted_frozen_bf')
        required{end+1} = 'stateRuntimeConfigPath';
    end
end
for i = 1:numel(required)
    index = find(strcmp({artifacts.parameter},required{i}),1);
    if isempty(index) || ~artifacts(index).identity.exists
        diagnostics(end+1,1) = diagnostic('error','MissingModelArtifact', ...
            ['The selected latent-model artifact is missing: ' required{i} '.'],required{i});
    end
end
for i = 1:numel(artifacts)
    if ~artifacts(i).identity.exists && ~any(strcmp(artifacts(i).parameter,required))
        diagnostics(end+1,1) = diagnostic('warning','UnverifiedOptionalArtifact', ...
            ['The configured artifact could not be inspected: ' artifacts(i).parameter '.'], ...
            artifacts(i).parameter);
    end
end
runtime = cellLatentModel.utils.resolvePythonRuntime(ctx,'ReadOnly',true);
context = struct();
if ~isempty(text(p,'runtimeCodeRoot'))
    runtime.repositoryRoot = text(p,'runtimeCodeRoot');
    lineage = fullfile(runtime.repositoryRoot,'lineage');
    if isfolder(fullfile(lineage,'src','cell_lineage_linker'))
        runtime.lineageRepositoryRoot = lineage;
    end
end
environment = struct('status','deferred','pythonExecutable',runtime.pythonExecutable, ...
    'selection',runtime.packageSource,'dependencies','unverified');
if ~isempty(runtime.pythonExecutable)
    if strcmp(runtime.packageSource,'requested_unverified')
        environment.status = 'requested_unverified';
    else
        environment.status = 'selected';
    end
    context.resolvedPythonRuntime = runtime;
else
    diagnostics(end+1,1) = diagnostic('warning','PythonSelectionDeferred', ...
        ['No existing Python selection could be pinned without bootstrapping; ' ...
         'the execution selector will resolve it.'],'python');
end
release = pipelineModuleFileIdentity(text(p,'resolvedModelReleaseManifestPath'));
model = struct('source',text(p,'modelSource'),'updatePolicy',text(p,'modelUpdatePolicy'), ...
    'releaseId',text(p,'resolvedModelReleaseId'),'releaseManifest',release, ...
    'artifacts',artifacts);
if ~isempty(model.releaseId)
    model.verification = 'promoted_release_checksums';
elseif isempty(artifacts)
    model.verification = 'deferred';
else
    model.verification = 'observed_file_checksums';
end
prepared = struct('format','detecdiv.module_runtime.v1','parameters',p, ...
    'diagnostics',diagnostics,'context',context,'provenance',struct( ...
        'engine',struct('package','cell_latent_model','backend',backend, ...
            'repositoryRoot',runtime.repositoryRoot,'lineageRepositoryRoot',runtime.lineageRepositoryRoot, ...
            'code',codeIdentity(runtime.repositoryRoot,'cell_latent_model')), ...
        'model',model,'environment',environment));
end

function identity = codeIdentity(root,package)
entrypoint = '';
if ~isempty(root), entrypoint = fullfile(root,'src',package,'__main__.py'); end
identity = pipelineModuleCodeIdentity(entrypoint);
end

function value = diagnostic(severity,code,message,parameter)
value = struct('severity',severity,'code',code,'message',message,'parameter',parameter);
end

function value = propertyText(obj,name)
value = '';
try, value = strtrim(char(string(obj.(name)))); catch, end
end

function value = text(source,key)
value = '';
if ~isfield(source,key), return; end
raw = source.(key);
while iscell(raw)
    if isempty(raw), return; end
    raw = raw{end};
end
if ~isempty(raw), value = strtrim(char(string(raw))); end
end
