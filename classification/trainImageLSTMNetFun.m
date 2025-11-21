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
        'LSTM_data_splitting_factor',0.9,...
        'LSTM_hidden_size',150,...
        'LSTM_mini_batch_size',8,...
        'LSTM_initial_learning_rate', 1e-4,...
        'LSTM_max_epochs', 50,...
        'LSTM_sequence_length', 40,...
        'LSTM_learn_rate_drop_factor', 0.9,...
        'execution_environment',{{'auto','parallel','cpu','gpu','multi-gpu','auto'}},...
        'transfer_learning',{{'ImageNet','ImageNet'}},...
        ... % ==== nouveaux paramètres de balancing / windowing ====
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
    trainingParam.CNN_storage_backend = 'hdf5';
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
        backend = char(lower(string(trainingParam.CNN_storage_backend)));
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

            % Datastore HDF5 avec les mêmes augmentations que pour l'entraînement CNN
            augParams = localGetH5AugParams(trainingParam);
            h5FrameDS = H5ImageDatastore(h5SeriesFile, ...
                'MiniBatchSize', max(1, trainingParam.CNN_mini_batch_size), ...
                'TransRange',    augParams.TransRange, ...
                'RotRange',      augParams.RotRange, ...
                'CropScale',     augParams.CropScale, ...
                'ContrastRange', augParams.ContrastRange, ...
                'HueDelta',      augParams.HueDelta, ...
                'NoiseSigma',    augParams.NoiseSigma, ...
                'ClassNames',    classif.classes);
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
            labs = h5read(h5SeriesFile, '/labels', [h5SeriesStart(ii)], [h5SeriesLen(ii)]);
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
            labs  = h5read(h5SeriesFile, '/labels', [h5SeriesStart(i)], [nbFra]);
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

        if doBalance
            isMinor = ismember(lab, categorical(minorityClasses));
            posIdx  = find(isMinor);

            winStridePos = max(1, round(L * trainingParam.win_stride_pos_frac));
            winStrideNeg = max(1, round(L * trainingParam.win_stride_neg_frac));

            posWins = []; negWins = [];

            % POS windows centered on minority frames
            for t = posIdx(:).'
                s = max(1, t - floor(L/2));
                e = min(T, s + L - 1); s = max(1, e - L + 1);
                posWins(end+1,:) = [s e]; %#ok<AGROW>
            end
            if ~isempty(posWins), posWins = unique(posWins, 'rows', 'stable'); end

            % NEG windows (avoid overlap with POS)
            t0 = 1;
            while t0 + L - 1 <= T
                s = t0; e = t0 + L - 1;
                overlap = ~isempty(posWins) && any( (posWins(:,1) <= e) & (posWins(:,2) >= s) );
                if ~overlap, negWins(end+1,:) = [s e]; end %#ok<AGROW>
                % stride depends on POS/NEG type
                t0 = t0 + winStrideNeg;
            end

            % Balance: keep r = pos_neg_ratio * kpos negatives
            kpos = size(posWins,1); kneg = size(negWins,1);
            if kpos==0
                selNeg = randperm(kneg, min(kneg, 2));
                useWins = negWins(selNeg,:);
            else
                r = min(kneg, max(0, round(trainingParam.pos_neg_ratio * kpos)));
                if r>0, selNeg = randperm(kneg, r); else, selNeg = []; end
                useWins = [posWins; negWins(selNeg,:)];
            end

            % Build sequences
            for w = 1:size(useWins,1)
                s = useWins(w,1); e = useWins(w,2);
                tmpvid = video(:,:,:,s:e);
                sequences{cc,1} = activations(netCNN,tmpvid,layerName,'OutputAs','columns');

                if strcmp(trainingParam.classifier_output{end},'sequence-to-one')
                    % label = "sequence contains any minority"
                    hasMinor = any(ismember(lab(s:e), categorical(minorityClasses)));
                    majorCats = setdiff(allCats, minorityClasses, 'stable');
                    if isempty(majorCats), majorCats = {'other'}; end
                    majorName = char(majorCats{1});
                    minorName = char(minorityClasses(1));
                    labOne = categorical(hasMinor,[false true],{majorName,minorName});
                    labels{cc,1} = labOne;
                else
                    tmpLab = lab(s:e);
                    if iscolumn(tmpLab), tmpLab = tmpLab'; end
                    tmpLab = categorical(tmpLab, allCats); % force order
                    labels{cc,1} = tmpLab;
                end
                cc = cc + 1;
            end

        else
            % Uniform slicing fallback
            fr = 1:T;
            nb = max(1, ceil(T / L));
            dis = discretize(fr, nb);
            for k=1:max(dis)
                tmpvid = video(:,:,:,fr(dis==k));
                sequences{cc,1} = activations(netCNN,tmpvid,layerName,'OutputAs','columns');
                tmpLab = lab(fr(dis==k));
                if iscolumn(tmpLab), tmpLab = tmpLab'; end
                tmpLab = categorical(tmpLab, categories(lab));
                labels{cc,1} = tmpLab;
                cc = cc + 1;
            end
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
    patience      = 10;

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
            scoreVal = predict(netLSTM, sequencesValidation, 'MiniBatchSize', miniBatchSize);
            posIdx = find(strcmp(classes, posName));
            posScore = []; Ytrue = [];
            for i=1:numel(scoreVal)
                posScore = [posScore; scoreVal{i}(:,posIdx)]; %#ok<AGROW>
                Ytrue    = [Ytrue; double(labelsValidation{i}(:)==categororical(posName))]; %#ok<AGROW>
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

function vid = readH5Sequence(dsSeq, frameSize)
% Helper: read an ordered sequence from H5ImageDatastore subset
% frameSize = [H W C N] for consistency checks

reset(dsSeq);

H = frameSize(1); W = frameSize(2); C = frameSize(3);
T = numObservations(dsSeq);

vid = zeros(H, W, C, T, 'uint8');
cc = 1;
while hasdata(dsSeq)
    [batch, ~] = read(dsSeq);
    B = size(batch,4);
    for k = 1:B
        if cc > T, break; end %#ok<AGROW>
        vid(:,:,:,cc) = uint8(round(batch(:,:,:,k) * 255));
        cc = cc + 1;
    end
end

if cc-1 ~= T
    warning('Expected %d frames from HDF5 datastore, got %d.', T, cc-1);
end

function augParams = localGetH5AugParams(trainingParam)
% Harmonise les paramètres d'augmentation spécifiques au backend HDF5
augParams = struct();

augParams.TransRange    = trainingParam.CNN_translation_augmentation;
augParams.RotRange      = trainingParam.CNN_rotation_augmentation;
augParams.CropScale     = trainingParam.CNN_crop_scale;
augParams.ContrastRange = trainingParam.CNN_contrast_range;
augParams.HueDelta      = trainingParam.CNN_hue_delta;
augParams.NoiseSigma    = trainingParam.CNN_noise_sigma;
