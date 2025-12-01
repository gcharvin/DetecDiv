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

% --------- DEBUG FLAG CNN ----------
debugCNN = false;

% Sinon tu peux aussi juste mettre debugCNN=true ici pour un test ponctuel.

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
if useCNN && ~(isa(classifierCNN,'DAGNetwork') || ...
               isa(classifierCNN,'SeriesNetwork') || ...
               isa(classifierCNN,'dlnetwork'))
    error('classifyImageLSTMNetFun:CNNType', ...
        'Classifier CNN type not supported: %s', class(classifierCNN));
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


%figure('Position',[100 100 400 400]), imshow(vid(:,:,:,100),[])


% --------- Déduire tailles d'entrée ---------
% LSTM: cherche SequenceInputLayer
inputSizeLSTM = [];
if useLSTM
    try
        if isa(classifier,'dlnetwork')
           
            % Normalement le full net assemblé est un DAGNetwork, mais au cas où :
            inputSizeLSTM = size(vid,[1,2]);
        else
            % Cherche explicitement une SequenceInputLayer dans le réseau assemblé

            for ii = 1:numel(classifier.Layers)
                if isa(classifier.Layers(ii), 'nnet.cnn.layer.SequenceInputLayer')
              
                    % InputSize = [H W C]
                    inputSizeLSTM = classifier.Layers(ii).InputSize(1:2);
                    break;
                end
            end

            % Fallback : si vraiment rien trouvé, garder la taille native
            if isempty(inputSizeLSTM)
                inputSizeLSTM = [224 224] ; %size(vid,[1,2]);
            end
        end
    catch
        % En cas de bug, ne pas crasher l'inférence
        inputSizeLSTM = [224 224]; % size(vid,[1,2]);
    end
end


% CNN: taille d'entrée
% inputSizeCNN = [];
% if useCNN
%     inputSizeCNN = classifierCNN.Layers(1).InputSize(1:2);
% end

% vidéos redimensionnées
videoLSTM = [];
videoCNN  = [];
if useLSTM
    videoLSTM = resizeTo(vid, inputSizeLSTM);
end

% if useCNN
%     if useLSTM && isequal(inputSizeCNN, inputSizeLSTM)
%         videoCNN = videoLSTM;
%     else
%         videoCNN = resizeTo(vid, inputSizeCNN);
%     end
% end

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
    targetSizeCNN = classifierCNN.Layers(1).InputSize(1:2);
    videoCNN      = resizeTo(vid, inputSizeCNN); %vid % buildCNNVidFromROI(roiobj, classif, frames, ...
                                      % Crop, CropCenter, CropSize, ...
                                      % targetSizeCNN);
end



% --------- Exécution (GPU / CPU avec fallback) ----------
env = iff(gpu==1, "gpu", "cpu");

labelsLSTM = []; probLSTM = []; idxLSTM = [];
labelsCNN  = []; probCNN  = []; idxCNN  = [];

classesTarget = string(classif.classes); % c'est la vérité côté dataseries

% LSTM
if useLSTM
    try
        [lbl, sc] = classify(classifier, videoLSTM, 'ExecutionEnvironment', env);
    catch
        warning('LSTM classify failed on %s: falling back to CPU.', upper(string(env)));
        [lbl, sc] = classify(classifier, videoLSTM, 'ExecutionEnvironment', 'cpu');
    end
    labelsLSTM = classifier.Layers(end).Classes;  % catégories apprises
    probLSTM   = sc;
    if size(probLSTM,1) == numel(labelsLSTM); probLSTM = probLSTM'; end
    [~, idxLSTM] = max(probLSTM, [], 2);
end

% CNN
% CNN
if useCNN
    if isa(classifierCNN,'dlnetwork')
        % --------- Chemin d'inférence pour CNN entraîné avec trainnet (dlnetwork) ---------
        % videoCNN : H x W x 3 x T (uint8 ou single)
        X = single(videoCNN);                            % comme pour trainnet
        dlX = dlarray(X, "SSCB");                        % S S C B  (B = frames)

        % Pour l'instant : exécution CPU (simple et robuste).
        % Si tu veux utiliser le GPU, on pourra ajouter un bloc pour
        % basculer aussi les learnables du réseau sur GPU.
dlY = forward(classifierCNN, dlX);   % logits, dlarray *formaté*
dlP = softmax(dlY);                  % softmax respecte déjà le format de dlY


        P = gather(extractdata(dlP));                    % [C x B]
        probCNN = P.';                                   % [B x C]

        % On sait que l'ordre des canaux == classif.classes
        labelsCNN = categorical(classesTarget, classesTarget);

        [~, idxCNN] = max(probCNN, [], 2);
        lblC = categorical(classesTarget(idxCNN), classesTarget); %#ok<NASGU>

    else
        % --------- Chemin legacy pour DAG/SeriesNetwork (trainNetwork) ---------
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
end

% --------- Cible de classes (ordre & noms de colonnes dans dataseries) ----------


% Choisir le "primaire"
primaryIsLSTM = useLSTM; % si LSTM absent -> primaire = CNN
if ~useLSTM && useCNN
    primaryIsLSTM = false;
end

if primaryIsLSTM
    labelsPrimary = string(labelsLSTM);
    probPrimary   = probLSTM;
    idxPrimary    = idxLSTM;
else
    labelsPrimary = string(labelsCNN);
    probPrimary   = probCNN;
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

