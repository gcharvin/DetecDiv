function spec = executionSpec(classif)
% cnn_lstm.executionSpec  Execution-time parameter contract.
%
% CNN/LSTM training parameters describe how the model was trained, including
% classifier_output (sequence-to-sequence vs sequence-to-one). Pipeline nodes
% should not silently rewrite those training/model-shape fields. They only
% own execution choices such as which trained outputs to materialize and an
% optional CPU/GPU override.

if nargin < 1
    classif = [];
end

spec = struct();
spec.summary = 'CNN/LSTM execution parameters used by pipeline nodes.';
spec.staticKeys = {'outputMode','executionEnvironment'};
spec.outputKeys = {'outputName','cnnOutputName'};
spec.defaultImportKeys = {'outputMode','executionEnvironment'};
spec.outputProvenance = struct('quality','pred','producer','cnn_lstm', ...
    'semantic','temporal_classification','template','<outputName>');

spec.defaults = struct( ...
    'outputMode', 'lstm_only', ...
    'outputName', 'pred_cnn_lstm_frame_class', ...
    'cnnOutputName', 'pred_cnn_frame_class', ...
    'executionEnvironment', 'module_default');

spec.labels = struct( ...
    'outputMode', 'Output resource', ...
    'outputName', '[PRED] LSTM output name', ...
    'cnnOutputName', '[PRED] CNN output name', ...
    'executionEnvironment', 'Execution environment');

spec.tips = struct( ...
    'outputMode', ['Controls which inference outputs this pipeline node writes: ' ...
                   'LSTM dataseries, CNN dataseries, or both.'], ...
    'outputName', ['Prediction dataseries group used for the primary LSTM output. ' ...
                   'Historical saved names remain valid.'], ...
    'cnnOutputName', ['Prediction dataseries group used when a separate CNN ' ...
                      'output is written; this is never GT.'], ...
    'executionEnvironment', ['Optional node-local CPU/GPU override. Module default ' ...
                             'keeps the run-level execution policy.']);

spec.choices = struct();
spec.choices.outputMode = {'lstm_only','cnn_only','both'};
spec.choices.executionEnvironment = {'module_default','cpu','gpu'};

spec.defaults = mergeDefaultsFromClassi(spec.defaults, classif);
spec.defaults.outputMode = normalizeOutputMode(spec.defaults.outputMode);
spec.defaults.executionEnvironment = normalizeExecutionEnvironment(spec.defaults.executionEnvironment);
end

function defaults = mergeDefaultsFromClassi(defaults, classif)
if isempty(classif)
    return;
end

sources = {};
try
    if isobject(classif) && isprop(classif, 'executionParam') && isstruct(classif.executionParam)
        sources{end+1} = classif.executionParam; %#ok<AGROW>
    elseif isstruct(classif) && isfield(classif, 'executionParam') && isstruct(classif.executionParam)
        sources{end+1} = classif.executionParam; %#ok<AGROW>
    end
catch
end
try
    if isobject(classif) && isprop(classif, 'defaultExecutionParam') && isstruct(classif.defaultExecutionParam)
        sources{end+1} = classif.defaultExecutionParam; %#ok<AGROW>
    elseif isstruct(classif) && isfield(classif, 'defaultExecutionParam') && isstruct(classif.defaultExecutionParam)
        sources{end+1} = classif.defaultExecutionParam; %#ok<AGROW>
    end
catch
end
try
    if isobject(classif) && isprop(classif, 'runProfiles') && isstruct(classif.runProfiles) && ...
            isfield(classif.runProfiles, 'classify') && isstruct(classif.runProfiles.classify)
        sources{end+1} = classif.runProfiles.classify; %#ok<AGROW>
    elseif isstruct(classif) && isfield(classif, 'runProfiles') && isstruct(classif.runProfiles) && ...
            isfield(classif.runProfiles, 'classify') && isstruct(classif.runProfiles.classify)
        sources{end+1} = classif.runProfiles.classify; %#ok<AGROW>
    end
catch
end

keys = fieldnames(defaults);
explicitOutput=false;
for s = 1:numel(sources)
    src = sources{s};
    explicitOutput=explicitOutput|| ...
        (isfield(src,'outputName')&&~isempty(src.outputName));
    for i = 1:numel(keys)
        key = keys{i};
        if isfield(src, key) && ~isempty(src.(key))
            defaults.(key) = src.(key);
        end
    end
end

if ~explicitOutput
    try
        id=char(string(classif.strid));
        if ~isempty(id)
            defaults.outputName=id;
            defaults.cnnOutputName=['cnn_' id];
        end
    catch
    end
end

try
    if isobject(classif) && isprop(classif, 'outputType') && ~isempty(classif.outputType)
        ot = normalizeOutputMode(classif.outputType);
        if any(strcmp(ot, {'lstm_only','cnn_only','both'}))
            defaults.outputMode = ot;
        end
    elseif isstruct(classif) && isfield(classif, 'outputType') && ~isempty(classif.outputType)
        ot = normalizeOutputMode(classif.outputType);
        if any(strcmp(ot, {'lstm_only','cnn_only','both'}))
            defaults.outputMode = ot;
        end
    end
catch
end

try
    tp = [];
    if isobject(classif) && isprop(classif, 'trainingParam') && isstruct(classif.trainingParam)
        tp = classif.trainingParam;
    elseif isstruct(classif) && isfield(classif, 'trainingParam') && isstruct(classif.trainingParam)
        tp = classif.trainingParam;
    end
    if ~isempty(tp) && isfield(tp, 'execution_environment') && ~isempty(tp.execution_environment)
        defaults.executionEnvironment = normalizeExecutionEnvironment(choiceToChar(tp.execution_environment));
    end
catch
end
end

function outputMode = normalizeOutputMode(outputMode)
outputMode = lower(strtrim(choiceToChar(outputMode)));
outputMode = strrep(outputMode, '-', '_');
outputMode = strrep(outputMode, ' ', '_');
switch outputMode
    case {'lstm','lstm_only','primary'}
        outputMode = 'lstm_only';
    case {'cnn','cnn_only'}
        outputMode = 'cnn_only';
    case {'both','all','lstm_and_cnn','cnn_and_lstm'}
        outputMode = 'both';
    otherwise
        if isempty(outputMode)
            outputMode = 'lstm_only';
        end
end
end

function env = normalizeExecutionEnvironment(env)
env = lower(strtrim(choiceToChar(env)));
env = strrep(env, '-', '_');
env = strrep(env, ' ', '_');
switch env
    case {'gpu','multi_gpu','force_gpu'}
        env = 'gpu';
    case {'cpu','force_cpu'}
        env = 'cpu';
    otherwise
        env = 'module_default';
end
end

function txt = choiceToChar(value)
txt = '';
if isempty(value)
    return;
end
if iscell(value)
    flat = value(~cellfun(@isempty, value));
    if isempty(flat)
        return;
    end
    txt = char(string(flat{end}));
elseif ischar(value)
    txt = value;
elseif isstring(value) || isnumeric(value) || islogical(value) || iscategorical(value)
    vals = string(value(:));
    if ~isempty(vals)
        txt = char(vals(end));
    end
else
    try
        txt = char(string(value));
    catch
        txt = '';
    end
end
end
