function [data,image] = classifyImageLSTMNetFun(roiobj, classif, classifier, varargin)
% Classif vidéo avec LSTM et/ou CNN optionnel.
% - Si LSTM absent et CNN présent -> "CNN only": on remplit les champs primaires (id/prob/labels) avec le CNN.
% - Si LSTM présent et CNN présent -> LSTM = primaire ; CNN dans les champs *_CNN (idCNN/probCNN_/labelsCNN).
%
% Options (varargin):
%   'ClassifierCNN', netCNN
%   'Frames', framesVec
%   'Channel', channelName
%   'Exec', 0|1  (0=CPU, 1=GPU)
%   'Crop', true/false
%   'CropCenter', [cx cy]
%   'CropSize',   [w h]

% --------- Defaults ----------
Crop         = false;
CropCenter   = [88 194];   % [cx cy]
CropSize     = [60 60];    % [w h]
channel      = classif.channelName;
frames       = [];
classifierCNN= [];
gpu          = 0;

% --------- Parse args ----------
for i = 1:numel(varargin)
    if ischar(varargin{i}) || isstring(varargin{i})
        key = lower(string(varargin{i}));
        switch key
            case "classifiercnn"
                classifierCNN = varargin{i+1};
            case "frames"
                frames = varargin{i+1};
            case "channel"
                channel = varargin{i+1};
            case "exec"
                gpu = varargin{i+1};
            case "crop"
                Crop = logical(varargin{i+1});
            case "cropcenter"
                CropCenter = varargin{i+1};
            case "cropsize"
                CropSize = varargin{i+1};
        end
    end
end

% --------- Guard: ROI image ---------
if isempty(roiobj.image); roiobj.load; end
if isempty(roiobj.image)
    warning('Could not find ROI image; quitting.');
    data = roiobj.data; image = [];
    return;
end

% --------- Guard: classifieurs présents / types ----------
useLSTM = ~isempty(classifier);
useCNN  = ~isempty(classifierCNN);

% tolère struct wrapper .net
if isstruct(classifier) && isfield(classifier,'net'); classifier = classifier.net; end
if isstruct(classifierCNN) && isfield(classifierCNN,'net'); classifierCNN = classifierCNN.net; end

% type check souple
if useLSTM && ~(isa(classifier,'DAGNetwork') || isa(classifier,'SeriesNetwork') || isa(classifier,'dlnetwork'))
    error('classifyImageLSTMNetFun:ClassifierType', 'Classifier LSTM type not supported: %s', class(classifier));
