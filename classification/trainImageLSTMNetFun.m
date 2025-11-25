function trainImageLSTMNetFun(classif,setparam)

path=fullfile(classif.path);
name=classif.strid;

%---------------- parameters setting
if nargin==2 % basic parameter initialization

    tip={'Check box to train CNN',...
        'Check box to compute CNN activations',...
        'Check box to train the LSTM network',...
        'Check box to asssemble the CNN and LSTM networks',...
        'Specify if each frame should be classified, or if one class is expected for the whole sequence of images',...
        'Choose the training method',...
        'Choose the CNN',...
        'Choose the size of the mini batch; Higher values require more memory and are prone to errors',...
        'Enter the number of epochs',...
        'Enter the initial learning rate',...
        'Enter the learning rate drop factor',...
        'Choose whether and how training and validation data should be shuffled during training',...
        'Enter fraction of the data to be used for training vs validation during training',...
        'Enter the magnitude of translation for data augmentation (in pixels)',...
        'Enter the magnitude of rotation for data augmentation (in pixels)',...
        'Specify value for L2 regularization',...
        'Check to use a dropout layer',...
        'Value for dropout regularization',...
        'Choose storage backend for CNN training data (''tiff'' or ''hdf5'')', ...
        'Range of random scale factor for CNN augmentation (e.g. [0.9 1.1])', ...
        'Enable random flips (left/right & up/down) during CNN augmentation', ...
        'Crop-in scale range for CNN augmentation (e.g. [0.8 1.0])', ...
        'Contrast multiplier range for CNN augmentation (e.g. [0.85 1.15])', ...
        'Maximum hue jitter (0–0.5, small values recommended)', ...
        'Std-dev of Gaussian noise for CNN augmentation (set 0 to disable)' ...
        'Choose the fraction of the data to be used for training vs validation during LSTM training',...
        'Enter the size of the hidden unit',...
        'Choose the size of the mini batch for LSTM training; Higher values require more memory and are prone to errors',...
        'Enter the LSTM initial learning rate',...
        'Enter the number of epochs for LSTM training',...
        'Enter the length of the sequences in frames; put 0 if all frames should be used upon training',...
        'Enter the dropping factor in learning rate',...
        'Choose execution environment',...
        'Select initial version of network to start training with; Default: ImageNet',...
        'Minority balancing mode (none/auto)',...
        'Activate balancing if min/max ratio ≤ this value',...
        'Percentile for multi-minority selection (0=off)',...
        '#Negatives per #Positives windows (e.g. 1 = 1:1)',...
        'Positive window stride as a fraction of L',...
        'Negative window stride as a fraction of L',...
        'Keep validation distribution unbalanced (true/false)'};

    classif.trainingParam = struct(...
        'train_CNN_classifier',true,...
        'compute_CNN_activations',true,...
        'train_LSTM_network',true,...
        'assemble_network',true,...
        'classifier_output',{{'sequence-to-sequence','sequence-to-one','sequence-to-sequence'}},...
        'CNN_training_method',{{'adam','sgdm','adam'}},...
        'CNN_network',{{'googlenet','inceptionresnetv2','inceptionv3','resnet50','resnet18','googlenet'}},...
        'CNN_mini_batch_size',8,...
        'CNN_max_epochs',6,...
        'CNN_initial_learning_rate',0.00003,...
        'CNN_learn_rate_drop_factor',0.9,...
        'CNN_data_shuffling',{{'once','every-epoch','never','every-epoch'}},...
        'CNN_data_splitting_factor',0.7,...
        'CNN_translation_augmentation',[-5 5],...
        'CNN_rotation_augmentation',[-20 20],...
        'CNN_l2_regularization',1e-5,...
        'CNN_use_dropout',true,...
        'CNN_dropout',0.5,...
        'CNN_storage_backend',{{'hdf5','tiff','hdf5'}}, ...        % 'tiff' (historique) ou 'hdf5'
        'CNN_rand_scale',[0.9 1.1], ...         % RandScale pour TIFF, approx. crop/zoom
        'CNN_rand_flip',true, ...               % flips aléatoires (TIFF / éventuellement HDF5)
        'CNN_crop_scale',[0.8 1.0], ...         % crop-in pour HDF5 datastore
        'CNN_contrast_range',[0.85 1.15], ...   % contraste mult. pour HDF5
        'CNN_hue_delta',0.05, ...               % jitter de teinte (HDF5)
        'CNN_noise_sigma',0.02, ...             % sigma bruit gaussien (HDF5)
        'LSTM_data_splitting_factor',0.9,...
        'LSTM_hidden_size',150,...
        'LSTM_mini_batch_size',8,...
        'LSTM_initial_learning_rate', 1e-4,...
        'LSTM_max_epochs', 50,...
        'LSTM_sequence_length', 40,...
        'LSTM_learn_rate_drop_factor', 0.9,...
        'execution_environment',{{'auto','parallel','cpu','gpu','multi-gpu','auto'}},...
        'transfer_learning',{{'ImageNet','ImageNet'}},...
        'minority_mode','none',...            % 'none' (par défaut) ou 'auto'
        'minority_min_ratio',0.30,...         % activer si min/max ≤ 0.30
        'minority_percentile',0.00,...        % 0 = off ; sinon ex 0.20
        'pos_neg_ratio',1.0,...               % #negatives per #positives (fenêtres)
        'win_stride_pos_frac',0.10,...        % stridePos = L*0.10
        'win_stride_neg_frac',1.00,...        % strideNeg = L*1.00
        'keep_valid_distrib',true,...
        'tip',{tip});
    return;



