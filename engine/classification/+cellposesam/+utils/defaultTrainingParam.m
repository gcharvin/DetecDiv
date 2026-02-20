function tp = defaultTrainingParam()
% cellposesam.utils.defaultTrainingParam
% Default training parameters for CellposeSAM.
% Preferred source: YAML spec (same folder).

yamlFile = fullfile(fileparts(mfilename('fullpath')), 'defaultTrainingParam.yaml');
if exist(yamlFile, 'file') == 2
    try
        tp = parseParamYaml(yamlFile);
        return;
    catch ME
        warning('cellposesam:defaultTrainingParam:YamlParse', ...
            'Failed to read %s: %s. Falling back to hardcoded defaults.', ...
            yamlFile, ME.message);
    end
end

% Fallback (keep in sync with YAML)
spec = {
    'diameter',            NaN, 'Expected average diameter of objects'
    'min_size',            10,  'Minimum size to keep (object)'
    'flow_threshold',      0.4, 'Flow threshold'
    'cell_prob_threshold', 0,   'Cell probability threshold -6 --> 6; default : 0'
    'n_epochs',            50,  'Number of training epochs'
    'learning_rate',       1e-4, 'Learning rate'
    'weight_decay',        1e-5, 'Weight decay (L2 regularization)'
    'batch_size',          1,   'Batch size'
    'min_train_masks',     0,   'Minimum number of masks per image (USED IN FORMAT)'
    'min_train_pixels',    0,   'Minimum number of foreground pixels per image (USED IN FORMAT)'
    'use_pretrained',      true, 'Use pretrained SAM model (true/false)'
    'verbose',             true, 'Verbose logging during training'
    'MaxTrainImages',      200,  'Max number of images used for training'
    'Seed',                12345,'Seed for random number generation'
    'NegDownsampleTrainRatio', 1, 'Downsampling of negative images (0: none; 1: at most as many negatives as positives)'
    'CPSAM_ValFraction',   0.2,  'Train/val/test splitting ratio (used in FORMAT to define /split fractions)'
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
            if ~isempty(cur.name)
                items{end+1} = cur; %#ok<AGROW>
                cur = struct('name','','value',[],'tip','', 'default','');
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

    if (startsWith(raw, '''') && endsWith(raw, '''')) || ...
       (startsWith(raw, '"')  && endsWith(raw, '"'))
        v = raw(2:end-1);
        return;
    end

    if startsWith(raw, '[') && endsWith(raw, ']')
        inner = strtrim(raw(2:end-1));
        if isempty(inner)
            v = [];
            return;
        end
        if contains(inner, ',')
            parts = strtrim(strsplit(inner, ','));
        else
            parts = strtrim(strsplit(inner));
        end

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

    if strcmpi(raw,'true')
        v = true;
        return;
    elseif strcmpi(raw,'false')
        v = false;
        return;
    end

    num = str2double(raw);
    if ~isnan(num)
        v = num;
        return;
    end

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
