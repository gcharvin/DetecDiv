function trainImageLSTMNetFun(classif,setparam)

path = fullfile(classif.path);
name = classif.strid;

%---------------- parameters setting
if nargin==2 % basic parameter initialization

    tip = { ...
        'Check box to train CNN', ...
        'Check box to compute CNN activations', ...
        'Check box to train the LSTM network', ...
        'Check box to asssemble the CNN and LSTM networks', ...
        'Specify if each frame should be classified, or if one class is expected for the whole sequence of images', ...
        'Choose the training method', ...
        'Choose the CNN', ...
        'Choose the size of the mini batch; Higher values require more memory and are prone to errors', ...
        'Enter the number of epochs', ...
        'Enter the initial learning rate', ...
        'Enter the learning rate drop factor', ...
        'Choose whether and how training and validation data should be shuffled during training', ...
        'Enter fraction of the data to be used for training vs validation during training', ...
        'Enter the magnitude of translation for data augmentation (in pixels)', ...
        'Enter the magnitude of rotation for data augmentation (in degrees)', ...
        'Specify value for L2 regularization', ...
        'Check to use a dropout layer', ...
        'Value for dropout regularization', ...
        'Range of random scale factor for CNN augmentation (e.g. [0.8 1.0])', ...
        'Enable random flips (left/right & up/down) during CNN augmentation', ...
        'Crop-in scale range for CNN augmentation (e.g. [0.8 1.0])', ...
        'Contrast multiplier range for CNN augmentation (e.g. [0.85 1.15])', ...
        'Brightness offset range (additive, e.g. [-0.10 0.10])', ...
        'Gamma exponent range for CNN augmentation (e.g. [0.9 1.1])', ...
        'Saturation multiplier range (RGB only, e.g. [0.95 1.05])', ...
        'Maximum hue jitter (0–0.5, small values recommended)', ...
        'Std-dev of Gaussian noise for CNN augmentation (set 0 to disable)', ...
        'Defocus sigma range in pixels (e.g. [0.3 1.0])', ...
        'Probability to apply defocus blur (e.g. 0.5)', ...
        'Choose the fraction of the data to be used for training vs validation during LSTM training', ...
        'Enter the size of the hidden unit', ...
        'Choose the size of the mini batch for LSTM training; Higher values require more memory and are prone to errors', ...
        'Enter the LSTM initial learning rate', ...
        'Enter the number of epochs for LSTM training', ...
        'Enter the length of the sequences in frames; put 0 if all frames should be used upon training', ...
        'Enter the dropping factor in learning rate', ...
        'Choose execution environment', ...
        'Select initial version of network to start training with; Default: ImageNet', ...
        'Minority balancing mode (none/auto)', ...
        'Activate balancing if min/max ratio ≤ this value', ...
        'Percentile for multi-minority selection (0=off)', ...
        '#Negatives per #Positives windows (e.g. 1 = 1:1)', ...
        'Positive window stride as a fraction of L', ...
        'Negative window stride as a fraction of L', ...
        'Keep validation distribution unbalanced (true/false)', ...
        'Fraction of ROIs used when formatting the LSTM training set', ...
        'Random seed used when sampling ROIs / frames for formatting', ...
        'Enable cropping when formatting the LSTM training set (true/false)', ...
        'Crop center [cx cy] used for formatting the LSTM training set', ...
        'Crop size [w h] used for formatting the LSTM training set', ...
        'Undersample majority classes (1 = no undersampling)', ...
        'Storage backend for formatted data (''hdf5'' or ''tiff'')' ...
        };

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
        'CNN_initial_learning_rate',0.0001,...
        'CNN_learn_rate_drop_factor',0.9,...
        'CNN_data_shuffling',{{'once','every-epoch','never','every-epoch'}},...
        'CNN_data_splitting_factor',0.7,...
        'CNN_translation_augmentation',[-5 5],...
        'CNN_rotation_augmentation',[-5 5],...
        'CNN_l2_regularization',1e-5,...
        'CNN_use_dropout',true,...
        'CNN_dropout',0.5,...
        'CNN_rand_scale',[0.8 1.0], ...
        'CNN_rand_flip',true, ...
        'CNN_crop_scale',[0.8 1.0], ...
        'CNN_contrast_range',[1 1], ...
        'CNN_brightness_range',[0 0], ...
        'CNN_gamma_range',[1 1], ...
        'CNN_saturation_range',[1 1], ...
        'CNN_hue_delta',0, ...
        'CNN_noise_sigma',0, ...
        'CNN_defocus_sigma_range',[0 0], ...
        'CNN_defocus_prob',0, ...
        'LSTM_data_splitting_factor',0.9,...
        'LSTM_hidden_size',150,...
        'LSTM_mini_batch_size',8,...
        'LSTM_initial_learning_rate', 1e-4,...
        'LSTM_max_epochs', 50,...
        'LSTM_sequence_length', 40,...
        'LSTM_learn_rate_drop_factor', 0.9,...
        'execution_environment',{{'auto','parallel','cpu','gpu','multi-gpu','auto'}},...
        'transfer_learning',{{'ImageNet','ImageNet'}},...
        'LSTM_minority_mode','none',...
        'LSTM_minority_min_ratio',0.30,...
        'LSTM_minority_percentile',0.00,...
        'LSTM_pos_neg_ratio',1.0,...
        'LSTM_win_stride_pos_frac',0.10,...
        'LSTM_win_stride_neg_frac',1.00,...
        'LSTM_keep_valid_distrib',true,...
        'Format_Fraction',1.0, ...
        'Format_Seed',12345, ...
        'Format_Crop',false, ...
        'Format_CropCenter',[88 194], ...
        'Format_CropSize',[60 60], ...
        'Format_UndersampleMajority',1.0, ...
        'Format_StorageBackend',{{'hdf5','tiff','hdf5'}}, ...
        'tip',{tip});
    return;

else
    trainingParam = updateLSTMTrainingParam(classif);
end
%-----------------------------------%

    function safeRunStop()
        try
            classif.runStop();
        catch
        end
    end

