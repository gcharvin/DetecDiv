function [classifierout, status] = loadClassifier(classif, option)
% loadClassifier  Robust loader for CNN/LSTM assembled classifier.
%
% Convention (same as yours):
%   <name>.mat          -> assembled network (CNN+LSTM) for inference
%   netCNN_<name>.mat   -> CNN only
%   netLSTM_<name>.mat  -> LSTM only
%
% Behavior:
%   1) If classifier already exists in base workspace (and valid), reuse it unless 'force'
%   2) Load <name>.mat; if it's a valid assembled net -> return it
%   3) If it's a dlnetwork or invalid/incomplete -> rebuild from netCNN_/netLSTM_
%      using the SAME assembly logic as trainImageLSTMNetFun (with deltaFeatureLayer).
%   4) Critical: preserve proper zerocenter Mean (fallback from pretrained backbone if missing).
%   5) Ensure class order consistency between classif.classes and LSTM classification layer.
%
% option:
%   'force' : ignore existing base variable; reload from disk
%   'check' : only check if a valid classifier is already in base workspace

status = false;
classifierout = [];

path = classif.path;
name = classif.strid;

force = false;
check = false;
if nargin >= 2 && ~isempty(option)
    force = strcmpi(option,'force');
    check = strcmpi(option,'check');
end

validNetClasses = {'DAGNetwork','SeriesNetwork','dlnetwork'};

% ------------------- workspace fast path -------------------
W = evalin('base','whos');
doesExist = ismember(name, {W(:).name});

if check
    if doesExist
        tmp = evalin('base', name);
        status = any(strcmp(class(tmp), validNetClasses));
    else
        status = false;
    end
    classifierout = [];
    return;
end

if doesExist && ~force
    tmp = evalin('base', name);
    if any(strcmp(class(tmp), validNetClasses))
        disp('Classifier already loaded in base workspace.');
        classifierout = tmp;
        status = true;
        return;
    end
end

% ------------------- load from disk -------------------
disp(['Loading classifier: ' name]);
mainFile = fullfile(path, [name '.mat']);
if exist(mainFile,'file') ~= 2
    warning('Classifier file does not exist: %s', mainFile);
    classifierout = [];
    status = false;
    return;
end

S = load(mainFile);

% Backward compatible field names
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
    % As a last resort, try the first variable in the MAT
    fn = fieldnames(S);
    if ~isempty(fn)
        classifier = S.(fn{1});
    end
end
if isempty(classifier)
    error('No network-like variable found in %s', mainFile);
end

% If already assembled DAG/Series and seems valid -> done
if isa(classifier,'DAGNetwork') || isa(classifier,'SeriesNetwork')
    disp(['Loaded classifier of type: ' class(classifier)]);
    classifierout = classifier;
    status = true;
    assignin('base', name, classifierout);
    return;
end

% If dlnetwork: try assembleNetwork; if fails -> rebuild from parts
if isa(classifier,'dlnetwork')
    try
        disp('Loaded classifier is dlnetwork -> trying assembleNetwork...');
        lgraph = layerGraph(classifier);
        classifier = assembleNetwork(lgraph);
        disp('dlnetwork successfully converted to DAGNetwork.');
        classifierout = classifier;
        status = true;
        assignin('base', name, classifierout);
        return;
    catch ME
        warning(['assembleNetwork failed on dlnetwork (%s). Rebuilding full CNN+LSTM ' ...
                 'network from netCNN_/netLSTM_ files...'], ME.message);
        classifier = localAssembleFromParts(classif);
        classifierout = classifier;
        status = true;
        assignin('base', name, classifierout);
        return;
    end
end

% Anything else: try rebuild
warning('Loaded object is type "%s" -> rebuilding from parts...', class(classifier));
classifier = localAssembleFromParts(classif);
classifierout = classifier;
status = true;
assignin('base', name, classifierout);

end


% =====================================================================
function classifier = localAssembleFromParts(classif)
% localAssembleFromParts  Rebuild CNN+LSTM assembled graph the SAME way as trainImageLSTMNetFun.
%
% - Loads netCNN_<name>.mat and netLSTM_<name>.mat
% - Determines backbone and the pooling layerName2
% - Builds:
%     sequenceInput -> sequenceFolding -> CNN trunk -> sequenceUnfolding -> flatten -> deltaFeatureLayer -> LSTM tail
% - Ensures correct zerocenter Mean for sequenceInputLayer (fallback if missing)
% - Ensures class order consistency (classif.classes vs LSTM classification layer)

path = classif.path;
name = classif.strid;

