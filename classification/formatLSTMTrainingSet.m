function output = formatLSTMTrainingSet(foldername, classif, rois, varargin)

% ---- Params optionnels ----
Frames   = [];
Fraction = 1;       % par défaut : tout le trainingset
Seed     = 12345;   % seed fixe par défaut (déterministe)

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
if ~isfolder([classif.path '/' foldername '/images'])
    mkdir([classif.path '/' foldername], 'images');
end

if ~isfolder(fullfile(classif.path, 'TrainingValidation'))
    mkdir(classif.path,'TrainingValidation');
end

if strcmp(classif.category{1},'LSTM')
    for i = 1:numel(classif.classes)
        if ~isfolder([classif.path '/' foldername '/images/' classif.classes{i}])
            mkdir([classif.path '/' foldername '/images'], classif.classes{i});
        end
    end
end

if strcmp(classif.category{1},'LSTM Regression')
    if ~isfolder([classif.path '/' foldername '/response/'])
        mkdir([classif.path '/' foldername], 'response');
    end
end

if ~isfolder([classif.path '/' foldername '/timeseries'])
    mkdir([classif.path '/' foldername], 'timeseries');
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
    % On échantillonne des indices dans 1:n_all
    pick_idx = randsample(s, n_all, k, false);
    rois_sel = rois(pick_idx);
    % (option) ordonner pour logs lisibles/reproductibles
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

% --- Bounds (sélection de frames par ROI) depuis userData, si présent ---
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

% --- Définition de fra (frames) : Frames optionnel puis intersection avec bounds ---
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

% Bornage de fra à la disponibilité réelle des labels (on fera après getData)

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
    labelIdx = rawLabels(:);   % on suppose déjà des indices ou 0
else
    % transformer en string puis mapper sur classif.classes
    catList = string(classif.classes(:));
    labStr  = string(rawLabels(:));
    [isIn, idxMap] = ismember(labStr, catList);
    labelIdx = zeros(size(idxMap));
    labelIdx(isIn) = idxMap(isIn);
end

% --- Sécuriser fra en fonction de la longueur des labels ---
nLab = numel(labelIdx);
fra = fra(fra >= 1 & fra <= nLab);
if isempty(fra)
    disp('No frames to process after intersecting with available labels; skipping ROI.');
    continue
end

dataid=labelIdx;
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

    if strcmp(classif.category{1},'LSTM') % image lstm classification
        reverseStr = '';
        cc = 1;

        imtest = cltmp(ridx).preProcessROIData(pix, 1, 1); % dorepmat=1 pour garantir 3 canaux
if isempty(imtest)
    disp('Pre-processing failed, likely because the image is void !');
    continue;
end

[H0, W0, C0] = size(imtest);
if C0 ~= 3
    % Par sécurité, mais preProcessROIData(dorepmat=1) renvoie déjà 3 canaux
    if C0 == 1, imtest = repmat(imtest, [1 1 3]); C0 = 3; end
end

vid = uint8(zeros(H0, W0, 3, 1));   % allocation sur la taille de référence



        for j = fra
             tmp = cltmp(ridx).preProcessROIData(pix, j, 1); % dorepmat=1 => 3 canaux
    if isempty(tmp)
        disp('Pre-processing failed, likely because the image is void !');
        emptyFrame = 1;
        break;
    end

    % --- Resize si nécessaire vers [H0 W0] ---
    if size(tmp,1) ~= H0 || size(tmp,2) ~= W0
        tmp = imresize(tmp, [H0 W0]);  % garde 3 canaux, double [0,1]
    end

    vid(:,:,:,cc) = uint8(256 * tmp);


            tr = num2str(j);
            while numel(tr)<4, tr = ['0' tr]; end

            if classif.output==0
                cmp = dataid(j); % sequence-to-sequence classif
            else
                cmp = dataid;    % sequence-to-one classif
            end

            if cmp~=0
                imwrite(tmp, [classif.path '/' foldername '/images/' classif.classes{cmp} '/' cltmp(ridx).id '_frame_' tr '.tif']);
                output = output + 1;
            end

            msg = sprintf('Processing frame: %d / %d for ROI %s', cc, numel(fra), cltmp(ridx).id);
            fprintf([reverseStr, msg]);
            reverseStr = repmat(sprintf('\b'), 1, length(msg));
            cc = cc + 1;
        end
    end

    if strcmp(classif.category{1},'LSTM Regression')
       cc = 1;
for j = fra
    tmp = cltmp(ridx).preProcessROIData(pix, j, 1);
    if isempty(tmp)
        disp('Pre-processing failed, likely because the image is void !');
        emptyFrame = 1;
        break;
    end

    if size(tmp,1) ~= H0 || size(tmp,2) ~= W0
        tmp = imresize(tmp, [H0 W0]);
    end

    vid(:,:,:,cc) = uint8(256 * tmp);
    cc = cc + 1;
end

        parsaveim([classif.path '/' foldername '/images/' cltmp(ridx).id '.mat'], tmp);
        parsaveresp([classif.path '/' foldername '/response/' cltmp(ridx).id '.mat'], dataidfra);
        output = output + 1;
    end

    fprintf('\n');

    deep = dataidfra;

    if isempty(emptyFrame)
        parsave([classif.path '/' foldername '/timeseries/lstm_labeled_' cltmp(ridx).id '.mat'], deep, vid, lab);
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