try
   % classif.runStart('trainImageLSTMNetFun', trainingParam, 'Attach', true);
    classif.runMsg('Backend=%s', trainingParam.Format_StorageBackend{end});

    classif.displayTrainingParam();
    blockRNG = 1;

    if ~checkLSTMFormattedDataset(classif.path, trainingParam, classif)
        safeRunStop();
        return;
    end
    classif.runMsg('Formatted dataset check OK');

    fprintf('------\n');

    %------------------------------------------
    %  CNN backbone : train / load + InputSize
    %------------------------------------------
    netCNN = [];

    if trainingParam.train_CNN_classifier

        if strcmp(trainingParam.transfer_learning{end},'ImageNet')

            classif.runMsg('Start CNN pretrain');

            trainImageGoogleNetFun(classif,'','','AttachRun', true); % will save <name>.mat in this folder
            

        else
            src = fullfile(classif.path, ['netCNN_' trainingParam.transfer_learning{end}]);
            if exist(src,"file")
                load(src); % loads classifier
            else
                disp(['Unable to load: ' trainingParam.transfer_learning{end}]);
                safeRunStop();
                return;
            end
            trainImageGoogleNetFun(classif,'ok',classifier);
        end

        target = fullfile(path,['netCNN_' name '.mat']);
        source = fullfile(path,[name '.mat']);

        if ~exist(source,"file")
            disp('Trained CNN does not exist; quitting !');
            safeRunStop();
            return;
        end

        copyfile(source,target);
    end

    fprintf('Loading Image classifier...\n');
    fprintf('------\n');
    str = fullfile(path,['netCNN_' name '.mat']);

    if exist(str,"file")
        load(str); % loads classifier
        netCNN = classifier;
    else
        disp('unable to find CNN classifier; first train the CNN classifier; quitting ...!');
        safeRunStop();
        return;
    end

    classif.runMsg('CNN loaded. Network class=%s', class(netCNN));

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

        backend = trainingParam.Format_StorageBackend{end};

        h5SeriesFile = "";
        if strcmp(backend,'hdf5')
            baseFB = fullfile(path,[classif.strid,'_framebank.h5']);
            [h5SeriesFile, ~] = findExistingFramebank(baseFB);
        end

        h5Exists    = (strlength(h5SeriesFile) > 0) && exist(h5SeriesFile,"file")==2;
        useH5Series = strcmp(backend,'hdf5') && h5Exists;

        if useH5Series
            fprintf('Using HDF5 framebank: %s\n', h5SeriesFile);
        elseif strcmp(backend,'hdf5')
            warning('HDF5 backend requested but no usable framebank found. Falling back to MAT/TIFF.');
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
            catch ME
                warning('Failed to read HDF5 framebank metadata (%s). Falling back to MAT files.', ME.message);
                useH5Series = false;
            end
        end

        if useH5Series
            numFiles = numel(h5SeriesStart);
            fprintf('Using HDF5 framebank (%d series).\n', numFiles);
        else
            fol  = [path '/trainingdataset/timeseries'];
            list = dir([fol '/*.mat']);
            numFiles = numel(list);
        end

        cc = 1;
        sequences = cell(numFiles*10,1);
        labels    = cell(numFiles*10,1);

        % -------- PRE-SCAN labels to detect minority classes --------
        fprintf('Scanning labels to detect minority classes...\n');

        allCats = [];
        totalCounts = [];

        for ii = 1:numFiles
            progressBar(ii, numFiles, ['Prescanning ROIs']);

            if useH5Series
                startIdx = double(h5SeriesStart(ii));
                lenSeq   = double(h5SeriesLen(ii));

                infoLabs = h5info(h5SeriesFile, '/labels');
                szLabs   = infoLabs.Dataspace.Size;
                rankLabs = numel(szLabs);

                if rankLabs == 1
                    Nlabels = szLabs(1);
                elseif rankLabs == 2
                    if szLabs(1) == 1 || szLabs(2) == 1
                        Nlabels = max(szLabs);
                    else
                        Nlabels = szLabs(1);
                    end
                else
                    error('Unexpected rank for /labels dataset: %d', rankLabs);
                end

                if startIdx < 1, startIdx = 1; end
                if startIdx > Nlabels
                    error('trainImageLSTMNetFun:StartIdxOutOfBounds', ...
                        'startIdx (%d) > number of labels (%d)', startIdx, Nlabels);
                end
                if startIdx + lenSeq - 1 > Nlabels
                    lenSeq = Nlabels - startIdx + 1;
                end

                switch rankLabs
                    case 1
                        labs = h5read(h5SeriesFile, '/labels', startIdx, lenSeq);
                    case 2
                        if szLabs(1) == 1 && szLabs(2) > 1
                            labs = h5read(h5SeriesFile, '/labels', [1 startIdx], [1 lenSeq]);
                        elseif szLabs(2) == 1 && szLabs(1) > 1
                            labs = h5read(h5SeriesFile, '/labels', [startIdx 1], [lenSeq 1]);
                        else
                            rowCount = lenSeq;
                            colCount = szLabs(2);
                            labs = h5read(h5SeriesFile, '/labels', [startIdx 1], [rowCount colCount]);
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
                allCats = categories(labLocal);
                allCats = allCats(:)';
                totalCounts = zeros(1, numel(allCats));
            end
            cnt = countcats(categorical(labLocal, allCats));
            totalCounts = totalCounts + reshape(cnt,1,[]);
        end
        fprintf('\n');

        nonzero = totalCounts > 0;
        if ~any(nonzero)
            warning('No labels counted in dataset. Falling back to uniform split.');
            minorityClasses = allCats(1);
            ratioMinMax = 1;
        else
            mn = min(totalCounts(nonzero));
            mx = max(totalCounts(nonzero));
            ratioMinMax = mn / max(1, mx);

            [~, idxMin] = min(totalCounts);
            minorityClasses = allCats(idxMin);

            if ~isempty(trainingParam.LSTM_minority_percentile) && trainingParam.LSTM_minority_percentile > 0
                thr = prctile(totalCounts, trainingParam.LSTM_minority_percentile*100);
                mask = totalCounts <= thr;
                if ~any(mask), mask = totalCounts == mn; end
                minorityClasses = allCats(mask);
            end
        end

        doBalance = ~strcmpi(trainingParam.LSTM_minority_mode,'none') ...
            && (ratioMinMax <= trainingParam.LSTM_minority_min_ratio);

        fprintf('Classes: %s | counts=%s | minority=%s | balance=%d\n', ...
            strjoin(string(allCats),','), mat2str(totalCounts), strjoin(string(minorityClasses),','), doBalance);

        classif.runSave('labelCounts.mat', ...
            'allCats', allCats, 'totalCounts', totalCounts, ...
            'minorityClasses', minorityClasses, 'ratioMinMax', ratioMinMax, 'doBalance', doBalance);

        % -------- build sequences/labels --------
        for i = 1:numFiles
            if useH5Series
                roiName = '';
                if numel(h5SeriesIds) >= i
                    roiName = char(h5SeriesIds(i));
                end
                if isempty(roiName)
                    roiName = sprintf('#%d', i);
                end

                progressBar(i, numFiles, ['Computing activations (hdf5) : ' roiName]);

                nbFra    = h5SeriesLen(i);
                idxStart = h5SeriesStart(i);
                idxEnd   = idxStart + nbFra - 1; %#ok<NASGU>

                video = h5read(h5SeriesFile, '/frames', ...
                    [1 1 1 idxStart], ...
                    [frameSizeH5(1) frameSizeH5(2) frameSizeH5(3) nbFra]);

                startIdx = double(h5SeriesStart(i));
                lenSeq   = double(nbFra);

                labs = h5read(h5SeriesFile, '/labels', [1 startIdx], [1 lenSeq]);
                lab  = categorical(labs(:), 1:numel(classif.classes), classif.classes);

            else
                progressBar(i, numFiles, ['Computing activations (mat) : ' list(i).name]);
                S = load(fullfile(list(i).folder, list(i).name));
                video = S.vid;
                lab   = S.lab;
            end

            video = centerCrop(video,inputSize);
            featAll = computeCNNActivationsFromBackbone(netCNN, video, layerName);

            if size(lab,1)>1 && size(lab,2)>1, error('lab must be 1D categorical'); end
            if size(lab,1)>size(lab,2), lab = lab'; end

            Lwin = trainingParam.LSTM_sequence_length;
            if Lwin<=0, Lwin = size(video,4); end
            T = size(video,4);

            if isfield(trainingParam,'LSTM_win_stride_pos_frac') && ~isempty(trainingParam.LSTM_win_stride_pos_frac)
                stridePos = max(1, round(Lwin * trainingParam.LSTM_win_stride_pos_frac));
            else
                stridePos = max(1, floor(Lwin/2));
            end

            if isfield(trainingParam,'LSTM_win_stride_neg_frac') && ~isempty(trainingParam.LSTM_win_stride_neg_frac)
                strideNeg = max(1, round(Lwin * trainingParam.LSTM_win_stride_neg_frac));
            else
                strideNeg = stridePos;
            end

            windows = [];
            if T <= Lwin
                windows = [1 T];
            else
                for s = 1:stridePos:(T - Lwin + 1)
                    windows(end+1,:) = [s s+Lwin-1]; %#ok<AGROW>
                end
                if windows(end,2) < T
                    windows(end+1,:) = [max(1,T-Lwin+1) T]; %#ok<AGROW>
                end
            end

            if doBalance
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

                if strideNeg > stridePos && size(negWins,1) > 1
                    stepThin = max(1, round(strideNeg / stridePos));
                    negWins  = negWins(1:stepThin:end, :);
                end

                kpos = size(posWins,1);
                kneg = size(negWins,1);

                if kpos == 0
                    useWins = negWins;
                else
                    r = min(kneg, round(trainingParam.LSTM_pos_neg_ratio * kpos));
                    if r > 0 && kneg > 0
                        selNeg = randperm(kneg, r);
                        useWins = [posWins; negWins(selNeg,:)];
                    else
                        useWins = posWins;
                    end
                end
            else
                useWins = windows;
            end

            for w = 1:size(useWins,1)
    s = useWins(w,1);
    e = useWins(w,2);

    % ----- Features window -----
    Fwin = featAll(:, s:e);  % [F x L]

    % ----- Delta backward (causal): F(t)-F(t-1) -----
    dFm = [zeros(size(Fwin,1),1,'like',Fwin), diff(Fwin,1,2)];  % [F x L]

    % ----- Delta forward (look-ahead): F(t+1)-F(t) -----
    dFp = [diff(Fwin,1,2), zeros(size(Fwin,1),1,'like',Fwin)];  % [F x L]

    % ----- Concatenate: [F ; dFm ; dFp] -----
    Xwin = [Fwin; dFm; dFp];  % [3F x L]
    %Xwin = Fwin;

    sequences{cc,1} = Xwin;

    tmpLab = lab(s:e);
    if iscolumn(tmpLab), tmpLab = tmpLab'; end
    tmpLab = categorical(tmpLab, categories(lab));
    labels{cc,1} = tmpLab;

    cc = cc + 1;
