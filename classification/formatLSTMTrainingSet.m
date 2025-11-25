function output = formatLSTMTrainingSet(foldername, classif, rois, varargin)

% ---- Params optionnels ----
Frames     = [];
Fraction   = 1;        % fraction de ROIs à utiliser
Seed       = 12345;    % seed pour la sélection de ROIs / RNG locales
Crop       = false;    % activer/désactiver le crop
CropCenter = [88 194]; % [cx cy]
CropSize   = [60 60];  % [w h]

UndersampleMajority = 1;   % 1 = désactivé (100% des frames gardées)
UseHDF5            = [];   % si vrai : export HDF5 framebank
WriteTiffImages    = [];   % si vrai : écrit des TIFF par classe

for i = 1:numel(varargin)
    if ischar(varargin{i}) || isstring(varargin{i})
        key = lower(string(varargin{i}));
        switch key
            case "frames"
                Frames = varargin{i+1};
            case "fraction"
                Fraction = varargin{i+1};
            case "seed"
                Seed = varargin{i+1};
            case "crop"
                Crop = logical(varargin{i+1});
            case "cropcenter"
                CropCenter = varargin{i+1};
            case "cropsize"
                CropSize = varargin{i+1};
            case "undersamplemajority"
                UndersampleMajority = varargin{i+1};
            case "usehdf5"
                UseHDF5 = logical(varargin{i+1});
            case "writetiffimages"
                WriteTiffImages = logical(varargin{i+1});
        end
    end
end

category = classif.category{1};

% ---- Backend par défaut selon trainingParam ----
if isempty(UseHDF5) || isempty(WriteTiffImages)
    backend = 'tiff'; % valeur historique
    if isprop(classif,'trainingParam') && isfield(classif.trainingParam,'CNN_storage_backend')
        backend = lower(string(classif.trainingParam.CNN_storage_backend{end}));
    end

    switch backend
        case "hdf5"
            UseHDF5         = true;
            WriteTiffImages = false;
        case "tiff"
            UseHDF5         = false;
            WriteTiffImages = true;
        otherwise
            warning('Unknown CNN_storage_backend ''%s'' -> defaulting to TIFF.', backend);
            UseHDF5         = false;
            WriteTiffImages = true;
    end
end

% Validation fraction
if isempty(Fraction) || ~isnumeric(Fraction) || ~isscalar(Fraction) || isnan(Fraction)
    Fraction = 1;
end
Fraction = max(0, min(1, Fraction));   % clamp [0,1]

output = 0;

% ---- FS prep ----
if ~isfolder(fullfile(classif.path, foldername, 'images')) && ~UseHDF5
    mkdir(fullfile(classif.path, foldername), 'images');
end

if ~isfolder(fullfile(classif.path, 'TrainingValidation'))
    mkdir(classif.path,'TrainingValidation');
end

if ~UseHDF5 && strcmp(category,'LSTM')
    for i = 1:numel(classif.classes)
        p = fullfile(classif.path, foldername, 'images', classif.classes{i});
        if ~isfolder(p)
            mkdir(fullfile(classif.path, foldername, 'images'), classif.classes{i});
        end
    end
end

if strcmp(category,'LSTM Regression')
    if ~isfolder(fullfile(classif.path, foldername, 'response'))
        mkdir(fullfile(classif.path, foldername), 'response');
    end
end

if ~UseHDF5 && ~isfolder(fullfile(classif.path, foldername, 'timeseries'))
    mkdir(fullfile(classif.path, foldername), 'timeseries');
end

% ---- Préparation HDF5 (framebank CNN) ----
h5Framebank = fullfile(classif.path, foldername, 'framebank.h5');
if UseHDF5 && exist(h5Framebank,"file")
    delete(h5Framebank);
end
h5Initialized = false;
nextFrameIdx  = 1;    % index de la prochaine frame CNN à écrire
seriesStart   = [];
seriesLen     = [];
seriesIds     = strings(0,1);

