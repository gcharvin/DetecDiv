function out = classify(roiobj, classif, ctx)
% CNN_LSTM.classify
% Pipeline-friendly CNN/LSTM inference for one ROI.
%
% Sections:
%   1) Inputs & ctx defaults
%   2) Load ROI frames + build video tensor
%   3) LSTM/CNN inference (seq2seq or seq2one)
%   4) Build dataseries patch (no direct ROI write)
%
% ctx fields used:
%   ctx.sel.frames
%   ctx.sel.channels
%   ctx.exec.gpu
%   ctx.exec.classifier / ctx.exec.classifierCNN (optional preloaded nets)
%   ctx.names.outputName
%   ctx.params.crop / cropCenter / cropSize (optional)

if nargin < 3 || isempty(ctx)
    ctx = struct();
end

params = struct();
if isfield(ctx, 'params') && isstruct(ctx.params)
    params = ctx.params;
end

% --------- 1) Defaults ----------
Crop         = getOpt(params, 'crop', false);
CropCenter   = getOpt(params, 'cropcenter', [88 194]);   % [cx cy]
CropSize     = getOpt(params, 'cropsize', [60 60]);      % [w h]
channel      = classif.channelName;
frames       = [];
classifierCNN= [];
classifier   = [];
gpu          = getExecOpt(ctx, 'gpu', 0);

if isfield(ctx, 'sel')
    if isfield(ctx.sel, 'frames') && ~isempty(ctx.sel.frames)
        frames = ctx.sel.frames;
    end
    if isfield(ctx.sel, 'channels') && ~isempty(ctx.sel.channels)
        channel = ctx.sel.channels;
    end
end

if iscell(channel) && ~isempty(channel)
    channel = channel{1};
elseif isstring(channel) && numel(channel) > 1
    channel = channel(1);
end

classifier   = getExecOpt(ctx, 'classifier', []);
classifierCNN= getExecOpt(ctx, 'classifierCNN', []);
classifierProvided = getExecOpt(ctx, 'classifierProvided', false);
classifierCNNProvided = getExecOpt(ctx, 'classifierCNNProvided', false);
if isempty(classifier) && isfield(params, 'classifier'), classifier = params.classifier; end
if isempty(classifierCNN) && isfield(params, 'classifierCNN'), classifierCNN = params.classifierCNN; end

outputName = "";
if isfield(ctx, 'names') && isfield(ctx.names, 'outputName') && ~isempty(ctx.names.outputName)
    outputName = string(ctx.names.outputName);
elseif isfield(ctx, 'outputName') && ~isempty(ctx.outputName)
    outputName = string(ctx.outputName);
end
if strlength(strtrim(outputName)) == 0
    outputName = string(classif.strid);
else
    outputName = strtrim(outputName);
end

outputMode = lower(strrep(strtrim(string(getOpt(params, 'outputMode', 'lstm_only'))), " ", "_"));
if ~any(outputMode == ["lstm_only","cnn_only","both"])
    outputMode = "lstm_only";
end
cnnOutputName = string(getOpt(params, 'cnnOutputName', ""));
if strlength(strtrim(cnnOutputName)) == 0
    cnnOutputName = "cnn_" + outputName;
else
    cnnOutputName = strtrim(cnnOutputName);
end
if outputMode == "cnn_only"
    outputName = cnnOutputName;
end

wantCNNOutput = any(outputMode == ["cnn_only","both"]);
if outputMode == "lstm_only"
    classifierCNN = [];
end

% --------- DEBUG FLAG CNN ----------
debugCNN = false;

% --------- 2) Guard: ROI image ---------
if isempty(roiobj.image)
    error('classifyImageLSTMNetFun:NoImage', 'ROI image not loaded.');
end

% --------- Guard: classifieurs présents / types ----------
% --------- 3) Load classifiers (optional from ctx) ----------
if isempty(classifier) && ~classifierProvided
    try
        classifier = classif.loadClassifier('force');
    catch
        classifier = [];
    end
    if isempty(classifier)
        classifier = loadNetworkArtifact(classif, {'classifier','net','netLSTM_dag','netLSTM'}, ...
            {[char(string(classif.strid)) '.mat'], ['netLSTM_' char(string(classif.strid)) '.mat']});
    end
end