else
    trainingParam=classif.trainingParam;

    % ---- Backward compatibility defaults ----
    if ~isfield(trainingParam,'CNN_use_dropout');       trainingParam.CNN_use_dropout = true;  end
    if ~isfield(trainingParam,'CNN_dropout');           trainingParam.CNN_dropout     = 0.5;   end
    if ~isfield(trainingParam,'CNN_l2_regularization'); trainingParam.CNN_l2_regularization = 1e-5; end
    % nouveaux champs (minority/windowing)
    if ~isfield(trainingParam,'minority_mode');         trainingParam.minority_mode       = 'none'; end
    if ~isfield(trainingParam,'minority_min_ratio');    trainingParam.minority_min_ratio  = 0.30;   end
    if ~isfield(trainingParam,'minority_percentile');   trainingParam.minority_percentile = 0.00;   end
    if ~isfield(trainingParam,'pos_neg_ratio');         trainingParam.pos_neg_ratio       = 1.0;    end
    if ~isfield(trainingParam,'win_stride_pos_frac');   trainingParam.win_stride_pos_frac = 0.10;   end
    if ~isfield(trainingParam,'win_stride_neg_frac');   trainingParam.win_stride_neg_frac = 1.00;   end
    if ~isfield(trainingParam,'keep_valid_distrib');    trainingParam.keep_valid_distrib  = true;   end
    if ~isfield(trainingParam,'CNN_storage_backend');   trainingParam.CNN_storage_backend = 'tiff'; end
    if ~isfield(trainingParam,'CNN_translation_augmentation'); trainingParam.CNN_translation_augmentation = [-5 5]; end
    if ~isfield(trainingParam,'CNN_rotation_augmentation');     trainingParam.CNN_rotation_augmentation     = [-20 20]; end
    if ~isfield(trainingParam,'CNN_crop_scale');                trainingParam.CNN_crop_scale                = [0.8 1.0]; end
    if ~isfield(trainingParam,'CNN_contrast_range');            trainingParam.CNN_contrast_range            = [0.85 1.15]; end
    if ~isfield(trainingParam,'CNN_hue_delta');                 trainingParam.CNN_hue_delta                 = 0.05; end
    if ~isfield(trainingParam,'CNN_noise_sigma');               trainingParam.CNN_noise_sigma               = 0.02; end

    % Forcer l'utilisation du backend HDF5 pour l'entraînement CNN

    classif.trainingParam = trainingParam;

    if numel(trainingParam)==0
        disp('Could not find training parameters : first launch train with an extra argument to force parameter assignment');
        return;
    end
end
%-----------------------------------%

blockRNG=1;
fprintf('Loading training options...\n');
fprintf('------\n');

%%% training image classifier
if trainingParam.train_CNN_classifier
    if strcmp(trainingParam.transfer_learning{end},'ImageNet')
      
        trainImageGoogleNetFun(classif); % saves as netCNN.mat in the LSTM dir
    else
        src=fullfile(classif.path,['netCNN_' trainingParam.transfer_learning{end}]);
        if exist(src,"file"); load(src); else; disp(['Unable to load: ' trainingParam.transfer_learning{end}]); return; end
        trainImageGoogleNetFun(classif,'ok',classifier);
    end

    target=fullfile(path,['netCNN_' name '.mat']);
    source=fullfile(path,[name '.mat']);
    if ~exist(source,"file"); disp('Trained CNN does not exist; quitting !'); return; end
    copyfile(source,target);
