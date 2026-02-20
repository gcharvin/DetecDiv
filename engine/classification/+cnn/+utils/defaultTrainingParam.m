function tp = defaultTrainingParam()
% CNN.utils.defaultTrainingParam
% Default training parameters for simple CNN image classifier.
% Preferred source: YAML spec (same folder).

yamlFile = fullfile(fileparts(mfilename('fullpath')), 'defaultTrainingParam.yaml');
if exist(yamlFile, 'file') == 2
    try
        tp = parseParamYaml(yamlFile);
        return;
    catch ME
        warning('cnn:defaultTrainingParam:YamlParse', ...
            'Failed to read %s: %s. Falling back to hardcoded defaults.', ...
            yamlFile, ME.message);
    end
end

% Fallback (keep in sync with YAML)
spec = {
    'CNN_training_method',   {{'adam','sgdm'}}, 'Choose the training method', 'adam'
    'CNN_network',           {{'googlenet','inceptionresnetv2','inceptionv3','resnet18','resnet50','resnet101','nasnetlarge','efficientnetb0'}}, 'Choose the CNN', 'googlenet'
    'CNN_mini_batch_size',   8, 'Choose the size of the mini batch; Higher values require more memory and are prone to errors'
    'CNN_max_epochs',        6, 'Enter the number of epochs'
    'CNN_initial_learning_rate', 0.0003, 'Enter the initial learning rate'
    'CNN_learn_rate_drop_factor', 0.9, 'Enter the learning rate drop factor'
    'CNN_data_shuffling',    {{'once','every-epoch','never'}}, 'Choose whether and how training and validation data should be shuffled during training', 'every-epoch'
    'CNN_data_splitting_factor', 0.7, 'Enter fraction of the data to be used for training vs validation during training'
    'CNN_translation_augmentation', [-5 5], 'Enter the magnitude of translation for data augmentation (in pixels)'
    'CNN_rotation_augmentation',    [-20 20], 'Enter the magnitude of rotation for data augmentation (in degrees)'
    'CNN_l2_regularization', 0.0001, 'Specify value for L2 regularization'
    'CNN_use_dropout',       true, 'Check to use a dropout layer'
    'CNN_dropout',           0.5, 'Value for dropout regularization'
    'execution_environment', {{'auto','parallel','cpu','gpu','multi-gpu'}}, 'Choose execution environment', 'auto'
    'transfer_learning',     {{'ImageNet'}}, 'Select initial version of network to start training with; Default: ImageNet', 'ImageNet'
    'CNN_rand_scale',        [0.8 1.0], 'Range of random scale factor for CNN augmentation (e.g. [0.8 1.0])'
    'CNN_rand_flip',         true, 'Enable random flips (left/right & up/down) during CNN augmentation'
    'CNN_crop_scale',        [0.8 1.0], 'Crop-in scale range for CNN augmentation (e.g. [0.8 1.0])'
    'CNN_contrast_range',    [1 1], 'Contrast multiplier range for CNN augmentation (e.g. [0.85 1.15])'
    'CNN_brightness_range',  [0 0], 'Brightness offset range (additive, e.g. [-0.10 0.10])'
    'CNN_gamma_range',       [1 1], 'Gamma exponent range for CNN augmentation (e.g. [0.9 1.1])'
    'CNN_saturation_range',  [1 1], 'Saturation multiplier range (RGB only, e.g. [0.95 1.05])'
    'CNN_hue_delta',         0, 'Maximum hue jitter (0-0.5, small values recommended)'
    'CNN_noise_sigma',       0, 'Std-dev of Gaussian noise for CNN augmentation (set 0 to disable)'
    'CNN_defocus_sigma_range', [0 0], 'Defocus sigma range in pixels (e.g. [0.3 1.0])'
    'CNN_defocus_prob',      0, 'Probability to apply defocus blur (e.g. 0.5)'
    'Format_Fraction',       1.0, 'Fraction of ROIs used when formatting the training set'
    'Format_Seed',           12345, 'Random seed used when sampling ROIs / frames for formatting'
    'Format_Crop',           false, 'Enable cropping when formatting the training set (true/false)'
    'Format_CropCenter',     [88 194], 'Crop center [cx cy] used for formatting the training set'
    'Format_CropSize',       [60 60], 'Crop size [w h] used for formatting the training set'
    'Format_UndersampleMajority', 1.0, 'Undersample majority classes (1 = no undersampling)'
    'Format_StorageBackend', {{'hdf5','tiff'}}, 'Storage backend for formatted data (''hdf5'' or ''tiff'')', 'hdf5'
    };