cltmp = classif.roi;

disp('Starting parallelized jobs for data formatting....')
warning off all

channel = classif.channelName;

% ---- Sélection déterministe d'une fraction de ROIs ----
n_all = numel(rois);
if Fraction == 1
    rois_sel = rois(:).';
elseif Fraction == 0
    disp('Fraction = 0 : aucun ROI ne sera exporté.');
    rois_sel = [];
else
    k = max(1, floor(Fraction * n_all));       % au moins 1
    s = RandStream('mt19937ar','Seed',Seed);   % RNG local
    pick_idx = randsample(s, n_all, k, false);
    rois_sel = rois(pick_idx);
    rois_sel = sort(rois_sel);
end

if isempty(rois_sel)
    warning('Aucun ROI sélectionné pour lexport (fraction = %.3f). Fin.', Fraction);
    warning on all
    return;
end

disp(['These ROIs will be processed (fraction=' num2str(Fraction) ', seed=' num2str(Seed) '): ' num2str(rois_sel)]);

numClasses            = numel(classif.classes);
majorityClassesGlobal = [];

% =====================================================
%  PRE-PASS GLOBAL POUR UNDERSAMPLING CNN (OPTIONNEL)
%  - On ne le fait que si UndersampleMajority < 1
%    ET qu'on génère un dataset CNN (TIFF ou HDF5).
%  - Ne touche PAS aux timeseries LSTM.
% =====================================================
if UndersampleMajority < 1 && (UseHDF5 || WriteTiffImages) && strcmp(category,'LSTM')
    globalCounts = zeros(numClasses,1);

    for k = 1:numel(rois_sel)
        ridx = rois_sel(k);

        % on ne charge que les métadonnées si possible
        roiSeries = cltmp(ridx).data;

        if isempty(roiSeries(1).data)
            fprintf(['Loading ' cltmp(ridx).id ' dataseries....\n']);
            cltmp(ridx).load('data');
            roiSeries = cltmp(ridx).data;
        end
      
        if isempty(roiSeries(1).data)
            fprintf('Dataseries is empty; skipping....\n');
            continue;
        end

        % Filtre par groupid
        mask = arrayfun(@(s) strcmp(s.groupid, classif.strid), roiSeries);
        roiSeriesSel = roiSeries(mask);
        if isempty(roiSeriesSel)
            continue;
        end

        % Bounds depuis userData
        bounds = [];
        ud = [];
        try
            ud = roiSeriesSel(1).userData;
        catch
            ud = [];
        end
        if isstruct(ud) && isfield(ud,'bounds')
            bounds = ud.bounds;
        elseif isa(ud,'containers.Map') && isKey(ud,'bounds')
            bounds = ud('bounds');
        end
        if ~isempty(bounds)
            if numel(bounds)==1 || bounds(1)==0
                bounds = [];
            end
        end

        % Labels bruts
        rawLabels = roiSeriesSel.getData('labels_training');
        if isempty(rawLabels)
            continue;
        end
        rawLabels = rawLabels(:);

        % Conversion labels -> indices [0..numClasses]
        if isnumeric(rawLabels)
            labelIdx = rawLabels(:);
        else
            catList = string(classif.classes(:));
            labStr  = string(rawLabels(:));
            [isIn, idxMap] = ismember(labStr, catList);
            labelIdx = zeros(size(idxMap));
            labelIdx(isIn) = idxMap(isIn);
        end

        nLab = numel(labelIdx);

        % Frames candidates pour ce ROI
        if isempty(Frames)
            fraLoc = 1:nLab;
        else
            fraLoc = Frames(:).';
        end

        % Application des bounds
        if ~isempty(bounds)
            minet = max(bounds(1), fraLoc(1));
            maxet = bounds(2);
            if maxet==0, maxet = max(fraLoc); else, maxet = min(maxet, max(fraLoc)); end
            fraLoc = minet:maxet;
        end

        fraLoc = fraLoc(fraLoc >= 1 & fraLoc <= nLab);
        if isempty(fraLoc)
            continue;
        end

        dataidfraPre = labelIdx(fraLoc);
        validMask    = (dataidfraPre > 0);

        for c = 1:numClasses
            globalCounts(c) = globalCounts(c) + nnz(validMask & dataidfraPre == c);
        end
    end

    validClassMask = (globalCounts > 0);
    if any(validClassMask)
        maxCount = max(globalCounts(validClassMask));
        majorityClassesGlobal = find(globalCounts == maxCount);
    else
        majorityClassesGlobal = [];
    end

    fprintf('Global class counts (CNN):\n');
    for c = 1:numClasses
        fprintf('  %s : %d frames\n', classif.classes{c}, globalCounts(c));
    end
    if ~isempty(majorityClassesGlobal)
        fprintf('Global majority class(es) for CNN undersampling: %s\n', ...
            strjoin(classif.classes(majorityClassesGlobal), ', '));
    else
        fprintf('No labeled frames found globally for CNN.\n');
    end
