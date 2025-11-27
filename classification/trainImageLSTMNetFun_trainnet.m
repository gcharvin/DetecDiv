
function trainImageLSTMNetFun_trainnet(classif,setparam)

path=fullfile(classif.path);
name=classif.strid;

%---------------- parameters setting
if nargin==2 % basic parameter initialization

    tip = { ...
        'Check box to train CNN',...                                                              % train_CNN_classifier
        'Check box to compute CNN activations',...                                               % compute_CNN_activations
        'Check box to train the LSTM network',...                                                % train_LSTM_network
        'Check box to asssemble the CNN and LSTM networks',...                                   % assemble_network
        'Specify if each frame should be classified, or if one class is expected for the whole sequence of images',... % classifier_output
        'Choose the training method',...                                                         % CNN_training_method
        'Choose the CNN',...                                                                     % CNN_network
        'Choose the size of the mini batch; Higher values require more memory and are prone to errors',... % CNN_mini_batch_size
        'Enter the number of epochs',...                                                         % CNN_max_epochs
        'Enter the initial learning rate',...                                                    % CNN_initial_learning_rate
        'Enter the learning rate drop factor',...                                                % CNN_learn_rate_drop_factor
        'Choose whether and how training and validation data should be shuffled during training',... % CNN_data_shuffling
        'Enter fraction of the data to be used for training vs validation during training',...   % CNN_data_splitting_factor
        'Enter the magnitude of translation for data augmentation (in pixels)',...               % CNN_translation_augmentation
        'Enter the magnitude of rotation for data augmentation (in degrees)',...                 % CNN_rotation_augmentation
        'Specify value for L2 regularization',...                                                % CNN_l2_regularization
        'Check to use a dropout layer',...                                                       % CNN_use_dropout
        'Value for dropout regularization',...                                                   % CNN_dropout
        'Range of random scale factor for CNN augmentation (e.g. [0.8 1.0])', ...                % CNN_rand_scale
        'Enable random flips (left/right & up/down) during CNN augmentation', ...                % CNN_rand_flip
        'Crop-in scale range for CNN augmentation (e.g. [0.8 1.0])', ...                         % CNN_crop_scale
        'Contrast multiplier range for CNN augmentation (e.g. [0.85 1.15])', ...                 % CNN_contrast_range
        'Brightness offset range (additive, e.g. [-0.10 0.10])', ...                             % CNN_brightness_range
        'Gamma exponent range for CNN augmentation (e.g. [0.9 1.1])', ...                        % CNN_gamma_range
        'Saturation multiplier range (RGB only, e.g. [0.95 1.05])', ...                          % CNN_saturation_range
        'Maximum hue jitter (0–0.5, small values recommended)', ...                              % CNN_hue_delta
        'Std-dev of Gaussian noise for CNN augmentation (set 0 to disable)', ...                 % CNN_noise_sigma
        'Defocus sigma range in pixels (e.g. [0.3 1.0])', ...                                    % CNN_defocus_sigma_range
        'Probability to apply defocus blur (e.g. 0.5)', ...                                      % CNN_defocus_prob
        'Choose the fraction of the data to be used for training vs validation during LSTM training',... % LSTM_data_splitting_factor
        'Enter the size of the hidden unit',...                                                  % LSTM_hidden_size
        'Choose the size of the mini batch for LSTM training; Higher values require more memory and are prone to errors',... % LSTM_mini_batch_size
        'Enter the LSTM initial learning rate',...                                               % LSTM_initial_learning_rate
        'Enter the number of epochs for LSTM training',...                                       % LSTM_max_epochs
        'Enter the length of the sequences in frames; put 0 if all frames should be used upon training',... % LSTM_sequence_length
        'Enter the dropping factor in learning rate',...                                         % LSTM_learn_rate_drop_factor
        'Choose execution environment',...                                                       % execution_environment
        'Select initial version of network to start training with; Default: ImageNet',...        % transfer_learning
        'Minority balancing mode (none/auto)',...                                % LSTM_minority_mode
        'Activate balancing if min/max ratio ≤ this value',...                   % LSTM_minority_min_ratio
        'Percentile for multi-minority selection (0=off)',...                    % LSTM_minority_percentile
        '#Negatives per #Positives windows (e.g. 1 = 1:1)',...                   % LSTM_pos_neg_ratio
        'Positive window stride as a fraction of L',...                          % LSTM_win_stride_pos_frac
        'Negative window stride as a fraction of L',...                          % LSTM_win_stride_neg_frac
        'Keep validation distribution unbalanced (true/false)',...               % LSTM_keep_valid_distrib
        'Fraction of ROIs used when formatting the LSTM training set', ...       % Format_Fraction
        'Random seed used when sampling ROIs / frames for formatting', ...       % Format_Seed
        'Enable cropping when formatting the LSTM training set (true/false)',... % Format_Crop
        'Crop center [cx cy] used for formatting the LSTM training set', ...     % Format_CropCenter
        'Crop size [w h] used for formatting the LSTM training set', ...         % Format_CropSize
        'Undersample majority classes (1 = no undersampling)', ...               % Format_UndersampleMajority
        'Storage backend for formatted data (''hdf5'' or ''tiff'')' ...          % Format_StorageBackend
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
        'CNN_rand_scale',[0.8 1.0], ...             % harmonisé avec GoogleNetFun
        'CNN_rand_flip',true, ...                   % flips aléatoires
        'CNN_crop_scale',[0.8 1.0], ...             % crop-in (HDF5) / zoom (TIFF)
        'CNN_contrast_range',[1 1], ...       % contraste multiplicatif
        'CNN_brightness_range',[0 0], ...    % offset additif
        'CNN_gamma_range',[1 1], ...            % gamma exponent
        'CNN_saturation_range',[1 1], ...     % saturation HSV
        'CNN_hue_delta',0, ...                   % jitter de teinte
        'CNN_noise_sigma',0, ...                 % bruit gaussien
        'CNN_defocus_sigma_range',[0 0], ...    % flou gaussien (px)
        'CNN_defocus_prob',0, ...                 % probabilité de flou
        'LSTM_data_splitting_factor',0.9,...
        'LSTM_hidden_size',150,...
        'LSTM_mini_batch_size',8,...
        'LSTM_initial_learning_rate', 1e-4,...
        'LSTM_max_epochs', 50,...
        'LSTM_sequence_length', 40,...
        'LSTM_learn_rate_drop_factor', 0.9,...
        'execution_environment',{{'auto','parallel','cpu','gpu','multi-gpu','auto'}},...
        'transfer_learning',{{'ImageNet','ImageNet'}},...
        'LSTM_minority_mode','none',...            % 'none' (par défaut) ou 'auto'
        'LSTM_minority_min_ratio',0.30,...         % activer si min/max ≤ 0.30 : if rare minority events, then use specific augmentation of sequences
        'LSTM_minority_percentile',0.00,...        % 0 = off ; sinon ex 0.20
        'LSTM_pos_neg_ratio',1.0,...               % #negatives per #positives (fenêtres)
        'LSTM_win_stride_pos_frac',0.10,...        % stridePos = L*0.10 : if minority class, then use a lot of sequences to augment positive cases
        'LSTM_win_stride_neg_frac',1.00,...        % strideNeg = L*1.00 : if not minority class, use normal shift between sequences
        'LSTM_keep_valid_distrib',true,...
        'Format_Fraction',1.0, ...                 % fraction de ROIs à utiliser
        'Format_Seed',12345, ...                   % seed RNG pour la sélection
        'Format_Crop',false, ...                   % activer/désactiver le crop
        'Format_CropCenter',[88 194], ...          % [cx cy]
        'Format_CropSize',[60 60], ...             % [w h]
        'Format_UndersampleMajority',1.0, ...      % 1 = pas d'undersampling
        'Format_StorageBackend',{{'hdf5','tiff','hdf5'}}, ...  % 'hdf5' ou 'tiff'
        'tip',{tip});
    return;



