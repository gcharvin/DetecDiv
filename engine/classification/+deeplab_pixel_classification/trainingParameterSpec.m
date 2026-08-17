function spec = trainingParameterSpec(~)
%DEEPLAB_PIXEL_CLASSIFICATION.TRAININGPARAMETERSPEC Readable DeepLab options.
spec=classifierBinding.parameterSpecFromDefaults( ...
    deeplab_pixel_classification.utils.defaultTrainingParam());
end