% ---------- load CNN ----------
srcCNN = fullfile(path, ['netCNN_' name '.mat']);
if exist(srcCNN,'file') ~= 2
    error('localAssembleFromParts:MissingCNN', 'Cannot find CNN file: %s', srcCNN);
end
SCNN = load(srcCNN);
netCNN = pickFirstNet(SCNN, {'classifier','netCNN','net'});

% ---------- load LSTM ----------
srcLSTM = fullfile(path, ['netLSTM_' name '.mat']);
if exist(srcLSTM,'file') ~= 2
    error('localAssembleFromParts:MissingLSTM', 'Cannot find LSTM file: %s', srcLSTM);
end
SLSTM = load(srcLSTM);
netLSTM = pickFirstNet(SLSTM, {'netLSTM','classifier','net'});

% ---------- trainingParam (optional but useful for backbone name) ----------
trainingParam = [];
try
    trainingParam = classif.trainingParam;
catch
    trainingParam = [];
end

% ---------- infer backbone + layer names from trainingParam OR from netCNN ----------
[backbone, baseInput, layerName2] = inferBackboneAndTap(netCNN, trainingParam);

% ---------- CNN graph ----------
cnnLayers = layerGraph(netCNN);

% Infer inputSize from the ORIGINAL CNN image input (or fallback)
inputSize = inferCNNInputSize(netCNN, trainingParam);

% Remove original ImageInputLayer(s)
isInput = arrayfun(@(L) isa(L,'nnet.cnn.layer.ImageInputLayer'), cnnLayers.Layers);
oldInputs = {cnnLayers.Layers(isInput).Name};
if ~isempty(oldInputs)
    cnnLayers = removeLayers(cnnLayers, oldInputs);
end

% Remove head downstream of layerName2 (keep up to pool layer)
cnnLayers = stripAfter(cnnLayers, layerName2);

% ---------- build new input + fold ----------
meanVal = extractCNNMean(netCNN);
if isempty(meanVal)
    % critical fallback: use pretrained backbone default mean
    meanVal = backboneDefaultMean(backbone);
end
if isempty(meanVal)
    error(['Cannot assemble: Mean is empty and no backbone default mean available. ' ...
           'Provide trainingParam.CNN_network{end} or ensure netCNN input layer has Mean.']);
end

inputLayer = sequenceInputLayer([inputSize 3], ...
    'Normalization','zerocenter', ...
    'Mean', meanVal, ...
    'Name','input');

foldLayer = sequenceFoldingLayer('Name','fold');

lgraph = addLayers(cnnLayers, [inputLayer; foldLayer]);

% Connect fold to CNN base input
lgraph = connectLayers(lgraph, "fold/out", baseInput);

% ---------- LSTM graph ----------
lgraphLSTM = layerGraph(netLSTM);
lstmLayersFull = lgraphLSTM.Layers;

% Remove the first SequenceInputLayer from LSTM (exactly like your training fun)
if ~isempty(lstmLayersFull) && isa(lstmLayersFull(1),'nnet.cnn.layer.SequenceInputLayer')
    lstmLayersFull(1) = [];
end
if isempty(lstmLayersFull)
    error('localAssembleFromParts:EmptyLSTM', 'LSTM tail is empty after removing its input layer.');
end

% Ensure class order consistency (if classification layer exists)
lstmLayersFull = enforceClassOrderIfNeeded(lstmLayersFull, classif);

% ---------- add unfolding + flatten + delta + lstm tail ----------
unfoldLayer  = sequenceUnfoldingLayer('Name','unfold');
flattenLayerObj = flattenLayer('Name','flatten');
deltaLayer = deltaFeatureLayer('deltaFeatures'); % your custom layer

layersTail = [ ...
    unfoldLayer; ...
    flattenLayerObj; ...
    deltaLayer; ...
    lstmLayersFull(:) ...
    ];

lgraph = addLayers(lgraph, layersTail);

% Mandatory fold/unfold wiring
lgraph = connectLayers(lgraph, layerName2, "unfold/in");
lgraph = connectLayers(lgraph, "fold/miniBatchSize", "unfold/miniBatchSize");

% IMPORTANT: do NOT manually connect unfold->flatten etc.
% Because addLayers(layersTail) keeps internal sequential connections:
% unfold -> flatten -> deltaFeatures -> firstLstmLayer -> ...
% Adding extra connectLayers here often triggers "connection already exists".

% ---------- assemble ----------
try
    classifier = assembleNetwork(lgraph);