end

        end

        sequences = sequences(1:cc-1);
        labels    = labels(1:cc-1);

        save(tempFile,"sequences","labels","-v7.3");
        classif.runMsg('Saved activations: %s', tempFile);
        fprintf('\n');
    end


    % ===================== LSTM TRAINING =====================
    str = fullfile(path,['netLSTM_' name '.mat']);
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
        N   = floor(trainingParam.LSTM_data_splitting_factor * numObservations);
        idxTrain      = idx(1:N);
        idxValidation = idx(N+1:end);

        sequencesTrain      = sequences(idxTrain);
        labelsTrain         = labels(idxTrain);
        sequencesValidation = sequences(idxValidation);
        labelsValidation    = labels(idxValidation);

        if strcmp(trainingParam.classifier_output{end},'sequence-to-one')
            labelsTrain      = [labelsTrain{:}]';
            labelsValidation = [labelsValidation{:}]';
        end

        numFeatures = size(sequencesTrain{1},1);

        classif.runMsg('LSTM input features = %d (base=%d, +d-=%d, +d+=%d)', ...
    numFeatures, numFeatures/3, numFeatures/3, numFeatures/3);


        numClasses  = numel(classif.classes);
        if numClasses==0
            disp('There is no classes defined ; Cannot continue !');
            safeRunStop();
            return;
        end

        sucl = zeros(numObservations, numClasses);
        for i = 1:numObservations
            sucl(i,:) = countcats(categorical(labels{i}, classif.classes));
        end
        sucl = sum(sucl,1);
        tempsucl = sucl(sucl>0);
        sucl(sucl==0) = min(tempsucl(:));
        classWeights = 1 ./ sucl;
        classWeights = classWeights' / mean(classWeights);

        fprintf('--- LSTM class weights ---\n');
        for k = 1:numClasses
            fprintf('  %s : w = %.3f\n', string(classif.classes{k}), classWeights(k));
        end
        fprintf('--------------------------\n');

        nh = trainingParam.LSTM_hidden_size;

        classesRaw = classif.classes;
        if iscell(classesRaw)
            classNames = classesRaw;
        else
            classNames = cellstr(classesRaw);
        end
        numClasses = numel(classNames);

        if strcmp(trainingParam.transfer_learning{end},'ImageNet')
            if strcmp(trainingParam.classifier_output{end},'sequence-to-sequence')
               layers = [
                    sequenceInputLayer(numFeatures,'Name','sequence')
                    bilstmLayer(nh,'OutputMode','sequence','Name','bilstm')
                    dropoutLayer(0.5,'Name','drop')
                    fullyConnectedLayer(numClasses,'Name','fc')
                    softmaxLayer('Name','softmax')
                    classificationLayer('Name','classification',"Classes", classNames)];
    %              k = 5;              % kernel temporel (3,5,7...)
    % nFilt = nh/2;        % pour matcher la sortie BiLSTM (2*nh)
    % 
    % layers = [
    %     sequenceInputLayer(numFeatures,'Name','sequence')
    %     bilstmLayer(nh,'OutputMode','sequence','Name','bilstm')
    % 
    %     convolution1dLayer(k, nFilt, 'Padding','same', 'Name','tconv1')
    %     reluLayer('Name','tconv1_relu')              % optionnel mais souvent utile
    %     dropoutLayer(0.5,'Name','drop')              % plutôt après la conv
    % 
    %     fullyConnectedLayer(numClasses,'Name','fc')
    %     softmaxLayer('Name','softmax')
    %     classificationLayer('Name','classification',"Classes", classNames)
    % ];
            else
                layers = [
                    sequenceInputLayer(numFeatures,'Name','sequence')
                    bilstmLayer(nh,'OutputMode','last','Name','bilstm')
                    dropoutLayer(0.5,'Name','drop')
                    fullyConnectedLayer(numClasses,'Name','fc')
                    softmaxLayer('Name','softmax')
                    classificationLayer('Name','classification',"Classes", classNames)];
            end
        else
            src = fullfile(classif.path, ['netLSTM_' trainingParam.transfer_learning{end}]);
            if exist(src,"file")
                load(src);
                layers = netLSTM.Layers;
            else
                disp(['Unable to load LSTM network: ' trainingParam.transfer_learning{end}]);
                safeRunStop();
                return;
            end
        end

        miniBatchSize = trainingParam.LSTM_mini_batch_size;
        sequencesTrain      = cellfun(@(x) x.', sequencesTrain,      'UniformOutput', false);
        sequencesValidation = cellfun(@(x) x.', sequencesValidation, 'UniformOutput', false);

        numObservationsTrain = numel(sequencesTrain);
        numIterationsPerEpoch= max(1,floor(numObservationsTrain / miniBatchSize));
        patience = 10;

        isSeq2Seq = strcmp(trainingParam.classifier_output{end},'sequence-to-sequence');
        if isSeq2Seq
            for i = 1:numel(labelsTrain)
                if isrow(labelsTrain{i}), labelsTrain{i} = labelsTrain{i}.'; end
            end
            for i = 1:numel(labelsValidation)
                if isrow(labelsValidation{i}), labelsValidation{i} = labelsValidation{i}.'; end
            end
        end

        options = trainingOptions("adam", ...
            "MiniBatchSize",        miniBatchSize, ...
            "MaxEpochs",            trainingParam.LSTM_max_epochs, ...
            "InitialLearnRate",     trainingParam.LSTM_initial_learning_rate, ...
            "LearnRateSchedule",    "piecewise", ...
            "LearnRateDropPeriod",  5, ...
            "LearnRateDropFactor",  trainingParam.LSTM_learn_rate_drop_factor, ...
            "Shuffle",              "every-epoch", ...
            "L2Regularization",     1e-5, ...      % <-- teste 1e-4 puis 3e-4
            "ValidationData",       {sequencesValidation, labelsValidation}, ...
            "ValidationFrequency",  numIterationsPerEpoch, ...
            "ValidationPatience",   patience, ...
            "GradientThresholdMethod","l2norm", ...
            "GradientThreshold", 1.0, ...
            "Plots",                "training-progress", ...
            "ExecutionEnvironment", "auto", ...
            "VerboseFrequency",     10, ...
            "InputDataFormats",     "TCB");

        lgraphLSTM = layerGraph(layers);
        if any(strcmp({lgraphLSTM.Layers.Name},'classification'))
            lgraphDL = removeLayers(lgraphLSTM,'classification');
        else
            lgraphDL = lgraphLSTM;
        end

        outputLayerName = 'softmax';
        dlNetLSTM = dlnetwork(lgraphDL, "OutputNames", outputLayerName);

        classWeightsVec = single(classWeights(:)'); % 1xC
       % lossFcn = @(Y,T) crossentropy(Y, T, classWeightsVec, "WeightsFormat", "C");

       C = numel(classNames);
alpha = classWeightsVec; %ones(1,C,'single');
%idxSmall = find(strcmp(classNames,"small"),1);
% if ~isempty(idxSmall)
%     alpha(idxSmall) = 2.0;     % commence à 2 (pas 10)
% end

gamma = 1.5;                   % 1 → doux, 2 → agressif

%lossFcn = @(Y,T) focalLoss(Y, T, alpha, gamma, classNames);

%isSeq2Seq = strcmp(trainingParam.classifier_output{end},'sequence-to-sequence');
lossFcn = @(Y,T) localFocalCELossLSTM(Y, T, alpha, gamma, classNames);


        disp('Training LSTM network (trainnet) ...');
        fprintf('------\n');

        [dlNetLSTM, info] = trainnet(sequencesTrain, labelsTrain, dlNetLSTM, lossFcn, options);

        classif.runSaveTrainingCurves(info, 'LSTM');

        lgraphTrained = layerGraph(dlNetLSTM.Layers);
        if ~any(strcmp({lgraphTrained.Layers.Name},'classification'))
            classLayer = classificationLayer('Name','classification','Classes', classNames);
            lgraphTrained = addLayers(lgraphTrained, classLayer);
            lgraphTrained = connectLayers(lgraphTrained, outputLayerName, 'classification');
        end
        netLSTM = assembleNetwork(lgraphTrained);

        target = fullfile(path,['netLSTM_' name '.mat']);
        save(target,'netLSTM','info');

        disp('Training LSTM network is done and saved ...');
        fprintf('------\n');

        classif.runSave('LSTM_info.mat', 'info', info);
        classif.runMsg('Saved netLSTM_%s.mat', name);

        bestThreshold = 0.5;
        try
            classesRaw = classif.classes;
            if iscell(classesRaw), classes = classesRaw(:);
            else, classes = cellstr(classesRaw);
            end

            posName = classes{min(2,numel(classes))};
            posIdx = find(strcmp(classes, posName), 1);
            if isempty(posIdx), error('posName "%s" not found in classes.', posName); end

            if strcmp(trainingParam.classifier_output{end},'sequence-to-one')
                numVal     = numel(sequencesValidation);
                numClasses = numel(classes);
                scoreVal   = zeros(numVal, numClasses, 'single');

                for i = 1:numVal
                    Xi = sequencesValidation{i};
                    Xi = reshape(Xi, size(Xi,1), size(Xi,2), 1);
                    dlXi = dlarray(Xi, "TCB");
                    dlYi = forward(dlNetLSTM, dlXi);
                    yi   = gather(extractdata(dlYi));
                    scoreVal(i,:) = yi.';
                end

                posScore = scoreVal(:, posIdx);
                posCat   = categorical({posName}, classes, classes);
                Ytrue    = double(labelsValidation == posCat);
            else
                posScore = [];
                Ytrue    = [];
                posCat   = categorical({posName}, classes, classes);
                numClasses = numel(classes);

                for i = 1:numel(sequencesValidation)
                    Xi = sequencesValidation{i};
                    Xi = reshape(Xi, size(Xi,1), size(Xi,2), 1);
                    dlXi = dlarray(Xi, "TCB");

                    dlYi   = forward(dlNetLSTM, dlXi);
                    Yidata = gather(extractdata(dlYi));

                    sz = size(Yidata);
                    classDim = find(sz == numClasses, 1);
                    if isempty(classDim)
                        error('Impossible de trouver une dimension = numClasses (%d) dans la sortie LSTM.', numClasses);
                    end

                    nd = ndims(Yidata);
                    perm = 1:nd;
                    perm([2,classDim]) = perm([classDim,2]);
                    Yperm = permute(Yidata, perm);

                    szp = size(Yperm);
                    numCls = szp(2);
                    other  = prod(szp) / numCls;
                    Yflat  = reshape(Yperm, other, numCls);

                    thisScore = Yflat(:, posIdx);
                    thisLab   = labelsValidation{i};

                    posScore = [posScore; thisScore(:)]; %#ok<AGROW>
                    Ytrue    = [Ytrue; double(thisLab(:) == posCat)]; %#ok<AGROW>
                end
            end

            ths = linspace(0,1,101);
            bestF1 = -inf; bestT = 0.5;
            for t = ths
                yhat = posScore >= t;
                TP = sum(yhat & Ytrue);
                FP = sum(yhat & ~Ytrue);
                FN = sum(~yhat & Ytrue);
                P  = TP / max(1, (TP+FP));
                R  = TP / max(1, (TP+FN));
                F1 = 2*P*R / max(1e-9, (P+R));
                if F1 > bestF1
                    bestF1 = F1;
                    bestT  = t;
                end
            end

            bestThreshold = bestT;
            fprintf('Chosen threshold=%.2f (F1=%.2f)\n', bestThreshold, bestF1);

        catch ME
            warning('Threshold selection failed: %s', ME.message);
        end

        save(target,'bestThreshold','-append');

    else
        target = fullfile(path,['netLSTM_' name '.mat']);
        load(target);
        disp('Loading LSTM network ...');
        fprintf('------\n');
    end

    % ================= ASSEMBLY =================
    if trainingParam.assemble_network || ~exist([path '/' name '.mat'],"file")
        disp('Assembling full network ...');
        fprintf('------\n');

        if isa(netCNN, 'dlnetwork')
            lgraphCNN = layerGraph(netCNN);
        else
            lgraphCNN = layerGraph(netCNN);
        end

        cnnLayers = lgraphCNN;

        switch trainingParam.CNN_network{end}
            case 'googlenet', baseInput = "conv1-7x7_s2";  layerName2 = "pool5-7x7_s1";
            case 'resnet50',  baseInput = "conv1";         layerName2 = "avg_pool";
            case 'resnet18',  baseInput = "conv1";         layerName2 = "pool5";
            case {'inceptionresnetv2','inceptionv3'}, baseInput = "conv2d_1"; layerName2 = "avg_pool";
            otherwise, error('Unsupported backbone: %s', trainingParam.CNN_network{end});
        end

        isInput = arrayfun(@(L) isa(L,'nnet.cnn.layer.ImageInputLayer'), cnnLayers.Layers);
        oldInputs = {cnnLayers.Layers(isInput).Name};
        if ~isempty(oldInputs), cnnLayers = removeLayers(cnnLayers, oldInputs); end

        names = string({cnnLayers.Layers.Name});
        toVisit = string(layerName2); toVisit = toVisit(:);
        desc    = strings(0,1);

        while ~isempty(toVisit)
            src = toVisit(1);
            toVisit(1) = [];

            mask = strcmp(cnnLayers.Connections.Source, src);
            kids = string(cnnLayers.Connections.Destination(mask));
            kids = kids(:);

            newKids = setdiff(kids, [desc; string(layerName2)]);
            newKids = newKids(:);

            desc = unique([desc; kids], 'stable');

            if ~isempty(newKids)
                toVisit = union(toVisit, newKids, 'stable');
                toVisit = toVisit(:);
            end
        end

        desc = setdiff(desc, layerName2);
        desc = intersect(desc, names);
        if ~isempty(desc)
            cnnLayers = removeLayers(cnnLayers, cellstr(desc));
        end

        inputLayer = sequenceInputLayer([inputSize 3], 'Normalization','zerocenter', ...
            'Mean', netCNN.Layers(1).Mean, 'Name','input');
        layersAdd = [ inputLayer; sequenceFoldingLayer('Name','fold') ];
        lgraph = addLayers(cnnLayers, layersAdd);

        lgraph = connectLayers(lgraph,"fold/out", baseInput);

        if isa(netLSTM, 'dlnetwork')
            lgraphLSTM = layerGraph(netLSTM);
        else
            lgraphLSTM = layerGraph(netLSTM);
        end

        lstmLayersFull = lgraphLSTM.Layers;
        lstmLayersFull(1) = [];

        % --- Split LSTM layers ---
%bilstmLayerObj = lstmLayersFull(1);     % bilstm
%otherLstmTail  = lstmLayersFull(2:end); % dropout + fc + ...

%nh=trainingParam.LSTM_hidden_size;
% layersTail = [ ...
%     sequenceUnfoldingLayer('Name','unfold'); ...
%     flattenLayer('Name','flatten'); ...
%     deltaFeatureLayer('deltaFeatures'); ...
%     bilstmLayerObj; ...
%     temporalAttentionLayer('temporalAttention', 2*nh); ...
%     otherLstmTail ...
% ];

layersTail = [ ...
    sequenceUnfoldingLayer('Name','unfold'); ...
    flattenLayer('Name','flatten'); ...
    deltaFeatureLayer('deltaFeatures'); ...
    lstmLayersFull ...
];

% layersTail = [ ...
%     sequenceUnfoldingLayer('Name','unfold'); ...
%     flattenLayer('Name','flatten'); ...
%     lstmLayersFull ...
% ];



        lgraph = addLayers(lgraph, layersTail);

        lgraph = connectLayers(lgraph, layerName2, "unfold/in");
        lgraph = connectLayers(lgraph, "fold/miniBatchSize", "unfold/miniBatchSize");

        classifier = assembleNetwork(lgraph);
        save([path '/' name '.mat'],'classifier');
        fprintf('Full network is assembled !\n');
    else
        load([path '/' name '.mat']);
    end

    %if classif.localRunIsActive()
    extra = {};
    if exist(fullfile(classif.path,'CNN_info.mat'),'file'), extra{end+1} = fullfile(classif.path,'CNN_info.mat'); end
    if exist(fullfile(classif.path,'LSTM_info.mat'),'file'), extra{end+1} = fullfile(classif.path,'LSTM_info.mat'); end
    classif.runCopyArtifacts('ExtraFiles', extra);
    %end


  %  classif.runStop();

catch ME
    try
        classif.runMsg('FATAL: %s', ME.getReport('extended','hyperlinks','off'));
    catch
    end
    safeRunStop();
    rethrow(ME);
end

classif.runStop();
end

% -------------------- helpers --------------------

%end

function videoResized = centerCrop(video,inputSize)
videoResized = imresize(video,inputSize(1:2));
end

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
end

function ok = checkLSTMFormattedDataset(path, trainingParam, classif)
%CHECKLSTMFORMATTEDDATASET  Vérifie que le dataset LSTM existe
% et correspond bien au backend sélectionné (TIFF ou HDF5).
%
% ok = true  -> tout va bien
% ok = false -> dataset absent, message affiché, training doit s'arrêter

ok = false;

backendFmt = lower(trainingParam.Format_StorageBackend{end});

% Le formatter utilise en dur "trainingdataset" comme dossier racine
foldername = 'trainingdataset';

switch backendFmt
    case 'tiff'
        % Dossiers utilisés par la fonction de formatage
        imagesRoot     = fullfile(path, foldername, 'images');
        timeseriesRoot = fullfile(path, foldername, 'timeseries');

        % ---- Vérification existence dossier ----
        if ~isfolder(imagesRoot) || ~isfolder(timeseriesRoot)
            disp('No exported TIFF dataset found for LSTM backend = TIFF.');
            fprintf('Expected folders:\n  %s\n  %s\n', imagesRoot, timeseriesRoot);
            disp('Run "Format LSTM dataset" (backend = TIFF) first.');
            return;
        end

        % ---- Vérification .mat dans timeseries ----
        matList = dir(fullfile(timeseriesRoot,'*.mat'));
        if isempty(matList)
            disp('No .mat timeseries found in TIFF LSTM dataset.');
            fprintf('Checked in: %s\n', timeseriesRoot);
            disp('Run "Format LSTM dataset" (backend = TIFF) first.');
            return;
        end

        % ---- Vérification qu'il existe des TIFF dans au moins 1 classe ----
        hasAnyTiff = false;
        for c = 1:numel(classif.classes)
            clsDir = fullfile(imagesRoot, classif.classes{c});
            if ~isfolder(clsDir)
                continue;
            end

            tifList  = dir(fullfile(clsDir,'*.tif'));
            tiffList = dir(fullfile(clsDir,'*.tiff'));

            if ~isempty(tifList) || ~isempty(tiffList)
                hasAnyTiff = true;
                break;
            end
        end

        if ~hasAnyTiff
            disp('No TIFF images found in any class folder for LSTM backend = TIFF.');
            fprintf('Classes checked under: %s\n', imagesRoot);
            disp('Run "Format LSTM dataset" (backend = TIFF) first.');
            return;
        end

        ok = true;
        return;

    case 'hdf5'
 % Pour LSTM, le framebank HDF5 est du type <strid>_framebank_XXX.h5
        % On utilise le helper pour trouver un fichier EXISTANT ET LISIBLE.
        baseFB = fullfile(path, [classif.strid '_framebank.h5']);

        [h5File, info] = findExistingFramebank(baseFB); %#ok<NASGU> % info si besoin plus tard

        if isempty(h5File)
            disp('No usable HDF5 framebank (*.h5) found for LSTM backend = HDF5.');

            [fbFolder, fbBase] = fileparts(baseFB);
            fprintf('Searched in folder: %s\n', fbFolder);
            fprintf('With pattern: %s*.h5\n', fbBase);
            disp('Run "Format LSTM dataset" (backend = HDF5) first.');
            return;
        end

        fprintf('Found VALID HDF5 framebank for LSTM backend: %s\n', h5File);

        % Optionnel mais pratique : mémoriser le fichier dans l'objet classif
        try
            classif.h5FramebankFile = h5File;
        catch
            % si la propriété n'existe pas, on ignore
        end

        ok = true;

    otherwise
        warning('Unknown Format_StorageBackend: %s. Expected ''tiff'' or ''hdf5''.', backendFmt);
        return;
end
end

function trainingParam = updateLSTMTrainingParam(classif)
%UPDATELSTMTRAININGPARAM  Normalise et complète les champs de trainingParam
% pour assurer compatibilité ascendante + cohérence CNN/LSTM.
%
% Retourne trainingParam mis à jour (ou [] si erreur).
% Met aussi à jour classif.trainingParam.

trainingParam = classif.trainingParam;

% ---- Backward compatibility defaults ----
if ~isfield(trainingParam,'CNN_use_dropout');       trainingParam.CNN_use_dropout = true;  end
if ~isfield(trainingParam,'CNN_dropout');           trainingParam.CNN_dropout     = 0.5;   end
if ~isfield(trainingParam,'CNN_l2_regularization'); trainingParam.CNN_l2_regularization = 1e-5; end

% ---- Harmonisation rand_scale / crop_scale ----
if ~isfield(trainingParam,'CNN_rand_scale') && ~isfield(trainingParam,'CNN_crop_scale')
    trainingParam.CNN_rand_scale = [0.8 1.0];
    trainingParam.CNN_crop_scale = [0.8 1.0];
elseif ~isfield(trainingParam,'CNN_rand_scale') && isfield(trainingParam,'CNN_crop_scale')
    trainingParam.CNN_rand_scale = trainingParam.CNN_crop_scale;
elseif ~isfield(trainingParam,'CNN_crop_scale') && isfield(trainingParam,'CNN_rand_scale')
    trainingParam.CNN_crop_scale = trainingParam.CNN_rand_scale;
end

if ~isfield(trainingParam,'CNN_rand_flip');         trainingParam.CNN_rand_flip         = true;          end
if ~isfield(trainingParam,'CNN_translation_augmentation'); trainingParam.CNN_translation_augmentation = [-5 5];  end
if ~isfield(trainingParam,'CNN_rotation_augmentation');     trainingParam.CNN_rotation_augmentation     = [-20 20]; end

% ---- Paramètres photométriques CNN (alignés sur GoogleNetFun) ----
if ~isfield(trainingParam,'CNN_contrast_range');      trainingParam.CNN_contrast_range      = [1 1]; end
if ~isfield(trainingParam,'CNN_brightness_range');    trainingParam.CNN_brightness_range    = [0 0]; end
if ~isfield(trainingParam,'CNN_gamma_range');         trainingParam.CNN_gamma_range         = [1 1];    end
if ~isfield(trainingParam,'CNN_saturation_range');    trainingParam.CNN_saturation_range    = [1 1]; end
if ~isfield(trainingParam,'CNN_hue_delta');           trainingParam.CNN_hue_delta           = 0;        end
if ~isfield(trainingParam,'CNN_noise_sigma');         trainingParam.CNN_noise_sigma         = 0;        end
if ~isfield(trainingParam,'CNN_defocus_sigma_range'); trainingParam.CNN_defocus_sigma_range = [0 0];   end
if ~isfield(trainingParam,'CNN_defocus_prob');        trainingParam.CNN_defocus_prob        = 0;         end

% ---- Champs minority/windowing (compat ancienne syntaxe) ----
if ~isfield(trainingParam,'LSTM_minority_mode')
    if isfield(trainingParam,'minority_mode')
        trainingParam.LSTM_minority_mode = trainingParam.minority_mode;
    else
        trainingParam.LSTM_minority_mode = 'none';
    end
end

if ~isfield(trainingParam,'LSTM_minority_min_ratio')
    if isfield(trainingParam,'minority_min_ratio')
        trainingParam.LSTM_minority_min_ratio = trainingParam.minority_min_ratio;
    else
        trainingParam.LSTM_minority_min_ratio = 0.30;
    end
end

if ~isfield(trainingParam,'LSTM_minority_percentile')
    if isfield(trainingParam,'minority_percentile')
        trainingParam.LSTM_minority_percentile = trainingParam.minority_percentile;
    else
        trainingParam.LSTM_minority_percentile = 0.00;
    end
end

if ~isfield(trainingParam,'LSTM_pos_neg_ratio')
    if isfield(trainingParam,'pos_neg_ratio')
        trainingParam.LSTM_pos_neg_ratio = trainingParam.pos_neg_ratio;
    else
        trainingParam.LSTM_pos_neg_ratio = 1.0;
    end
end

if ~isfield(trainingParam,'LSTM_win_stride_pos_frac')
    if isfield(trainingParam,'win_stride_pos_frac')
        trainingParam.LSTM_win_stride_pos_frac = trainingParam.win_stride_pos_frac;
    else
        trainingParam.LSTM_win_stride_pos_frac = 0.10;
    end
end

if ~isfield(trainingParam,'LSTM_win_stride_neg_frac')
    if isfield(trainingParam,'win_stride_neg_frac')
        trainingParam.LSTM_win_stride_neg_frac = trainingParam.win_stride_neg_frac;
    else
        trainingParam.LSTM_win_stride_neg_frac = 1.00;
    end
end

if ~isfield(trainingParam,'LSTM_keep_valid_distrib')
    if isfield(trainingParam,'keep_valid_distrib')
        trainingParam.LSTM_keep_valid_distrib = trainingParam.keep_valid_distrib;
    else
        trainingParam.LSTM_keep_valid_distrib = true;
    end
end

% ---- Defaults pour la partie Format_* ----
if ~isfield(trainingParam,'Format_Fraction');            trainingParam.Format_Fraction            = 1.0;      end
if ~isfield(trainingParam,'Format_Seed');                trainingParam.Format_Seed                = 12345;    end
if ~isfield(trainingParam,'Format_Crop');                trainingParam.Format_Crop                = false;    end
if ~isfield(trainingParam,'Format_CropCenter');          trainingParam.Format_CropCenter          = [88 194]; end
if ~isfield(trainingParam,'Format_CropSize');            trainingParam.Format_CropSize            = [60 60];  end
if ~isfield(trainingParam,'Format_UndersampleMajority'); trainingParam.Format_UndersampleMajority = 1.0;      end
if ~isfield(trainingParam,'Format_StorageBackend');      trainingParam.Format_StorageBackend      = {'hdf5','tiff','hdf5'}; end

% ---- Retour + mise à jour classif.trainingParam ----
classif.trainingParam = trainingParam;

if numel(trainingParam)==0
    disp('Could not find training parameters : first launch train with an extra argument to force parameter assignment');
    trainingParam = [];
    return;
end
end


function inputSizeHW = getCNNInputSize(netCNN, trainingParam)
%GETCNNINPUTSIZE  Récupère [H W] à partir de la couche d'input image.
%
% 1) Cherche une ImageInputLayer dans netCNN.
% 2) Si aucune trouvée, reconstruit un backbone à partir de
%    trainingParam.CNN_network{end} pour déduire InputSize.
% 3) Lève une erreur explicite en dernier recours.

