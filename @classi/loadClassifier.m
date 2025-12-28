function [classifierout, status] = loadClassifier(classif, option)
% loadClassifier  Load the network (classifier) associated with a given @classi
%
% Convention:
%   <name>.mat                 -> assembled network (CNN+LSTM) for inference
%   netCNN_<name>.mat          -> CNN-only network
%   netLSTM_<name>.mat         -> LSTM-only network
%
% This loader:
%   - loads <name>.mat
%   - if it contains a dlnetwork, tries to convert to DAGNetwork via assembleNetwork
%   - if conversion fails, rebuilds the full CNN+LSTM network from netCNN_*/netLSTM_*
%     and saves a DAGNetwork back into <name>.mat (variable 'classifier')

path = classif.path;
name = classif.strid;

force  = false;
check  = false;
status = false;

if nargin >= 2 && ~isempty(option)
    if strcmpi(option,'force'), force = true; end
    if strcmpi(option,'check'), check = true; end
end

% Types we accept as "valid networks"
validNetClasses = {'DAGNetwork','SeriesNetwork','dlnetwork'};

% --- Check if already in base workspace ---
W = evalin('base','whos');
doesExist = ismember(name, {W(:).name});

if check
    classifierout = [];
    if doesExist
        tmp = evalin('base', name);
        status = any(strcmp(class(tmp), validNetClasses));
    end
    return;
end

if doesExist && ~force
    tmp = evalin('base', name);
    if any(strcmp(class(tmp), validNetClasses))
        disp('Classifier is already loaded in the workspace');
        classifierout = tmp;
        status = true;
        return;
    end
end

% --- Load from disk ---
disp(['Loading classifier: ' name]);

matFile = fullfile(path, [name '.mat']);
if ~exist(matFile,'file')
    disp('Classifier does not exist! Has training been done?');
    classifierout = [];
    return;
end

S = load(matFile);

% Backward compatible field names
candidateFields = {'classifier','net','netLSTM_dag','netLSTM','netCNN'};
classifier = [];

for k = 1:numel(candidateFields)
    f = candidateFields{k};
    if isfield(S, f)
        classifier = S.(f);
        break;
    end
end

if isempty(classifier)
    error('loadClassifier:NoNetworkFound', ...
        'No classifier-like variable found in %s.', matFile);
end

% --- If dlnetwork: try assembleNetwork, otherwise rebuild from parts ---
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

% IMPORTANT: do not assign name' here
assignin('base', name, classifier);

end


% =====================================================================
function classifier = localAssembleFromParts(classif)
% localAssembleFromParts  Rebuild assembled CNN+LSTM network from:
%   netCNN_<name>.mat  (CNN-only)
%   netLSTM_<name>.mat (LSTM-only)
%
% Saves result into <name>.mat as variable 'classifier' (DAGNetwork).

path = classif.path;
name = classif.strid;

if ~isprop(classif,'trainingParam') || isempty(classif.trainingParam)
    error('localAssembleFromParts:MissingTrainingParam', ...
        'classif.trainingParam is missing/empty; cannot infer backbone/layer names.');
end
trainingParam = classif.trainingParam;

% -------------------- Load CNN --------------------
srcCNN = fullfile(path, ['netCNN_' name '.mat']);
if ~exist(srcCNN,'file')
    error('localAssembleFromParts:MissingCNN', 'Cannot find CNN file: %s', srcCNN);
end
SCNN = load(srcCNN);

netCNN = [];
if isfield(SCNN,'classifier')
    netCNN = SCNN.classifier;
elseif isfield(SCNN,'netCNN')
    netCNN = SCNN.netCNN;
else
    fn = fieldnames(SCNN);
    netCNN = SCNN.(fn{1});
end

% -------------------- Load LSTM --------------------
srcLSTM = fullfile(path, ['netLSTM_' name '.mat']);
if ~exist(srcLSTM,'file')
    error('localAssembleFromParts:MissingLSTM', 'Cannot find LSTM file: %s', srcLSTM);
end
SLSTM = load(srcLSTM);

netLSTM = [];
if isfield(SLSTM,'netLSTM')
    netLSTM = SLSTM.netLSTM;
elseif isfield(SLSTM,'classifier')
    netLSTM = SLSTM.classifier;
else
    fnL = fieldnames(SLSTM);
    netLSTM = SLSTM.(fnL{1});
end

% -------------------- CNN layerGraph + input size --------------------
lgraphCNN = layerGraph(netCNN);

layersCNN = lgraphCNN.Layers;
isInput = arrayfun(@(L) isa(L,'nnet.cnn.layer.ImageInputLayer'), layersCNN);
idxIn = find(isInput,1,'first');
if isempty(idxIn)
    error('localAssembleFromParts:NoImageInput', ...
        'Cannot find ImageInputLayer in netCNN to infer input size.');
end

inputSizeHW = layersCNN(idxIn).InputSize(1:2);
meanVal = [];
if isprop(layersCNN(idxIn),'Mean')
    meanVal = layersCNN(idxIn).Mean;
end

% Backbone inference
if isfield(trainingParam,'CNN_network') && ~isempty(trainingParam.CNN_network)
    backbone = trainingParam.CNN_network{end};
else
    backbone = '';
end

