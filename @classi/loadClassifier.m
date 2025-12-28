function [classifierout, status]=loadClassifier(classif,option)
% load classifier (network) associated with a given @classi
%
% Convention :
%   <name>.mat                 -> réseau assemblé (CNN+LSTM) pour l'inférence
%   netCNN_<name>.mat          -> CNN simple
%   netLSTM_<name>.mat         -> LSTM simple
%
% Cette fonction :
%   - charge <name>.mat
%   - si c'est un dlnetwork, tente assembleNetwork
%   - si assembleNetwork échoue, reconstruit le réseau assemblé
%     à partir de netCNN_*/netLSTM_* et sauve un DAGNetwork dans <name>.mat

path = classif.path;
name = classif.strid;

force  = false;
check  = false;
status = false;

if nargin==2
    if strcmp(option,'force')
        force = true;
    end
    if strcmp(option,'check')
        check = true;
    end
end

% Types qu'on considère comme réseaux "valides"
validNetClasses = {'DAGNetwork','SeriesNetwork','dlnetwork'};

% --- Vérifier s'il existe déjà en base workspace ---
W = evalin('base','whos') ;
doesExist = ismember(name,{W(:).name});

if check
    classifierout=[];
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

% --- Chargement depuis le disque ---
disp(['Loading classifier: ' name]);

str = fullfile(path,[name '.mat']);
if ~exist(str,'file')
    disp('Classifier does not exist ! Has training been done?');
    classifierout = [];
    return;
end

S = load(str);

% Champs possibles pour compatibilité ascendante
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
    error('No classifier-like variable found in %s.', str);
end

% --- Cas dlnetwork : on tente assembleNetwork, sinon on reconstruit ---
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
        % on vient de reconstruire un DAGNetwork propre et de le sauver
    end
end

disp(['Loaded classifier of type: ' class(classifier)]);

classifierout = classifier;
status = true;

% IMPORTANT : pas de name' ici
assignin('base',name,classifier);
end


% =====================================================================
function classifier = localAssembleFromParts(classif)
% Reconstruit le réseau assemblé CNN+LSTM à partir de :
%   netCNN_<name>.mat  (CNN simple)
%   netLSTM_<name>.mat (LSTM simple)
%
% et sauve le résultat dans <name>.mat (variable 'classifier').

path = classif.path;
name = classif.strid;

trainingParam = classif.trainingParam;  % on assume qu'il est présent et cohérent

% --- Charger CNN simple ---
srcCNN = fullfile(path, ['netCNN_' name '.mat']);
if ~exist(srcCNN,'file')
    error('localAssembleFromParts:MissingCNN', ...
          'Cannot find CNN file: %s', srcCNN);
end

SCNN = load(srcCNN);
if isfield(SCNN,'classifier')
    netCNN = SCNN.classifier;
elseif isfield(SCNN,'netCNN')
    netCNN = SCNN.netCNN;
else
    % fallback : prendre le premier field réseau qu'on trouve
    fn = fieldnames(SCNN);
    netCNN = SCNN.(fn{1});
end

% --- Charger LSTM simple ---
srcLSTM = fullfile(path, ['netLSTM_' name '.mat']);
if ~exist(srcLSTM,'file')
    error('localAssembleFromParts:MissingLSTM', ...
          'Cannot find LSTM file: %s', srcLSTM);
end

SLSTM = load(srcLSTM);
if isfield(SLSTM,'netLSTM')
    netLSTM = SLSTM.netLSTM;
elseif isfield(SLSTM,'classifier')
    netLSTM = SLSTM.classifier;
else
    fnL = fieldnames(SLSTM);
    netLSTM = SLSTM.(fnL{1});
end

% --- Reconstruction du graph CNN ---
if isa(netCNN,'dlnetwork')
    lgraphCNN = layerGraph(netCNN);
else
    lgraphCNN = layerGraph(netCNN);
end

% Taille d'entrée image [H W] (on suppose ImageInputLayer en premier)
inputSize = [];
layersCNN = lgraphCNN.Layers;
isInput = arrayfun(@(L) isa(L,'nnet.cnn.layer.ImageInputLayer'), layersCNN);
idxIn = find(isInput,1,'first');
if ~isempty(idxIn)
    inputSize = layersCNN(idxIn).InputSize(1:2);
else
    error('localAssembleFromParts:NoImageInput', ...
          'Cannot find ImageInputLayer in netCNN to infer input size.');
end

% Nom du backbone pour identifier les couches
if isfield(trainingParam,'CNN_network') && ~isempty(trainingParam.CNN_network)
    backbone = trainingParam.CNN_network{end};
else
    backbone = '';
end

