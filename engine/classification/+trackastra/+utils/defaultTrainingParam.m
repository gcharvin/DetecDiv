function tp = defaultTrainingParam()
% trackastra.utils.defaultTrainingParam  Trackastra training/export defaults.

spec = {
    'imageChannelName',        '',             'Raw/intensity channel; empty uses the first selected classifier input.'
    'groundTruthChannelName',  '',             'Indexed stable-tracklet GT; empty uses the classifier annotation channel.'
    'validationFraction',      0.2,            'Fraction of training ROIs held out when no validation split is defined.'
    'epochs',                  100,            'Number of Trackastra training epochs.'
    'warmupEpochs',            10,             'Linear learning-rate warmup epochs.'
    'window',                  6,              'Temporal window length.'
    'batchSize',               8,              'Training batch size.'
    'cropSize',                [256 256],       'Random spatial crop [height width].'
    'maxTokens',               2048,            'Maximum detections per training sample.'
    'trainSamples',            50000,           'Balanced samples drawn per training epoch.'
    'learningRate',            1e-4,            'AdamW learning rate.'
    'numWorkers',              0,               'Training data-loader worker processes (0 is safest on Windows).'
    'augment',                 3,               'Trackastra augmentation level.'
    'features',                'wrfeat',        'Object feature extractor used by Trackastra.'
    'device',                  'cuda',          'Training device.'
    'distributed',             false,           'Enable Lightning distributed training.'
    'logger',                  'tensorboard',   'Training logger: tensorboard, wandb, or none.'
    'modelName',               'trackastra_detecdiv', 'Output model/run folder name.'
    'initialModelPath',        '',              'Optional Trackastra model folder used to initialize training.'
    'resume',                  true,            'Resume the last checkpoint in the same model folder.'
    'trackastraVersion',       '0.5.3',         'Pinned upstream training-source version.'
    'trackastraSourceRoot',    '',              'Optional existing Trackastra source root containing scripts/train.py.'
    };

tp = struct();
tip = cell(size(spec,1),1);
for i = 1:size(spec,1)
    tp.(spec{i,1}) = spec{i,2};
    tip{i} = spec{i,3};
end
tp.tip = {tip};
end
