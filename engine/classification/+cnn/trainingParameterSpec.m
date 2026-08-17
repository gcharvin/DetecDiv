function spec = trainingParameterSpec(~)
%CNN.TRAININGPARAMETERSPEC Readable metadata for every legacy CNN option.
spec=classifierBinding.parameterSpecFromDefaults(cnn.utils.defaultTrainingParam());
end
