function scope = trainingScopeSpec(classif)
%CNN_LSTM.TRAININGSCOPESPEC Dynamic CNN/LSTM ownership contract.
tp=trainingParams(classif);
trained={}; frozen={}; notes={};
if logicalValue(tp,'train_CNN_classifier',true)
    trained{end+1}='CNN image backbone and frame classifier';
else
    frozen{end+1}='CNN image backbone and frame classifier';
end
if logicalValue(tp,'train_LSTM_network',true)
    trained{end+1}='LSTM temporal classification head';
else
    frozen{end+1}='LSTM temporal classification head';
end
if logicalValue(tp,'compute_CNN_activations',true)
    notes{end+1}='CNN activations are recomputed; this operation does not itself update weights.';
else
    notes{end+1}='Previously formatted CNN activations are reused.';
end
if logicalValue(tp,'assemble_network',true)
    notes{end+1}='A deployable CNN + LSTM artifact is assembled after fitting.';
end
if isempty(trained),trained={'No weight update selected'};end
frozen=[frozen {'Segmentation modules','tracking modules','lineage modules'}];
objective=textValue(tp,'classifier_output','sequence-to-sequence');
scope=classifierBinding.newTrainingScope( ...
    'module','cnn_lstm', ...
    'displayName','CNN + LSTM — temporal classifier', ...
    'objective',['Predict reviewed ' strrep(objective,'-',' ') ' labels from image sequences.'], ...
    'trainedComponents',trained,'frozenComponents',frozen, ...
    'datasetUnit','Formatted image sequences and reviewed frame/sequence labels.', ...
    'splitPolicy',['CNN and LSTM legacy split fractions are configured separately; ' ...
        'neither is guaranteed ROI-disjoint unless the formatted dataset is pre-split by ROI.'], ...
    'outputParameter','outputName','outputQuality','pred', ...
    'outputSemantic','temporal classification dataseries', ...
    'outputTemplate','<outputName>', ...
    'canonicalOutput','pred_cnn_lstm_frame_class','notes',notes);
end

function tp=trainingParams(classif)
tp=cnn_lstm.utils.defaultTrainingParam();
try
    if isobject(classif)&&isprop(classif,'trainingParam')&&isstruct(classif.trainingParam)
        tp=classif.trainingParam;
    elseif isstruct(classif)&&isfield(classif,'trainingParam')&&isstruct(classif.trainingParam)
        tp=classif.trainingParam;
    end
catch
end
end
function value=logicalValue(tp,name,fallback)
value=fallback;
try
    raw=tp.(name); while iscell(raw),raw=raw{end};end
    value=logical(raw);
catch
end
end
function value=textValue(tp,name,fallback)
value=fallback;
try raw=tp.(name);while iscell(raw),raw=raw{end};end,value=char(string(raw));catch,end
end
