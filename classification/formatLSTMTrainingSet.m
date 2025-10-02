function output = formatLSTMTrainingSet(foldername, classif, rois, varargin)

% ---- Params optionnels ----
Frames     = [];
Fraction   = 1;       % par défaut : tout le trainingset
Seed       = 12345;   % seed fixe par défaut (déterministe)
Crop       = false;   % <-- NEW: activer/désactiver le crop
CropCenter = [88 194];% <-- NEW: [cx cy]
CropSize   = [60 60]; % <-- NEW: [w h]

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
        end
    end
end

% Validation fraction
if isempty(Fraction) || ~isnumeric(Fraction) || ~isscalar(Fraction) || isnan(Fraction)
    Fraction = 1;
end
Fraction = max(0, min(1, Fraction));   % clamp dans [0,1]

output = 0;

% ---- FS prep ----
if ~isfolder(fullfile(classif.path, foldername, 'images'))
    mkdir(fullfile(classif.path, foldername), 'images');
end

if ~isfolder(fullfile(classif.path, 'TrainingValidation'))
    mkdir(classif.path,'TrainingValidation');
end

if strcmp(classif.category{1},'LSTM')
    for i = 1:numel(classif.classes)
        if ~isfolder(fullfile(classif.path, foldername, 'images', classif.classes{i}))
            mkdir(fullfile(classif.path, foldername, 'images'), classif.classes{i});
        end
    end
end

if strcmp(classif.category{1},'LSTM Regression')
    if ~isfolder(fullfile(classif.path, foldername, 'response'))
        mkdir(fullfile(classif.path, foldername), 'response');
    end
end

if ~isfolder(fullfile(classif.path, foldername, 'timeseries'))
    mkdir(fullfile(classif.path, foldername), 'timeseries');
