function aug = localGetH5AugParams(tp)
% Prépare une struct de paramètres homogène pour H5ImageDatastore
aug = struct();
aug.TransRange        = tp.CNN_translation_augmentation;
aug.RotRange          = tp.CNN_rotation_augmentation;
aug.CropScale         = tp.CNN_crop_scale;
aug.ContrastRange     = tp.CNN_contrast_range;
aug.BrightnessRange   = tp.CNN_brightness_range;
aug.GammaRange        = tp.CNN_gamma_range;
aug.SaturationRange   = tp.CNN_saturation_range;
aug.HueDelta          = tp.CNN_hue_delta;
aug.NoiseSigma        = tp.CNN_noise_sigma;
aug.DefocusSigmaRange = tp.CNN_defocus_sigma_range;
aug.DefocusProb       = tp.CNN_defocus_prob;
end