% --- Étape 1 : essayer d'extraire l'input du réseau fourni ---
layers = [];
if isa(netCNN,'SeriesNetwork') || isa(netCNN,'DAGNetwork')
    layers = netCNN.Layers;
elseif isa(netCNN,'nnet.cnn.LayerGraph')
    layers = netCNN.Layers;
elseif isstruct(netCNN) && isfield(netCNN,'Layers')
    layers = netCNN.Layers;
end

if ~isempty(layers)
    isInput = arrayfun(@(L) isa(L,'nnet.cnn.layer.ImageInputLayer'), layers);
    idx = find(isInput, 1, 'first');
    if ~isempty(idx)
        sz = layers(idx).InputSize;   % [H W C]
        inputSizeHW = sz(1:2);
        return;
    end
end

% --- Étape 2 : fallback via l'architecture déclarée dans trainingParam ---
if nargin >= 2 && isfield(trainingParam,'CNN_network') && ~isempty(trainingParam.CNN_network)
    netName = trainingParam.CNN_network{end};
    try
        backbone = eval(netName);  % ex: googlenet, resnet50, ...
        if isa(backbone,'SeriesNetwork') || isa(backbone,'DAGNetwork')
            layersB = backbone.Layers;
        elseif isa(backbone,'nnet.cnn.LayerGraph')
            layersB = backbone.Layers;
        else
            layersB = [];
        end

        if ~isempty(layersB)
            isInputB = arrayfun(@(L) isa(L,'nnet.cnn.layer.ImageInputLayer'), layersB);
            idxB = find(isInputB, 1, 'first');
            if ~isempty(idxB)
                sz = layersB(idxB).InputSize;
                inputSizeHW = sz(1:2);
                warning('getCNNInputSize:Fallback', ...
                    ['No ImageInputLayer found in supplied CNN; ', ...
                    'using backbone "%s" to infer InputSize = [%d %d].'], ...
                    netName, inputSizeHW(1), inputSizeHW(2));
                return;
            end
        end
    catch ME
        warning('getCNNInputSize:FallbackFailed', ...
            'Failed to instantiate backbone %s to infer InputSize (%s).', ...
            netName, ME.message);
    end
