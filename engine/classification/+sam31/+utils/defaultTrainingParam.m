function tp = defaultTrainingParam()
% sam31.utils.defaultTrainingParam
% User-facing defaults for the DetecDiv -> SAM3.1 bridge.
%
% Repository paths, Python executable details, dataset artifact names and
% other plumbing live in sam31.utils.internalDefaults. They are deliberately
% not exposed in classifierGUI.

spec = {
    'resolution',                    {'140','280','560','1008','280'}, 'SAM3.1 working resolution. 140/280/560 are yeast-friendly modes; 1008 is the original heavy SAM3.1 size.'
    'trainModules',                  {'semantic segmentation','instance segmentation','video memory','instance + video memory','all','instance + video memory'}, 'Training module preset.'
    'epochs',                        20,          'Training epochs.'
    'saveFreq',                      100000,      'Checkpoint save frequency in optimizer steps.'
    'clipLength',                    8,           'Number of frames per video-memory training clip.'
    'clipStride',                    4,           'Stride, in frames, between exported training clips.'
    'maxTracksPerClip',              8,           'Maximum GT tracks per training clip.'
    'minVisibleFrames',              4,           'Minimum number of visible frames required to keep a track in a clip.'
    };

tp = struct();
tip = cell(size(spec,1),1);
for i = 1:size(spec,1)
    tp.(spec{i,1}) = spec{i,2};
    tip{i} = spec{i,3};
end
tp.tip = {tip};
end
