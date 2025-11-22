function augParams = localGetH5AugParams(trainingParam)
% Paramètres d'augmentation à partager entre entraînement CNN et lecture HDF5
augParams = struct();
augParams.TransRange    = trainingParam.CNN_translation_augmentation;
augParams.RotRange      = trainingParam.CNN_rotation_augmentation;
augParams.CropScale     = trainingParam.CNN_crop_scale;
augParams.ContrastRange = trainingParam.CNN_contrast_range;
augParams.HueDelta      = trainingParam.CNN_hue_delta;
augParams.NoiseSigma    = trainingParam.CNN_noise_sigma;

function layers = freezeWeights(layers)
for ii = 1:size(layers,1)
    props = properties(layers(ii));
    for p = 1:numel(props)
        propName = props{p};
        if ~isempty(regexp(propName, 'LearnRateFactor$', 'once'))
            layers(ii).(propName) = 0;
        end
    end
end