end

fprintf('Loading Image classifier...\n');
fprintf('------\n');
str=fullfile(path,['netCNN_' name '.mat']);
if exist(str,"file"); load(str); netCNN=classifier;
else; disp('unable to find CNN classifier; first train the CNN classifier; quitting ...!'); return;
end

%%% choose feature layer
inputSize = netCNN.Layers(1).InputSize(1:2);
switch trainingParam.CNN_network{end}
    case 'googlenet', layerName = "pool5-7x7_s1";
    case 'resnet18',  layerName = "pool5";
    case 'resnet50',  layerName = "avg_pool";
    case {'inceptionresnetv2','inceptionv3'}, layerName = "avg_pool";
    otherwise, error("Unsupported backbone: %s", trainingParam.CNN_network{end});
end

tempFile = [path '/' name '_image_classifier_activations.mat'];

% ===================== COMPUTE / LOAD ACTIVATIONS =====================
if trainingParam.compute_CNN_activations==false && exist(tempFile,"file")
    fprintf('Loading Image classifier activation data...\n------\n');
    load(tempFile,"sequences","labels");
else
    fprintf('Computing Image classifier activation data...\n------\n');

    backend = 'tiff';
    if isfield(trainingParam, 'CNN_storage_backend')
        backend = char(lower(string(trainingParam.CNN_storage_backend{end})));
    end

    h5SeriesFile = fullfile(path,'trainingdataset','framebank.h5');
    h5Exists = exist(h5SeriesFile,"file")==2;
    useH5Series = strcmp(backend,'hdf5') && h5Exists;
    if h5Exists && ~useH5Series
        fprintf('HDF5 framebank detected but backend ''%s'' configured -> sticking to legacy MAT/TIFF workflow.\n', backend);
    end
    h5SeriesStart = [];
    h5SeriesLen   = [];
    h5SeriesIds   = strings(0,1);
    frameSizeH5   = [];
    h5FrameDS     = [];




    if useH5Series
        try
            h5SeriesStart = double(h5read(h5SeriesFile, '/series_start'));
            h5SeriesLen   = double(h5read(h5SeriesFile, '/series_len'));
            try
                h5SeriesIds = string(h5read(h5SeriesFile, '/series_roi_id'));
            catch
                h5SeriesIds = strings(numel(h5SeriesStart),1);
            end
            infoFrames = h5info(h5SeriesFile, '/frames');
            frameSizeH5 = infoFrames.Dataspace.Size;
            h5FrameDS = [];
            % Datastore HDF5 avec les mêmes augmentations que pour l'entraînement CNN
            % augParams = localGetH5AugParams(trainingParam);
            % h5FrameDS = H5ImageDatastore(h5SeriesFile, ...
            %     'MiniBatchSize', max(1, trainingParam.CNN_mini_batch_size), ...
            %     'TransRange',    augParams.TransRange, ...
            %     'RotRange',      augParams.RotRange, ...
            %     'CropScale',     augParams.CropScale, ...
            %     'ContrastRange', augParams.ContrastRange, ...
            %     'HueDelta',      augParams.HueDelta, ...
            %     'NoiseSigma',    augParams.NoiseSigma, ...
            %     'ClassNames',    classif.classes);
        catch ME
            warning('Failed to read HDF5 framebank metadata (%s). Falling back to MAT files.', ME.message);
            useH5Series = false;
        end
    end

    if useH5Series
        numFiles = numel(h5SeriesStart);
        fprintf('Using HDF5 framebank (%d series).\n', numFiles);
    elseif strcmp(backend,'hdf5')
        warning('HDF5 backend requested but framebank.h5 not found; falling back to MAT/TIFF export.');
        fprintf('HDF5 backend configured but no framebank available -> using legacy MAT/TIFF sequence files.\n');
        fol= [path '/trainingdataset/timeseries'];
        list=dir([fol '/*.mat']);
        numFiles = numel(list);
    else
        fol= [path '/trainingdataset/timeseries'];
        list=dir([fol '/*.mat']);
        numFiles = numel(list);
    end

    cc=1;
    sequences = cell(numFiles*10,1); % simple over-allocation
    labels    = cell(numFiles*10,1);

    % -------- PRE-SCAN labels to detect minority classes (robust) --------
    fprintf('Scanning labels to detect minority classes...\n');

    allCats = [];
    totalCounts = [];

    for ii = 1:numFiles
        if useH5Series
            % Indices de début / longueur (convertis en double pour h5read)
            startIdx = double(h5SeriesStart(ii));
            lenSeq   = double(h5SeriesLen(ii));

            infoLabs = h5info(h5SeriesFile, '/labels');
            szLabs   = infoLabs.Dataspace.Size;
            rankLabs = numel(szLabs);

            % --- Nombre total de labels (vecteur ligne ou colonne, ou matrice N×K) ---
            if rankLabs == 1
                % Dataset 1D [N]
                Nlabels = szLabs(1);

            elseif rankLabs == 2
                if szLabs(1) == 1 || szLabs(2) == 1
                    % Vecteur ligne [1 N] ou colonne [N 1]
                    Nlabels = max(szLabs);
                else
                    % Matrice [N K] -> N = nb de frames
                    Nlabels = szLabs(1);
                end
            else
                error('Unexpected rank for /labels dataset: %d', rankLabs);
            end

            % ======== PROTECTION anti-dépassement ========
            if startIdx < 1
                startIdx = 1;
            end
            if startIdx > Nlabels
                error('trainImageLSTMNetFun:StartIdxOutOfBounds', ...
                    'startIdx (%d) > number of labels (%d)', startIdx, Nlabels);
            end

            if startIdx + lenSeq - 1 > Nlabels
                lenSeq = Nlabels - startIdx + 1;   % clip si nécessaire
            end
            % =============================================

            switch rankLabs
                case 1
                    % /labels est un vecteur 1D [N]
                    labs = h5read(h5SeriesFile, '/labels', startIdx, lenSeq);

                case 2
                    if szLabs(1) == 1 && szLabs(2) > 1
                        % Vecteur ligne [1 N] : on lit en colonne
                        labs = h5read(h5SeriesFile, '/labels', ...
                            [1        startIdx], ...
                            [1        lenSeq  ]);
                    elseif szLabs(2) == 1 && szLabs(1) > 1
                        % Vecteur colonne [N 1]
                        labs = h5read(h5SeriesFile, '/labels', ...
                            [startIdx 1], ...
                            [lenSeq   1]);
                    else
                        % Matrice [N K] : N = frames, K = nb de colonnes
                        rowCount = lenSeq;
                        colCount = szLabs(2);
                        labs = h5read(h5SeriesFile, '/labels', ...
                            [startIdx 1], ...
                            [rowCount colCount]);
                    end

                otherwise
                    error('Unexpected rank for /labels dataset: %d', rankLabs);
            end


            labLocal = categorical(labs(:), 1:numel(classif.classes), classif.classes);
        else
            S = load(fullfile(list(ii).folder, list(ii).name), 'lab');
            labLocal = S.lab;
        end

        if ii == 1
            allCats = categories(labLocal); % cellstr
            allCats = allCats(:)';
            totalCounts = zeros(1, numel(allCats));
        end
        cnt = countcats( categorical(labLocal, allCats) );
        totalCounts = totalCounts + reshape(cnt,1,[]);
    end

    nonzero = totalCounts > 0;
    if ~any(nonzero)
        warning('No labels counted in dataset. Falling back to uniform split.');
        minorityClasses = allCats(1);
        ratioMinMax = 1;
    else
        mn = min(totalCounts(nonzero));
        mx = max(totalCounts(nonzero));
        ratioMinMax = mn / max(1, mx);

        % min unique by default
        [~, idxMin] = min(totalCounts);
        minorityClasses = allCats(idxMin);

        % percentile option (multi-minority)
        if ~isempty(trainingParam.minority_percentile) && trainingParam.minority_percentile > 0
            thr = prctile(totalCounts, trainingParam.minority_percentile*100);
            mask = totalCounts <= thr;
            if ~any(mask), mask = totalCounts == mn; end
            minorityClasses = allCats(mask);
        end
    end

    doBalance = ~strcmpi(trainingParam.minority_mode,'none') ...
        && (ratioMinMax <= trainingParam.minority_min_ratio);

    fprintf('Classes: %s | counts=%s | minority=%s | balance=%d\n', ...
        strjoin(string(allCats),','), mat2str(totalCounts), strjoin(string(minorityClasses),','), doBalance);

    % --------------------------------------------------------------------

    for i=1:numFiles
        if useH5Series
            roiName = '';
            if numel(h5SeriesIds) >= i
                roiName = char(h5SeriesIds(i));
            end
            if isempty(roiName), roiName = sprintf('#%d', i); end
            fprintf('Processing series %d/%d (%s)...', i, numFiles, roiName);

            nbFra = h5SeriesLen(i);
            idxStart = h5SeriesStart(i);
            idxEnd   = idxStart + nbFra - 1;

            if isempty(h5FrameDS)
                video = h5read(h5SeriesFile, '/frames', [1 1 1 idxStart], [frameSizeH5(1) frameSizeH5(2) frameSizeH5(3) nbFra]);
            else
                dsSeq = subset(h5FrameDS, idxStart:idxEnd);
                video = readH5Sequence(dsSeq, frameSizeH5);
            end
            startIdx = double(h5SeriesStart(i));
            lenSeq   = double(nbFra);

            labs = h5read(h5SeriesFile, '/labels', ...
                [1        startIdx], ...   % start = (row=1, col=startIdx)
                [1        lenSeq]);        % count = (1 ligne, lenSeq colonnes)
            lab   = categorical(labs(:), 1:numel(classif.classes), classif.classes);
        else
            fprintf('Processing movie %d/%d...', i, numFiles);
            S = load(fullfile(list(i).folder, list(i).name)); % loads deep, vid, lab
            video = S.vid;
            lab   = S.lab; % categorical
        end

        video = centerCrop(video,inputSize);
        if size(lab,1)>1 && size(lab,2)>1, error('lab must be 1D categorical'); end
        if size(lab,1)>size(lab,2), lab = lab'; end

        L = trainingParam.LSTM_sequence_length;
        if L<=0, L = size(video,4); end
        T = size(video,4);


