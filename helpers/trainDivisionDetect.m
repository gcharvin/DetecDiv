function lstmmodel=trainDivisionDetect(classiobj,classeid,roilist)

% input argument : 
% classiobj : classi obj of the classification object to be scored
% classeid : id of the class to train on 
% roilist : the array of the roi to be taken into account. If no argument ,
% will take all the roi available 

% output argument :
%lstmmodel, that can classifies time series. 

% train an lstm network to identify / cure timerseries of P(particular
% state following image classification 

% classnames

if nargin==2
    roilist=1:numel(classiobj.roi); 
end

className=classiobj.classes{classeid};
cate=categorical({className, 'other'});
classes=categories(cate);

% get the groundtruth data and results from classif

X={};
Y={};

for i=1:numel(roilist)
    roiid=roilist(i);
    
X{i}=classiobj.roi(roiid).results.(classiobj.strid).prob(classeid,:);
temp=uint8(classiobj.roi(roiid).train.(classiobj.strid).id==classeid);
temp=temp+1;
Y{i}=categorical(temp,[1 2],classes); 
end


lstmmodel=[];

% setup architecture of lstm network 

numFeatures = 1;
numHiddenUnits = 20;
numClasses = 2;

layers = [ ...
    sequenceInputLayer(numFeatures)
    lstmLayer(numHiddenUnits,'OutputMode','sequence')
    fullyConnectedLayer(numClasses)
    softmaxLayer
    classificationLayer];

options = trainingOptions('adam', ...
    'MaxEpochs',300, ...
    'InitialLearnRate',0.005, ...
    'GradientThreshold',2, ...
    'Verbose',0, ...
    'Plots','training-progress');

lstmmodel = trainNetwork(X,Y,layers,options);








