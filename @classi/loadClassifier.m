function [classifierout, status] = loadClassifier(classif, option)
% loadClassifier  Load assembled CNN+LSTM classifier for a given classif.
%
% Convention:
%   <name>.mat                 -> assembled (CNN+LSTM) for inference
%   netCNN_<name>.mat          -> CNN only
%   netLSTM_<name>.mat         -> LSTM only
%
% Behavior:
%   - loads <name>.mat
%   - if it's a dlnetwork, tries assembleNetwork
%   - if assembleNetwork fails, rebuilds assembled net from netCNN_/netLSTM_ and saves <name>.mat

path = classif.path;
name = classif.strid;

force  = false;
check  = false;
status = false;

if nargin >= 2 && ~isempty(option)
    if strcmpi(option,'force'), force = true; end
    if strcmpi(option,'check'), check = true; end
end

validNetClasses = {'DAGNetwork','SeriesNetwork','dlnetwork'};

% --- check workspace ---
W = evalin('base','whos');
doesExist = ismember(name,{W(:).name});

if check
    classifierout = [];
    if doesExist
        tmp = evalin('base',name);
        status = any(strcmp(class(tmp), validNetClasses));
    end
    return;
end

if doesExist && ~force
    tmp = evalin('base',name);
    if any(strcmp(class(tmp), validNetClasses))
        disp('Classifier is already loaded in the workspace');
        classifierout = tmp;
        status = true;
        return;
    end
end

% --- load from disk ---
disp(['Loading classifier: ' name]);

matMain = fullfile(path,[name '.mat']);
if ~exist(matMain,'file')
    disp('Classifier does not exist ! Has training been done?');
    classifierout = [];
    return;
end

S = load(matMain);

candidateFields = {'classifier','net','netLSTM_dag','netLSTM','netCNN'};
classifier = [];
for k = 1:numel(candidateFields)
    f = candidateFields{k};
    if isfield(S,f)
        classifier = S.(f);
        break;
    end
end
if isempty(classifier)
    error('No classifier-like variable found in %s.', matMain);
end

% --- dlnetwork -> try assembleNetwork, else rebuild from parts ---
if isa(classifier,'dlnetwork')
    try
        disp('Loaded classifier is dlnetwork -> trying assembleNetwork...');
        lgraph = layerGraph(classifier);
        classifier = assembleNetwork(lgraph);
        disp('dlnetwork successfully converted to DAGNetwork.');
    catch ME
        warning(['assembleNetwork failed on dlnetwork (%s). ', ...
                 'Rebuilding full CNN+LSTM network from netCNN_/netLSTM_ files...'], ME.message);
        classifier = localAssembleFromParts(classif);
    end
end

disp(['Loaded classifier of type: ' class(classifier)]);
classifierout = classifier;
status = true;

assignin('base',name,classifierout);

end


% =====================================================================
function classifier = localAssembleFromParts(classif)
% Rebuild assembled CNN+LSTM network exactly like trainImageLSTMNetFun.

path = classif.path;
name = classif.strid;

% ---------- load CNN ----------
srcCNN = fullfile(path, ['netCNN_' name '.mat']);
if ~exist(srcCNN,'file')
    error('localAssembleFromParts:MissingCNN', 'Cannot find CNN file: %s', srcCNN);
end
SCNN = load(srcCNN);
netCNN = localPickNetFromStruct(SCNN);

% ---------- load LSTM ----------
srcLSTM = fullfile(path, ['netLSTM_' name '.mat']);
if ~exist(srcLSTM,'file')
    error('localAssembleFromParts:MissingLSTM', 'Cannot find LSTM file: %s', srcLSTM);
end
SLSTM = load(srcLSTM);
if isfield(SLSTM,'netLSTM')
    netLSTM = SLSTM.netLSTM;
else
    netLSTM = localPickNetFromStruct(SLSTM);
end

% ---------- CNN layerGraph ----------
if isa(netCNN,'dlnetwork')
    cnnLayers = layerGraph(netCNN);
else
    cnnLayers = layerGraph(netCNN);
end

% infer input size safely (same logic as your training code)
inputSize = localGetCNNInputSizeHW(netCNN, cnnLayers);

% infer backbone-specific key layer names from existing CNN
[baseInput, layerName2] = localInferBackbonePorts(cnnLayers);

