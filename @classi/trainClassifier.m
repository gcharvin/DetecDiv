function trainClassifier(classif)


% first format data for training procedure and save to disk

prompt='If you have not yet formatted groundtruth dataset for training, you need to do it first. Do it (y/n) (Default: n): ';
fmt= input(prompt,'s');
if numel(fmt)==0
    fmt='n';
end


if strcmp(fmt,'y')
    disp('OK, the ground truth dataset will be formatted before launching the training');
end

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
    trai='new';
end

if ~strcmp(trai,'n')
    if strcmp(trai,'new')
            trainingParam=[];
    end
             
    switch classif.typeid % type of classification used
        case 4 %image classification training options
            
            fi={'network','googlenet'}; 
            trainingParam=setParam(trainingParam,fi);
            
            prompt=[fi{1} ' (Default: ' str '): ']; answ= input(prompt,'s'); if numel(answ)==0  answ=str; end
            trainingParam.(fi{1})=answ;
            
            fi={'MiniBatchSize',8}; str=findDefault(trainingParam,fi);
            prompt=[fi{1} ' (Default: ' str '): ']; answ= input(prompt,'s'); if numel(answ)==0  answ=str; end
            trainingParam.(fi{1})=answ;
            
          
            
%                'MiniBatchSize',miniBatchSize, ...
%     'MaxEpochs',6, ...
%     'InitialLearnRate',3e-4, ... % 3e-4
%     'Shuffle','every-epoch', ...
%     'ValidationData',augimdsValidation, ...
%     'ValidationFrequency',valFrequency, ...
%      'VerboseFrequency',2,...
%     'Plots','training-progress',...
%     'ExecutionEnvironment','parallel');
    end
end

% first format data for training procedure and save to disk

if strcmp(fmt,'y')
    obj.formatDataForTraining(classiid);
end

% launch the classification-specific training procedure

trainingFun=classif.trainingFun;

path=classif.path;
name=classif.strid;

disp(['Launching training procedure with ' trainingFun]);

feval(trainingFun,path,name); % launch the training function for classification


function trainingParam=findDefault(trainingParam,fi)

str=fi{2};
if isfield(vari,fi{1})   
if numel(vari.(fi{1}))>0
    str=vari.(fi{1});
end
end
