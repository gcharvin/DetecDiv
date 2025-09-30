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
    warning('Aucun ROI sélectionné pour l'export (fraction = %.3f). Fin.', Fraction);
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
    data = cltmp(ridx).data;

    if numel(data)==0
        disp('No training data available for this position');
        continue
    end

    pixdata = arrayfun(@(x) strcmp(x.groupid,classif.strid), data);
    data    = data(pixdata);
    bounds  = [];

    if isfield(data.userData,'bounds')
        bounds = data.userData.bounds;
        if numel(bounds) && bounds(1)==0; bounds = []; end
        if numel(bounds)==1; bounds = []; end
    end

    if isempty(Frames)
        fra = 1:size(im,4);
    else
        fra = Frames;
    end

    if numel(bounds) % restricting frames used on a per-ROI basis
        minet = bounds(1); maxet = bounds(2);
        minet = max(minet, fra(1));
        if maxet==0
            maxet = max(maxet, fra(end));
        else
            maxet = min(maxet, fra(end));
        end
        fra = minet:maxet;
    end

    if isempty(classif.trainingset)
        param.nframes = 1;
    else
        param.nframes = classif.trainingset;
    end

    param  = [];
    imtest = cltmp(ridx).preProcessROIData(pix,1,param); % determine image size

    if isempty(imtest)
        disp('Pre-processing failed, likely because the image is void !');
        continue;
    end

    vid = uint8(zeros(size(imtest,1), size(imtest,2), 3, 1));

    % ----- Labels (labels_training -> indices 1..numel(classes)) -----
    dataid  = data.getData('labels_training');
    catList = string(classif.classes(:));     % Mx1
    catStr  = string(dataid(:));              % Nx1
    [isInList, idx] = ismember(catStr, catList);
    idx(~isInList) = 0;
    dataid  = idx(:);
    dataidfra = dataid(fra);

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

        for j = fra
            tmp = cltmp(ridx).preProcessROIData(pix,j,param);

            if isempty(tmp)
                disp('Pre-processing failed, likely because the image is void !');
                emptyFrame = 1;
                break;
            end

            vid(:,:,:,cc) = uint8(256*tmp);

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
        tmp = zeros(size(im,1), size(im,2), 3, 1);
        cc  = 1;
        for j = fra
            tmp = cltmp(ridx).preProcessROIData(pix,j,param);
            vid(:,:,:,cc) = uint8(256*tmp);
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
