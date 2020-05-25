function trainClassifier(obj,classiid)


% first format data for training procedure and save to disk

%obj.formatDataForTraining(classiid);

% launch the classification-specific training procedure 

trainingFun=obj.processing.classification(classiid).trainingFun;

path=obj.processing.classification(classiid).path;
name=obj.processing.classification(classiid).strid;

disp(['Launching training procedure with ' trainingFun]);

feval(trainingFun,path,name); % launch the training function for classification