catch ME
    % Provide a more actionable message
    msg = ME.message;
    if contains(msg, 'Empty Mean property', 'IgnoreCase', true)
        msg = [msg newline ...
            'Fix: ensure sequenceInputLayer uses Normalization=zerocenter with a NONEMPTY Mean.' newline ...
            'This loader already falls back to pretrained backbone Mean; if backbone cannot be inferred, ' ...
            'set classif.trainingParam.CNN_network{end} (e.g. ''googlenet'').'];
    end
    error('localAssembleFromParts:AssembleFailed', 'assembleNetwork failed: %s', msg);
end

% Save assembled classifier for future fast loads
save(fullfile(path,[name '.mat']), 'classifier', '-v7.3');
disp('Rebuilt full CNN+LSTM network and saved assembled classifier.');

end


% =====================================================================
function net = pickFirstNet(S, preferredFields)
net = [];
for k = 1:numel(preferredFields)
    f = preferredFields{k};
    if isfield(S,f)
        net = S.(f);
        return;
    end
end
fn = fieldnames(S);
for k = 1:numel(fn)
    v = S.(fn{k});
    if isa(v,'DAGNetwork') || isa(v,'SeriesNetwork') || isa(v,'dlnetwork') || isa(v,'nnet.cnn.LayerGraph')
        net = v;
        return;
    end
end
if isempty(net)
    % last resort: first field
    if ~isempty(fn)
        net = S.(fn{1});
    end
end
end


function inputSizeHW = inferCNNInputSize(netCNN, trainingParam)
% Prefer true ImageInputLayer.InputSize from the provided netCNN.
layers = [];
if isa(netCNN,'DAGNetwork') || isa(netCNN,'SeriesNetwork')
    layers = netCNN.Layers;
elseif isa(netCNN,'dlnetwork')
    layers = netCNN.Layers;
elseif isa(netCNN,'nnet.cnn.LayerGraph')
    layers = netCNN.Layers;
end

if ~isempty(layers)
    isInput = arrayfun(@(L) isa(L,'nnet.cnn.layer.ImageInputLayer'), layers);
    idx = find(isInput, 1, 'first');
    if ~isempty(idx)
        sz = layers(idx).InputSize;
        inputSizeHW = sz(1:2);
        return;
    end
end

% Fallback: instantiate backbone from trainingParam if possible
netName = '';
if nargin >= 2 && ~isempty(trainingParam) && isfield(trainingParam,'CNN_network') && ~isempty(trainingParam.CNN_network)
    netName = trainingParam.CNN_network{end};
end
if ~isempty(netName)
    try
        bb = feval(netName); %#ok<FVAL>
        layersB = bb.Layers;
        isInputB = arrayfun(@(L) isa(L,'nnet.cnn.layer.ImageInputLayer'), layersB);
        idxB = find(isInputB, 1, 'first');
        if ~isempty(idxB)
            sz = layersB(idxB).InputSize;
            inputSizeHW = sz(1:2);
            warning('inferCNNInputSize:Fallback', ...
                'CNN input size inferred from backbone "%s": [%d %d].', netName, inputSizeHW(1), inputSizeHW(2));
            return;
        end
    catch
    end
end

error('inferCNNInputSize:Failed', ...
    'Cannot determine CNN input size (no ImageInputLayer found, and backbone fallback failed).');
end


function meanVal = extractCNNMean(netCNN)
meanVal = [];
try
    layers = netCNN.Layers;
catch
    meanVal = [];
    return;
end
isInput = arrayfun(@(L) isa(L,'nnet.cnn.layer.ImageInputLayer'), layers);
idx = find(isInput, 1, 'first');
if isempty(idx), return; end

L = layers(idx);
if isprop(L,'Mean')
    try
        meanVal = L.Mean;
        if isempty(meanVal), meanVal = []; end
    catch
        meanVal = [];
    end
end
end


function meanVal = backboneDefaultMean(backbone)
meanVal = [];
try
    switch lower(backbone)
        case 'googlenet'
            net = googlenet;
        case 'resnet18'
            net = resnet18;
        case 'resnet50'
            net = resnet50;
        case 'inceptionv3'
            net = inceptionv3;
        case 'inceptionresnetv2'
            net = inceptionresnetv2;
        otherwise
            net = [];
    end
    if ~isempty(net)
        meanVal = net.Layers(1).Mean;
        if isempty(meanVal), meanVal = []; end
    end
catch
    meanVal = [];
end
end


function [backbone, baseInput, layerName2] = inferBackboneAndTap(netCNN, trainingParam)
% 1) prefer trainingParam.CNN_network{end}
backbone = '';
if ~isempty(trainingParam) && isfield(trainingParam,'CNN_network') && ~isempty(trainingParam.CNN_network)
    try backbone = trainingParam.CNN_network{end}; catch, backbone = ''; end
end