% % === LEGACY : découpe par discretize, sans minority mode ===
% fr = 1:T;
% nb = max(1, ceil(T / L));
% dis = discretize(fr, nb);
% for k = 1:max(dis)
%     tmpvid = video(:,:,:, fr(dis==k));
%     sequences{cc,1} = activations(netCNN,tmpvid,layerName,'OutputAs','columns');
% 
%     tmpLab = lab(fr(dis==k));
%     if iscolumn(tmpLab), tmpLab = tmpLab'; end
%     tmpLab = categorical(tmpLab, categories(lab));
%     labels{cc,1} = tmpLab;
% 
%     cc = cc + 1;
% end


        % --- Sliding windows parameters ---
        if isfield(trainingParam,'win_stride_neg_frac') && ~isempty(trainingParam.win_stride_neg_frac)
            stride = max(1, round(L * trainingParam.win_stride_neg_frac));
        else
            stride = max(1, floor(L/2));   % défaut : L/2
        end

        % Construire toutes les fenêtres glissantes [s e]
        windows = [];
        if T <= L
            windows = [1 T];
        else
            for s = 1:stride:(T - L + 1)
                windows(end+1,:) = [s s+L-1]; %#ok<AGROW>
            end
            % dernière fenêtre alignée sur la fin si besoin
            if windows(end,2) < T
                windows(end+1,:) = [max(1,T-L+1) T]; %#ok<AGROW>
            end
        end

        if doBalance
            % ---- 1. Marquer les fenêtres contenant des classes minoritaires ----
            isMinor = ismember(lab, categorical(minorityClasses));
            posWins = [];
            negWins = [];

            for w = 1:size(windows,1)
                s = windows(w,1);
                e = windows(w,2);
                if any(isMinor(s:e))
                    posWins = [posWins; windows(w,:)]; %#ok<AGROW>
                else
                    negWins = [negWins; windows(w,:)]; %#ok<AGROW>
                end
            end

            % ---- 2. Sous-échantillonnage des NEG selon pos_neg_ratio ----
            kpos = size(posWins,1);
            kneg = size(negWins,1);

            if kpos == 0
                useWins = negWins;
            else
                r = min(kneg, round(trainingParam.pos_neg_ratio * kpos));
                selNeg = randperm(kneg, max(r,0));
                useWins = [posWins; negWins(selNeg,:)];
            end

        else
            % ---- Pas de minority mode : toutes les fenêtres glissantes ----
            useWins = windows;
        end

        % ---- 3. Construction des séquences finales ----
        for w = 1:size(useWins,1)
            s = useWins(w,1);
            e = useWins(w,2);

            tmpvid = video(:,:,:,s:e);
            sequences{cc,1} = activations(netCNN,tmpvid,layerName,'OutputAs','columns');

            tmpLab = lab(s:e);
            if iscolumn(tmpLab), tmpLab = tmpLab'; end
            tmpLab = categorical(tmpLab, categories(lab));
            labels{cc,1} = tmpLab;

            cc = cc + 1;
        end


        fprintf('\n');
    end

    sequences = sequences(1:cc-1);
    labels    = labels(1:cc-1);

    save(tempFile,"sequences","labels","-v7.3");
    fprintf('\n');