if isempty(classifierCNN) && ~classifierCNNProvided
    try
        str = fullfile(classif.path, ['netCNN_' classif.strid '.mat']);
        if exist(str,'file')
            S = load(str);
            if isfield(S, 'classifier')
                classifierCNN = S.classifier;
            elseif isfield(S, 'netCNN')
                classifierCNN = S.netCNN;
            elseif isfield(S, 'net')
                classifierCNN = S.net;
            else
                fn = fieldnames(S);
                if ~isempty(fn), classifierCNN = S.(fn{1}); end
            end
        end
    catch
        classifierCNN = [];
    end
    if isempty(classifierCNN)
        classifierCNN = loadNetworkArtifact(classif, {'classifier','netCNN','net'}, ...
            {['netCNN_' char(string(classif.strid)) '.mat']});
    end
end

useLSTM = ~isempty(classifier);
useCNN  = wantCNNOutput && ~isempty(classifierCNN);

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

if outputMode == "lstm_only" && ~useLSTM
    error('classifyImageLSTMNetFun:NoLSTM', 'outputMode=lstm_only requires an LSTM classifier.');
end
if outputMode == "cnn_only" && ~useCNN
    error('classifyImageLSTMNetFun:NoCNN', 'outputMode=cnn_only requires a CNN classifier.');
end
if outputMode == "both" && (~useLSTM || ~useCNN)
    error('classifyImageLSTMNetFun:MissingModel', 'outputMode=both requires both LSTM and CNN classifiers.');
end
if ~useLSTM && ~useCNN
    error('classifyImageLSTMNetFun:NoModel', 'Aucun classifieur fourni (ni LSTM, ni CNN).');
end

% --------- 4) Frames & channel selection ---------


pix = roiobj.findChannelID(channel);

if iscell(pix)
    % enlever les éléments vides
    pix = pix(~cellfun(@isempty, pix));

    if isempty(pix)
        % aucun indice valide → on retourne un vecteur vide et on continue sans erreur
        pix = [];
    else
        % concaténer proprement même si certaines cellules sont lignes/colonnes
        pix = cellfun(@(x) x(:).', pix, 'UniformOutput', false);
        pix = [pix{:}];    % concat à la suite
    end
end

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


% --------- 5) Input sizes / resize ---------
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
    inputSizeCNN = inferCNNInputSizeFromNet(classifierCNN, size(vid,[1,2]));
end

% vidéos redimensionnées
videoLSTM = [];
videoCNN  = [];
if useLSTM
    videoLSTM = resizeTo(vid, inputSizeLSTM);
end


if useCNN
    targetSizeCNN = inputSizeCNN;
    videoCNN      = resizeTo(vid, inputSizeCNN); %vid % buildCNNVidFromROI(roiobj, classif, frames, ...
                                      % Crop, CropCenter, CropSize, ...
                                      % targetSizeCNN);
end



% --------- 6) Inference (GPU / CPU with fallback) ----------
env = iff(gpu==1, "gpu", "cpu");

labelsLSTM = []; probLSTM = []; idxLSTM = [];
labelsCNN  = []; probCNN  = []; idxCNN  = [];

classesTarget = string(classif.classes); % c'est la vérité côté dataseries

% --------- 7) classifier_output (source of truth) ----------
tp = [];
try
    tp = classif.trainingParam;
catch
end

outMode = "sequence-to-sequence"; % default
if ~isempty(tp) && isfield(tp,'classifier_output') && ~isempty(tp.classifier_output)
    if iscell(tp.classifier_output)
        outMode = string(tp.classifier_output{end});
    else
        outMode = string(tp.classifier_output);
    end
end

isSeq2One = strcmpi(outMode, "sequence-to-one");
isSeq2Seq = strcmpi(outMode, "sequence-to-sequence");
if ~isSeq2One && ~isSeq2Seq
    warning('Unknown classifier_output="%s" -> defaulting to sequence-to-sequence.', outMode);
    isSeq2Seq = true;
end

% --------- 8) Windowing for seq2one inference ----------
Lwin = 0;
if ~isempty(tp) && isfield(tp,'LSTM_sequence_length') && ~isempty(tp.LSTM_sequence_length)
    Lwin = tp.LSTM_sequence_length;
