function setTrainingParam(classif)

% setting training parameters
if isfile([classif.path '/trainingParam.mat'])
    disp('Current training parameters:');
    
    load([classif.path '/trainingParam.mat']) % loading trainingParam variable
    
    disp(trainingParam);
    
    prompt='Change training param (y/n) (Default: n): ';
    trai= input(prompt,'s');
    if numel(trai)==0
        trai='n';
    end
else
    disp('Training parameters do not exist. We must set them before going further:');
    trai='new';
end

if ~strcmp(trai,'n')
    if strcmp(trai,'new')
        trainingParam=[];
        trainingParam.imageclassifier=[];
    end
    
    
    
    disp('Which ROIs to use?');
    trainingParam=setParam(trainingParam,{'rois',1:numel(classif.roi)});
    
    disp('WARNING: if you change the number of ROIs, you must launch the formatDataFor Training function again !');
    cc=1;
    trainingParam.roisID={};
    for i=1:numel(trainingParam.rois)
    trainingParam.roisID{cc}=classif.roi(trainingParam.rois(i)).id;
    cc=cc+1;
    end
    
    trainingParam.classes=classif.classes; % saves the classes for use in the training fucntions
    
    if classif.typeid==4 || classif.typeid == 12 % LSTM: ask which part needs to be trained
        disp('Train image classifier?');
        trainingParam=setParam(trainingParam,{'imageclassifier','y'});
        
        disp('Compute activation for image classifier?');
        trainingParam=setParam(trainingParam,{'cactivations','y'});
        
        disp('Train LSTM network ?');
        trainingParam=setParam(trainingParam,{'lstmtraining','y'});
        
        disp('Assemble full network ?');
        trainingParam=setParam(trainingParam,{'assemblenet','y'});
        
        trainingParam.output=classif.output; % sequence-to-sequence vs sequence-to-one
    end
    
    if classif.typeid==1 || (classif.typeid==4 & strcmp(trainingParam.imageclassifier,'y')) ||  classif.typeid==11 || (classif.typeid==12 & strcmp(trainingParam.imageclassifier,'y'))
        trainingParam=imageTraining(trainingParam);
    end
    
    if classif.typeid==4 || classif.typeid == 12  % LSTM specific
        trainingParam=LSTMTraining(trainingParam);
    end
    
    if classif.typeid==8 ||  classif.typeid==2 % seg specific
        trainingParam=SegTraining(trainingParam);
    end
        
end

disp('---------------');
disp('Stored training parameters: ');

disp(trainingParam)

mkdir([classif.path '/TrainingValidation'])
save([classif.path '/trainingParam.mat'],'trainingParam')
save([classif.path '/TrainingValidation' '/trainingParam.mat'],'trainingParam')

function trainingParam=imageTraining(trainingParam)

disp('*** Set training options for image classification ***');

disp('Select optimization method (sgdm, adam, rmsprop): ');
trainingParam=setParam(trainingParam,{'method','sgdm'});

disp('Select CNN (googlenet, resnet50, resnet101, inceptionresnetv2, nasnetlarge, efficientnetb0): ');
trainingParam=setParam(trainingParam,{'network','googlenet'});

disp('Select Batch size (8-128): ');
trainingParam=setParam(trainingParam,{'MiniBatchSize',8});

disp('Select Number of Epochs (ie iterations): ');
trainingParam=setParam(trainingParam,{'MaxEpochs',6});

disp('Select Learning rate: ');
trainingParam=setParam(trainingParam,{'InitialLearnRate',3e-4});

disp('Select Data shuffling (once,never,every-epoch): ');
trainingParam=setParam(trainingParam,{'Shuffle','every-epoch'});

disp('Split factor between training and validation: ');
trainingParam=setParam(trainingParam,{'split',0.7});

disp('Freeze 10 first layers (speeds up training): ');
trainingParam=setParam(trainingParam,{'freeze','n'});

disp('Image augmentation (translation range in pixels): ');
trainingParam=setParam(trainingParam,{'translateAugmentation',[-5 5]});