else
    trainingParam = updateLSTMTrainingParam(classif);
end
%-----------------------------------%


classif.displayTrainingParam();
blockRNG=1;

if ~checkLSTMFormattedDataset(classif.path, trainingParam, classif)
    return;
end

fprintf('------\n');

%%% training image classifier
%------------------------------------------
%  CNN backbone : train / load + InputSize
%------------------------------------------

netCNN = [];

if trainingParam.train_CNN_classifier

    if strcmp(trainingParam.transfer_learning{end},'ImageNet')
        trainImageGoogleNetFun_trainnet(classif); % trainImageGoogle net first and saves it as netCNN.mat in the LSTM dir
    else
        src=fullfile(classif.path,['netCNN_' trainingParam.transfer_learning{end}]);
        if exist(src)
            load(src); %loads classifier
        else
            disp(['Unable to load: ' trainingParam.transfer_learning{end}]);
            return;
        end
        trainImageGoogleNetFun_trainnet(classif,'ok',classifier);
    end

    target=fullfile(path,['netCNN_' name '.mat']);
    source=fullfile(path,[name '.mat']);

    if ~exist(source)
        disp('Trained CNN does not exist; quitting !');
        return;
    end

    copyfile(source,target); % copies the trained CNN classifieer so that it can later be assembled to the lstm network
