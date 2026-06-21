function tp = defaultTrainingParam()
% sam31.utils.defaultTrainingParam
% Defaults for the DetecDiv -> SAM3.1 bridge.

defaultRepo = fullfile(getenv('USERPROFILE'), 'Documents', 'MATLAB', 'SAM31_zero_shot_ctc_benchmark');
defaultSam3 = fullfile(defaultRepo, 'artifacts', 'sam3_official');

spec = {
    'backend',                       'wsl',       'Execution backend: wsl or local'
    'pythonExecutable',              '/home/gilles/venvs/sam3/bin/python', 'Python executable used by the selected backend'
    'repoRoot',                      defaultRepo, 'Generic SAM31 benchmark repository root'
    'sam3Repo',                      defaultSam3, 'Official SAM3.1 checkout'
    'artifactsRoot',                 '',          'SAM31 artifacts root; empty means <classifier path>/sam31_artifacts'
    'resolution',                    280,         'SAM3.1 image/video resolution'
    'numGpus',                       1,           'Number of GPUs for training'
    'trainModules',                  'instance video-memory', 'Modules to train: semantic, instance, video-memory, or all'
    'prepareBeforeTrain',            true,        'Convert DetecDiv CTC export to SAM31 datasets before training'
    'splits',                        'train val', 'Dataset splits exported to SAM31'
    'imageDatasetName',              'moma_sam31_image_coco', 'SAM31 image dataset artifact name'
    'videoDatasetName',              'moma_sam31_video', 'SAM31 full-video dataset artifact name'
    'trackletDatasetName',           'moma_sam31_tracklet_clips_len8_ref', 'SAM31 tracklet dataset artifact name'
    'epochs',                        20,          'Training epochs for image modules; video-memory uses this when provided'
    'saveFreq',                      100000,      'Checkpoint save frequency'
    'clipLength',                    8,           'Tracklet clip length for video-memory training'
    'clipStride',                    4,           'Tracklet clip stride'
    'maxTracksPerClip',              8,           'Maximum GT tracks per tracklet clip'
    'minVisibleFrames',              4,           'Minimum visible frames per retained track'
    'stageStrideMax',                4,           'SAM31 video training stage stride max'
    'maxTracksPerDatapoint',         8,           'SAM31 video training max tracks per datapoint'
    'detectorCheckpointPath',        '',          'SAM31 detector checkpoint used for inference'
    'trackerCheckpointPath',         '',          'SAM31 tracker/memory checkpoint used for inference'
    'maxNumObjects',                 40,          'SAM31 video object-slot budget'
    'chunkSize',                     0,           'Inference chunk size; 0 means full ROI in one SAM31 session'
    'chunkOverlap',                  0,           'Inference chunk overlap'
    'prompt',                        'cell',      'Text prompt for SAM31 full model inference'
    'promptMode',                    'text',      'Prompt mode'
    'minScore',                      0.0,         'Minimum output probability score'
    'videoScoreThreshold',           0.40,        'SAM31 video detection score threshold'
    'videoNewDetThreshold',          0.40,        'SAM31 threshold for accepting new detections'
    'videoDetNmsThreshold',          0.10,        'SAM31 detection NMS threshold'
    'videoAssocIouThreshold',        0.50,        'SAM31 association IoU threshold'
    'outputName',                    'sam31',     'DetecDiv output channel name suffix'
    };

tp = struct();
tip = cell(size(spec,1),1);
for i = 1:size(spec,1)
    tp.(spec{i,1}) = spec{i,2};
    tip{i} = spec{i,3};
end
tp.tip = {tip};
end