end
if isempty(Lwin) || ~isscalar(Lwin), Lwin = 0; end
Lwin = round(Lwin);

% Fenêtres contiguës (comme training) : [s e]
useWins = [];
if isSeq2One
    if Lwin <= 0 || Lwin >= T
        useWins = [1 T];
    else
        starts = 1:Lwin:T;
        useWins = zeros(numel(starts),2);
        for k = 1:numel(starts)
            s = starts(k);
            e = min(T, s + Lwin - 1);
            useWins(k,:) = [s e];
        end
    end
end



% =========================
% LSTM inference
% =========================
if useLSTM
    labelsLSTM = classifier.Layers(end).Classes;  % catégories apprises
    C = numel(labelsLSTM);

    if isSeq2One
        % --- seq2one fenêtré : prédire 1 fois par fenêtre, puis "déplier" par frame ---
        probLSTM = zeros(T, C, 'single');
        idxLSTM  = zeros(T, 1, 'int32');

        for w = 1:size(useWins,1)
            s = useWins(w,1);
            e = useWins(w,2);

            clip = videoLSTM(:,:,:,s:e);

            try
                [~, scW] = classify(classifier, clip, 'ExecutionEnvironment', env);
            catch
                warnGpuFallback('LSTM window', env, classif);
                [~, scW] = classify(classifier, clip, 'ExecutionEnvironment', 'cpu');
            end

            % scW attendu: 1xC (ou Cx1). Sécuriser en 1xC.
            if size(scW,1) == C && size(scW,2) == 1
                scW = scW';
            elseif size(scW,1) ~= 1
                scW = scW(1,:); % safety
            end

            [~, idW] = max(scW, [], 2); % scalaire

            probLSTM(s:e, :) = repmat(single(scW), [e-s+1, 1]);
            idxLSTM(s:e, 1)  = int32(idW);
        end

    else
        % --- seq2seq : comportement actuel (une prédiction par frame) ---
        try
            [~, sc] = classify(classifier, videoLSTM, 'ExecutionEnvironment', env);
        catch
            warnGpuFallback('LSTM', env, classif);
            [~, sc] = classify(classifier, videoLSTM, 'ExecutionEnvironment', 'cpu');
        end

        probLSTM = sc;
        if size(probLSTM,1) == C
            probLSTM = probLSTM'; % [T x C]
        end

        if size(probLSTM,1) ~= T
            warning('LSTM seq2seq: unexpected #rows=%d, expected T=%d. Forcing broadcast of first row.', size(probLSTM,1), T);
            probLSTM = repmat(probLSTM(1,:), [T 1]);
        end

        [~, idxLSTM] = max(probLSTM, [], 2);
    end
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
            warnGpuFallback('CNN', env, classif);
            [lblC, scC] = classify(classifierCNN, videoCNN, 'ExecutionEnvironment', 'cpu');
        end
        labelsCNN = classifierCNN.Layers(end).ClassNames;
        probCNN   = scC;
        if size(probCNN,1) == numel(labelsCNN); probCNN = probCNN'; end
        [~, idxCNN] = max(probCNN, [], 2);
    end
end

% --------- Normalize CNN outputs to per-frame (only if CNN actually returned 1xC) ----------
if useCNN
    if size(probCNN,1) == 1 && T > 1
        probCNN = repmat(probCNN, [T 1]);
        idxCNN  = repmat(idxCNN(1), [T 1]);
    elseif size(probCNN,1) ~= T
        warning('CNN: unexpected #rows=%d, expected T=%d. Forcing broadcast of first row.', size(probCNN,1), T);
        probCNN = repmat(probCNN(1,:), [T 1]);
        idxCNN  = repmat(idxCNN(1), [T 1]);
    end
end



% --------- Cible de classes (ordre & noms de colonnes dans dataseries) ----------


% Choisir le "primaire"
primaryIsLSTM = useLSTM; % si LSTM absent -> primaire = CNN
if outputMode == "cnn_only"
    if ~useCNN
        error('classifyImageLSTMNetFun:NoCNN', 'outputMode=cnn_only requires a CNN classifier.');
    end
    primaryIsLSTM = false;
elseif ~useLSTM && useCNN
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

% --------- 9) Build dataseries patch (idempotent) ----------
data = roiobj.data;
if isempty(data)
    data = dataseries;
