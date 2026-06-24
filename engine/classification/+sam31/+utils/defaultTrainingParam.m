function tp = defaultTrainingParam()
% sam31.utils.defaultTrainingParam
% User-facing defaults for the DetecDiv -> SAM3.1 bridge.
%
% Repository paths, Python executable details, dataset artifact names and
% other plumbing live in sam31.utils.internalDefaults. They are deliberately
% not exposed in classifierGUI.

spec = {
    'resolution',                    {'280','1008','280'}, 'SAM3.1 working resolution. 280 is the yeast-friendly mode; 1008 is the original heavy SAM3.1 size.'
    'trainModules',                  {'semantic segmentation','instance segmentation','video memory','instance + video memory','all','instance + video memory'}, 'Training module preset.'
    'epochs',                        20,          'Training epochs.'
    'saveFreq',                      100000,      'Checkpoint save frequency in optimizer steps.'
    'clipLength',                    8,           'Number of frames per video-memory training clip.'
    'clipStride',                    4,           'Stride, in frames, between exported training clips.'
    'maxTracksPerClip',              8,           'Maximum GT tracks per training clip.'
    'minVisibleFrames',              4,           'Minimum number of visible frames required to keep a track in a clip.'
    'maxNumObjects',                 40,          'Maximum number of simultaneously tracked object slots during inference.'
    'detectorCheckpointPath',        '',          'SAM3.1 detector checkpoint used for inference; empty uses package defaults.'
    'trackerCheckpointPath',         '',          'SAM3.1 tracker/memory checkpoint used for inference; empty uses package defaults.'
    'prompt',                        'cell',      'Text prompt used to initialize SAM3.1 tracking.'
    'minScore',                      0,           'Minimum mask score kept in SAM3.1 inference output.'
    'chunkSize',                     0,           'Frames per tracking chunk. 0 tracks the full ROI movie in one session.'
    'chunkOverlap',                  0,           'Overlap, in frames, between chunks when chunkSize is enabled.'
    'videoScoreThreshold',           0.40,        'Per-frame detection score threshold.'
    'videoNewDetThreshold',          0.40,        'Threshold for accepting new detections.'
    'videoDetNmsThreshold',          0.10,        'Detection NMS threshold.'
    'videoAssocIouThreshold',        0.50,        'Temporal association IoU threshold.'
    'sam31Runner',                   {'session','external','session'}, 'Runner mode for inference. session keeps the SAM31 predictor loaded across ROIs; external starts one Python process per ROI.'
    };

tp = struct();
tip = cell(size(spec,1),1);
for i = 1:size(spec,1)
    tp.(spec{i,1}) = spec{i,2};
    tip{i} = spec{i,3};
end
tp.tip = {tip};
end
