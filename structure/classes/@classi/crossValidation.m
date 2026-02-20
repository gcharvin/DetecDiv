function crossValidation(classif,nsteps)

% this function performs crossvalidation using initial classif.trainingset
% to set the size of the training pool

% only for pixel classification for now !

if ~isfield(classif.trainingParam,'CNN_crossvalidation')
classif.trainingParam.CNN_crossvalidation=true;
end
classif.trainingParam.CNN_crossvalidation=true;

output=classif.score;

for i=1:nsteps
    
    classif.trainClassifier; % this will randomly pick rois among all rois in the @classi, taking numel(@classi.trainingset) as the number of rois
    
    trainingrois=classif.trainingset;
    
    testrois=setxor(1:numel(classif.roi),trainingrois);
    
    evalin('base',['clear ' classif.strid]); % removes existing classifier from workspace
    classif.loadClassifier; 
    
    roiobj=classif.roi(testrois);
    
    classif.validateTrainingData(roiobj,'RoiWithGT');
    
    str=[num2str(i)];
    
    while numel(str)<3
        str=['0' str];
    end
    
    str=['Step' str '.mat'];
    pth=fullfile(classif.path,'TrainingValidation',str);
    
    classif.stats('Confusion','Classes','Rois',testrois,'Force','Export',pth);
    close all
    
    if i==1
        output=classif.score;
    else
    output(i)=classif.score;
    end
    
end

pth=fullfile(classif.path,'TrainingValidation','output.mat');
save(pth,'output');