end

% --- sanitize: remove invalid/deleted dataseries handles ---
try
    if isa(data,'handle')
        data = data(isvalid(data));
    end
catch
end
if isempty(data)
    data = dataseries;
end

groupid = char(outputName);
if isempty(groupid)
    groupid = classif.strid;
end

% Cherche dataseries existant pour ce groupid
pixdata = find(arrayfun(@(x) strcmp(x.groupid, groupid), data), 1, 'first');
if isempty(pixdata)
    datatmp = dataseries;
    datatmp.class    = "classification";
    datatmp.groupid  = groupid;
    datatmp.parentid = roiobj.id;
else
    datatmp = cloneDataseries(data(pixdata));
    if isempty(datatmp.groupid)
        datatmp.groupid = groupid;
    end
    if isempty(datatmp.parentid)
        datatmp.parentid = roiobj.id;
    end
end

% plotGroup / groupProperties (basique)
if ~isprop(datatmp,'plotGroup') || isempty(datatmp.plotGroup)
    datatmp.plotGroup = {[] [] [] [] [] {'id' 'prob' 'labels'}};
end
if ~isprop(datatmp,'groupProperties') || isempty(datatmp.groupProperties)
    datatmp.groupProperties = {'id','Plot','auto','auto'; 'label','Plot','auto','auto'; 'prob','Plot','auto','auto'};
end

% Nombre de lignes à écrire
% Nombre de lignes = nb total de frames ROI (dataseries alignée ROI)
n = size(roiobj.image,4);

% ============================================================
% Inference hygiene:
% - Drop previous inference columns (id/labels/prob_*, CNN*) to avoid pollution
% - Keep training columns: labels_training, id_training
% - Reset inference columns on ALL frames (1:n), then write only on 'frames'
% ============================================================

datatmp = pruneInferenceColsKeepTraining(datatmp);

% Reset inference outputs (for all frames) so partial inference doesn't leave stale values
classesUI = classesTarget(:).';
if ~any(classesUI == "unclassified")
    classesUI(end+1) = "unclassified";
end
catsLabels = ["undefined", classesUI];

datatmp = resetInferenceOutputs(datatmp, classesTarget, outputMode == "both", catsLabels, n);



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
% --------- Write ONLY on requested frames ----------
datatmp.data.labels(frames) = labelPrimaryCat;  % labelPrimaryCat is length T

for ii = 1:numel(classesTarget)
    colName = "prob_" + classesTarget(ii);
    v = datatmp.data.(colName);
    v(frames) = probPrimaryAligned(:, ii);      % <-- no extra indexing
    datatmp.data.(colName) = v;
end

idv = datatmp.data.id;
idv(frames) = idxP;                              % idxP length T
datatmp.data.id = idv;


% Champs CNN additionnels
if outputMode == "both"
    ensureNumericCol('idCNN');
    for ii = 1:numel(classesTarget)
        ensureNumericCol("probCNN_" + classesTarget(ii));
    end
    ensureCategoricalCol('labelsCNN', 'undefined');

  datatmp.data.labelsCNN(frames) = labelCNNCat;

for ii = 1:numel(classesTarget)
    colName = "probCNN_" + classesTarget(ii);
    v = datatmp.data.(colName);
    v(frames) = probCNNAligned(:, ii);          % <-- no extra indexing
    datatmp.data.(colName) = v;
end

idv = datatmp.data.idCNN;
idv(frames) = idxCNNAligned;                      % idxCNNAligned length T
datatmp.data.idCNN = idv;

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
pp = ensurePlotProperties(pp, string(classif.classes), outputMode == "both", 'Prune', true);
pp = syncPlotPropsToTable(pp, datatmp.data);
datatmp.plotProperties = pp;

classesTarget = string(classif.classes); % c'est la vérité côté dataseries
% classes à exposer à l'UI (garantit 'unclassified')
classesUI = classesTarget(:).';
if ~any(classesUI == "unclassified")
    classesUI(end+1) = "unclassified";
end

% --- Ensure userData.classes is always present (for UI consistency) ---
datatmp = ensureUserDataClasses(datatmp, classesUI);


% Build pipeline output
if exist('outInit','file') == 2
    out = outInit('cnn_lstm.classify');