end

error(['Could not determine CNN input size: ', ...
    'no ImageInputLayer in provided CNN, and fallback on CNN_network failed.']);

end

function featSeq = computeCNNActivationsFromBackbone(netCNN, video4D, layerName)
% computeCNNActivationsFromBackbone
%   Unifie le calcul des features CNN pour :
%     - un vieux CNN type SeriesNetwork / DAGNetwork  -> activations(...)
%     - un nouveau CNN type dlnetwork                 -> forward(..., 'Outputs', layerName)
%
%   video4D : [H W C T]  (T = nb de frames)
%   featSeq : [numFeatures x T]  (comme 'OutputAs','columns' avant)

    % Sécurité type
    if ndims(video4D) ~= 4
        error('video4D must be HxWxCxT (4D array).');
    end

    if isa(netCNN, 'dlnetwork')
        % === Nouveau cas : CNN stocké comme dlnetwork (trainnet) ===
        %
        % On assume que le layer "layerName" est un global pooling
        % (1x1xF) au-dessus duquel on a mis la tête de classification.
        % On récupère donc les activations [1 1 F T] puis on reshape
        % en [F x T].

        % Convertir en single si besoin
        X = single(video4D);           % [H W C T]
        dlX = dlarray(X, 'SSCB');      % S=H, S=W, C=canaux, B=temps

        % forward jusqu'au layer intermédiaire
        dlZ = forward(netCNN, dlX, 'Outputs', layerName);

        % Récupérer les données
        Z = extractdata(dlZ);          % attendu: [1 1 F T] ou [H' W' F T]

        sz = size(Z);
        if numel(sz) < 4
            error('Unexpected activation size at layer "%s" from dlnetwork.', layerName);
        end

        % Cas habituel : global pooling -> [1 1 F T]
        % On reformatte en [F x T]
        numF  = sz(3);
        seqLen = sz(4);
        featSeq = reshape(Z, [numF seqLen]);

    else
        % === Cas legacy : SeriesNetwork / DAGNetwork ===
        featSeq = activations(netCNN, video4D, layerName, 'OutputAs','columns');
    end

end

    % =========================================================================
% === Nested helper functions pour la gestion robuste du framebank CNN ====
% =========================================================================

    function tf = tryDeleteSafe(fpath)
        % Essaye de supprimer 'fpath' et vérifie qu'il a vraiment disparu.
        % Renvoie true si supprimé ou absent, false si encore présent.
        tf = false;
        if ~exist(fpath, 'file')
            tf = true;    % déjà absent
            return;
        end

        try
            delete(fpath);
        catch
            % delete() a échoué -> fichier suspect/locké
            return;
        end

        % Attente brève (filesystem / cache / NFS)
        for kk = 1:20
            pause(0.05); % 50 ms
            if ~exist(fpath, 'file')
                tf = true;
                return;
            end
        end

        % Toujours présent -> fichier vérolé / fantôme
        tf = false;
    
    end

  

