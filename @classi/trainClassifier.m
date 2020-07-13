function trainClassifier(classif)


% first format data for training procedure and save to disk

%obj.formatDataForTraining(classiid);

% launch the classification-specific training procedure 

trainingFun=classif.trainingFun;

path=classif.path;
name=classif.strid;

disp(['Launching training procedure with ' trainingFun]);

feval(trainingFun,path,name); % launch the training function for classification