disp('Image augmentation (rotation range in degrees): ');
trainingParam=setParam(trainingParam,{'rotateAugmentation',[-180 180]});

disp('L2regularization (0.00001-0.1) : ');
trainingParam=setParam(trainingParam,{'regularization',0.00001});

if gpuDeviceCount>0
    disp(['You have ' num2str(gpuDeviceCount) ' GPUs available']);
else
    disp(['There is no GPU available']);
end

disp('Select the execution environment: ');
disp('''auto'' = Use a GPU if one is available. Otherwise, use the CPU');
disp('''cpu'' — Use the CPU');
disp('''gpu'' — Use the GPU');
disp('''multi-gpu'' — Multiple GPUs');
disp('''parallel'' — use a parallel pool, one GPU per worker if available  ');
trainingParam=setParam(trainingParam,{'ExecutionEnvironment','parallel'});


function trainingParam=LSTMTraining(trainingParam)

disp('*** Set training options for LSTM classification ***');

disp('Split factor between training and validation: ');
trainingParam=setParam(trainingParam,{'lstmsplit',0.7});

disp('Number of bilstm layers: ');
trainingParam=setParam(trainingParam,{'lstmlayers',2000});

disp('Select Mini Batch size (1-128): ');
trainingParam=setParam(trainingParam,{'lstmMiniBatchSize',8});

disp('Select Learning rate: ');
trainingParam=setParam(trainingParam,{'lstmInitialLearnRate',1e-4});



function trainingParam=SegTraining(trainingParam)

disp('*** Set training options for image classification ***');

disp('Select optimization method (sgdm, adam, rmsprop): ');
trainingParam=setParam(trainingParam,{'method','sgdm'});

disp('Select CNN (resnet18, resnet50): ');
trainingParam=setParam(trainingParam,{'network','resnet50'});

disp('Select Batch size (8-128): ');
trainingParam=setParam(trainingParam,{'MiniBatchSize',8});

disp('Select Number of Epochs (ie iterations): ');
trainingParam=setParam(trainingParam,{'MaxEpochs',60});

disp('Select Learning rate: ');
trainingParam=setParam(trainingParam,{'InitialLearnRate',1e-2});

disp('Select Data shuffling (once,never,every-epoch): ');
trainingParam=setParam(trainingParam,{'Shuffle','every-epoch'});

disp('Split factor between training and validation: ');
trainingParam=setParam(trainingParam,{'split',0.7});

disp('Image augmentation (translation range in pixels): ');
trainingParam=setParam(trainingParam,{'translateAugmentation',[-50 50]});

disp('Image augmentation (rotation range in degrees): ');
trainingParam=setParam(trainingParam,{'rotateAugmentation',[-0 0]});

disp('L2regularization (0.00001-0.1) : ');
trainingParam=setParam(trainingParam,{'regularization',0.005});

if gpuDeviceCount>0
    disp(['You have ' num2str(gpuDeviceCount) ' GPUs available']);
else
    disp(['There is no GPU available']);
end

disp('Select the execution environment: ');
disp('''auto'' = Use a GPU if one is available. Otherwise, use the CPU');
disp('''cpu'' — Use the CPU');
disp('''gpu'' — Use the GPU');
disp('''multi-gpu'' — Multiple GPUs');
disp('''parallel'' — use a parallel pool, one GPU per worker if available  ');
trainingParam=setParam(trainingParam,{'ExecutionEnvironment','parallel'});


function trainingParam=setParam(trainingParam,fi)

str=fi{2};%default value if not previously assigned
if isfield(trainingParam,fi{1})
    if numel(trainingParam.(fi{1}))>0
        str=trainingParam.(fi{1});
    end
end

if ischar(str)
    prompt=[fi{1} ' (Default: ' str '): '];
    answ= input(prompt,'s'); 
    if numel(answ)==0  
        answ=str; 
    end
    trainingParam.(fi{1})=answ;
else
    prompt=[fi{1} ' (Default: ' num2str(str) '): '];
    answ= input(prompt);
    if numel(answ)==0 
        answ=str;
    end
    trainingParam.(fi{1})=answ;
end