end

% ==========================
%     BOUCLE PRINCIPALE
% ==========================
for i = 1:numel(rois_sel)
    emptyFrame = [];
    lab        = [];
    ridx       = rois_sel(i);

    disp(['Launching ROI :' num2str(ridx) ' processing...'])

    % Charger les images + data si nécessaire
    if numel(cltmp(ridx).image)==0 || numel(cltmp(ridx).data)==0
        cltmp(ridx).load;
    end

    if numel(cltmp(ridx).image) == 0
        disp(['ROI# ' num2str(ridx) ' / ' num2str(numel(rois_sel))  ...
              ' ID: ' cltmp(ridx).id ' is not available; skipping...']);
        continue;
    end

    % Channel index
    pix = cltmp(ridx).findChannelID(channel);
    if iscell(pix); pix = cell2mat(pix); end

    im        = cltmp(ridx).image(:,:,pix,:);
    roiSeries = cltmp(ridx).data;

    if isempty(roiSeries)
        disp('No training data available for this position');
        continue
    end

    % Filtre par groupid
    mask = arrayfun(@(s) strcmp(s.groupid, classif.strid), roiSeries);
    roiSeriesSel = roiSeries(mask);

    if isempty(roiSeriesSel)
        disp('No training data for this classifier group in this ROI');
        continue
    end

    % --- Bounds depuis userData ---
    bounds = [];
    ud = [];
    try
        ud = roiSeriesSel(1).userData;
    catch
        ud = [];
    end
    if isstruct(ud) && isfield(ud,'bounds')
        bounds = ud.bounds;
    elseif isa(ud,'containers.Map') && isKey(ud,'bounds')
        bounds = ud('bounds');
    end
    if ~isempty(bounds)
        if numel(bounds)==1 || bounds(1)==0
            bounds = [];
        end
    end

    % --- Frames pour cette ROI ---
    if isempty(Frames)
        fra = 1:size(im,4);
    else
        fra = Frames(:).';
    end
    if ~isempty(bounds)
        minet = max(bounds(1), fra(1));
        maxet = bounds(2);
        if maxet==0, maxet = max(fra); else, maxet = min(maxet, max(fra)); end
        fra = minet:maxet;
    end

    % --- Labels bruts ---
    rawLabels = roiSeriesSel.getData('labels_training');
    if isempty(rawLabels)
        disp('No ''labels_training'' data for this ROI/group; skipping...');
        continue
    end
    rawLabels = rawLabels(:);

    % --- Conversion labels -> indices [0..numClasses] ---
    if isnumeric(rawLabels)
        labelIdx = rawLabels(:);
    else
        catList = string(classif.classes(:));
        labStr  = string(rawLabels(:));
        [isIn, idxMap] = ismember(labStr, catList);
        labelIdx = zeros(size(idxMap));
        labelIdx(isIn) = idxMap(isIn);
    end

    % --- Sécuriser fra ---
    nLab = numel(labelIdx);
    fra  = fra(fra >= 1 & fra <= nLab);
    if isempty(fra)
        disp('No frames to process after intersecting with available labels; skipping ROI.');
        continue
    end

    dataid    = labelIdx;
    dataidfra = labelIdx(fra);

    % ---- Masque pour undersampling CNN (par frame) ----
    % Par défaut : on garde tout pour le CNN
    keepIdxCNN = true(size(dataidfra));

    if UndersampleMajority < 1 && (UseHDF5 || WriteTiffImages) ...
            && strcmp(category,'LSTM') && ~isempty(majorityClassesGlobal)

        fracKeep = UndersampleMajority;

        fprintf('CNN undersampling (%.2f) for ROI %s ; majority classes: %s\n', ...
            fracKeep, cltmp(ridx).id, ...
            strjoin(classif.classes(majorityClassesGlobal), ', '));

        for c = majorityClassesGlobal(:)'
            frames_c = find(dataidfra == c);
            if numel(frames_c) > 1
                nKeep = max(1, round(fracKeep * numel(frames_c)));

                % RNG locale pour reproductibilité
                s_local = RandStream('mt19937ar', 'Seed', Seed + ridx + 1000*c);
                frames_keep = randsample(s_local, frames_c, nKeep, false);

                drop_mask = true(size(dataidfra));
                drop_mask(frames_keep) = false;

                keepIdxCNN(drop_mask & dataidfra == c) = false;
            end
        end
        % NB : on ne met PAS de garde-fou ici : une classe peut être
        % absente du dataset CNN pour ce ROI, mais elle reste présente
        % dans la timeseries LSTM (deep/vid/lab).
    end

    % =======================
    %  LSTM Classification
    % =======================
    if strcmp(category,'LSTM')
        pixb = numel(dataidfra);
        pixa = find(dataidfra==0);

        if numel(pixa)>0 || (numel(pixa)==0 && pixb==0)
            if strcmp(classif.trainingParam.classifier_output{end},'sequence-to-sequence')
                disp('Error: some images are not labeled in this ROI - LSTM requires all images to be labeled in the timeseries!');
            else
                disp('Error: no images are labeled : sequence-to-one LSTM requires some images to be labeled in the timeseries!');
            end
            continue
        end

        lab = categorical(dataidfra, 1:numClasses, classif.classes);

        reverseStr = '';
        cc = 1;

        % Taille cible CNN (GoogLeNet, ResNet, ...)
        targetH = 224;
        targetW = 224;

        % frame de référence pour dimensionner vid
        imtest = cltmp(ridx).preProcessROIData(pix, 1, 1);
        if isempty(imtest)
            disp('Pre-processing failed, likely because the image is void !');
            continue;
        end
        
        % if size(imtest,3)==1, imtest = repmat(imtest,[1 1 3]); end
        % 
        % if Crop
        %     imtest = localCrop(imtest, CropCenter, CropSize);
        % end

        H0 = targetH;
        W0 = targetW;

        % vid = timeseries complète pour LSTM (toutes les frames de fra)
        vid = uint8(zeros(H0, W0, 3, numel(fra)));

        % Pour le HDF5 CNN : on écrit en streaming frame par frame,
        % donc pas besoin de bufferiser toutes les frames CNN.

        firstIdxROI_CNN = [];  % pour seriesStart/seriesLen
        nFramesROI_CNN  = 0;

        for kf = 1:numel(fra)
            j = fra(kf);
            tmp = cltmp(ridx).preProcessROIData(pix, j, 1);
            if isempty(tmp)
                disp('Pre-processing failed, likely because the image is void !');
                emptyFrame = 1;
                break;
            end
            if size(tmp,3)==1, tmp = repmat(tmp,[1 1 3]); end

            % Crop éventuel
            if Crop
                tmp = localCrop(tmp, CropCenter, CropSize);
            end

            % Resize vers taille CNN
            if size(tmp,1) ~= H0 || size(tmp,2) ~= W0
                tmp = imresize(tmp, [H0 W0]);
            end

            % Stockage pour LSTM (timeseries complète)
            vid(:,:,:,kf) = uint8(256 * tmp);

            % Label de la frame pour CNN
            if classif.output==0
                cmp = dataid(j);  % sequence-to-sequence
            else
                cmp = dataid;     % sequence-to-one (code historique)
            end

            % Export TIFF pour CNN (undersamplé via keepIdxCNN)
            if  ~UseHDF5 && WriteTiffImages && keepIdxCNN(kf) && cmp ~= 0
                tr = num2str(j);
                while numel(tr)<4, tr = ['0' tr]; end

                imwrite(tmp, fullfile(classif.path, foldername, 'images', ...
                    classif.classes{cmp}, ...
                    [cltmp(ridx).id '_frame_' tr '.tif']));

                output = output + 1;
            end

            % Export HDF5 framebank pour CNN (undersamplé via keepIdxCNN)
            if UseHDF5 && keepIdxCNN(kf) && cmp ~= 0
                if ~h5Initialized
                    % Création des datasets extensibles
                    h5create(h5Framebank, '/frames', [H0 W0 3 Inf], ...
                        Datatype="uint8", ...
                        ChunkSize=[H0 W0 3 1], ...
                        Deflate=1);

                    h5create(h5Framebank, '/labels', [1 Inf], ...
                        Datatype="int32", ...
                        ChunkSize=[1 max(128,1)], ...
                        Deflate=1);

                    classNames = string(classif.classes(:))';
                    h5create(h5Framebank, '/classNames', size(classNames), Datatype="string");
                    h5write(h5Framebank, '/classNames', classNames);

                    h5Initialized = true;
                else
                    info = h5info(h5Framebank, '/frames');
                    sz = info.Dataspace.Size;
                    if sz(1)~=H0 || sz(2)~=W0
                        error('HDF5 framebank size mismatch: expected [%d %d], found [%d %d].', ...
                            H0, W0, sz(1), sz(2));
                    end
                end

                % Écriture d'une seule frame CNN
                h5write(h5Framebank, '/frames', uint8(256 * tmp), ...
                    [1 1 1 nextFrameIdx], [H0 W0 3 1]);

                labVal = int32(cmp);
                h5write(h5Framebank, '/labels', labVal, ...
                    [1 nextFrameIdx], [1 1]);

                if isempty(firstIdxROI_CNN)
                    firstIdxROI_CNN = nextFrameIdx;
                end
                nextFrameIdx   = nextFrameIdx + 1;
                nFramesROI_CNN = nFramesROI_CNN + 1;

                output = output + 1;
            end

            msg = sprintf('Processing frame: %d / %d for ROI %s', ...
                kf, numel(fra), cltmp(ridx).id);
            fprintf([reverseStr, msg]);
            reverseStr = repmat(sprintf('\b'), 1, length(msg));
            cc = cc + 1;
        end

        % Métadonnées de séries CNN (optionnel)
        if UseHDF5 && nFramesROI_CNN > 0 && ~isempty(firstIdxROI_CNN)
            seriesStart(end+1,1) = firstIdxROI_CNN; %#ok<AGROW>
            seriesLen(end+1,1)   = nFramesROI_CNN;  %#ok<AGROW>
            seriesIds(end+1,1)   = string(cltmp(ridx).id); %#ok<AGROW>
        end
    end

    % =======================
    %  LSTM Regression
    % =======================
    if strcmp(category,'LSTM Regression')
        imtest = cltmp(ridx).preProcessROIData(pix, fra(1), 1);
        if isempty(imtest)
            disp('Pre-processing failed, likely because the image is void !');
            continue;
        end
        if size(imtest,3)==1, imtest = repmat(imtest,[1 1 3]); end
        if Crop
            imtest = localCrop(imtest, CropCenter, CropSize);
        end
        [H0,W0,~] = size(imtest);
        vid = uint8(zeros(H0, W0, 3, numel(fra)));

        cc = 1;
        for kf = 1:numel(fra)
            j = fra(kf);
            tmp = cltmp(ridx).preProcessROIData(pix, j, 1);
            if isempty(tmp)
                disp('Pre-processing failed, likely because the image is void !');
                emptyFrame = 1;
                break;
            end
            if size(tmp,3)==1, tmp = repmat(tmp,[1 1 3]); end
            if Crop
                tmp = localCrop(tmp, CropCenter, CropSize);
            else
                if size(tmp,1)~=H0 || size(tmp,2)~=W0
                    tmp = imresize(tmp, [H0 W0]);
                end
            end

            vid(:,:,:,cc) = uint8(256 * tmp);
            cc = cc + 1;
        end

        parsaveim(fullfile(classif.path, foldername, 'images', [cltmp(ridx).id '.mat']), imtest);
        parsaveresp(fullfile(classif.path, foldername, 'response', [cltmp(ridx).id '.mat']), dataidfra);

        output = output + 1;
    end

    fprintf('\n');

    % --------- Sauvegarde timeseries LSTM (pas undersamplée) ---------
    deep = dataidfra ; % étiquette par frame, dans l'ordre temporel

    if isempty(emptyFrame)
        if ~UseHDF5
        parsave(fullfile(classif.path, foldername, 'timeseries', ...
            ['lstm_labeled_' cltmp(ridx).id '.mat']), deep, vid, lab);
        end
       % cltmp(ridx).save;
    else
        disp('This ROI was not saved because it has empty frames');
    end

    disp(['Processing ROI: ' num2str(ridx) ' ... Done !'])
