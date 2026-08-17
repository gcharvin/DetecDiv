function defaults = trainingExecutionDefaults(classif)
%CELLLATENTTRACKER.TRAININGEXECUTIONDEFAULTS Recover deployable tracker state.
defaults = struct();
if isempty(classif), return; end
tp = cellLatentTracker.utils.defaultTrainingParam();
try
    if isstruct(classif.trainingParam)
        tp = cellLatentModel.utils.applyOverrides(tp,classif.trainingParam);
    end
catch
end
root=''; try root=char(string(classif.path)); catch, end
if isempty(root), return; end
modelName=safeName(tp.modelName);
checkpoint=fullfile(root,'models',modelName,'checkpoint');
if ~isfile(fullfile(checkpoint,'manifest.json')), return; end
defaults.imageChannelName=textValue(tp.brightfieldChannelName);
defaults.instanceChannelName=textValue(tp.instanceChannelName);
defaults.outputName=[safeName(classif.strid) '_tracks'];
defaults.checkpointDir=fullfile('models',modelName,'checkpoint');
defaults.topK=double(tp.topK);
defaults.frameIntervalMinutes=double(tp.frameIntervalMinutes);
defaults.device=textValue(tp.device);
end
function value=textValue(value),while iscell(value),if isempty(value),value='';return;end,value=value{end};end,value=strtrim(char(string(value)));end
function value=safeName(value),value=regexprep(textValue(value),'[^A-Za-z0-9_.-]','_');if isempty(value),value='latent_tracker';end,end
