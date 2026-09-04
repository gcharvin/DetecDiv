function info = annotationActiveModelInfo(classif, roiIndices, plan)
%ANNOTATIONACTIVEMODELINFO Describe the model used to seed editable GT.
%   This is intentionally a read-only UI helper. Prediction itself is
%   delegated to classifierPredictForAnnotation, which resolves and audits
%   the effective per-ROI inputs without consulting ground truth.

if nargin < 2, roiIndices = []; end
if nargin < 3, plan = []; end
info = struct( ...
    'available', false, ...
    'supported', false, ...
    'classifierId', '', ...
    'package', '', ...
    'releaseId', '', ...
    'modelReference', '', ...
    'modelLabel', '', ...
    'inputs', {{}}, ...
    'roiIndices', double(roiIndices(:)'), ...
    'usesGroundTruth', false, ...
    'inputsResolved', true, ...
    'inputMappingRequired', false, ...
    'hasExistingMaskInputs', false, ...
    'canRunOnExistingInputs', false, ...
    'issues', {{}}, ...
    'reason', ['Only cellLatentModel and CellposeSAM classifiers support ' ...
        'direct prediction-assisted GT initialization.']);

if isempty(classif), return; end
try, info.classifierId = char(string(classif.strid)); catch, end
package = '';
try, package = char(string(classif.classifierPkg)); catch, end
if isempty(package)
    try
        fun = char(string(classif.classifyFun));
        if any(strcmpi(fun, {'classifyCPSAMFun','cellposesam.classify'}))
            package = 'cellposesam';
        end
    catch
    end
end
info.package = package;
if ~any(strcmpi(strtrim(package), {'cellLatentModel','cellposesam'})), return; end
info.supported = true;

if strcmpi(package, 'cellposesam')
    if ~isempty(plan)
        info = applyPlan(info, plan);
        return;
    end
    [reference, label] = cellposeModelReference(classif);
    info.available = true;
    info.modelReference = reference;
    info.modelLabel = label;
    try
        channel = char(string(classif.channelName));
        if ~isempty(channel), info.inputs = {['Microscopy image: ' channel]}; end
    catch
    end
    info.reason = '';
    return;
end

parameters = struct();
try
    if isstruct(classif.executionParam), parameters = classif.executionParam; end
catch
end
% Training can replace the deployable backend and artifacts without
% rewriting the classifier object immediately.  Resolve the same immutable
% post-training snapshot used by classify/annotation inference; otherwise a
% stale legacy executionParam hides a valid trained model from the GT seed
% dialog even though prediction would run the trained model.
try
    spec = cellLatentModel.executionSpec(classif);
    parameters = classifierApplyTrainingExecutionDefaults( ...
        parameters, classif, spec, 'active_model');
catch
end
if ~isempty(plan)
    info = applyPlan(info, plan);
    return;
end
info.releaseId = fieldText(parameters, 'resolvedModelReleaseId');
source = fieldText(parameters, 'modelSource');
if ~strcmpi(source, 'trained')
    info.reason = ['The active cellLatentModel classifier does not reference ' ...
        'a trained model.'];
    return;
end

[reference, label] = modelReference(parameters);
if isempty(reference)
    info.reason = ['The classifier says modelSource=trained, but no model ' ...
        'manifest or checkpoint is referenced.'];
    return;
end
resolved = resolveClassifierPath(classif, reference);
if ~(isfile(resolved) || isfolder(resolved))
    info.reason = sprintf('The active model reference was not found: %s', resolved);
    return;
end

info.available = true;
info.modelReference = resolved;
info.modelLabel = label;
info.inputs = inputDescriptions(parameters);
% A model artifact alone is not enough to expose the annotation action.
% The per-ROI read-only plan must also confirm an existing compatible
% PRED mask/track input (or a safe user-selectable mapping).
info.canRunOnExistingInputs = false;
info.reason = '';
end

function info = applyPlan(info, plan)
try
    if isfield(plan, 'canRun')
        info.inputsResolved = logical(plan.canRun);
    else
        info.inputsResolved = logical(plan.available);
    end
catch
end
try
    package = fieldText(plan.model, 'package');
    info.package = package;
    modelUsable = logical(plan.model.available);
    if strcmpi(package, 'cellLatentModel')
        modelUsable = modelUsable && ...
            strcmpi(fieldText(plan.model, 'modelSource'), 'trained');
    end
    info.available = modelUsable;
catch
    info.available = false;
end
try, info.issues = cellstr(string(plan.issues)); catch, end
if ~isempty(info.issues)
    info.reason = char(strjoin(string(info.issues), newline));
end
try
    model = plan.model;
    info.releaseId = fieldText(model, 'releaseId');
    candidates = {'compositeManifestPath','modelPath','trackingCheckpointDir'};
    for i = 1:numel(candidates)
        value = fieldText(model, candidates{i});
        if ~isempty(value)
            info.modelReference = value;
            break;
        end
    end
    if isempty(info.modelReference)
        info.modelReference = fieldText(model, 'modelLabel');
    end
    info.modelLabel = fieldText(model, 'modelLabel');
catch
end
try
    info.inputMappingRequired = ~isempty(annotationInputMappingRequests(plan));
catch
    info.inputMappingRequired = false;
end
info.hasExistingMaskInputs = planHasRequiredInputs(plan);
info.canRunOnExistingInputs = info.available && ...
    info.hasExistingMaskInputs && ...
    (info.inputsResolved || info.inputMappingRequired);
if info.available && info.inputsResolved, info.reason = ''; end
try
    descriptions = {};
    items = plan.items;
    for i = 1:numel(items)
        inputs = items(i).inputs;
        resolution = inputs.resolution;
        roles = fieldnames(resolution);
        selected = {};
        for j = 1:numel(roles)
            value = fieldText(resolution.(roles{j}), 'selected');
            if ~isempty(value)
                selected{end+1} = sprintf('%s: %s', ...
                    inputRoleLabel(roles{j}), value); %#ok<AGROW>
            end
        end
        if isempty(selected), selected = {'required inputs unresolved'}; end
        descriptions{end+1} = sprintf('ROI %s — %s', ...
            char(string(items(i).roiId)), strjoin(selected, ' | ')); %#ok<AGROW>
    end
    if ~isempty(descriptions), info.inputs = descriptions; end
catch
end
end

function tf = planHasRequiredInputs(plan)
tf = false;
try
    items = plan.items;
    if isempty(items), return; end
    tf = true;
    for i = 1:numel(items)
        resolution = items(i).inputs.resolution;
        roles = fieldnames(resolution);
        for j = 1:numel(roles)
            entry = resolution.(roles{j});
            required = false;
            try, required = logical(entry.required); catch, end
            required = required || any(strcmp(roles{j}, ...
                {'instanceChannelName','inputChannelName'}));
            if ~required, continue; end
            selected = fieldText(entry, 'selected');
            candidates = {};
            try, candidates = cellstr(string(entry.candidates)); catch, end
            candidates = candidates(strlength(string(candidates)) > 0);
            if isempty(selected) && isempty(candidates)
                tf = false;
                return;
            end
        end
    end
catch
    tf = false;
end
end

function label = inputRoleLabel(role)
switch char(string(role))
    case 'inputChannelName', label = 'Microscopy image';
    case 'instanceChannelName', label = 'Instance masks';
    case 'brightfieldChannelName', label = 'Brightfield';
    case 'nucleusChannelName', label = 'Division/nucleus';
    case 'budneckChannelName', label = 'Bud-neck';
    otherwise, label = char(string(role));
end
end

function [reference, label] = cellposeModelReference(classif)
reference = 'CellposeSAM default SAM model';
label = 'built-in default model';
root = '';
id = '';
try, root = char(string(classif.path)); catch, end
try, id = char(string(classif.strid)); catch, end
if isempty(root) || isempty(id), return; end
candidates = {fullfile(root, 'models', id), ...
    fullfile(root, 'models', [id '.pth'])};
for i = 1:numel(candidates)
    if isfile(candidates{i})
        reference = candidates{i};
        label = 'active local model';
        return;
    end
end
end

function [reference, label] = modelReference(parameters)
reference = fieldText(parameters, 'compositeManifestPath');
label = 'composite manifest';
if isempty(reference)
    reference = fieldText(parameters, 'modelPath');
    label = 'model checkpoint';
end
if isempty(reference)
    reference = fieldText(parameters, 'trackingCheckpointDir');
    label = 'tracking checkpoint';
end
end

function values = inputDescriptions(parameters)
definitions = { ...
    'instanceChannelName', 'Instance masks', true; ...
    'brightfieldChannelName', 'Brightfield', false; ...
    'gfpChannelName', 'Legacy GFP', false; ...
    'nucleusChannelName', 'Division/nucleus', false; ...
    'budneckChannelName', 'Bud-neck', false};
values = {};
for i = 1:size(definitions, 1)
    value = fieldText(parameters, definitions{i,1});
    if isempty(value)
        if definitions{i,3}
            values{end+1} = sprintf('%s: resolve automatically per ROI', ...
                definitions{i,2}); %#ok<AGROW>
        end
    else
        values{end+1} = sprintf('%s: %s', definitions{i,2}, value); %#ok<AGROW>
    end
end
if isempty(values), values = {'Inputs: resolve automatically per ROI'}; end
end

function value = fieldText(parameters, name)
value = '';
try
    if isfield(parameters, name)
        value = strtrim(char(string(parameters.(name))));
    end
catch
end
end

function value = resolveClassifierPath(classif, reference)
value = char(string(reference));
if isAbsolutePath(value), return; end
try
    root = char(string(classif.path));
    if ~isempty(root), value = fullfile(root, value); end
catch
end
end

function tf = isAbsolutePath(value)
tf = ~isempty(regexp(value, '^[A-Za-z]:[\\/]', 'once')) || ...
    startsWith(value, '/') || startsWith(value, '\\');
end