end

fprintf('Loading Image classifier...\n');
fprintf('------\n');
str=fullfile(path,['netCNN_' name '.mat']);

if exist(str)
    load(str); % load the image classifier
    netCNN=classifier;
else
    disp('unable to find CNN classifier; first train the CNN classifier; quitting ...!');
    return;
end

% % 1) Si on doit entraîner le CNN dans ce run
% if isfield(trainingParam,'train_CNN_classifier') && trainingParam.train_CNN_classifier
%     fprintf('Training CNN classifier (train_CNN_classifier = true)...\n');
%
%     % Ici tu as deux options :
%     %   - soit tu appelles directement trainImageGoogleNetFun
%     %   - soit tu laisses ton code existant qui entraîne le CNN
%     %
%     % Exemple si tu utilises trainImageGoogleNetFun :
%
%     trainImageGoogleNetFun(classif, true);  % ou setparam si nécessaire
%
%
%     % Après training, on s'attend à trouver un fichier <name>.mat avec 'classifier'
%     cnnFile = fullfile(path, [name '.mat']);
%     if exist(cnnFile,'file')
%         S = load(cnnFile);
%         if isfield(S,'classifier')
%             netCNN = S.classifier;
%         else
%             warning('File %s loaded but no ''classifier'' variable found.', cnnFile);
%         end
%     else
%         warning('CNN training supposedly done, but no classifier file found at %s.', cnnFile);
%     end
%
% else
%     % 2) Cas où train_CNN_classifier = false :
%     %    on tente de recharger un CNN déjà entraîné
%     fprintf('train_CNN_classifier = false -> trying to load existing CNN classifier from disk...\n');
%     cnnFile = fullfile(path, [name '.mat']);
%     if exist(cnnFile,'file')
%         S = load(cnnFile);
%         if isfield(S,'classifier')
%             netCNN = S.classifier;
%         else
%             warning('Existing CNN file %s does not contain variable ''classifier''.', cnnFile);
%         end
%     else
%         warning('No existing CNN classifier file found at %s.', cnnFile);
%     end
% end
%
% % 3) Si malgré tout on n'a pas de CNN valide -> on stoppe proprement
% if isempty(netCNN)
%     disp('No CNN backbone available (training skipped or load failed).');
%     disp('Cannot compute activations / InputSize for LSTM. Aborting training.');
%     return;
% end
%
%
% % 4) Récupération robuste de la taille d'entrée [H W]
% inputSizeHW = getCNNInputSize(netCNN);   % helper ci-dessous
% inputSize   = [inputSizeHW 3];           % si tu as besoin de [H W C] ailleurs


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

    backend = trainingParam.Format_StorageBackend{end};

    h5SeriesFile = fullfile(path,[classif.strid,'_framebank.h5']);
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
    fprintf('Scanning labels to detect minority classes...\n');

    allCats = [];
    totalCounts = [];

    for ii = 1:numFiles
        progressBar(ii, numFiles, ['Prescanning ROIs']);

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

        % min unique by default
        [~, idxMin] = min(totalCounts);
        minorityClasses = allCats(idxMin);

        % percentile option (multi-minority)
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

    % --------------------------------------------------------------------

    for i = 1:numFiles
        if useH5Series
            % Nom de la série/ROI (si dispo dans le HDF5)
            roiName = '';
            if numel(h5SeriesIds) >= i
                roiName = char(h5SeriesIds(i));
            end
            if isempty(roiName)
                roiName = sprintf('#%d', i);
            end

            % Message de progression en une seule ligne
            %msg = sprintf('Processing series %d/%d (%s)...', i, numFiles, roiName);
            %fprintf('%s%s', reverseStr, msg);
            %reverseStr = repmat(sprintf('\b'), 1, length(msg));


            progressBar(i, numFiles, ['Computing activations (hdf5) : ' roiName]);

            % --- lecture des données HDF5 ---
            nbFra    = h5SeriesLen(i);
            idxStart = h5SeriesStart(i);
            idxEnd   = idxStart + nbFra - 1;

            if isempty(h5FrameDS)
                video = h5read(h5SeriesFile, '/frames', ...
                    [1 1 1 idxStart], ...
                    [frameSizeH5(1) frameSizeH5(2) frameSizeH5(3) nbFra]);
            else
                dsSeq = subset(h5FrameDS, idxStart:idxEnd);
                video = readH5Sequence(dsSeq, frameSizeH5);
            end

            startIdx = double(h5SeriesStart(i));
            lenSeq   = double(nbFra);

            labs = h5read(h5SeriesFile, '/labels', ...
                [1 startIdx], ...
                [1 lenSeq]);
            lab = categorical(labs(:), 1:numel(classif.classes), classif.classes);

        else
            % Optionnel : afficher aussi le nom du fichier .mat
            [~, baseName, ~] = fileparts(fullfile(list(i).folder, list(i).name));
            %msg = sprintf('Processing movie %d/%d (%s)...', i, numFiles, baseName);
            %fprintf('%s%s', reverseStr, msg);
            %reverseStr = repmat(sprintf('\b'), 1, length(msg));


            progressBar(i, numFiles, ['Computing activations (mat) : ' list(i).name]);

            % --- lecture des données MAT ---
            S = load(fullfile(list(i).folder, list(i).name));  % loads deep, vid, lab
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

        % Stride pour la construction initiale des fenêtres (fin, pour bien couvrir les positifs)
        if isfield(trainingParam,'LSTM_win_stride_pos_frac') && ~isempty(trainingParam.LSTM_win_stride_pos_frac)
            stridePos = max(1, round(L * trainingParam.LSTM_win_stride_pos_frac));
        else
            stridePos = max(1, floor(L/2));  % défaut : L/2
        end

        % Stride "effectif" souhaité pour les fenêtres négatives
        if isfield(trainingParam,'LSTM_win_stride_neg_frac') && ~isempty(trainingParam.LSTM_win_stride_neg_frac)
            strideNeg = max(1, round(L * trainingParam.LSTM_win_stride_neg_frac));
        else
            strideNeg = stridePos;  % par défaut identique
        end

        % --- 1. Construire toutes les fenêtres glissantes avec stridePos ---
        windows = [];
        if T <= L
            windows = [1 T];
        else
            for s = 1:stridePos:(T - L + 1)
                windows(end+1,:) = [s s+L-1]; %#ok<AGROW>
            end
            % dernière fenêtre alignée sur la fin si besoin
            if windows(end,2) < T
                windows(end+1,:) = [max(1,T-L+1) T]; %#ok<AGROW>
            end
        end

        if doBalance
            % ---- 2. Marquer les fenêtres contenant la/les classes minoritaires ----
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

            % ---- 3. Éclaircir les fenêtres négatives pour approx. strideNeg ----
            % facteur ~ strideNeg / stridePos
            if strideNeg > stridePos && size(negWins,1) > 1
                stepThin = max(1, round(strideNeg / stridePos));
                negWins  = negWins(1:stepThin:end, :);
            end

            % ---- 4. Sous-échantillonnage des NEG selon pos_neg_ratio ----
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
            % ---- Pas de minority mode : toutes les fenêtres glissantes ----
            % Ici, on n'a pas de notion de minoritaire, donc on garde la grille windows
            useWins = windows;
        end

        % ---- 5. Construction des séquences finales (inchangé) ----
        for w = 1:size(useWins,1)
            s = useWins(w,1);
            e = useWins(w,2);

            tmpvid = video(:,:,:,s:e);
            sequences{cc,1} = computeCNNActivationsFromBackbone(netCNN, tmpvid, layerName);

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

    % ==== Split TRAIN / VAL (inchangé) ====
    numObservations   = numel(sequences);
    idx               = randperm(numObservations);
    N                 = floor(trainingParam.LSTM_data_splitting_factor * numObservations);
    idxTrain          = idx(1:N);
    idxValidation     = idx(N+1:end);

    sequencesTrain       = sequences(idxTrain);
    labelsTrain          = labels(idxTrain);
    sequencesValidation  = sequences(idxValidation);
    labelsValidation     = labels(idxValidation);

    if strcmp(trainingParam.classifier_output{end},'sequence-to-one')
        labelsTrain      = [labelsTrain{:}]';
        labelsValidation = [labelsValidation{:}]';
    end

    % ==== Dimensions & classes ====
    numFeatures = size(sequencesTrain{1},1);
    numClasses  = numel(classif.classes);
    if numClasses==0
        disp('There is no classes defined ; Cannot continue !');
        return;
    end

    % ==== class weights (frame-level sommés sur toutes les séquences) ====
    sucl = zeros(numObservations, numClasses);
    for i = 1:numObservations
        sucl(i,:) = countcats( categorical(labels{i}, classif.classes) );
    end
    sucl = sum(sucl,1);
    tempsucl = sucl(sucl>0);
    sucl(sucl==0) = min(tempsucl(:));      % évite poids infinis
    classWeights = 1 ./ sucl;
    classWeights = classWeights' / mean(classWeights);

    fprintf('--- LSTM class weights ---\n');
    for k = 1:numClasses
        fprintf('  %s : w = %.3f\n', string(classif.classes{k}), classWeights(k));
    end
    fprintf('--------------------------\n');

    nh = trainingParam.LSTM_hidden_size;

    % ============================================================
    % 1) DÉFINITION DU LSTM "STANDARD" (plus de weightedLSTM...)
    % ============================================================
    if strcmp(trainingParam.transfer_learning{end},'ImageNet')
        if strcmp(trainingParam.classifier_output{end},'sequence-to-sequence')
            layers = [
                sequenceInputLayer(numFeatures,'Name','sequence')
                bilstmLayer(nh,'OutputMode','sequence','Name','bilstm')
                dropoutLayer(0.5,'Name','drop')
                fullyConnectedLayer(numClasses,'Name','fc')
                softmaxLayer('Name','softmax')
                classificationLayer('Name','classification')];
        else
            layers = [
                sequenceInputLayer(numFeatures,'Name','sequence')
                bilstmLayer(nh,'OutputMode','last','Name','bilstm')
                dropoutLayer(0.5,'Name','drop')
                fullyConnectedLayer(numClasses,'Name','fc')
                softmaxLayer('Name','softmax')
                classificationLayer('Name','classification')];
        end
    else
        % Cas transfer learning LSTM existant : on garde ton comportement
        src = fullfile(classif.path, ['netLSTM_' trainingParam.transfer_learning{end}]);
        if exist(src,"file")
            load(src);                     % charge netLSTM
            layers = netLSTM.Layers;
        else
            disp(['Unable to load LSTM network: ' trainingParam.transfer_learning{end}]);
            return;
        end
    end

    % ============================================================
    % 2) OPTIONS TRAINING (trainnet)
    % ============================================================
    miniBatchSize        = trainingParam.LSTM_mini_batch_size;
    numObservationsTrain = numel(sequencesTrain);
    numIterationsPerEpoch= max(1,floor(numObservationsTrain / miniBatchSize));
    patience             = 20;

       % ==== NORMALISATION DES LABELS POUR trainnet ====
    isSeq2Seq = strcmp(trainingParam.classifier_output{end},'sequence-to-sequence');

    if isSeq2Seq
        % Chaque entrée de labelsTrain / labelsValidation doit être T×1
        for i = 1:numel(labelsTrain)
            lab = labelsTrain{i};
            if isrow(lab)
                labelsTrain{i} = lab.';
            end
        end
        for i = 1:numel(labelsValidation)
            lab = labelsValidation{i};
            if isrow(lab)
                labelsValidation{i} = lab.';
            end
        end
    else
        % sequence-to-one : labelsTrain / labelsValidation sont déjà des vecteurs
        % (labelsTrain = [labelsTrain{:}]'; etc. plus haut)
        % Rien à faire ici.
    end

    % ============================================================
    % 2) OPTIONS TRAINING (trainnet)
    % ============================================================
    miniBatchSize        = trainingParam.LSTM_mini_batch_size;
    numObservationsTrain = numel(sequencesTrain);
    numIterationsPerEpoch= max(1,floor(numObservationsTrain / miniBatchSize));
    patience             = 20;

    % Format des données ENTRÉE uniquement (features x time -> "CBT")
    %   - séquences: C x T  (numFeatures x numTime)
    %   - batch: dimension B gérée par trainnet
    inputFmt = "CBT";

    options = trainingOptions("adam", ...
        "MiniBatchSize",        miniBatchSize, ...
        "MaxEpochs",            trainingParam.LSTM_max_epochs, ...
        "InitialLearnRate",     trainingParam.LSTM_initial_learning_rate, ...
        "LearnRateSchedule",    "piecewise", ...
        "LearnRateDropPeriod",  5, ...
        "LearnRateDropFactor",  trainingParam.LSTM_learn_rate_drop_factor, ...
        "Shuffle",              "every-epoch", ...
        "ValidationData",       {sequencesValidation, labelsValidation}, ...
        "ValidationFrequency",  numIterationsPerEpoch, ...
        "ValidationPatience",   patience, ...
        "Plots",                "training-progress", ...
        "ExecutionEnvironment", "auto", ...
        "VerboseFrequency",     10, ...
        "InputDataFormats",     inputFmt);   % *** PAS de TargetDataFormats ici ***

    % ============================================================
    % 3) PASSAGE EN dlnetwork + trainnet (avec class weights)
    % ============================================================
    lgraphLSTM = layerGraph(layers);

    % On enlève la classificationLayer pour le dlnetwork (comme pour le CNN)
    if any(strcmp({lgraphLSTM.Layers.Name},'classification'))
        lgraphDL = removeLayers(lgraphLSTM,'classification');
    else
        lgraphDL = lgraphLSTM;
    end

    % La sortie du réseau pour la loss = softmax
    outputLayerName = 'softmax';
    dlNetLSTM = dlnetwork(lgraphDL, "OutputNames", outputLayerName);

    % vectorisation des poids de classes (format attendu par crossentropy)
    classWeightsVec = single(classWeights(:)');   % 1 x C

    % Loss avec pondération de classes (crossentropy gère les cibles catégorielles)
    lossFcn = @(Y,T) crossentropy(Y, T, classWeightsVec);

    disp('Training LSTM network (trainnet) ...');
    fprintf('------\n');

    [dlNetLSTM, info] = trainnet(sequencesTrain, labelsTrain, dlNetLSTM, lossFcn, options);



    % ============================================================
    % 4) RECONSTRUCTION d'un DAGNetwork netLSTM pour le framework
    % ============================================================
    % On repart des couches entraînées dans dlNetLSTM, on réajoute
    % la classificationLayer et on assemble.
    lgraphTrained = layerGraph(dlNetLSTM.Layers);

    if ~any(strcmp({lgraphTrained.Layers.Name},'classification'))
        classLayer = classificationLayer('Name','classification');
        lgraphTrained = addLayers(lgraphTrained, classLayer);
        lgraphTrained = connectLayers(lgraphTrained, outputLayerName, 'classification');
    end

    netLSTM = assembleNetwork(lgraphTrained);

    % ==== Sauvegarde identique à avant ====
    target = fullfile(path,['netLSTM_' name '.mat']);
    save(target,'netLSTM','info');
    disp('Training LSTM network is done and saved ...');
    fprintf('------\n');

    % ============================================================
    % 5) Recherche du meilleur threshold (inchangée)
    % ============================================================
    bestThreshold = 0.5;
    try
        classes = classif.classes;
        posName = classes{min(2,numel(classes))}; % classe 2 par défaut

        if strcmp(trainingParam.classifier_output{end},'sequence-to-one')
            scoreVal = predict(netLSTM, sequencesValidation, 'MiniBatchSize', miniBatchSize);
            posIdx   = find(strcmp(classes, posName));
            posScore = scoreVal(:, posIdx);
            Ytrue    = double(labelsValidation == categorical(posName));
        else
            scoreVal = predict(netLSTM, sequencesValidation, 'MiniBatchSize', miniBatchSize);
            posIdx   = find(strcmp(classes, posName), 1);
            if isempty(posIdx)
                error('posName "%s" not found in classes.', posName);
            end
            posScore = [];
            Ytrue    = [];
            posCat   = categorical(posName, classes, classes);

            for i = 1:numel(scoreVal)
                thisScore = scoreVal{i}(:, posIdx);
                thisLab   = labelsValidation{i};
                posScore  = [posScore; thisScore(:)]; %#ok<AGROW>
                Ytrue     = [Ytrue;  double(thisLab(:) == posCat)]; %#ok<AGROW>
            end
        end

        ths = linspace(0,1,101);
        bestF1 = -inf; bestT = 0.5;
        for t = ths
            yhat = posScore >= t;
            TP = sum(yhat & Ytrue); FP = sum(yhat & ~Ytrue);
            FN = sum(~yhat & Ytrue);
            P  = TP / max(1, (TP+FP));
            R  = TP / max(1, (TP+FN));
            F1 = 2*P*R / max(1e-9, (P+R));
            if F1 > bestF1, bestF1 = F1; bestT = t; end
        end
        bestThreshold = bestT;
        fprintf('Chosen threshold=%.2f (F1=%.2f)\n', bestThreshold, bestF1);
    catch ME
        warning('Threshold selection failed: %s', ME.message);
    end

    % On écrase le fichier pour inclure bestThreshold
    save(target,'netLSTM','info','bestThreshold');