else
    out = struct('ok', true, 'status', "OK", 'stepId', "classifyImageLSTMNetFun", ...
        'provides', {{}}, 'requires', {{}}, 'refs', struct(), ...
        'patch', struct('roi', struct('dataseries', struct('upsert', {{}}))), ...
        'artifacts', struct(), 'metrics', struct(), 'warnings', {{}}, ...
        'error', struct('id',"",'message',"",'stack',[]), 'logs', {{}} );
end
out.requires = {'ROIImages'};
out.provides = {'ClassificationScores'};
out.refs.classes = classesTarget;
out.metrics.nFrames = n;
out.metrics.frames = frames;
upserts = {struct('groupid', groupid, 'dataseries', datatmp, 'mode', 'replace')};
if outputMode == "both"
    if ~useCNN
        error('classifyImageLSTMNetFun:NoCNN', 'outputMode=both requires a CNN classifier.');
    end
    datacnn = makeCnnOnlyDataseries(datatmp, char(cnnOutputName), probCNNAligned, labelCNNCat, idxCNNAligned, classesTarget, catsLabels, frames);
    upserts{end+1} = struct('groupid', char(cnnOutputName), 'dataseries', datacnn, 'mode', 'replace'); %#ok<AGROW>
end
out.patch.roi.dataseries.upsert = upserts;

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
        datatmp.removeData(char(string(name)));
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

function ds = makeCnnOnlyDataseries(baseDs, groupid, probCNNAligned, labelCNNCat, idxCNNAligned, classesTarget, catsLabels, frames)
    ds = cloneDataseries(baseDs);
    ds.groupid = groupid;
    ds.class = "classification";

    if isempty(ds.data) || ~istable(ds.data)
        return;
    end

    vars = string(ds.data.Properties.VariableNames);
    cnnVars = vars(ismember(vars, ["idCNN","labelsCNN"]) | startsWith(vars, "probCNN_"));
    if ~isempty(cnnVars)
        ds.data = removevars(ds.data, cellstr(cnnVars));
    end

    nRows = height(ds.data);
    if ~ismember("id", string(ds.data.Properties.VariableNames))
        ds.addData(zeros(nRows,1), 'id', 'groups', 'id');
    else
        ds.data.id = zeros(nRows,1);
    end

    if ~ismember("labels", string(ds.data.Properties.VariableNames))
        ds.addData(categorical(repmat("undefined", nRows, 1), catsLabels), 'labels', 'groups', 'labels');
    else
        ds.data.labels = categorical(repmat("undefined", nRows, 1), catsLabels);
    end

    for kk = 1:numel(classesTarget)
        colName = "prob_" + classesTarget(kk);
        if ~ismember(colName, string(ds.data.Properties.VariableNames))
            ds.addData(zeros(nRows,1), char(colName), 'groups', 'prob');
        else
            ds.data.(char(colName)) = zeros(nRows,1);
        end
        v = ds.data.(char(colName));
        v(frames) = probCNNAligned(:, kk);
        ds.data.(char(colName)) = v;
    end

    ds.data.id(frames) = idxCNNAligned;
    ds.data.labels(frames) = labelCNNCat;

    pp = [];
    if isprop(ds, 'plotProperties') && ~isempty(ds.plotProperties)
        pp = ds.plotProperties;
    end
    pp = ensurePlotProperties(pp, string(classesTarget), false, 'Prune', true);
    pp = syncPlotPropsToTable(pp, ds.data);
    ds.plotProperties = pp;

    classesUI = classesTarget(:).';
    if ~any(classesUI == "unclassified")
        classesUI(end+1) = "unclassified";
    end
    ds = ensureUserDataClasses(ds, classesUI);
end

end


