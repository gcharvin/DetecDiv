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
            'Choose whether and how training and validation data should be shuffled during training',...
            'Enter fraction of the data to be used for training vs validation during training',...
            'Enter the magnitude of translation for data augmentation (in pixels)',...
            'Enter the magnitude of rotation for data augmentation (in pixels)',...
            'Specify value for L2 regularization',...
            'Choose execution environment',...
            'Choose the fraction of the data to be used for training vs validation during LSTM training',...
            'Enter the size of the hidden unit',...
            'Choose the size of the mini batch for LSTM training; Higher values require more memory and are prone to errors',...
            'Enter the LSTM initial learning rate',...
            };
        
        classif.trainingParam=struct('train_CNN_classifier',true,...
            'compute_CNN_activations',true,...
            'train_LSTM_network',true,...
            'assemble_network',true,...
            'classifier_output',{{'sequence-to-sequence','sequence-to-one','sequence-to-sequence'}},...
            'CNN_training_method',{{'adam','sgdm','adam'}},...
            'CNN_network',{{'googlenet','resnet50','googlenet'}},...
            'CNN_mini_batch_size',8,...
            'CNN_max_epochs',6,...
            'CNN_initial_learning_rate',0.0003,...
            'CNN_data_shuffling',{{'once','every-epoch','never','every-epoch'}},...
            'CNN_data_splitting_factor',0.7,...
            'CNN_translation_augmentation',[-5 5],...
            'CNN_rotation_augmentation',[-20 20],...
            'CNN_l2_regularization',0.00001,...
            'LSTM_data_splitting_factor',0.9,...
            'LSTM_hidden_size',150,...
            'LSTM_mini_batch_size',8,...
            'LSTM_initial_learning_rate', 0.0001,...
            'execution_environment',{{'auto','parallel','cpu','gpu','multi-gpu','auto'}},...
            'tip',{tip});
        
        return;
        %   end
    else
        trainingParam=classif.trainingParam;
        
        if numel(trainingParam)==0
            disp('Could not find training parameters : first launch train with an extra argument to force parameter assignment');
            return;
        end
        
    end
    %-----------------------------------%
    
    
    blockRNG=0;
    fprintf('Loading training options...\n');
    fprintf('------\n');
    
    
    %load([ path '/options.mat']); % loading options for training --> imageclassifier, cactivations, lstm_training, assemblenet, validation
    
  
    %%% training image classifier
    
    if trainingParam.train_CNN_classifier
        feval('trainImageGoogleNetFun',classif); % trainImageGoogle net first and saves it as netCNN.mat in the LSTM dir
        % corresponding variable name is 'classifier'
        copyfile(fullfile(path,[name '.mat']),fullfile(path,'netCNN.mat')); % copies the trained CNN classifieer so that it can later be assembled to the lstm network
    end
    
    
    fprintf('Loading Image classifier...\n');
    fprintf('------\n');
    str=fullfile(path,'netCNN.mat');
    
    if exist(str)
        load(str); % load the image classifier
        netCNN=classifier;
    else
        disp('unable to find CNN classifier; first train the CNN classifier; quitting ...!');
        return;
    end
    
    %%% Calculate activations from the image classifier network based on the training
    %%% set
    
    % load and format data as sequences of vectors using spepcific network
    % layer
    
    inputSize = netCNN.Layers(1).InputSize(1:2);
    
    if strcmp(trainingParam.CNN_network{end},'googlenet')
        layerName = "pool5-7x7_s1"; % layer id where the network will be connected
    end
    if strcmp(trainingParam.CNN_network{end},'resnet50')
        layerName = "avg_pool"; % layer id where the network will be connected
    end
    % if strcmp(trainingParam.CNN_network{end},'efficientnetb0')
    %     layerName = "pool5-7x7_s1"; % layer id where the network will be connected
    % end
    
    tempFile = [path '/' name '_image_classifier_activations.mat'];
    
    if trainingParam.compute_CNN_activations==false && exist(tempFile)  % if acitvations already exist
        fprintf('Loading Image classifier activation data...\n');
        fprintf('------\n');
        
        load(tempFile,"sequences","labels"); % loads vid, lab, deep variables
        % label in an array of categorical labels, vid is a video file of uint8
    else % compute acitvations for input data
        fprintf('Computing Image classifier activation data...\n');
        fprintf('------\n');
        
        cc=1;
        
        % load all the files in the timeseries
        fol= [path '/trainingdataset/timeseries'];
        list=dir([fol '/*.mat']);
        numFiles = numel(list);
        sequences = cell(numFiles,1);
        labels = cell(numFiles,1);
        
        for i=1:numel(list)
            fprintf(['Processing movie ' num2str(i) '...']);
            load([list(i).folder '/' list(i).name]); % loads deep, vid, lab (categories of labels)
            video = centerCrop(vid,inputSize);
            sequences{cc,1} = activations(netCNN,video,layerName,'OutputAs','columns');
            labels{cc,1}= lab;
            cc=cc+1;
            fprintf('\n');
        end
        
        save(tempFile,"sequences","labels","-v7.3");
        fprintf('\n');
    end
    
    if trainingParam.train_LSTM_network | ~exist([path '/netLSTM.mat']) % training of LSTM network, if file does not exist, then must train
        
        disp('Preparing LSTM network ...');
        fprintf('------\n');
        
        %=====BLOCKs RNG====
        if blockRNG==1
            stCPU= RandStream('Threefry','Seed',0,'NormalTransform','Inversion');
            stGPU=parallel.gpu.RandStream('Threefry','Seed',0,'NormalTransform','Inversion');
            RandStream.setGlobalStream(stCPU);
            parallel.gpu.RandStream.setGlobalStream(stGPU);
        end
        %===================
        
        numObservations = numel(sequences);
        idx = randperm(numObservations);
        N = floor(trainingParam.LSTM_data_splitting_factor* numObservations); % 0.9 replace
        
        idxTrain = idx(1:N);
        %idxTrain=1; % warning
        
        sequencesTrain = sequences(idxTrain);
        labelsTrain = labels(idxTrain);
        %class(labelsTrain)
        %size(labelsTrain)
        %class(labelsTrain{:})
        %size(labelsTrain{:})
        %labelsTrain{1}= repmat(labelsTrain{1},[1 500])
        %class(labels{1})
        
        if strcmp(trainingParam.classifier_output{end},'sequence-to-one') % sequence to one classification
            labelsTrain=[labelsTrain{:}]';
        end
        
        idxValidation = idx(N+1:end);
        %idxValidation = 1; %warning
        
        sequencesValidation = sequences(idxValidation);
        labelsValidation = labels(idxValidation);
        
        if strcmp(trainingParam.classifier_output{end},'sequence-to-one') % sequence to one classification
            labelsValidation = [labelsValidation{:}]';
        end
        
        
        % labelsValidation{1}= repmat(labelsValidation{1},[1 500])
        % create LSTM network
        
        numFeatures = size(sequencesTrain{1},1);
        numClasses = numel(classif.classes); %numel(categories(labelsTrain{1}));
        
        %ntot=countcats(labelsTrain{1});
        %weights = double(ntot)/double(sum(ntot));
        
        sucl=zeros(numObservations,numClasses);
        
        for i=1:numObservations
            sucl(i,:)=countcats(labels{i});
        end
        sucl=sum(sucl,1);
        
        tempsucl=sucl(sucl>0);
        sucl(sucl==0)=min(tempsucl(:));
        classWeights = 1./sucl;
        classWeights = classWeights'/mean(classWeights);
        
        %==============OPTIONS=================
        
        if strcmp(trainingParam.classifier_output{end},'sequence-to-sequence') % seuqence to sequence clssif
            layers = [
                sequenceInputLayer(numFeatures,'Name','sequence')
                bilstmLayer(trainingParam.LSTM_hidden_size,'OutputMode','sequence','Name','bilstm')
                % lstmLayer(200,'OutputMode','sequence','Name','bilstm')
                dropoutLayer(0.5,'Name','drop');
                fullyConnectedLayer(numClasses,'Name','fc')
                softmaxLayer('Name','softmax')
                weightedLSTMClassificationLayer(classWeights,'classification')];
        else % sequence to one classification
            layers = [
                sequenceInputLayer(numFeatures,'Name','sequence')
                bilstmLayer(trainingParam.LSTM_hidden_size,'OutputMode','last','Name','bilstm')
                % lstmLayer(200,'OutputMode','sequence','Name','bilstm')
                dropoutLayer(0.5,'Name','drop');
                fullyConnectedLayer(numClasses,'Name','fc')
                softmaxLayer('Name','softmax')
                weightedLSTMClassificationLayer(classWeights,'classification')];
        end
        
        % specifiy training options
        
        miniBatchSize = trainingParam.LSTM_mini_batch_size;
        numObservations = numel(sequencesTrain);
        numIterationsPerEpoch = max(1,floor(numObservations / miniBatchSize));
        
        options = trainingOptions('adam', ...
            'MiniBatchSize',miniBatchSize, ...
            'MaxEpochs',50,...
            'InitialLearnRate',trainingParam.LSTM_initial_learning_rate, ...
            'LearnRateSchedule','piecewise',...
            'LearnRateDropPeriod',5,...
            'LearnRateDropFactor',0.5,...            
            'Shuffle','every-epoch', ...
            'ValidationData',{sequencesValidation,labelsValidation}, ...
            'ValidationFrequency',numIterationsPerEpoch, ...
            'Plots','training-progress', ...
            'ExecutionEnvironment','auto',...
            'VerboseFrequency',10);
        
        % warning : Parallel training of recurrent networks is not supported. 'ExecutionEnvironment' value in trainingOptions function must be 'auto',
        %'gpu', or 'cpu'.
        
        %options.SequenceLength
        %options.SequencePaddingValue
        %return;
        % train network
        disp('Training LSTM network ...');
        fprintf('------\n');
        
        [netLSTM,info] = trainNetwork(sequencesTrain,labelsTrain,layers,options);
        
        save([path '/netLSTM.mat'],'netLSTM','info');
        disp('Training LSTM network is done and saved ...');
        fprintf('------\n');
        
    else
        load([path '/netLSTM.mat']);
        disp('Loading LSTM network ...');
        fprintf('------\n');
    end
    
    
    %%% assemble the full network
    %%%
    
    if trainingParam.assemble_network | ~exist([path '/' name '.mat'])
        disp('Assembling full network ...');
        fprintf('------\n');
        
        
        % remove non necessary layers
        fprintf(' remove output layers from CNN net\n');
        
        cnnLayers = layerGraph(netCNN);
        %layerNames = ["data" "pool5-drop_7x7_s1" "loss3-classifier" "prob" "output"];
        
        if strcmp(trainingParam.CNN_network{end},'googlenet')
            layerNames = ["data" "pool5-drop_7x7_s1" "new_fc" "prob" "new_classoutput"];
        end
        
        if strcmp(trainingParam.CNN_network{end},'resnet50')
            layerNames = ["input_1" "new_fc" "fc1000_softmax" "new_classoutput"];
        end
        
        cnnLayers = removeLayers(cnnLayers,layerNames);
        
        % create layers to adjust to CNN network layers
        fprintf(' create layers to adjust to CNN network layers\n');
        
        inputSize = netCNN.Layers(1).InputSize(1:2);
        averageImage = netCNN.Layers(1).AverageImage;
        
        inputLayer = sequenceInputLayer([inputSize 3], ...
            'Normalization','zerocenter', ...
            'Mean',averageImage, ...
            'Name','input');
        
        % add the sequence input layer to the layer graph
        layers = [
            inputLayer
            sequenceFoldingLayer('Name','fold')];
        
        lgraph = addLayers(cnnLayers,layers);
        
        if strcmp(trainingParam.CNN_network{end},'googlenet')
            lgraph = connectLayers(lgraph,"fold/out","conv1-7x7_s2");
        end
        if strcmp(trainingParam.CNN_network{end},'resnet50')
            lgraph = connectLayers(lgraph,"fold/out","conv1");
        end
        
        % create lstm network and remove first layer (sequence)
        fprintf(' create LSTM network\n');
        
        lstmLayers = netLSTM.Layers;
        lstmLayers(1) = [];
        
        layers = [
            sequenceUnfoldingLayer('Name','unfold')
            flattenLayer('Name','flatten')
            lstmLayers];
        
        lgraph = addLayers(lgraph,layers);
        % lgraph = connectLayers(lgraph,"pool5-7x7_s1","unfold/in");
        lgraph = connectLayers(lgraph,layerName,"unfold/in");
        lgraph = connectLayers(lgraph,"fold/miniBatchSize","unfold/miniBatchSize");
        
        %analyzeNetwork(lgraph)
        
        fprintf('Assemble full network\n');
        
        classifier = assembleNetwork(lgraph);
        save([path '/' name '.mat'],'classifier');
        LSTMOptions=struct(options);
        save([path '/TrainingValidation/' 'LSTMOptions' '.mat'],'LSTMOptions');
        
        fprintf('Full network is assembled !\n');
        
        %   saveTrainingPlot(path, 'LSTMTraining');
    else
        load( [path '/' name '.mat']); % loading the fully assembled network
    end
    
    %end
    
    
    function videoResized = centerCrop(video,inputSize)
    
    sz = size(video);
    
    if sz(1) < sz(2)
        % Video is landscape
        idx = floor((sz(2) - sz(1))/2);
        video(:,1:(idx-1),:,:) = [];
        video(:,(sz(1)+1):end,:,:) = [];
        
    elseif sz(2) < sz(1)
        % Video is portrait
        idx = floor((sz(1) - sz(2))/2);
        video(1:(idx-1),:,:,:) = [];
        video((sz(2)+1):end,:,:,:) = [];
    end
    
    videoResized = imresize(video,inputSize(1:2));