% remove original image input(s)
isInput = arrayfun(@(L) isa(L,'nnet.cnn.layer.ImageInputLayer'), cnnLayers.Layers);
oldInputs = {cnnLayers.Layers(isInput).Name};
if ~isempty(oldInputs)
    cnnLayers = removeLayers(cnnLayers, oldInputs);
end

% remove downstream of layerName2 (keep trunk up to pooling)
names = string({cnnLayers.Layers.Name});
toVisit = string(layerName2); toVisit = toVisit(:);
desc    = strings(0,1);

while ~isempty(toVisit)
    src = toVisit(1); toVisit(1) = [];
    mask = strcmp(cnnLayers.Connections.Source, src);
    kids = string(cnnLayers.Connections.Destination(mask));
    kids = kids(:);

    newKids = setdiff(kids, [desc; string(layerName2)]);
    newKids = newKids(:);

    desc = unique([desc; kids], 'stable');

    if ~isempty(newKids)
        toVisit = union(toVisit, newKids, 'stable');
        toVisit = toVisit(:);
    end
end

desc = setdiff(desc, layerName2);
desc = intersect(desc, names);
if ~isempty(desc)
    cnnLayers = removeLayers(cnnLayers, cellstr(desc));
end

% build sequence input + folding, keep CNN mean if available
meanVal = [];
try
    if isa(netCNN,'DAGNetwork') || isa(netCNN,'SeriesNetwork')
        if isprop(netCNN.Layers(1),'Mean'), meanVal = netCNN.Layers(1).Mean; end
    else
        % if netCNN is dlnetwork: try from original ImageInputLayer in cnnLayers before removal
        % (we already removed; so try from SCNN if possible)
    end
catch
end

if ~isempty(meanVal)
    inputLayer = sequenceInputLayer([inputSize 3], ...
        'Normalization','zerocenter', 'Mean', meanVal, 'Name','input');
else
    inputLayer = sequenceInputLayer([inputSize 3], ...
        'Normalization','zerocenter', 'Name','input');
end

foldLayer = sequenceFoldingLayer('Name','fold');

lgraph = addLayers(cnnLayers, [inputLayer; foldLayer]);
lgraph = connectLayers(lgraph, "fold/out", baseInput);

% ---------- LSTM layerGraph ----------
if isa(netLSTM,'dlnetwork')
    lgraphLSTM = layerGraph(netLSTM);
else
    lgraphLSTM = layerGraph(netLSTM);
end

lstmLayersFull = lgraphLSTM.Layers;

% remove LSTM sequence input (first layer)
if ~isempty(lstmLayersFull) && isa(lstmLayersFull(1),'nnet.cnn.layer.SequenceInputLayer')
    lstmLayersFull(1) = [];
end

% --- EXACTLY like your training assembly ---
layersTail = [ ...
    sequenceUnfoldingLayer('Name','unfold'); ...
    flattenLayer('Name','flatten'); ...
    deltaFeatureLayer('deltaFeatures'); ...
    lstmLayersFull ...
    ];

% Build tail graph to get its internal connections automatically
tail = layerGraph(layersTail);

% Add tail layers + tail connections (portable across MATLAB versions)
lgraph = addLayers(lgraph, tail.Layers);
lgraph = localAddConnectionsSafe(lgraph, tail.Connections);

% Connect trunk->tail (only 2 explicit connections, like your working code)
lgraph = connectLayers(lgraph, layerName2, "unfold/in");
lgraph = connectLayers(lgraph, "fold/miniBatchSize", "unfold/miniBatchSize");

% Final assemble
classifier = assembleNetwork(lgraph);

% Save rebuilt assembled classifier
save(fullfile(path,[name '.mat']), 'classifier', '-v7.3');
disp('Rebuilt full CNN+LSTM network and saved assembled classifier.');

end


% =====================================================================
function net = localPickNetFromStruct(S)
% pick a network-like variable from a loaded .mat struct
if isfield(S,'classifier')
    net = S.classifier; return;
end
if isfield(S,'net')
    net = S.net; return;
end
if isfield(S,'netCNN')
    net = S.netCNN; return;
end
if isfield(S,'netLSTM')
    net = S.netLSTM; return;
end

