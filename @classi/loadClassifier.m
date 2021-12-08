function classifierout=loadClassifier(classif)
% load classifier (network) associated with a given @classi

path=classif.path;
name=classif.strid;


    disp(['Loading classifier: ' name]);
    
 str=[path '/' name '.mat'];
     
 if exist(str)
    load(str); % load classifier 
 else
    disp('Classifier does not exist ! Has training been done?');
    classifierout=[];
    return;
 end
 

 classifierout=classifier;