end
if useCNN && ~(isa(classifierCNN,'DAGNetwork') || isa(classifierCNN,'SeriesNetwork'))
    % (classify sur dlnetwork n'est pas dispo directement)
    error('classifyImageLSTMNetFun:CNNType', 'Classifier CNN type not supported: %s', class(classifierCNN));
end
if ~useLSTM && ~useCNN
    error('classifyImageLSTMNetFun:NoModel', 'Aucun classifieur fourni (ni LSTM, ni CNN).');
end

% --------- Trouver frames & canal ---------
pix = roiobj.findChannelID(channel);
if iscell(pix); pix = cell2mat(pix); end
if isempty(frames); frames = 1:size(roiobj.image,4); end

% empile le canal demandé en 3 canaux uint8 avec preProcessROIData (comme avant)
si = size(roiobj.image);
T  = numel(frames);
vid = uint8(zeros(si(1), si(2), 3, T));
cc = 1; param = [];
for j = frames
    tmp = roiobj.preProcessROIData(pix, j, param);
    if isempty(tmp)
        vid(:,:,:,cc) = uint8(0);
    else
        vid(:,:,:,cc) = uint8(255*tmp);
    end
    cc = cc + 1;
end

% Crop optionnel
if Crop
    vid = cropAroundCenter4D(vid, CropCenter, CropSize);
end

% --------- Déduire tailles d'entrée ---------
% LSTM: cherche SequenceInputLayer
inputSizeLSTM = [];
if useLSTM
    try
        if isa(classifier,'dlnetwork')
            % pas de .Layers public; on suppose l'entrée de taille connue en amont.
            % On prend la taille de la 1ère dimension spatiale de la vidéo comme fallback.
            inputSizeLSTM = size(vid,[1,2]);
        else
            for ii = 1:numel(classifier.Layers)
                if strcmp(class(classifier.Layers(ii)), 'nnet.cnn.layer.SequenceInputLayer')
                    inputSizeLSTM = classifier.Layers(ii).InputSize(1:2);
                    break;
                end
            end
            if isempty(inputSizeLSTM)
                % fallback raisonnable si non trouvé
                inputSizeLSTM = size(vid,[1,2]);
            end
        end
    catch
        inputSizeLSTM = size(vid,[1,2]);
    end
end

% CNN: taille d'entrée
inputSizeCNN = [];
if useCNN
    inputSizeCNN = classifierCNN.Layers(1).InputSize(1:2);
end

% vidéos redimensionnées
videoLSTM = [];
videoCNN  = [];
if useLSTM
    videoLSTM = resizeTo(vid, inputSizeLSTM);
end
if useCNN
    % si mêmes tailles que LSTM, évite un second resize
    if useLSTM && isequal(inputSizeCNN, inputSizeLSTM)
        videoCNN = videoLSTM;
    else
        videoCNN = resizeTo(vid, inputSizeCNN);
    end
end

% --------- Exécution (GPU / CPU avec fallback) ----------
env = iff(gpu==1, "gpu", "cpu");

labelsLSTM = []; probLSTM = []; idxLSTM = [];
labelsCNN  = []; probCNN  = []; idxCNN  = [];

% LSTM
if useLSTM
    try
        [lbl, sc] = classify(classifier, videoLSTM, 'ExecutionEnvironment', env);
    catch
        warning('LSTM classify failed on %s: falling back to CPU.', upper(string(env)));
        [lbl, sc] = classify(classifier, videoLSTM, 'ExecutionEnvironment', 'cpu');
    end
    labelsLSTM = classifier.Layers(end).Classes;  % catégories apprises
    probLSTM   = sc;                               % Nobs x Nclasses (ou l'inverse selon version)
    if size(probLSTM,1) == numel(labelsLSTM); probLSTM = probLSTM'; end
    [~, idxLSTM] = max(probLSTM, [], 2);
end

% CNN
if useCNN
    try
        [lblC, scC] = classify(classifierCNN, videoCNN, 'ExecutionEnvironment', env);
    catch
        warning('CNN classify failed on %s: falling back to CPU.', upper(string(env)));
        [lblC, scC] = classify(classifierCNN, videoCNN, 'ExecutionEnvironment', 'cpu');
    end
    labelsCNN = classifierCNN.Layers(end).ClassNames;
    probCNN   = scC;
    if size(probCNN,1) == numel(labelsCNN); probCNN = probCNN'; end
    [~, idxCNN] = max(probCNN, [], 2);
end

% --------- Cible de classes (ordre & noms de colonnes dans dataseries) ----------
classesTarget = string(classif.classes); % c'est la vérité côté dataseries

% Choisir le "primaire"
primaryIsLSTM = useLSTM; % si LSTM absent -> primaire = CNN
if ~useLSTM && useCNN
    primaryIsLSTM = false;
end

if primaryIsLSTM
    labelsPrimary = string(labelsLSTM);
    probPrimary   = probLSTM;   % T x NLstm
    idxPrimary    = idxLSTM;
else
    labelsPrimary = string(labelsCNN);
    probPrimary   = probCNN;    % T x NCnn
    idxPrimary    = idxCNN;
end

% Aligner probPrimary sur classesTarget
[isIn, perm] = ismember(classesTarget, labelsPrimary);
if any(~isIn)
    missing = classesTarget(~isIn);
    warning('Classes absentes dans le modèle primaire: %s', strjoin(missing, ', '));
end
probPrimaryAligned = zeros(size(probPrimary,1), numel(classesTarget), 'like', probPrimary);
validCols = find(isIn);
probPrimaryAligned(:, validCols) = probPrimary(:, perm(validCols));

% étiquettes primaires
[~, idxP] = max(probPrimaryAligned, [], 2);
labelPrimaryCat = categorical(classesTarget(idxP), classesTarget);

% Prépare les champs CNN supplémentaires si CNN présent
probCNNAligned = [];
labelCNNCat    = [];
idxCNNAligned  = [];
if useCNN
    [isInC, permC] = ismember(classesTarget, string(labelsCNN));
    if any(~isInC)
        warning('Classes absentes dans le CNN: %s', strjoin(classesTarget(~isInC), ', '));
    end
    probCNNAligned = zeros(size(probCNN,1), numel(classesTarget), 'like', probCNN);
    validC = find(isInC);
    probCNNAligned(:, validC) = probCNN(:, permC(validC));
    [~, idxCNNAligned] = max(probCNNAligned, [], 2);
    labelCNNCat = categorical(classesTarget(idxCNNAligned), classesTarget);
end

% --------- Écriture dans dataseries (idempotent) ----------
data = roiobj.data;
if isempty(data)
    roiobj.data = dataseries;
    data = roiobj.data;
end

% Cherche dataseries existant pour ce classif
pixdata = find(arrayfun(@(x) strcmp(x.groupid, classif.strid), roiobj.data), 1, 'first');
if isempty(pixdata)
    % crée
    cc = (numel(roiobj.data)==1 && isempty(roiobj.data.data)) * 1 + ...
         (numel(roiobj.data)~=1 || ~isempty(roiobj.data.data)) * (numel(roiobj.data)+1);
    data(cc) = dataseries;
    data(cc).class    = "classification";
    data(cc).groupid  = classif.strid;
    data(cc).parentid = roiobj.id;
else
    cc = pixdata;
end

% plotGroup / groupProperties (basique)
if ~isprop(data(cc),'plotGroup') || isempty(data(cc).plotGroup)
    data(cc).plotGroup = {[] [] [] [] [] {'id' 'prob' 'labels'}};
end
if ~isprop(data(cc),'groupProperties') || isempty(data(cc).groupProperties)
    data(cc).groupProperties = {'id','Plot','auto','auto'; 'label','Plot','auto','auto'; 'prob','Plot','auto','auto'};
end

datatmp = data(cc);

% Nombre de lignes à écrire
n = iff(classif.output==0, size(roiobj.image,4), 1);

% --- NORMALISATION PLOTGROUP (évite horzcat char vs cell) ---
if ~isprop(datatmp,'plotGroup') || isempty(datatmp.plotGroup)
    datatmp.plotGroup = {[] [] [] [] [] {'id' 'prob' 'labels'}};
else
    % garantir l'index 6 et son type
    if numel(datatmp.plotGroup) < 6 || isempty(datatmp.plotGroup{6})
        datatmp.plotGroup{6} = {'id' 'prob' 'labels'};
    else
        g6 = datatmp.plotGroup{6};
        if ischar(g6)
            datatmp.plotGroup{6} = cellstr(g6);        % 'id' -> {'id'}
        elseif ~iscell(g6)
            datatmp.plotGroup{6} = {'id' 'prob' 'labels'};
        end
        % forcer forme ligne
        datatmp.plotGroup{6} = reshape(datatmp.plotGroup{6}, 1, []);
    end
end


% Initialise (ou vérifie) les colonnes primaires
ensureNumericCol('id');
for ii = 1:numel(classesTarget)
    ensureNumericCol("prob_" + classesTarget(ii));
end
ensureCategoricalCol('labels', 'undefined');

% Valeurs (restreintes aux frames)
datatmp.data.labels(frames) = labelPrimaryCat;
for ii = 1:numel(classesTarget)
    datatmp.data.("prob_" + classesTarget(ii))(frames) = probPrimaryAligned(frames, ii);
end
datatmp.data.id(frames) = idxP;

% Champs CNN additionnels
if useCNN
    ensureNumericCol('idCNN');
    for ii = 1:numel(classesTarget)
        ensureNumericCol("probCNN_" + classesTarget(ii));
    end
    ensureCategoricalCol('labelsCNN', 'undefined');

    datatmp.data.labelsCNN(frames) = labelCNNCat;
    for ii = 1:numel(classesTarget)
        datatmp.data.("probCNN_" + classesTarget(ii))(frames) = probCNNAligned(frames, ii);
    end
    datatmp.data.idCNN(frames) = idxCNNAligned;
else
    % si pas de CNN -> s'assurer qu'on ne laisse pas d'anciens champs CNN
    for ii = 1:numel(classesTarget)
        dropColIfExists("probCNN_" + classesTarget(ii));
    end
    dropColIfExists('labelsCNN');
    dropColIfExists('idCNN');
end

% plotProperties idempotent (pas d'empilement)
% plotProperties idempotent + aligné sur la table
pp = [];
if isprop(datatmp,'plotProperties') && ~isempty(datatmp.plotProperties)
    pp = datatmp.plotProperties;
end
pp = ensurePlotProperties(pp, string(classif.classes), useCNN, ...
                           'Prune', true);
pp = syncPlotPropsToTable(pp, datatmp.data);  % <<< élimine toute réf. manquante
datatmp.plotProperties = pp;



% Commit
data(cc) = datatmp;

% Sorties
image = roiobj.image;          % on ne modifie pas
roiobj.data = data;            % reflète les changements

% ----------------- Helpers locaux -----------------
function out = resizeTo(V, inSize)
    out = imresize(V, inSize(1:2));
end

function Vout = cropAroundCenter4D(Vin, center, winsz)
    [H,W,C,T] = size(Vin);
    cx = round(center(1));  cy = round(center(2));
    w  = round(winsz(1));   h  = round(winsz(2));
    halfw = floor(w/2);     halfh = floor(h/2);
    x1 = cx - halfw;  x2 = x1 + w - 1;
    y1 = cy - halfh;  y2 = y1 + h - 1;
    sx1 = max(1, x1);  sx2 = min(W, x2);
    sy1 = max(1, y1);  sy2 = min(H, y2);
    dx1 = 1 + (sx1 - x1); dy1 = 1 + (sy1 - y1);
    dx2 = dx1 + (sx2 - sx1); dy2 = dy1 + (sy2 - sy1);
    Vout = zeros(h, w, C, T, 'like', Vin);
    Vout(dy1:dy2, dx1:dx2, :, :) = Vin(sy1:sy2, sx1:sx2, :, :);
end

function v = iff(cond, a, b)
    if cond, v = a; else, v = b; end
end

function ensureNumericCol(name)
    name = char(name);
    if ~ismember(name, datatmp.data.Properties.VariableNames)
        datatmp.addData(zeros(n,1), name);
    else
        % étend si nécessaire
        cur = datatmp.data.(name);
        if numel(cur) < n
            cur(end+1:n,1) = 0;
            datatmp.data.(name) = cur;
        end
    end
end

function ensureCategoricalCol(name, undef)
    name = char(name);
    if ~ismember(name, datatmp.data.Properties.VariableNames)
        tmp = categorical(zeros(n,1), 0, {undef});
        datatmp.addData(tmp, name);
    else
        cur = datatmp.data.(name);
        if numel(cur) < n
            % pad avec la 1re catégorie si possible
            if iscategorical(cur)
                pad = repmat(cur(1), n-numel(cur), 1);
            else
                pad = categorical(zeros(n-numel(cur),1),0,{undef});
            end
            datatmp.data.(name) = [cur; pad];
        end
    end
end

function dropColIfExists(name)
    name = char(name);
    if ismember(name, datatmp.data.Properties.VariableNames)
        datatmp.removeData(name);
    end
end

function props = ensurePlotProperties(props, classList, addCNN, varargin)
    p = inputParser;
    p.addParameter('Prune',            true);
    p.parse(varargin{:});
   
    doPrune = logical(p.Results.Prune);

    if iscell(classList), classList = string(classList); end
    classList = classList(:).';

    req = {
        false,  'id_training',     'double',      'k', 2, 'id';
        true,  'labels_training', 'categorical', 'k', 2, 'label';
        false,  'id',              'double',      'k', 2, 'id';
    };
    for c = classList
        req(end+1,:) = {false, ['prob_' char(c)], 'double', 'k', 2, 'prob'}; %#ok<AGROW>
    end
    req(end+1,:) = {true, 'labels', 'categorical', 'k', 2, 'label'};

    if addCNN
        req(end+1,:) = {false, 'idCNN', 'double', 'k', 2, 'id'};
        for c = classList
            req(end+1,:) = {false, ['probCNN_' char(c)], 'double', 'k', 2, 'prob'}; %#ok<AGROW>
        end
        req(end+1,:) = {true, 'labelsCNN', 'categorical', 'k', 2, 'label'};
       
    end

    props = upsertProps(props, req);
    props = dedupByName(props);
    props = orderByList(props, req);
    if doPrune
        props = pruneByClassList(props, classList);
    end
end

function props = syncPlotPropsToTable(props, tbl)
    % retire toute ligne qui réfère à un nom de variable absent
    if isempty(props), return; end
    present = ismember(string(props(:,2)), string(tbl.Properties.VariableNames));
    props = props(present, :);
    % normalise colonne 1 en logical
    for i=1:size(props,1)
        if ~islogical(props{i,1}), props{i,1} = logical(props{i,1}); end
    end
end

% -- helpers utilisés par ensurePlotProperties --
function props = upsertProps(props, rows)
    if isempty(props), props = rows; return; end
    names = lower(string(props(:,2)));
    for r = 1:size(rows,1)
        key = lower(string(rows{r,2}));
        idx = find(names == key, 1, 'first');
        row = rows(r,:);
        if ~islogical(row{1}), row{1} = logical(row{1}); end
        if isempty(idx)
            props(end+1,:) = row;
            names(end+1) = key;
        else
            props(idx,:) = row;
        end
    end
end
function props = dedupByName(props)
    [~, ia] = unique(lower(string(props(:,2))), 'stable');
    props = props(sort(ia), :);
end
function props = orderByList(props, referenceRows)
    refNames = lower(string(referenceRows(:,2)));
    curNames = lower(string(props(:,2)));
    [found, loc] = ismember(refNames, curNames);
    head = props(loc(found), :);
    tail = props(~ismember(curNames, refNames), :);
    props = [head; tail];
end
function props = pruneByClassList(props, classList)
    names = string(props(:,2));
    isProb    = startsWith(names, "prob_");
    isProbCNN = startsWith(names, "probCNN_");
    keep = true(size(names));
    idx = find(isProb);
    for k = idx(:).'
        cname = extractAfter(names(k), "prob_");
        if ~any(classList == cname), keep(k) = false; end
    end
    idx = find(isProbCNN);
    for k = idx(:).'
        cname = extractAfter(names(k), "probCNN_");
        if ~any(classList == cname), keep(k) = false; end
    end
    props = props(keep, :);
end



end