% 2) if missing, infer from layer names
if isempty(backbone)
    names = string({layerGraph(netCNN).Layers.Name});
    if any(names == "pool5-7x7_s1") && any(names == "conv1-7x7_s2")
        backbone = 'googlenet';
    elseif any(names == "avg_pool") && any(names == "conv1")
        % could be resnet50 or inception family; disambiguate by presence of "res5a_branch2a" etc.
        if any(contains(names,"res"))
            backbone = 'resnet50';
        else
            % safest: treat as inception-like tap
            backbone = 'inceptionv3';
        end
    elseif any(names == "pool5") && any(names == "conv1")
        backbone = 'resnet18';
    elseif any(names == "conv2d_1") && any(names == "avg_pool")
        backbone = 'inceptionv3';
    else
        error('inferBackboneAndTap:Unknown', ...
            ['Cannot infer backbone. Provide classif.trainingParam.CNN_network{end} ' ...
             '(e.g. ''googlenet'',''resnet18'',''resnet50'',''inceptionv3'',''inceptionresnetv2'').']);
    end
end

switch lower(backbone)
    case 'googlenet'
        baseInput  = "conv1-7x7_s2";
        layerName2 = "pool5-7x7_s1";
    case 'resnet50'
        baseInput  = "conv1";
        layerName2 = "avg_pool";
    case 'resnet18'
        baseInput  = "conv1";
        layerName2 = "pool5";
    case {'inceptionresnetv2','inceptionv3'}
        baseInput  = "conv2d_1";
        layerName2 = "avg_pool";
    otherwise
        error('inferBackboneAndTap:Unsupported', 'Unsupported backbone: %s', backbone);
end
end


function lgraph = stripAfter(lgraph, layerNameKeep)
% stripAfter  Remove all descendants downstream of layerNameKeep (keep it).

names   = string({lgraph.Layers.Name});
keep    = string(layerNameKeep);

toVisit = keep(:);          % FORCE column
desc    = strings(0,1);     % FORCE column

while ~isempty(toVisit)
    src = toVisit(1);
    toVisit(1) = [];

    mask = strcmp(lgraph.Connections.Source, src);
    kids = string(lgraph.Connections.Destination(mask));
    kids = kids(:);         % FORCE column

    if isempty(kids)
        continue;
    end

    % accumulate all downstream nodes
    desc = unique([desc; kids], 'stable');
    desc = desc(:);         % FORCE column

    % new kids to explore = kids not yet visited and not the keep node
    newKids = setdiff(kids, [desc; keep], 'stable');
    newKids = newKids(:);   % FORCE column

    if ~isempty(newKids)
        % use union to avoid shape issues (and duplicates)
        toVisit = union(toVisit(:), newKids(:), 'stable');
        toVisit = toVisit(:); % FORCE column
    end
end

% remove everything downstream (desc) except keep
desc = setdiff(desc, keep, 'stable');
desc = intersect(desc, names, 'stable');

if ~isempty(desc)
    lgraph = removeLayers(lgraph, cellstr(desc));
end
end



function layersOut = enforceClassOrderIfNeeded(layersIn, classif)
layersOut = layersIn;

% If no classes info in classif, nothing to do
clsObj = [];
try
    clsObj = classif.classes;
catch
    clsObj = [];
end
if isempty(clsObj)
    return;
end
if isstring(clsObj), clsObj = cellstr(clsObj); end
if ischar(clsObj), clsObj = {clsObj}; end
clsObj = clsObj(:)';

% Find classificationLayer in LSTM
idx = find(arrayfun(@(L) isa(L,'nnet.cnn.layer.ClassificationOutputLayer'), layersOut), 1, 'last');
if isempty(idx)
    % Sometimes it's a custom classification layer; if not found, ignore.
    return;
end

L = layersOut(idx);
if ~isprop(L,'Classes')
    return;
end

try
    clsNet = L.Classes;
catch
    clsNet = [];
end
if isempty(clsNet)
    return;
end
clsNetCell = cellstr(string(clsNet(:))');

% If same set but different order, rebuild layer with correct order
if numel(clsNetCell) == numel(clsObj) && all(ismember(clsObj, clsNetCell)) && ~isequal(clsNetCell, clsObj)
    warning('loadClassifier:ClassOrderMismatch', ...
        'Class order mismatch between netLSTM and classif.classes. Rebuilding classification layer with classif.classes order.');
    try
        layersOut(idx) = classificationLayer('Name', L.Name, 'Classes', clsObj);
    catch ME
        warning('Failed to rebuild classificationLayer with classif.classes order (%s). Keeping net''s order.', ME.message);
    end
end
end
