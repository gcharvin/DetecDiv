function p = normalizeParam(param,ctx,classif)
%CELLLATENTMODEL.NORMALIZEPARAM Normalize runtime and artifact parameters.
if nargin < 2, ctx = struct(); end
if nargin < 3, classif = []; end
defaults = cellLatentModel.utils.defaultExecutionParam();
try
    if ~isempty(classif) && isa(classif,'classi') && ...
            isstruct(classif.executionParam)
        defaults = cellLatentModel.utils.applyOverrides( ...
            defaults,classif.executionParam);
    end
catch
end
if nargin < 1 || isempty(param), param = struct(); end
p = cellLatentModel.utils.applyOverrides(defaults,param);
obsolete = {'pythonExecutable','repositoryRoot','lineageRepositoryRoot', ...
    'packagePath','modelPackage','cellLatentRepository'};
present = obsolete(isfield(p,obsolete));
if ~isempty(present), p = rmfield(p,present); end

p.backend = normalizeBackend(readChoice(p.backend));
p.instanceChannelName = readChoice(p.instanceChannelName);
p.trackChannelName = readChoice(p.trackChannelName);
p.outputTrackChannelName = readChoice(p.outputTrackChannelName);
p.gfpChannelName = readChoice(p.gfpChannelName);
p.brightfieldChannelName = readChoice(p.brightfieldChannelName);
p.nucleusChannelName = readChoice(p.nucleusChannelName);
p.budneckChannelName = readChoice(p.budneckChannelName);
runtimeChannels = collectRuntimeChannels(param,ctx,classif);
if strcmp(p.backend,'causal_composite')
    gtChannel=trainingGroundTruthChannel(classif);
    p.instanceChannelName= ...
        cellLatentModel.utils.resolveFrameLocalInstanceChannel( ...
        classif,p.instanceChannelName,gtChannel,ctx);
    p.trackChannelName='';
elseif isMissingChoice(p.trackChannelName)
    p.trackChannelName = preferred(runtimeChannels, ...
        {'trackastra','track','label','mask'},1);
end

if strcmp(p.backend,'legacy')
    if isMissingChoice(p.gfpChannelName)
        p.gfpChannelName = preferred(runtimeChannels,{'gfp','nuc'},2);
    end
    if isMissingChoice(p.gfpChannelName), p.gfpChannelName = ''; end
else
    % A generic GFP channel has no unambiguous biological role. Temporal and
    % continuous inference accept only explicitly typed selectors.
    p.gfpChannelName = '';
end
if isMissingChoice(p.brightfieldChannelName)
    p.brightfieldChannelName = '';
end
if isMissingChoice(p.nucleusChannelName), p.nucleusChannelName = ''; end
if isMissingChoice(p.budneckChannelName), p.budneckChannelName = ''; end
p.inputFamily = readChoice(p.inputFamily);
p.outputFamilyName = strtrim(char(string(p.outputFamilyName)));
p.modelSource = lower(readChoice(p.modelSource));
p.modelPath = strtrim(readChoice(p.modelPath));
p.compositeManifestPath = strtrim(readChoice(p.compositeManifestPath));
p.trackingCheckpointDir = strtrim(readChoice(p.trackingCheckpointDir));
p.stateUpdateMode = lower(readChoice(p.stateUpdateMode));
p.stateRuntimeConfigPath = strtrim(readChoice(p.stateRuntimeConfigPath));
p.adaptiveMarkerModelSource = lower(readChoice( ...
    p.adaptiveMarkerModelSource));
p.adaptiveMarkerModelPath = strtrim(readChoice( ...
    p.adaptiveMarkerModelPath));
p.device = lower(readChoice(p.device));
p.temporalVariant = lower(readChoice(p.temporalVariant));
p.primaryStateAxis = lower(readChoice(p.primaryStateAxis));
if isempty(p.modelSource), p.modelSource = 'builtin'; end
if isempty(p.adaptiveMarkerModelSource)
    p.adaptiveMarkerModelSource = 'none';
end
if isempty(p.device), p.device = 'auto'; end
if isempty(p.temporalVariant), p.temporalVariant = 'temporal_geometry'; end
if isempty(p.primaryStateAxis), p.primaryStateAxis = 'budding'; end
if isempty(p.stateUpdateMode), p.stateUpdateMode = 'none'; end
if isempty(p.outputTrackChannelName)
    p.outputTrackChannelName = 'pred_latent_model_tracks';
end

