function scores = predictHGB(features, param)
%BUDMOTHERLINKER.PREDICTHGB Evaluate exported sklearn HGB trees in MATLAB.

if nargin < 2 || isempty(param)
    param = budMotherLinker.utils.defaultExecutionParam();
end
features = double(features);
if isvector(features), features = reshape(features, 1, []); end
if size(features,2) ~= 16
    error('budMotherLinker:InvalidFeatureCount', ...
        'The lineage ranker expects 16 descriptors, received %d.', ...
        size(features,2));
end

if strcmp(param.modelSource, 'trained')
    model = loadArtifact(param.modelPath);
else
    model = loadBuiltin();
end

required = {'feature_mean','feature_scale','baseline','feature_idx', ...
    'threshold','left','right','value','is_leaf','missing_go_left'};
if ~all(isfield(model,required))
    error('budMotherLinker:InvalidTrainedModel', ...
        'The HGB artifact does not contain a complete native tree export.');
end
normalized = (features - reshape(model.feature_mean,1,[])) ./ ...
    reshape(model.feature_scale,1,[]);
raw = repmat(double(model.baseline), size(normalized,1), 1);
for row = 1:size(normalized,1)
    for tree = 1:size(model.feature_idx,1)
        node = 1;
        while ~logical(model.is_leaf(tree,node))
            featureIndex = double(model.feature_idx(tree,node));
            value = normalized(row,featureIndex);
            if isnan(value)
                goLeft = logical(model.missing_go_left(tree,node));
            else
                goLeft = value <= model.threshold(tree,node);
            end
            if goLeft
                node = double(model.left(tree,node));
            else
                node = double(model.right(tree,node));
            end
        end
        raw(row) = raw(row) + model.value(tree,node);
    end
end
scores = 1 ./ (1 + exp(-raw));
end

function artifact = loadArtifact(filename)
persistent cachedFile cachedStamp cachedArtifact
entry = dir(filename);
if isempty(entry)
    error('budMotherLinker:InvalidTrainedModel', ...
        'Trained model artifact is missing: %s',filename);
end
stamp = sprintf('%.12f:%d',entry.datenum,entry.bytes);
if isempty(cachedArtifact) || ~strcmp(cachedFile, filename) || ...
        ~strcmp(cachedStamp,stamp)
    payload = load(filename, 'artifact');
    if ~isfield(payload,'artifact') || ~isstruct(payload.artifact) || ...
            ~isfield(payload.artifact,'feature_idx')
        error('budMotherLinker:InvalidTrainedModel', ...
            'Invalid trained model artifact: %s', filename);
    end
    cachedFile = filename;
    cachedStamp = stamp;
    cachedArtifact = payload.artifact;
end
artifact = cachedArtifact;
end

function model = loadBuiltin()
persistent builtin
if isempty(builtin)
    root = fileparts(mfilename('fullpath'));
    filename = fullfile(root, 'model', 'project47_v002', 'hgb_lyn16.mat');
    if ~isfile(filename)
        error('budMotherLinker:MissingBuiltinModel', ...
            'Builtin HGB model is missing: %s', filename);
    end
    builtin = load(filename);
end
model = builtin;
end