end

% ===================== LSTM TRAINING =====================
str=fullfile(path,['netLSTM_' name '.mat']);
if trainingParam.train_LSTM_network || ~exist(str,"file")
    disp('Preparing LSTM network ...');
    fprintf('------\n');

    if blockRNG==1
        stCPU= RandStream('Threefry','Seed',0,'NormalTransform','Inversion');
        stGPU=parallel.gpu.RandStream('Threefry','Seed',0,'NormalTransform','Inversion');
        RandStream.setGlobalStream(stCPU);
        parallel.gpu.RandStream.setGlobalStream(stGPU);
    end

    numObservations = numel(sequences);
    idx = randperm(numObservations);
    N = floor(trainingParam.LSTM_data_splitting_factor * numObservations);
    idxTrain = idx(1:N);
    idxValidation = idx(N+1:end);

    sequencesTrain = sequences(idxTrain);
    labelsTrain    = labels(idxTrain);
    sequencesValidation = sequences(idxValidation);
    labelsValidation    = labels(idxValidation);

    if strcmp(trainingParam.classifier_output{end},'sequence-to-one')
        labelsTrain       = [labelsTrain{:}]';
        labelsValidation  = [labelsValidation{:}]';
    end

    numFeatures = size(sequencesTrain{1},1);
    numClasses  = numel(classif.classes);
    if numClasses==0, disp('There is no classes defined ; Cannot continue !'); return; end

    % class weights (frame-level summed across sequences)
    sucl=zeros(numObservations,numClasses);
    for i=1:numObservations
        sucl(i,:)=countcats( categorical(labels{i}, classif.classes) );
    end
    sucl=sum(sucl,1);
    tempsucl=sucl(sucl>0); sucl(sucl==0)=min(tempsucl(:));
    classWeights = 1./sucl; classWeights = classWeights'/mean(classWeights);

    nh=trainingParam.LSTM_hidden_size;
    if strcmp(trainingParam.transfer_learning{end},'ImageNet')
        if strcmp(trainingParam.classifier_output{end},'sequence-to-sequence')
            layers = [
                sequenceInputLayer(numFeatures,'Name','sequence')
                bilstmLayer(nh,'OutputMode','sequence','Name','bilstm')
                dropoutLayer(0.5,'Name','drop')
                fullyConnectedLayer(numClasses,'Name','fc')
                softmaxLayer('Name','softmax')
                weightedLSTMClassificationLayer(classWeights,'classification')];
        else
            layers = [
                sequenceInputLayer(numFeatures,'Name','sequence')
                bilstmLayer(nh,'OutputMode','last','Name','bilstm')
                dropoutLayer(0.5,'Name','drop')
                fullyConnectedLayer(numClasses,'Name','fc')
                softmaxLayer('Name','softmax')
                weightedLSTMClassificationLayer(classWeights,'classification')];
        end
    else
        src=fullfile(classif.path,['netLSTM_' trainingParam.transfer_learning{end}]);
        if exist(src,"file"); load(src); layers=netLSTM.Layers;
        else; disp(['Unable to load LSTM network: ' trainingParam.transfer_learning{end}]); return; end
    end

    miniBatchSize = trainingParam.LSTM_mini_batch_size;
    numObservations = numel(sequencesTrain);
    numIterationsPerEpoch = max(1,floor(numObservations / miniBatchSize));
    patience      = 20;

    options = trainingOptions('adam', ...
        'MiniBatchSize',miniBatchSize, ...
        'MaxEpochs',trainingParam.LSTM_max_epochs,...
        'InitialLearnRate',trainingParam.LSTM_initial_learning_rate, ...
        'LearnRateSchedule','piecewise',...
        'LearnRateDropPeriod',5,...
        'LearnRateDropFactor',trainingParam.LSTM_learn_rate_drop_factor,...
        'Shuffle','every-epoch', ...
        'ValidationData',{sequencesValidation,labelsValidation}, ...
        'ValidationFrequency',numIterationsPerEpoch, ...
        'ValidationPatience', patience, ...
        'Plots','training-progress', ...
        'ExecutionEnvironment','auto',...
        'VerboseFrequency',10);

    disp('Training LSTM network ...');
    fprintf('------\n');
    [netLSTM,info] = trainNetwork(sequencesTrain,labelsTrain,layers,options);

    % ---- Simple threshold search on validation (binary) ----
    bestThreshold = 0.5;
    try
        classes = classif.classes;
        posName = classes{min(2,numel(classes))}; % classe 2 par défaut
        if strcmp(trainingParam.classifier_output{end},'sequence-to-one')
            scoreVal = predict(netLSTM, sequencesValidation, 'MiniBatchSize', miniBatchSize);
            posIdx = find(strcmp(classes, posName));
            posScore = scoreVal(:, posIdx);
            Ytrue    = double(labelsValidation == categorical(posName));
        else
            % sequence-to-sequence : scoreVal est un cell array
            scoreVal = predict(netLSTM, sequencesValidation, 'MiniBatchSize', miniBatchSize);
            posIdx = find(strcmp(classes, posName), 1);
            if isempty(posIdx)
                error('posName "%s" not found in classes.', posName);
            end

            posScore = [];
            Ytrue    = [];
            posCat   = categorical(posName, classes, classes);  % même référentiel

            for i = 1:numel(scoreVal)
                % scoreVal{i} : [T x K] (probabilités)
                thisScore = scoreVal{i}(:, posIdx);
                thisLab   = labelsValidation{i};   % 1xT ou Tx1 categorical

                posScore = [posScore; thisScore(:)]; %#ok<AGROW>
                Ytrue    = [Ytrue; double(thisLab(:) == posCat)]; %#ok<AGROW>
            end
        end

        ths = linspace(0,1,101);
        bestF1=-inf; bestT=0.5;
        for t = ths
            yhat = posScore >= t;
            TP = sum(yhat & Ytrue); FP = sum(yhat & ~Ytrue);
            FN = sum(~yhat & Ytrue);
            P = TP / max(1, (TP+FP));
            R = TP / max(1, (TP+FN));
            F1 = 2*P*R / max(1e-9, (P+R));
            if F1 > bestF1, bestF1=F1; bestT=t; end
        end
        bestThreshold = bestT;
        fprintf('Chosen threshold=%.2f (F1=%.2f)\n', bestThreshold, bestF1);
    catch ME
        warning('Threshold selection failed: %s', ME.message);
    end

    target=fullfile(path,['netLSTM_' name '.mat']);
    save(target,'netLSTM','info','bestThreshold');
    disp('Training LSTM network is done and saved ...');
    fprintf('------\n');
