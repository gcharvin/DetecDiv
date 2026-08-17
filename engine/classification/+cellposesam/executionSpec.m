function spec = executionSpec(classif)
% cellposesam.executionSpec  Execution-time parameter contract.
%
% The legacy classifier GUI stores several CellposeSAM values in
% classif.trainingParam because they are useful both for training and for
% inference. Pipeline execution must nevertheless treat them as node-local
% execution parameters: a linked classi object provides defaults, while
% node.params remains the effective source used by runPipeline.

if nargin < 1
    classif = [];
end

spec = struct();
spec.category = 'Pixel';
spec.defaultClasses = {'cell'};
spec.segmentationKind = 'instance';
spec.instanceSegmentation = true;
spec.summary = 'CellposeSAM execution parameters used by pipeline nodes.';
spec.staticKeys = {'outputType','diameter','min_size','flow_threshold','cell_prob_threshold'};
spec.outputKeys = {'outputName','probabilityOutputName'};
spec.defaultImportKeys = {'outputType','diameter','min_size','flow_threshold','cell_prob_threshold'};
spec.outputProvenance = struct('quality','pred','producer','cellposesam', ...
    'semantic','frame_local_instances','template','results_<outputName>_cell');

spec.defaults = struct( ...
    'outputType', 'segmentation', ...
    'outputName', 'pred_cellposesam', ...
    'probabilityOutputName', 'pred_cellposesam_probability', ...
    'diameter', NaN, ...
    'min_size', 10, ...
    'flow_threshold', 0.4, ...
    'cell_prob_threshold', 0);

spec.labels = struct( ...
    'outputType', 'Output resource', ...
    'outputName', '[PRED] Instance-mask output name', ...
    'probabilityOutputName', '[PRED] Cell-probability output name', ...
    'diameter', 'Cell diameter', ...
    'min_size', 'Minimum object size', ...
    'flow_threshold', 'Flow threshold', ...
    'cell_prob_threshold', 'Cell probability threshold');

spec.tips = struct( ...
    'outputType', ['Controls the pipeline resources produced by this node: ' ...
                   'segmentation mask, probability channel, or both.'], ...
    'outputName', ['Prediction stem. New classifiers use pred_cellposesam, ' ...
        'which materializes as results_pred_cellposesam_cell.'], ...
    'probabilityOutputName', ['Prediction channel name for Cellpose foreground ' ...
        'probability; this is never GT.'], ...
    'diameter', ['Average object diameter used for CellposeSAM inference. ' ...
                 'NaN lets Cellpose estimate it when supported.'], ...
    'min_size', 'Minimum object size kept in the generated mask.', ...
    'flow_threshold', 'Cellpose flow threshold used during inference.', ...
    'cell_prob_threshold', 'Cellpose cell probability threshold used during inference.');

spec.choices = struct();
spec.choices.outputType = {'segmentation','probability','both'};

spec.defaults = mergeDefaultsFromClassi(spec.defaults, classif);
spec.defaults.outputType = normalizeOutputType(spec.defaults.outputType);
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
    if isobject(classif) && isprop(classif, 'trainingParam') && isstruct(classif.trainingParam)
        sources{end+1} = classif.trainingParam; %#ok<AGROW>
    elseif isstruct(classif) && isfield(classif, 'trainingParam') && isstruct(classif.trainingParam)
        sources{end+1} = classif.trainingParam; %#ok<AGROW>
    end
catch
end

keys = fieldnames(defaults);
for s = 1:numel(sources)
    src = sources{s};
    for i = 1:numel(keys)
        key = keys{i};
        if isfield(src, key) && ~isempty(src.(key))
            defaults.(key) = src.(key);
        end
    end
end

try
    if isobject(classif) && isprop(classif, 'outputType') && ~isempty(classif.outputType)
        defaults.outputType = classif.outputType;
    elseif isstruct(classif) && isfield(classif, 'outputType') && ~isempty(classif.outputType)
        defaults.outputType = classif.outputType;
    end
catch
end
end

function outputType = normalizeOutputType(outputType)
outputType = lower(strtrim(char(string(outputType))));
switch outputType
    case {'proba','probabilities','probability_map','probability'}
        outputType = 'probability';
    case {'seg','mask','masks','semantic','semantic_segmentation','postprocessing'}
        outputType = 'segmentation';
    case {'both','segmentation_and_probability','all'}
        outputType = 'both';
    otherwise
        if isempty(outputType)
            outputType = 'segmentation';
        end
end
end