numericNames = {'frameEnd','minLifetime','maxBirthArea','minParentAge', ...
    'maxParentCentroidDistance','maxParentContourDistance','maxCandidates', ...
    'maxNewTracksPerFrame','motherRefractoryFrames','youngMotherFrames', ...
    'solverBeamSize','statePositiveThreshold','stateNegativeThreshold'};
numericNames = [numericNames {'trackingTopK', ...
    'trackingSolverTimeLimitSeconds'}];
for i = 1:numel(numericNames)
    name = numericNames{i};
    p.(name) = readScalar(p.(name),defaults.(name));
end
p.frameIntervalMinutes = normalizeFrameInterval( ...
    p.frameIntervalMinutes,p.backend);
p.frameEnd = floor(p.frameEnd);
p.minLifetime = max(2,floor(p.minLifetime));
p.maxBirthArea = max(1,p.maxBirthArea);
p.minParentAge = max(1,floor(p.minParentAge));
p.maxParentCentroidDistance = max(0,p.maxParentCentroidDistance);
p.maxParentContourDistance = max(0,p.maxParentContourDistance);
p.maxCandidates = max(1,min(12,floor(p.maxCandidates)));
p.maxNewTracksPerFrame = max(0,floor(p.maxNewTracksPerFrame));
p.motherRefractoryFrames = max(0,floor(p.motherRefractoryFrames));
p.youngMotherFrames = max(0,floor(p.youngMotherFrames));
p.solverBeamSize = max(1,floor(p.solverBeamSize));
p.trackingTopK = max(1,floor(p.trackingTopK));
p.trackingSolverTimeLimitSeconds = max(0.1, ...
    p.trackingSolverTimeLimitSeconds);
p.trackingLoadGuard = logical(p.trackingLoadGuard);
p.globalSolver = logical(p.globalSolver);
p.causalSolverFeedback = logical(p.causalSolverFeedback);
p.materializeCellStates = logical(p.materializeCellStates);
p.reviewGlobalReassignments = logical(p.reviewGlobalReassignments);
p.overwriteOutputFamily = logical(p.overwriteOutputFamily);
p.debug = logical(p.debug);
if ~any(strcmp(p.primaryStateAxis,{'none','budding'}))
    error('cellLatentModel:InvalidPrimaryStateAxis', ...
        'primaryStateAxis must be none or budding.');
end
if p.stateNegativeThreshold < 0 || p.statePositiveThreshold > 1 || ...
        p.stateNegativeThreshold >= p.statePositiveThreshold
    error('cellLatentModel:InvalidStateThresholds', ...
        ['State thresholds must satisfy 0 <= negative < positive <= 1.']);
end

if strcmp(p.backend,'temporal_lineage')
    validateChannelRoles( ...
        {p.trackChannelName,p.nucleusChannelName,p.budneckChannelName}, ...
        {'tracked-label','nucleus','budneck'});
    if ~any(strcmp(p.temporalVariant,{'temporal_geometry','all_observed'}))
        error('cellLatentModel:InvalidTemporalVariant', ...
            ['temporalVariant must be temporal_geometry or ' ...
             'all_observed.']);
    end
elseif strcmp(p.backend,'continuous_cell_state')
    validateChannelRoles( ...
        {p.trackChannelName,p.brightfieldChannelName, ...
         p.nucleusChannelName,p.budneckChannelName}, ...
        {'tracked-label','brightfield','nucleus','budneck'});
elseif strcmp(p.backend,'causal_composite')
    validateChannelRoles( ...
        {p.instanceChannelName,p.brightfieldChannelName, ...
         p.nucleusChannelName,p.budneckChannelName}, ...
        {'frame-local instances','brightfield','nucleus','budneck'});
end

usesTrainedArtifact = ...
    (strcmp(p.backend,'legacy') && strcmp(p.modelSource,'trained')) || ...
    strcmp(p.backend,'continuous_cell_state');
if usesTrainedArtifact
    if isempty(p.modelPath)
        if strcmp(p.backend,'legacy')
            try
                candidate = fullfile(classif.path, ...
                    'models','latest','ensemble.pt');
                if isfile(candidate), p.modelPath = candidate; end
            catch
            end
        end
    elseif ~isfile(p.modelPath)
        try
            candidate = fullfile(classif.path,p.modelPath);
            if isfile(candidate), p.modelPath = candidate; end
        catch
        end
    end