fn = fieldnames(S);
net = [];
for k = 1:numel(fn)
    v = S.(fn{k});
    if isa(v,'DAGNetwork') || isa(v,'SeriesNetwork') || isa(v,'dlnetwork') || isa(v,'nnet.cnn.LayerGraph')
        net = v;
        return;
    end
end
% fallback: first field
net = S.(fn{1});
end


function inputSizeHW = localGetCNNInputSizeHW(netCNN, lgraphCNN)
% Try to find ImageInputLayer InputSize in original network/graph
inputSizeHW = [];

% 1) Try from netCNN.Layers (legacy)
try
    if isa(netCNN,'DAGNetwork') || isa(netCNN,'SeriesNetwork')
        layers = netCNN.Layers;
        isIn = arrayfun(@(L) isa(L,'nnet.cnn.layer.ImageInputLayer'), layers);
        idx = find(isIn,1,'first');
        if ~isempty(idx)
            sz = layers(idx).InputSize;
            inputSizeHW = sz(1:2);
            return;
        end
    end
catch
end

% 2) Try from layerGraph (if still has ImageInputLayer)
try
    layers = lgraphCNN.Layers;
    isIn = arrayfun(@(L) isa(L,'nnet.cnn.layer.ImageInputLayer'), layers);
    idx = find(isIn,1,'first');
    if ~isempty(idx)
        sz = layers(idx).InputSize;
        inputSizeHW = sz(1:2);
        return;
    end
catch
end

error('localGetCNNInputSizeHW:Failed', 'Cannot infer CNN input size.');
end


function [baseInput, layerName2] = localInferBackbonePorts(lgraphCNN)
% Infer backbone ports from layer names (no need trainingParam).

nms = string({lgraphCNN.Layers.Name});

if any(nms == "pool5-7x7_s1") && any(nms == "conv1-7x7_s2")
    % googlenet
    baseInput  = "conv1-7x7_s2";
    layerName2 = "pool5-7x7_s1";
    return;
end

if any(nms == "avg_pool") && any(nms == "conv1") && any(contains(nms,"res"))
    % resnet50 often
    baseInput  = "conv1";
    layerName2 = "avg_pool";
    return;
end

if any(nms == "pool5") && any(nms == "conv1")
    % resnet18 often
    baseInput  = "conv1";
    layerName2 = "pool5";
    return;
end

if any(nms == "avg_pool") && any(nms == "conv2d_1")
    % inceptionv3 / inceptionresnetv2
    baseInput  = "conv2d_1";
    layerName2 = "avg_pool";
    return;
end

% fallback: try common pooling layer names
candidates = ["avg_pool","pool5","pool5-7x7_s1"];
for k = 1:numel(candidates)
    if any(nms == candidates(k))
        layerName2 = candidates(k);
        % guess baseInput
        if any(nms=="conv1"), baseInput="conv1"; else, baseInput="conv1"; end
        warning('localInferBackbonePorts:Fallback', ...
            'Backbone not clearly identified; using layerName2=%s, baseInput=%s.', layerName2, baseInput);
        return;
    end
end

error('localInferBackbonePorts:UnknownBackbone', ...
    'Cannot infer backbone port/layer names from CNN. Known patterns not found.');
end


function lgraph = localAddConnectionsSafe(lgraph, conns)
% Add connections, ignoring "already exists" errors.

if isempty(conns)
    return;
end

% conns is a table in most versions
if istable(conns)
    src = string(conns.Source);
    dst = string(conns.Destination);
    for i = 1:height(conns)
        s = char(src(i));
        d = char(dst(i));
        try
            lgraph = connectLayers(lgraph, s, d);
        catch ME
            if contains(ME.message,'already exists','IgnoreCase',true)
                % ignore
            else
                rethrow(ME);
            end
        end
    end
else
    % fallback: struct array
    try
        src = string({conns.Source});
        dst = string({conns.Destination});
        for i = 1:numel(src)
            try
                lgraph = connectLayers(lgraph, char(src(i)), char(dst(i)));
            catch ME
                if contains(ME.message,'already exists','IgnoreCase',true)
                else
                    rethrow(ME);
                end
            end
        end
    catch
        error('localAddConnectionsSafe:Unsupported', 'Unsupported connections type: %s', class(conns));
    end
end
end
