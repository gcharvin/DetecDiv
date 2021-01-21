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
    end
             
    switch classif.typeid % type of classification used
        case {1,4} %image classification training options
            
            disp('*** Set training options for image classification ***'); 
            
            disp('Select optimization method (sgdm, adam, rmsprop): '); 
            trainingParam=setParam(trainingParam,{'method','sgdm'});
            
            disp('Select CNN (googlenet, resnet50, resnet101, inceptionresnetv2, nasnetlarge): '); 
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
            
        
    end
end

disp('---------------');
disp('Stored training parameters: ');

disp(trainingParam)

save([classif.path '/trainingParam.mat'],'trainingParam')

function trainingParam=setParam(trainingParam,fi)


str=fi{2};
if isfield(trainingParam,fi{1})   
if numel(trainingParam.(fi{1}))>0
    str=trainingParam.(fi{1});
end
end

if ischar(str)
prompt=[fi{1} ' (Default: ' str '): ']; answ= input(prompt,'s'); if numel(answ)==0  answ=str; end
trainingParam.(fi{1})=answ;
else

prompt=[fi{1} ' (Default: ' num2str(str) '): ']; answ= input(prompt); if numel(answ)==0  answ=str; end
trainingParam.(fi{1})=answ;    
end