end
if strcmp(p.backend,'causal_composite')
    p.compositeManifestPath = resolveArtifactPath( ...
        p.compositeManifestPath,classif);
    p.trackingCheckpointDir = resolveArtifactPath( ...
        p.trackingCheckpointDir,classif);
    p.modelPath = resolveArtifactPath(p.modelPath,classif);
    p.stateRuntimeConfigPath = resolveArtifactPath( ...
        p.stateRuntimeConfigPath,classif);
    if isempty(p.compositeManifestPath) || ...
            ~isfile(p.compositeManifestPath)
        error('cellLatentModel:MissingCompositeManifest', ...
            'The composite latent-model manifest was not found.');
    end
    if isempty(p.trackingCheckpointDir) || ...
            ~isfile(fullfile(p.trackingCheckpointDir,'manifest.json'))
        error('cellLatentModel:MissingTrackingCheckpoint', ...
            'The composite EDGE/APPEAR/END checkpoint was not found.');
    end
    if isempty(p.modelPath) || ~isfile(p.modelPath)
        error('cellLatentModel:MissingCompositeLineageCheckpoint', ...
            'The composite mother/NULL checkpoint was not found.');
    end
    if isMissingChoice(p.instanceChannelName)
        error('cellLatentModel:MissingInstanceChannel', ...
            'Select the frame-local instance-mask channel.');
    end
    if ~any(strcmp(p.stateUpdateMode,{'none','promoted_frozen_bf'}))
        error('cellLatentModel:InvalidStateUpdateMode', ...
            'stateUpdateMode must be none or promoted_frozen_bf.');
    end
    if strcmp(p.stateUpdateMode,'promoted_frozen_bf') && ...
            (isempty(p.stateRuntimeConfigPath) || ...
             ~isfile(p.stateRuntimeConfigPath))
        error('cellLatentModel:MissingStateRuntime', ...
            'The promoted biological-state runtime configuration was not found.');
    end
    if strcmp(p.stateUpdateMode,'promoted_frozen_bf') && ...
            isMissingChoice(p.brightfieldChannelName)
        error('cellLatentModel:MissingBrightfieldChannel', ...
            ['The promoted BF state component requires an explicit ' ...
             'brightfield channel from the current pipeline dataset.']);
    end
elseif isMissingChoice(p.trackChannelName)
    error('cellLatentModel:MissingTrackChannel', ...
        'Select a tracked-label channel.');
end
if isempty(p.outputFamilyName)
    error('cellLatentModel:MissingOutputFamily', ...
        'Output family name cannot be empty.');
end
if strcmp(p.backend,'legacy') && ...
        ~any(strcmp(p.modelSource,{'builtin','trained'}))
    error('cellLatentModel:InvalidModelSource', ...
        'modelSource must be builtin or trained.');
end
if strcmp(p.backend,'legacy') && strcmp(p.modelSource,'trained') && ...
        (isempty(p.modelPath) || ~isfile(p.modelPath))
    error('cellLatentModel:MissingTrainedModel', ...
        'The trained ensemble checkpoint was not found.');
end
if strcmp(p.backend,'continuous_cell_state')
    if ~strcmp(p.modelSource,'trained')
        error('cellLatentModel:ContinuousRequiresTrainedModel', ...
            ['continuous_cell_state requires modelSource="trained" and a ' ...
             'trusted continuous checkpoint.']);
    end
    if isempty(p.modelPath) || ~isfile(p.modelPath)
        error('cellLatentModel:MissingContinuousCheckpoint', ...
            'The trained continuous cell-state checkpoint was not found.');
    end
end
if ~any(strcmp(p.adaptiveMarkerModelSource,{'none','trained'}))
    error('cellLatentModel:InvalidAdaptiveMarkerModelSource', ...
        'adaptiveMarkerModelSource must be none or trained.');
end
if strcmp(p.adaptiveMarkerModelSource,'trained')
    if ~strcmp(p.backend,'continuous_cell_state')
        error('cellLatentModel:AdaptiveMarkerRequiresContinuous', ...
            ['The adaptive marker residual is supported only by ' ...
             'continuous_cell_state.']);
    end
    p.adaptiveMarkerModelPath = resolveArtifactPath( ...
        p.adaptiveMarkerModelPath,classif);
    if isempty(p.adaptiveMarkerModelPath) || ...
            ~isfile(p.adaptiveMarkerModelPath)
        error('cellLatentModel:MissingAdaptiveMarkerCheckpoint', ...
            'The trained adaptive marker checkpoint was not found.');
    end
    if p.causalSolverFeedback
        error('cellLatentModel:AdaptiveMarkerSolverConflict', ...
            ['Adaptive marker inference and causal solver feedback cannot ' ...
             'currently be enabled together. Disable causalSolverFeedback.']);
    end