tp = specToStruct(spec);
end

function tp = parseParamYaml(yamlFile)
    txt = fileread(yamlFile);
    lines = regexp(txt, '\r\n|\n|\r', 'split');

    items = {};
    cur = struct('name','','value',[],'tip','', 'default','');

    for i = 1:numel(lines)
        line = strtrim(lines{i});
        if isempty(line) || startsWith(line,'#')
            continue;
        end

        if startsWith(line,'- ')
            % flush previous
            if ~isempty(cur.name)
                items{end+1} = cur; %#ok<AGROW>
                cur = struct('name','','value',[],'tip','');
            end
            line = strtrim(line(3:end));
        end

        if startsWith(line,'name:')
            cur.name = strtrim(line(numel('name:')+1:end));
        elseif startsWith(line,'value:')
            raw = strtrim(line(numel('value:')+1:end));
            cur.value = parseYamlValue(raw);
        elseif startsWith(line,'tip:')
            cur.tip = strtrim(line(numel('tip:')+1:end));
        elseif startsWith(line,'default:')
            cur.default = strtrim(line(numel('default:')+1:end));
        end
    end

    if ~isempty(cur.name)
        items{end+1} = cur;
    end

    spec = cell(numel(items), 4);
    for i = 1:numel(items)
        spec{i,1} = items{i}.name;
        spec{i,2} = items{i}.value;
        spec{i,3} = items{i}.tip;
        spec{i,4} = items{i}.default;
    end

    tp = specToStruct(spec);
end

function v = parseYamlValue(raw)
    if isempty(raw)
        v = '';
        return;
    end

    % quoted string
    if (startsWith(raw, '''') && endsWith(raw, '''')) || ...
       (startsWith(raw, '"')  && endsWith(raw, '"'))
        v = raw(2:end-1);
        return;
    end

    % list
    if startsWith(raw, '[') && endsWith(raw, ']')
        inner = strtrim(raw(2:end-1));
        if isempty(inner)
            v = [];
            return;
        end
        % split by comma first, fallback to whitespace
        if contains(inner, ',')
            parts = strtrim(strsplit(inner, ','));
        else
            parts = strtrim(strsplit(inner));
        end

        % parse parts
        isNum = true;
        nums = zeros(1, numel(parts));
        strs = cell(1, numel(parts));
        for i = 1:numel(parts)
            p = parts{i};
            if strcmpi(p,'true')
                strs{i} = 'true';
                isNum = false;
            elseif strcmpi(p,'false')
                strs{i} = 'false';
                isNum = false;
            else
                val = str2double(p);
                if ~isnan(val)
                    nums(i) = val;
                    strs{i} = p;
                else
                    isNum = false;
                    strs{i} = stripQuotes(p);
                end
            end
        end

        if isNum
            v = nums;
        else
            v = strs;
        end
        return;
    end

    % logical
    if strcmpi(raw,'true')
        v = true;
        return;
    elseif strcmpi(raw,'false')
        v = false;
        return;
    end

    % numeric
    num = str2double(raw);
    if ~isnan(num)
        v = num;
        return;
    end

    % plain string
    v = stripQuotes(raw);
end

function out = stripQuotes(s)
    out = s;
    if (startsWith(out, '''') && endsWith(out, '''')) || ...
       (startsWith(out, '"')  && endsWith(out, '"'))
        out = out(2:end-1);
    end
end

function tp = specToStruct(spec)
    tp = struct();
    tip = cell(size(spec,1),1);
    for i = 1:size(spec,1)
        name = spec{i,1};
        val  = spec{i,2};
        tip{i} = spec{i,3};
        def = [];
        if size(spec,2) >= 4
            def = spec{i,4};
        end

        if iscell(val) && ~isempty(val) && all(cellfun(@ischar, val))
            if ~isempty(def)
                def = char(string(def));
                val = val(~strcmp(val, def));
                val = [val, {def}];
            end
        end

        tp.(name) = val;
    end
    tp.tip = {tip};
end