end

% Finalisation du framebank HDF5 (métadonnées CNN séries)
if UseHDF5 && h5Initialized
    nbSeries = numel(seriesStart);

    h5create(h5Framebank, '/series_start', [1 nbSeries], Datatype="int64");
    h5write(h5Framebank, '/series_start', int64(seriesStart(:))');

    h5create(h5Framebank, '/series_len',   [1 nbSeries], Datatype="int64");
    h5write(h5Framebank, '/series_len', int64(seriesLen(:))');

    if ~isempty(seriesIds)
        seriesIds = seriesIds(:)';  % row vector
        h5create(h5Framebank, '/series_roi_id', size(seriesIds), Datatype="string");
        h5write(h5Framebank, '/series_roi_id', seriesIds);
    end
end

warning on all;

% Clear uniquement les ROIs traités
for i = 1:numel(rois_sel)
    cltmp(rois_sel(i)).clear;
end

% ---- Local helpers ----
function parsaveim(fname, im)
eval(['save  ''''  '  fname  ''''  '  im']);

function parsaveresp(fname, response)
eval(['save  ' '''' fname  ''''  '  response']);

function parsave(fname, deep, vid, lab)
eval(['save  ' ''''  fname  ''''  '  deep vid lab']);

% ------------ Center crop avec padding -------------
function out = localCrop(in, center, cropSz)
% in: double [0..1], HxWxC
cx = round(center(1)); cy = round(center(2));
cw = round(cropSz(1)); ch = round(cropSz(2));
[H,W,C] = size(in);
if C==1, in = repmat(in,[1 1 3]); C=3; end

x1 = cx - floor((cw-1)/2);  x2 = x1 + cw - 1;
y1 = cy - floor((ch-1)/2);  y2 = y1 + ch - 1;

padL = max(0, 1 - x1);
padT = max(0, 1 - y1);
padR = max(0, x2 - W);
padB = max(0, y2 - H);

if any([padL padR padT padB] > 0)
    in = padarray(in, [padT padL], 'replicate', 'pre');
    in = padarray(in, [padB padR], 'replicate', 'post');
end

x1p = x1 + padL; x2p = x2 + padL;
y1p = y1 + padT; y2p = y2 + padT + (ch-1);
out = in(y1p:y2p, x1p:x2p, :);