else
    target=fullfile(path,['netLSTM_' name '.mat']);
    load(target);
    disp('Loading LSTM network ...');
    fprintf('------\n');
end

%%% ================= ASSEMBLY =================
if trainingParam.assemble_network || ~exist([path '/' name '.mat'],"file")
    disp('Assembling full network ...');
    fprintf('------\n');

    cnnLayers = layerGraph(netCNN);
    % points d'ancrage
    switch trainingParam.CNN_network{end}
        case 'googlenet', baseInput = "conv1-7x7_s2";  layerName = "pool5-7x7_s1";
        case 'resnet50',  baseInput = "conv1";         layerName = "avg_pool";
        case 'resnet18',  baseInput = "conv1";         layerName = "pool5";
        case {'inceptionresnetv2','inceptionv3'}, baseInput = "conv2d_1"; layerName = "avg_pool";
        otherwise, error('Unsupported backbone: %s', trainingParam.CNN_network{end});
    end

    % retire l'input image d'origine
    isInput = arrayfun(@(L) isa(L,'nnet.cnn.layer.ImageInputLayer'), cnnLayers.Layers);
    oldInputs = {cnnLayers.Layers(isInput).Name};
    if ~isempty(oldInputs), cnnLayers = removeLayers(cnnLayers, oldInputs); end

    % retire la tête en aval de layerName
    names = string({cnnLayers.Layers.Name});
    toVisit = string(layerName); toVisit = toVisit(:);
    desc = strings(0,1);
    while ~isempty(toVisit)
        src = toVisit(1); toVisit(1) = [];
        mask = strcmp(cnnLayers.Connections.Source, src);
        kids = string(cnnLayers.Connections.Destination(mask));
        newKids = setdiff(kids, [desc; string(layerName)]);
        desc    = unique([desc; kids], 'stable');
        toVisit = unique([toVisit; newKids], 'stable');
    end
    desc = setdiff(desc, layerName);
    desc = intersect(desc, names);
    if ~isempty(desc), cnnLayers = removeLayers(cnnLayers, cellstr(desc)); end

    % entrée séquence + folding
    inputLayer = sequenceInputLayer([inputSize 3], 'Normalization','zerocenter', ...
        'Mean', netCNN.Layers(1).Mean, 'Name','input');
    layersAdd = [ inputLayer; sequenceFoldingLayer('Name','fold') ];
    lgraph = addLayers(cnnLayers, layersAdd);

    switch trainingParam.CNN_network{end}
        case 'googlenet', lgraph = connectLayers(lgraph,"fold/out","conv1-7x7_s2");
        case 'resnet50',  lgraph = connectLayers(lgraph,"fold/out","conv1");
        case 'resnet18',  lgraph = connectLayers(lgraph,"fold/out","conv1");
        case {'inceptionresnetv2','inceptionv3'}, lgraph = connectLayers(lgraph,"fold/out","conv2d_1");
    end

    % Unfold + LSTM (sans sa 1ère couche sequenceInputLayer)
    lstmLayers = netLSTM.Layers; lstmLayers(1) = [];
    layersTail = [sequenceUnfoldingLayer('Name','unfold'); flattenLayer('Name','flatten'); lstmLayers];
    lgraph = addLayers(lgraph,layersTail);

    lgraph = connectLayers(lgraph, layerName, "unfold/in");
    lgraph = connectLayers(lgraph, "fold/miniBatchSize", "unfold/miniBatchSize");

    classifier = assembleNetwork(lgraph);
    save([path '/' name '.mat'],'classifier');
    fprintf('Full network is assembled !\n');