switch backbone
    case 'googlenet'
        baseInput = "conv1-7x7_s2";
        trunkOut  = "pool5-7x7_s1";
    case 'resnet50'
        baseInput = "conv1";
        trunkOut  = "avg_pool";
    case 'resnet18'
        baseInput = "conv1";
        trunkOut  = "pool5";
    case {'inceptionresnetv2','inceptionv3'}
        baseInput = "conv2d_1";
        trunkOut  = "avg_pool";
    otherwise
        error('localAssembleFromParts:UnsupportedBackbone', ...
            'Unsupported/unknown backbone in trainingParam.CNN_network: %s', string(backbone));
end

% Remove original image input(s)
oldInputs = {lgraphCNN.Layers(isInput).Name};
if ~isempty(oldInputs)
    lgraphCNN = removeLayers(lgraphCNN, oldInputs);
end

% Prune everything downstream of trunkOut (remove classification head)
names = string({lgraphCNN.Layers.Name});
toVisit = string(trunkOut); toVisit = toVisit(:);
desc = strings(0,1);

while ~isempty(toVisit)
    src = toVisit(1); toVisit(1) = [];

    mask = strcmp(string(lgraphCNN.Connections.Source), src);
    kids = string(lgraphCNN.Connections.Destination(mask));
    kids = kids(:);

    % record all descendants
    desc = unique([desc; kids], 'stable');

    % discover new nodes to explore
    newKids = setdiff(kids, [desc; string(trunkOut)], 'stable');
    newKids = newKids(:);

    if ~isempty(newKids)
        toVisit = unique([toVisit(:); newKids(:)], 'stable');
    end
end

desc = setdiff(desc, trunkOut, 'stable');
desc = intersect(desc, names, 'stable');
if ~isempty(desc)
    lgraphCNN = removeLayers(lgraphCNN, cellstr(desc));
end

% -------------------- Add sequence input + folding --------------------
if ~isempty(meanVal)
    inputLayer = sequenceInputLayer([inputSizeHW 3], ...
        'Normalization','zerocenter', 'Mean', meanVal, 'Name','input');
else
    inputLayer = sequenceInputLayer([inputSizeHW 3], ...
        'Normalization','zerocenter', 'Name','input');
end

foldLayer = sequenceFoldingLayer('Name','fold');
lgraph = addLayers(lgraphCNN, [inputLayer; foldLayer]);

% Connect folding to backbone entry
lgraph = connectLayers(lgraph, "fold/out", baseInput);

% -------------------- LSTM layerGraph (remove sequenceInputLayer) --------------------
lgraphLSTM = layerGraph(netLSTM);
lstmLayersFull = lgraphLSTM.Layers;

if ~isempty(lstmLayersFull) && isa(lstmLayersFull(1),'nnet.cnn.layer.SequenceInputLayer')
    lstmLayersFull(1) = []; % remove sequence input
end

% Find BiLSTM layer name robustly
bilstmName = "";
for k = 1:numel(lstmLayersFull)
    if isa(lstmLayersFull(k),'nnet.cnn.layer.BiLSTMLayer') || strcmp(lstmLayersFull(k).Name,'bilstm')
        bilstmName = string(lstmLayersFull(k).Name);
        break;
    end
end
if bilstmName == ""
    error('localAssembleFromParts:NoBiLSTM', 'No BiLSTM layer found in netLSTM.');
end

% -------------------- Tail: unfold -> flatten -> deltaFeatures -> LSTM tail --------------------
unfoldLayer = sequenceUnfoldingLayer('Name','unfold');
flatLayer   = flattenLayer('Name','flatten');

% Your custom layer expects X as TCB (F x T x B) and outputs 3F x T x B
deltaLayer  = deltaFeatureLayer('deltaFeatures');

layersTail = [
    unfoldLayer
    flatLayer
    deltaLayer
    lstmLayersFull(:)
];

lgraph = addLayers(lgraph, layersTail);

% Connect CNN trunk output to unfolding
lgraph = connectLayers(lgraph, trunkOut, "unfold/in");
lgraph = connectLayers(lgraph, "fold/miniBatchSize", "unfold/miniBatchSize");

% Explicit wiring inside the tail (CRITICAL in layerGraph workflow)
lgraph = safeConnect(lgraph, "unfold", "flatten");
lgraph = safeConnect(lgraph, "flatten", "deltaFeatures");
lgraph = safeConnect(lgraph, "deltaFeatures", char(bilstmName));



% -------------------- Final assemble --------------------
% (Optional but very helpful if something is still wrong)
% analyzeNetwork(lgraph);

classifier = assembleNetwork(lgraph);

save(fullfile(path,[name '.mat']), 'classifier', '-v7.3');
disp('Rebuilt full CNN+LSTM network and saved assembled classifier.');

end

function lgraph = safeConnect(lgraph, src, dst)
%SAFECONNECT Connect src->dst only if it does not already exist.
% Accepts "layer" or "layer/port" notations and canonicalizes them.

src0 = canonicalLayerName(src);
dst0 = canonicalLayerName(dst);

C = lgraph.Connections;

already = false;
if ~isempty(C)
    srcC = canonicalLayerName(string(C.Source));
    dstC = canonicalLayerName(string(C.Destination));
    already = any(srcC == src0 & dstC == dst0);
end

if ~already
    % Connect WITHOUT ports (robust for single-in/single-out layers)
    lgraph = connectLayers(lgraph, char(src0), char(dst0));
end
end

function nm = canonicalLayerName(x)
%CANONICALLAYERNAME Strip "/in", "/out", "/something" from layer/port notations.

sx = string(x);
% Keep only the part before the first '/'
nm = extractBefore(sx, "/");
nm(nm == "") = sx(nm == ""); % if no '/', extractBefore returns ""
nm = string(nm);
end