end


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
    k = max(1, floor(Fraction * n_all));       % au moins 1 si Fraction > 0
    s = RandStream('mt19937ar','Seed',Seed);   % RNG local (n'affecte pas global)
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

for i = 1:numel(rois_sel)
    emptyFrame = [];
    ridx = rois_sel(i);
    disp(['Launching ROI :' num2str(ridx) ' processing...'])

    if numel(cltmp(ridx).image)==0 || numel(cltmp(ridx).data)==0
        cltmp(ridx).load; % load image sequence
    end

    if numel(cltmp(ridx).image) == 0
        disp(['ROI# ' num2str(ridx) ' / ' num2str(numel(rois_sel))  ' ID: ' cltmp(ridx).id ' is not available; skipping...']);
        continue;
    end

    % normalize intensity levels
    pix = cltmp(ridx).findChannelID(channel);
    if iscell(pix); pix = cell2mat(pix); end

    im   = cltmp(ridx).image(:,:,pix,:);
    roiSeries = cltmp(ridx).data;   % <== ne PAS réutiliser le nom "data" plus loin

    if isempty(roiSeries)
        disp('No training data available for this position');
        continue
    end

    % Filtre par groupid (classif.strid)
    mask = arrayfun(@(s) strcmp(s.groupid, classif.strid), roiSeries);
    roiSeriesSel = roiSeries(mask);

    if isempty(roiSeriesSel)
        disp('No training data for this classifier group in this ROI');
        continue
    end

    % --- Bounds depuis userData, si présent ---
    bounds = [];
    ud = [];
    try
        ud = roiSeriesSel(1).userData;
    catch
        ud = [];
    end
    if isstruct(ud) && isfield(ud, 'bounds')
        bounds = ud.bounds;
    elseif isa(ud, 'containers.Map') && isKey(ud, 'bounds')
        bounds = ud('bounds');
    end
    if ~isempty(bounds)
        if numel(bounds)==1 || bounds(1)==0
            bounds = [];
        end
    end

    % --- Définition de fra (frames) ---
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

    % --- Récupération des labels bruts ---
    rawLabels = roiSeriesSel.getData('labels_training');   % peut être cellstr/string/num
    if isempty(rawLabels)
        disp('No ''labels_training'' data for this ROI/group; skipping...');
        continue
    end
    rawLabels = rawLabels(:);   % vecteur colonne

    % --- Conversion labels -> indices [0..numel(classif.classes)] ---
    % 0 = non étiqueté
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
    fra = fra(fra >= 1 & fra <= nLab);
    if isempty(fra)
        disp('No frames to process after intersecting with available labels; skipping ROI.');
        continue
    end

    dataid    = labelIdx;
    dataidfra = labelIdx(fra);

    if strcmp(classif.category{1},'LSTM')
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

        lab = categorical(dataidfra, 1:numel(classif.classes), classif.classes);
    else
        lab = [];
    end

    % =======================
    %  LSTM Classification
    % =======================
    if strcmp(classif.category{1},'LSTM')
        reverseStr = '';
        cc = 1;

        % ---- frame de référence
        imtest = cltmp(ridx).preProcessROIData(pix, 1, 1); % dorepmat=1 => 3 canaux
        if isempty(imtest)
            disp('Pre-processing failed, likely because the image is void !');
            continue;
        end
        if size(imtest,3)==1, imtest = repmat(imtest,[1 1 3]); end

        if Crop
            imtest = localCrop(imtest, CropCenter, CropSize); % <-- NEW
        end

        [H0, W0, ~] = size(imtest);
        vid = uint8(zeros(H0, W0, 3, numel(fra)));

        for j = fra
            tmp = cltmp(ridx).preProcessROIData(pix, j, 1); % 3 canaux [0,1]
            if isempty(tmp)
                disp('Pre-processing failed, likely because the image is void !');
                emptyFrame = 1;
                break;
            end
            if size(tmp,3)==1, tmp = repmat(tmp,[1 1 3]); end

            % --- Crop optionnel (sortie = taille fixe)
            if Crop
                tmp = localCrop(tmp, CropCenter, CropSize); % <-- NEW
            else
                % harmonise taille si différence
                if size(tmp,1)~=H0 || size(tmp,2)~=W0
                    tmp = imresize(tmp, [H0 W0]);
                end
            end

            vid(:,:,:,cc) = uint8(256 * tmp);

            % Ecriture image par classe si applicable
            tr = num2str(j);
            while numel(tr)<4, tr = ['0' tr]; end

            if classif.output==0
                cmp = dataid(j); % sequence-to-sequence
            else
                cmp = dataid;    % sequence-to-one
            end

            if cmp~=0
                imwrite(tmp, fullfile(classif.path, foldername, 'images', classif.classes{cmp}, ...
    [cltmp(ridx).id '_frame_' tr '.tif']));

                output = output + 1;
            end

            msg = sprintf('Processing frame: %d / %d for ROI %s', cc, numel(fra), cltmp(ridx).id);
            fprintf([reverseStr, msg]);
            reverseStr = repmat(sprintf('\b'), 1, length(msg));
            cc = cc + 1;
        end
    end

    % =======================
    %  LSTM Regression
    % =======================
    if strcmp(classif.category{1},'LSTM Regression')
        % frame de référence pour allocation
        imtest = cltmp(ridx).preProcessROIData(pix, fra(1), 1);
        if isempty(imtest)
            disp('Pre-processing failed, likely because the image is void !');
            continue;
        end
        if size(imtest,3)==1, imtest = repmat(imtest,[1 1 3]); end
        if Crop
            imtest = localCrop(imtest, CropCenter, CropSize); % <-- NEW
        end
        [H0, W0, ~] = size(imtest);
        vid = uint8(zeros(H0, W0, 3, numel(fra)));

        cc = 1;
        for j = fra
            tmp = cltmp(ridx).preProcessROIData(pix, j, 1);
            if isempty(tmp)
                disp('Pre-processing failed, likely because the image is void !');
                emptyFrame = 1;
                break;
            end
            if size(tmp,3)==1, tmp = repmat(tmp,[1 1 3]); end
            if Crop
                tmp = localCrop(tmp, CropCenter, CropSize); % <-- NEW
            else
                if size(tmp,1)~=H0 || size(tmp,2)~=W0
                    tmp = imresize(tmp, [H0 W0]);
                end
            end

            vid(:,:,:,cc) = uint8(256 * tmp);
            cc = cc + 1;
        end

        % sauvegardes
parsaveim(fullfile(classif.path, foldername, 'images', [cltmp(ridx).id '.mat']), imtest);

parsaveresp(fullfile(classif.path, foldername, 'response', [cltmp(ridx).id '.mat']), dataidfra);

        output = output + 1;
    end

    fprintf('\n');

    deep = dataidfra;

    if isempty(emptyFrame)
        parsave(fullfile(classif.path, foldername, 'timeseries', ...
    ['lstm_labeled_' cltmp(ridx).id '.mat']), deep, vid, lab);
        cltmp(ridx).save;
    else
        disp('This ROI was not saved because it has empty frames');
    end

    disp(['Processing ROI: ' num2str(ridx) ' ... Done !'])
end

warning on all;

% Clear uniquement les ROIs traités
for i = 1:numel(rois_sel)
    cltmp(rois_sel(i)).clear; %%% remove !!!!
end

% ---- Local helpers ----
function parsaveim(fname, im)
eval(['save  ''''  '  fname  ''''  '  im']);

function parsaveresp(fname, response)
eval(['save  ' '''' fname  ''''  '  response']);

function parsave(fname, deep, vid, lab)
eval(['save  ' ''''  fname  ''''  '  deep vid lab']);

% ------------ NEW: robust center crop with padding -------------
function out = localCrop(in, center, cropSz)
% in: double [0..1], HxWxC (C=3)
% center = [cx cy], cropSz = [w h]
cx = round(center(1)); cy = round(center(2));
cw = round(cropSz(1)); ch = round(cropSz(2));
[H,W,C] = size(in);
if C==1, in = repmat(in,[1 1 3]); C=3; end

% bornes désirées
x1 = cx - floor((cw-1)/2);  x2 = x1 + cw - 1;
y1 = cy - floor((ch-1)/2);  y2 = y1 + ch - 1;

% padding nécessaire
padL = max(0, 1 - x1);
padT = max(0, 1 - y1);
padR = max(0, x2 - W);
padB = max(0, y2 - H);

if any([padL padR padT padB] > 0)
    in = padarray(in, [padT padL], 'replicate', 'pre');
    in = padarray(in, [padB padR], 'replicate', 'post');
end

% coordonnées après padding
x1p = x1 + padL; x2p = x2 + padL;
y1p = y1 + padT; y2p = y2 + padT;

out = in(y1p:y2p, x1p:x2p, :);