function ds = ensureUserDataClasses(ds, classesUI)
    % ds : dataseries
    % classesUI : string row

    if isempty(classesUI)
        classesUI = "unclassified";
    end
    classesUI = string(classesUI(:).');
    classesUI(classesUI=="") = [];
    if ~any(classesUI == "unclassified")
        classesUI(end+1) = "unclassified";
    end

    % userData doit être une struct
    if ~isprop(ds,'userData') || isempty(ds.userData) || ~isstruct(ds.userData)
        ds.userData = struct();
    end

    % stocker en cellstr row (le plus compatible AppDesigner)
    ds.userData.classes = cellstr(classesUI);
end

function ds = pruneInferenceColsKeepTraining(ds)
    if isempty(ds.data) || ~istable(ds.data), return; end

    vars = string(ds.data.Properties.VariableNames);

    % ---- Colonnes d'inférence à retirer (match exact) ----
    drop = strings(0,1);

    % exact names
    exact = ["id","labels","idCNN","labelsCNN"];
    drop = [drop; exact(ismember(exact, vars)).'];

    % prob_*
    % --- ensure consistent type + shape ---
varsS = string(vars);                  % safe even if vars is cellstr
drop  = string(drop);                  % idem
drop  = drop(:);                       % force column

drop  = [drop; varsS(startsWith(varsS,"prob_")).'];  % <-- attention au .'
drop  = unique(drop,'stable');         % optional, but usually useful


    % ---- Mais on protège explicitement les colonnes d'annotation ----
    protect = ["id_training","labels_training"];
    drop = setdiff(drop, protect, 'stable');

    drop = unique(drop, 'stable');
    if isempty(drop), return; end

    % 1) remove from table (exact var names)
    ds.data = removevars(ds.data, cellstr(drop));

    % 2) sync plotProperties (col 2 = varname)
    if ~isempty(ds.plotProperties)
        try
            toDel = ismember(string(ds.plotProperties(:,2)), drop);
            ds.plotProperties(toDel,:) = [];
        catch
        end
    end

    % 3) sync plotGroup{6} from remaining plotProperties (safe)
    try
        if isempty(ds.plotProperties)
            ds.plotGroup{6} = {};
        else
            ds.plotGroup{6} = unique(ds.plotProperties(:,6));
        end
    catch
    end
end


function ds = resetInferenceOutputs(ds, classesTarget, useCNN, catsLabels, n)
    % classesTarget: string row (classes "truth" côté dataseries)
    % catsLabels  : string row, e.g. ["undefined", classes..., "unclassified"]
    % n           : nb total frames ROI

    % --- Primary outputs ---
    % id
    if ~ismember("id", string(ds.data.Properties.VariableNames))
        ds.addData(zeros(n,1), 'id', 'groups', 'id');
    else
        ds.data.id = zeros(n,1);
    end

    % labels
    if ~ismember("labels", string(ds.data.Properties.VariableNames))
        ds.addData(categorical(repmat("undefined",n,1), catsLabels), 'labels', 'groups', 'labels');

    else
        ds.data.labels = categorical(repmat("undefined",n,1), catsLabels);
    end

    % prob_*
    for ii = 1:numel(classesTarget)
        nm = "prob_" + classesTarget(ii);
        if ~ismember(nm, string(ds.data.Properties.VariableNames))
           % ds.addData(zeros(n,1), char(nm));
            ds.addData(zeros(n,1), char(nm), 'groups', 'prob');
        else
            ds.data.(char(nm)) = zeros(n,1);
        end
    end

    % --- CNN secondary outputs ---
    if useCNN
        if ~ismember("idCNN", string(ds.data.Properties.VariableNames))
            ds.addData(zeros(n,1), 'idCNN');
        else
            ds.data.idCNN = zeros(n,1);
        end

        if ~ismember("labelsCNN", string(ds.data.Properties.VariableNames))
            ds.addData(categorical(repmat("undefined",n,1), catsLabels), 'labelsCNN');
        else
            ds.data.labelsCNN = categorical(repmat("undefined",n,1), catsLabels);
        end

        for ii = 1:numel(classesTarget)
            nm = "probCNN_" + classesTarget(ii);
            if ~ismember(nm, string(ds.data.Properties.VariableNames))
                ds.addData(zeros(n,1), char(nm));
            else
                ds.data.(char(nm)) = zeros(n,1);
            end
        end
    end
end

function v = getOpt(params, name, defaultValue)
    v = defaultValue;
    if ~isstruct(params), return; end
    fn = fieldnames(params);
    hit = find(strcmpi(fn, name), 1, 'first');
    if ~isempty(hit)
        v = params.(fn{hit});
    end
end