switch backbone
    case 'googlenet'
        baseInput = "conv1-7x7_s2";  
        layerName = "pool5-7x7_s1";
    case 'resnet50'
        baseInput = "conv1";         
        layerName = "avg_pool";
    case 'resnet18'
        baseInput = "conv1";         
        layerName = "pool5";
    case {'inceptionresnetv2','inceptionv3'}
        baseInput = "conv2d_1";      
        layerName = "avg_pool";
    otherwise
        error('Unsupported or unknown backbone in trainingParam.CNN_network: %s', backbone);
end

% --- Retirer l'input image d'origine ---
isInput = arrayfun(@(L) isa(L,'nnet.cnn.layer.ImageInputLayer'), lgraphCNN.Layers);
oldInputs = {lgraphCNN.Layers(isInput).Name};
if ~isempty(oldInputs)
    lgraphCNN = removeLayers(lgraphCNN, oldInputs);
end

% --- Retirer la tête en aval de layerName ---
names = string({lgraphCNN.Layers.Name});
toVisit = string(layerName); 
toVisit = toVisit(:);
desc = strings(0,1);
while ~isempty(toVisit)
    src = toVisit(1); 
    toVisit(1) = [];
    mask = strcmp(lgraphCNN.Connections.Source, src);
    kids = string(lgraphCNN.Connections.Destination(mask));
kids = kids(:);  % <-- CRITIQUE : colonne

newKids = setdiff(kids, [desc; string(layerName)]);
newKids = newKids(:);  % <-- CRITIQUE : colonne

desc    = unique([desc; kids], 'stable');
% Force same shape (column) before concatenation
% Normalize types (string) and shapes (column)
toVisit = string(toVisit);
newKids = string(newKids);
toVisit = unique([toVisit(:); newKids(:)], 'stable');

end
desc = setdiff(desc, layerName);
desc = intersect(desc, names);
if ~isempty(desc)
    lgraphCNN = removeLayers(lgraphCNN, cellstr(desc));
end

meanVal = [];
origInput = layersCNN(idxIn);
if isprop(origInput,'Mean')
    meanVal = origInput.Mean;
end

if ~isempty(meanVal)
    inputLayer = sequenceInputLayer([inputSize 3], ...
        'Normalization','zerocenter', 'Mean', meanVal, 'Name','input');
    
else
    inputLayer = sequenceInputLayer([inputSize 3], ...
        'Normalization','zerocenter', 'Name','input');
    fprintf('Sequence input layer has no Mean\n');
end

% Si tu as un champ Mean dans l'input d'origine, tu peux l'utiliser :
% (optionnel)
if ~isempty(idxIn)
    origInput = layersCNN(idxIn);
    if isprop(origInput,'Mean') || isfield(origInput,'Mean')
        try
            inputLayer.Mean = origInput.Mean;
        catch
            % si problème, on ignore
        end
    end
end

foldLayer = sequenceFoldingLayer('Name','fold');
lgraph = addLayers(lgraphCNN, [inputLayer; foldLayer]);

switch backbone
    case 'googlenet'
        lgraph = connectLayers(lgraph,"fold/out","conv1-7x7_s2");
    case 'resnet50'
        lgraph = connectLayers(lgraph,"fold/out","conv1");
    case 'resnet18'
        lgraph = connectLayers(lgraph,"fold/out","conv1");
    case {'inceptionresnetv2','inceptionv3'}
        lgraph = connectLayers(lgraph,"fold/out","conv2d_1");
end

% --- Partie LSTM : on enlève seulement la première sequenceInputLayer ---
if isa(netLSTM,'dlnetwork')
    lgraphLSTM = layerGraph(netLSTM);
else
    lgraphLSTM = layerGraph(netLSTM);
end
lstmLayersFull = lgraphLSTM.Layers;

if isa(lstmLayersFull(1),'nnet.cnn.layer.SequenceInputLayer')
    lstmLayersFull(1) = [];  % on enlève l'input sequence
end

unfoldLayer = sequenceUnfoldingLayer('Name','unfold');
flattenLayerObj = flattenLayer('Name','flatten');

layersTail = [ ...
    unfoldLayer; ...
    flattenLayerObj; ...
    lstmLayersFull ...
    ];

lgraph = addLayers(lgraph, layersTail);

lgraph = connectLayers(lgraph, layerName, "unfold/in");
lgraph = connectLayers(lgraph, "fold/miniBatchSize", "unfold/miniBatchSize");

% --- Assemblage final ---
classifier = assembleNetwork(lgraph);

% Sauvegarder pour les futurs load
save(fullfile(path,[name '.mat']),'classifier','-v7.3');
disp('Rebuilt full CNN+LSTM network and saved assembled classifier.');
end