else
    p.adaptiveMarkerModelPath = '';
end
if ~any(strcmp(p.device,{'auto','cuda','cpu'}))
    error('cellLatentModel:InvalidDevice', ...
        'device must be auto, cuda, or cpu.');
end
end

function value = resolveArtifactPath(value,classif)
if isempty(value) || isfile(value) || isfolder(value), return; end
try
    candidate = fullfile(classif.path,value);
    if isfile(candidate) || isfolder(candidate), value = candidate; end
catch
end
end

function backend = normalizeBackend(value)
backend = lower(strtrim(char(string(value))));
backend = strrep(backend,'-','_');
backend = strrep(backend,' ','_');
if isempty(backend) || any(strcmp(backend, ...
        {'legacy','relation_ensemble','relationensemble'}))
    backend = 'legacy';
elseif strcmp(backend,'continuouscellstate')
    backend = 'continuous_cell_state';
elseif any(strcmp(backend,{'causalcomposite','composite', ...
        'cell_latent_composite'}))
    backend = 'causal_composite';
elseif ~any(strcmp(backend, ...
        {'causal_composite','temporal_lineage','continuous_cell_state'}))
    error('cellLatentModel:InvalidBackend', ...
        ['backend must be causal_composite, legacy, temporal_lineage, ' ...
         'or continuous_cell_state.']);
end
end

function validateChannelRoles(roles,labels)
for i = 1:numel(roles)
    if isempty(roles{i}), continue; end
    for j = i+1:numel(roles)
        if isempty(roles{j}), continue; end
        if strcmpi(roles{i},roles{j})
            error('cellLatentModel:ConflictingChannelRoles', ...
                'Channel "%s" cannot be both %s and %s.', ...
                roles{i},labels{i},labels{j});
        end
    end
end
end

function value = normalizeFrameInterval(value,backend)
if iscell(value)
    if isempty(value), value = []; else, value = value{end}; end
end
if ischar(value) || isstring(value)
    if strlength(strtrim(string(value))) == 0
        value = [];
    else
        value = str2double(string(value));
    end
end
if isempty(value)
    if any(strcmp(backend,{'continuous_cell_state','causal_composite'}))
        error('cellLatentModel:MissingFrameInterval', ...
            ['frameIntervalMinutes must be set explicitly for ' ...
             'continuous or composite latent inference.']);
    end
    value = 1;
end
if ~isnumeric(value) || ~isscalar(value) || ...
        ~isfinite(value) || value <= 0
    error('cellLatentModel:InvalidFrameInterval', ...
        'frameIntervalMinutes must be finite and strictly positive.');
end
value = double(value);
end

function channels = collectRuntimeChannels(param,ctx,classif)
channels = {};
sources = {};
try sources{end+1} = classif.channelName; catch, end
try sources{end+1} = classif.channelName2; catch, end
try sources{end+1} = ctx.io.requiredChannels; catch, end
try sources{end+1} = ctx.params.channels; catch, end
try sources{end+1} = ctx.params.channel; catch, end
try sources{end+1} = param.channels; catch, end
try sources{end+1} = param.channel; catch, end
for i = 1:numel(sources)
    values = cellstr(string(sources{i}));
    values = values(strlength(string(values)) > 0);
    channels = [channels values(:)']; %#ok<AGROW>
end
channels = unique(channels,'stable');
end

function value = preferred(channels,patterns,fallback)
value = '';
for i = 1:numel(patterns)
    hit = find(contains(lower(string(channels)),patterns{i}),1,'last');
    if ~isempty(hit), value = channels{hit}; return; end
end
if numel(channels) >= fallback, value = channels{fallback}; end
end

function value = readChoice(value)
if iscell(value)
    if isempty(value), value = ''; else, value = value{end}; end
end
value = strtrim(char(string(value)));
end

function value = readScalar(value,fallback)
if iscell(value)
    if isempty(value), value = fallback; else, value = value{end}; end
end
if ischar(value) || isstring(value), value = str2double(string(value)); end
if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value)
    value = fallback;
end
value = double(value);
end

function tf = isMissingChoice(value)
value = strtrim(char(string(value)));
tf = isempty(value) || strcmpi(value,'N/A') || ...
    strcmpi(value,'<none>') || strcmpi(value,'<auto>');
end

function value=trainingGroundTruthChannel(classif)
value='';
try
    if isstruct(classif.trainingParam)&& ...
            isfield(classif.trainingParam,'trackChannelName')
        value=readChoice(classif.trainingParam.trackChannelName);
    end
catch
end
end