function v = getExecOpt(ctx, name, defaultValue)
    v = defaultValue;
    if isstruct(ctx) && isfield(ctx, 'exec') && isstruct(ctx.exec)
        fn = fieldnames(ctx.exec);
        hit = find(strcmpi(fn, name), 1, 'first');
        if ~isempty(hit)
            v = ctx.exec.(fn{hit});
            return;
        end
    end
end

function net = loadNetworkArtifact(classif, candidateFields, fileNames)
    net = [];
    try
        basePath = char(string(classif.path));
        if isempty(basePath)
            return;
        end
        for i = 1:numel(fileNames)
            filePath = fullfile(basePath, char(string(fileNames{i})));
            if exist(filePath, 'file') ~= 2
                continue;
            end
            S = load(filePath);
            for k = 1:numel(candidateFields)
                fieldName = candidateFields{k};
                if isfield(S, fieldName) && ~isempty(S.(fieldName))
                    net = S.(fieldName);
                    return;
                end
            end
            names = fieldnames(S);
            for k = 1:numel(names)
                candidate = S.(names{k});
                if isa(candidate, 'DAGNetwork') || isa(candidate, 'SeriesNetwork') || isa(candidate, 'dlnetwork')
                    net = candidate;
                    return;
                end
            end
        end
    catch
        net = [];
    end
end

function inputSizeHW = inferCNNInputSizeFromNet(netCNN, fallbackSizeHW)
    inputSizeHW = fallbackSizeHW;
    if nargin < 2 || isempty(fallbackSizeHW)
        fallbackSizeHW = [224 224];
    end
    try
        layers = netCNN.Layers;
    catch
        inputSizeHW = fallbackSizeHW;
        return;
    end

    try
        isInput = arrayfun(@(L) isa(L,'nnet.cnn.layer.ImageInputLayer'), layers);
        idx = find(isInput, 1, 'first');
        if isempty(idx)
            isInput = arrayfun(@(L) isa(L,'nnet.cnn.layer.SequenceInputLayer'), layers);
            idx = find(isInput, 1, 'first');
        end
        if ~isempty(idx)
            sz = layers(idx).InputSize;
            inputSizeHW = sz(1:2);
            return;
        end
    catch
    end

    try
        if isprop(netCNN, 'InputSizes') && ~isempty(netCNN.InputSizes)
            sz = netCNN.InputSizes{1};
            if numel(sz) >= 2
                inputSizeHW = sz(1:2);
                return;
            end
        end
    catch
    end

    inputSizeHW = fallbackSizeHW;
end

function ds = cloneDataseries(ds0)
    if isempty(ds0)
        ds = dataseries;
        return;
    end
    ds = dataseries;
    try, ds.id = ds0.id; end
    try, ds.groupid = ds0.groupid; end
    try, ds.parentid = ds0.parentid; end
    try, ds.class = ds0.class; end
    try, ds.type = ds0.type; end
    try, ds.data = ds0.data; end
    try, ds.plotGroup = ds0.plotGroup; end
    try, ds.plotProperties = ds0.plotProperties; end
    try, ds.groupProperties = ds0.groupProperties; end
    try, ds.description = ds0.description; end
    try, ds.history = ds0.history; end
    try, ds.userData = ds0.userData; end
    try, ds.show = ds0.show; end
    try, ds.parent = ds0.parent; end
end

function warnGpuFallback(stage, env, classif)
    % warnGpuFallback  Emit GPU fallback warning once and log to run.
    persistent didWarn
    if isempty(didWarn), didWarn = false; end
    if didWarn, return; end
    didWarn = true;

    if nargin < 1 || isempty(stage), stage = 'LSTM'; end
    if nargin < 2, env = ''; end

    try
        if ~isempty(env)
            warning('cnn_lstm:GpuFallback', ...
                '%s classify failed on GPU: falling back to CPU (env=%s).', ...
                char(stage), char(env));
        else
            warning('cnn_lstm:GpuFallback', ...
                '%s classify failed on GPU: falling back to CPU.', ...
                char(stage));
        end
    catch
    end

    try
        if nargin >= 3 && ismethod(classif,'runMsg')
            if ~isempty(env)
                classif.runMsg('GPU fallback: %s (env=%s)', char(stage), char(env));
            else
                classif.runMsg('GPU fallback: %s', char(stage));
            end
        end
    catch
    end
end