else
    % ==== Cas "pas de nouvel entraînement" : on recharge ====
    target = fullfile(path,['netLSTM_' name '.mat']);
    load(target);
    disp('Loading LSTM network ...');
    fprintf('------\n');
end



%%% ================= ASSEMBLY =================
if trainingParam.assemble_network || ~exist([path '/' name '.mat'],"file")
    disp('Assembling full network ...');
    fprintf('------\n');

if isa(netCNN, 'dlnetwork')
    % R2024b : conversion directe d'un dlnetwork en layerGraph
    lgraphCNN = layerGraph(netCNN);
else
    % Cas legacy : SeriesNetwork / DAGNetwork
    lgraphCNN = layerGraph(netCNN);
end

    cnnLayers = lgraphCNN;

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
        % Pour LSTM, framebank.h5 est à la racine de la classif
        h5File = fullfile(path, [classif.strid '_framebank.h5']);

        if ~exist(h5File, 'file')
            disp('HDF5 framebank.h5 not found for LSTM backend = HDF5.');
            fprintf('Expected file: %s\n', h5File);
            disp('Run "Format LSTM dataset" (backend = HDF5) first.');
            return;
        end

        ok = true;
        return;

    otherwise
        warning('Unknown Format_StorageBackend: %s. Expected ''tiff'' or ''hdf5''.', backendFmt);
        return;
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

