function defaults = trainingExecutionDefaults(classif)
%CELLLATENTMODEL.TRAININGEXECUTIONDEFAULTS Infer deployable training state.
%
% This also migrates continuous/legacy trainings completed before DetecDiv
% persisted a generic post-training execution snapshot.

defaults = struct();
if isempty(classif)
    return;
end
tp = cellLatentModel.utils.defaultTrainingParam();
try
    if isstruct(classif.trainingParam)
        tp = cellLatentModel.utils.applyOverrides(tp, classif.trainingParam);
    end
catch
end

objective = selectedText(tp.trainingObjective, 'relation_ensemble');
modelName = selectedText(tp.modelName, 'cell_latent_relation_v001');
root = '';
try
    root = char(string(classif.path));
catch
end
if isempty(root)
    return;
end
modelDir = fullfile(root, 'models', modelName);
report = fullfile(modelDir, 'training_report.json');
if strcmp(objective, 'continuous_lineage')
    checkpointName = 'continuous_cell_state.pt';
else
    checkpointName = 'ensemble.pt';
end
checkpoint = fullfile(modelDir, checkpointName);
if exist(checkpoint, 'file') ~= 2 || exist(report, 'file') ~= 2
    return;
end

defaults.modelSource = 'trained';
defaults.modelPath = fullfile('models', modelName, checkpointName);
defaults.trackChannelName = selectedText(tp.trackChannelName, '');
defaults.device = selectedText(tp.device, 'auto');
if strcmp(objective, 'continuous_lineage')
    defaults.backend = 'continuous_cell_state';
    defaults.temporalVariant = continuousVariant(tp.continuousVariant);
    defaults.frameIntervalMinutes = tp.frameIntervalMinutes;
    defaults.gfpChannelName = '';
    defaults.brightfieldChannelName = ...
        selectedText(tp.brightfieldChannelName, '');
    defaults.nucleusChannelName = selectedText(tp.nucleusChannelName, '');
    defaults.budneckChannelName = selectedText(tp.budneckChannelName, '');
    defaults.causalSolverFeedback = logical(tp.continuousCausalFeedback);
    defaults.materializeCellStates = false;
    defaults.primaryStateAxis = 'none';
else
    defaults.backend = 'legacy';
    defaults.gfpChannelName = selectedText(tp.gfpChannelName, '');
end
end

function value = selectedText(value, fallback)
while iscell(value)
    if isempty(value)
        value = fallback;
        return;
    end
    value = value{end};
end
value = strtrim(char(string(value)));
if isempty(value)
    value = fallback;
end
end

function value = continuousVariant(raw)
value = lower(selectedText(raw, 'all_observed'));
if strcmp(value, 'geometry')
    value = 'temporal_geometry';
elseif ~any(strcmp(value, {'temporal_geometry','all_observed'}))
    value = 'all_observed';
end
end
