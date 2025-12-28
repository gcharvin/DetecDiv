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
% Rebuild assembled CNN+LSTM network exactly like trainImageLSTMNetFun,
% but robust to missing/empty Mean in the CNN.

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

% infer input size
inputSize = localGetCNNInputSizeHW(netCNN, cnnLayers);

% infer backbone-specific key layer names from existing CNN
[baseInput, layerName2] = localInferBackbonePorts(cnnLayers);

% remove original image input(s)
isInput = arrayfun(@(L) isa(L,'nnet.cnn.layer.ImageInputLayer'), cnnLayers.Layers);
oldInputs = {cnnLayers.Layers(isInput).Name};
if ~isempty(oldInputs)
    cnnLayers = removeLayers(cnnLayers, oldInputs);
end

% remove downstream of layerName2
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

% ---- IMPORTANT FIX: robust Mean handling ----
meanVal = localExtractCNNMean(netCNN);
inputLayer = makeSeqInputLayer([inputSize 3], meanVal);  % <-- safe

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

% --- EXACTLY like your working assembly ---
layersTail = [ ...
    sequenceUnfoldingLayer('Name','unfold'); ...
    flattenLayer('Name','flatten'); ...
    deltaFeatureLayer('deltaFeatures'); ...
    lstmLayersFull ...
    ];

tail = layerGraph(layersTail);

lgraph = addLayers(lgraph, tail.Layers);
lgraph = localAddConnectionsSafe(lgraph, tail.Connections);

% connect trunk->tail
lgraph = connectLayers(lgraph, layerName2, "unfold/in");
lgraph = connectLayers(lgraph, "fold/miniBatchSize", "unfold/miniBatchSize");

% Final assemble
classifier = assembleNetwork(lgraph);

save(fullfile(path,[name '.mat']), 'classifier', '-v7.3');
disp('Rebuilt full CNN+LSTM network and saved assembled classifier.');

end


% =====================================================================
function inputLayer = makeSeqInputLayer(seqInputSize, meanVal)
% makeSeqInputLayer  Create robust sequenceInputLayer:
% - If meanVal is nonempty -> use zerocenter + Mean
% - If meanVal is empty/missing -> use Normalization 'none' (MATLAB requires Mean for zerocenter)

if nargin < 2
    meanVal = [];
end

if isempty(meanVal)
    inputLayer = sequenceInputLayer(seqInputSize, ...
        'Normalization','none', ...
        'Name','input');
else
    inputLayer = sequenceInputLayer(seqInputSize, ...
        'Normalization','zerocenter', ...
        'Mean', meanVal, ...
        'Name','input');
end
end


function meanVal = localExtractCNNMean(netCNN)
% Try to get Mean from the original ImageInputLayer (legacy networks).
meanVal = [];

try
    if isa(netCNN,'DAGNetwork') || isa(netCNN,'SeriesNetwork')
        L = netCNN.Layers;
        isIn = arrayfun(@(x) isa(x,'nnet.cnn.layer.ImageInputLayer'), L);
        idx = find(isIn,1,'first');
        if ~isempty(idx) && isprop(L(idx),'Mean')
            m = L(idx).Mean;
            if ~isempty(m), meanVal = m; end
        end
    end
catch
end
end


function net = localPickNetFromStruct(S)
% pick a network-like variable from a loaded .mat struct
if isfield(S,'classifier'), net = S.classifier; return; end
if isfield(S,'net'),        net = S.net;        return; end
if isfield(S,'netCNN'),     net = S.netCNN;     return; end
if isfield(S,'netLSTM'),    net = S.netLSTM;    return; end

fn = fieldnames(S);
for k = 1:numel(fn)
    v = S.(fn{k});
    if isa(v,'DAGNetwork') || isa(v,'SeriesNetwork') || isa(v,'dlnetwork') || isa(v,'nnet.cnn.LayerGraph')
        net = v; return;
    end
end
net = S.(fn{1});
end


function inputSizeHW = localGetCNNInputSizeHW(netCNN, lgraphCNN)
inputSizeHW = [];

% legacy
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

% from graph
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
nms = string({lgraphCNN.Layers.Name});

if any(nms == "pool5-7x7_s1") && any(nms == "conv1-7x7_s2")
    baseInput  = "conv1-7x7_s2";
    layerName2 = "pool5-7x7_s1";
    return;
end

if any(nms == "avg_pool") && any(nms == "conv1") && any(contains(nms,"res"))
    baseInput  = "conv1";
    layerName2 = "avg_pool";
    return;
end

if any(nms == "pool5") && any(nms == "conv1")
    baseInput  = "conv1";
    layerName2 = "pool5";
    return;
end

if any(nms == "avg_pool") && any(nms == "conv2d_1")
    baseInput  = "conv2d_1";
    layerName2 = "avg_pool";
    return;
end

error('localInferBackbonePorts:UnknownBackbone', ...
    'Cannot infer backbone port/layer names from CNN. Known patterns not found.');
end


function lgraph = localAddConnectionsSafe(lgraph, conns)
% Add connections, ignoring "already exists" errors.

if isempty(conns), return; end

if istable(conns)
    for i = 1:height(conns)
        s = char(string(conns.Source(i)));
        d = char(string(conns.Destination(i)));
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
    error('localAddConnectionsSafe:Unsupported', 'Unsupported connections type: %s', class(conns));
end
end