% --------- DEBUG CNN (distribution des scores) ----------
if useCNN && debugCNN
    debugCNNInference(classifierCNN, classesTarget, probCNNAligned, labelCNNCat, frames, roiobj);
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
    if numel(datatmp.plotGroup) < 6 || isempty(datatmp.plotGroup{6})
        datatmp.plotGroup{6} = {'id' 'prob' 'labels'};
    else
        g6 = datatmp.plotGroup{6};
        if ischar(g6)
            datatmp.plotGroup{6} = cellstr(g6);
        elseif ~iscell(g6)
            datatmp.plotGroup{6} = {'id' 'prob' 'labels'};
        end
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
    for ii = 1:numel(classesTarget)
        dropColIfExists("probCNN_" + classesTarget(ii));
    end
    dropColIfExists('labelsCNN');
    dropColIfExists('idCNN');
end

% plotProperties idempotent + aligné sur la table
pp = [];
if isprop(datatmp,'plotProperties') && ~isempty(datatmp.plotProperties)
    pp = datatmp.plotProperties;
end
pp = ensurePlotProperties(pp, string(classif.classes), useCNN, 'Prune', true);
pp = syncPlotPropsToTable(pp, datatmp.data);
datatmp.plotProperties = pp;

% Commit
data(cc) = datatmp;

% Sorties
image = roiobj.image;
roiobj.data = data;

% ----------------- Helpers locaux -----------------
    % function out = resizeTo(V, inSize)
    %     out = imresize(V, inSize(1:2));
    % end

function Vout = resizeTo(Vin, targetSize)
    % Vin : H x W x C x T
    [H,W,C,T] = size(Vin);
    Vout = zeros(targetSize(1), targetSize(2), C, T, 'like', Vin);
    for t = 1:T
        Vout(:,:,:,t) = imresize(Vin(:,:,:,t), targetSize);
    end
end

function vid = buildCNNVidFromROI(roiobj, classif, frames, Crop, CropCenter, CropSize, targetSize)
    % Version alignée sur HDF5/H5ImageDatastore :
    %  - preProcessROIData -> double [0,1]
    %  - recopie éventuelle en 3 canaux
    %  - crop identique à formatLSTMTrainingSet (localCrop)
    %  - resize -> targetSize
    %  - sortie en single [0,1], comme H5ImageDatastore

    channel = classif.channelName;
    pix     = roiobj.findChannelID(channel);
    if iscell(pix); pix = cell2mat(pix); end

    T  = numel(frames);
    Ht = targetSize(1);
    Wt = targetSize(2);

    vid = zeros(Ht, Wt, 3, T, 'single');

    for k = 1:T
        j   = frames(k);
        tmp = roiobj.preProcessROIData(pix, j, 1);  % double [0,1], dorepmat=1

        if isempty(tmp)
            vid(:,:,:,k) = 0;
            continue;
        end

        if size(tmp,3) == 1
            tmp = repmat(tmp,[1 1 3]);
        end

        if Crop
            tmp = localCrop(tmp, CropCenter, CropSize);
        end

        if size(tmp,1) ~= Ht || size(tmp,2) ~= Wt
            tmp = imresize(tmp, [Ht Wt]);
        end

        % ⚠ pas de *255 ni uint8 ici
        vid(:,:,:,k) = single(tmp);
    end
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
    p.addParameter('Prune', true);
    p.parse(varargin{:});
    doPrune = logical(p.Results.Prune);

    if iscell(classList), classList = string(classList); end
    classList = classList(:).';

    req = {
        false,  'id_training',     'double',      'k', 2, 'id';
        true,   'labels_training', 'categorical', 'k', 2, 'label';
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
    if isempty(props), return; end
    present = ismember(string(props(:,2)), string(tbl.Properties.VariableNames));
    props = props(present, :);
    for i=1:size(props,1)
        if ~islogical(props{i,1}), props{i,1} = logical(props{i,1}); end
    end
end

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

% --------- DEBUG helper ---------
function debugCNNInference(classifierCNN, classesTarget, probCNNAligned, labelCNNCat, frames, roiobj)
    try
        netClasses = string(classifierCNN.Layers(end).ClassNames);
    catch
        netClasses = strings(0,1);
    end

    P = gather(probCNNAligned);
    classesTarget = string(classesTarget);

    fprintf('\n=== DEBUG CNN inference ===\n');
    fprintf('ROI id: %d | frames: [%d..%d] (N=%d)\n', ...
        roiobj.id, frames(1), frames(end), numel(frames));
    fprintf('Net classes      : %s\n', strjoin(netClasses, ', '));
    fprintf('classif.classes  : %s\n', strjoin(classesTarget, ', '));

    for i = 1:numel(classesTarget)
        cname = classesTarget(i);
        col   = P(:, i);
        if all(col == 0)
            fprintf('  %s : all scores = 0 (col vide)\n', cname);
        else
            q = quantile(col, [0 0.25 0.5 0.75 0.9 0.95 0.99]);
            fprintf('  %s : q[0 25 50 75 90 95 99] = [%0.3f %0.3f %0.3f %0.3f %0.3f %0.3f %0.3f]\n', ...
                cname, q);
        end
    end

    % Focus spécifique sur "foci" si présent
    idxFoci = find(classesTarget == "foci", 1);
    if ~isempty(idxFoci)
        sf = P(:, idxFoci);
        fprintf('  "foci" : prop(score>=0.5)=%4.1f%%, >=0.7=%4.1f%%, >=0.9=%4.1f%%\n', ...
            100*mean(sf>=0.5), 100*mean(sf>=0.7), 100*mean(sf>=0.9));
    end

    % Petit résumé des labels CNN sur cette ROI
    if ~isempty(labelCNNCat)
        lab = labelCNNCat(frames);
        cats = categories(lab);
        counts = countcats(lab);
        fprintf('  LabelsCNN sur cette ROI :\n');
        for k = 1:numel(cats)
            fprintf('    %s : %d frames\n', string(cats{k}), counts(k));
        end
    end
    fprintf('===========================\n');
end

end
