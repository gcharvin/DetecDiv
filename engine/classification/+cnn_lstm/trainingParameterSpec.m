function spec = trainingParameterSpec(~)
%CNN_LSTM.TRAININGPARAMETERSPEC Readable metadata for every CNN/LSTM option.
spec=classifierBinding.parameterSpecFromDefaults(cnn_lstm.utils.defaultTrainingParam());
spec=setLabel(spec,'train_CNN_classifier','Train CNN backbone','Training stages');
spec=setLabel(spec,'compute_CNN_activations','Compute CNN features','Training stages');
spec=setLabel(spec,'train_LSTM_network','Train LSTM temporal head','Training stages');
spec=setLabel(spec,'assemble_network','Assemble deployable CNN + LSTM','Training stages');
spec=setLabel(spec,'classifier_output','Prediction time scale','Training objective');
end

function spec=setLabel(spec,param,label,group)
idx=find(strcmp({spec.param},param),1);
if isempty(idx),return;end
spec(idx).label=label; spec(idx).group=group;
end