else
    load( [path '/' name '.mat']); % loading the fully assembled network
end

%end

function videoResized = centerCrop(video,inputSize)
videoResized = imresize(video,inputSize(1:2));

function video = readH5Sequence(dsSeq, frameSizeH5)
% dsSeq : subset du datastore (TIFF ou HDF5)
% frameSizeH5 : [H W C] attendu pour la vidéo

H = frameSizeH5(1);
W = frameSizeH5(2);
C = frameSizeH5(3);

% Nombre de frames de la séquence = nb d'observations du dsSeq
nFrames = numObservations(dsSeq);  % ou numObservations(dsSeq) si tu préfères

vid = zeros(H, W, C, nFrames, 'uint8');

reset(dsSeq);
cc = 1;

while hasdata(dsSeq) && cc <= nFrames
    % Nouveau format : read peut renvoyer une TABLE ou un array
    batch = read(dsSeq);

    if istable(batch)
        % Cas H5ImageDatastore : batch.input est une cell B×1
        if ismember('input', batch.Properties.VariableNames)
            imgs = batch.input;
        else
            % fallback : on prend la 1ère colonne
            imgs = batch{:,1};
        end
    elseif iscell(batch)
        % Si un jour tu as un datastore qui renvoie un cell array
        imgs = batch;
    else
        % Cas historique : batch est un array [H W C B]
        B = size(batch,4);
        imgs = cell(B,1);
        for k = 1:B
            imgs{k} = batch(:,:,:,k);
        end
    end

    % On remplit la vidéo frame par frame
    for k = 1:numel(imgs)
        if cc > nFrames
            break;
        end

        img = imgs{k};

        % Normalisation / cast
        if isa(img,'single') || isa(img,'double')
            % supposé déjà dans [0,1] pour H5ImageDatastore
            img01 = img;
        else
            img01 = im2single(img);   % uint8 → [0,1]
        end

        % Resize au besoin
        if size(img01,1) ~= H || size(img01,2) ~= W
            img01 = imresize(img01, [H W]);
        end

        % Forcer 3 canaux
        if size(img01,3) == 1
            img01 = repmat(img01, [1 1 3]);
        end

        vid(:,:,:,cc) = uint8(round(img01 * 255));
        cc = cc + 1;
    end
end

video = vid;


function augParams = localGetH5AugParams(trainingParam)
% Harmonise les paramètres d'augmentation spécifiques au backend HDF5
augParams = struct();

augParams.TransRange    = trainingParam.CNN_translation_augmentation;
augParams.RotRange      = trainingParam.CNN_rotation_augmentation;
augParams.CropScale     = trainingParam.CNN_crop_scale;
augParams.ContrastRange = trainingParam.CNN_contrast_range;
augParams.HueDelta      = trainingParam.CNN_hue_delta;
augParams.NoiseSigma    = trainingParam.CNN_noise_sigma;
