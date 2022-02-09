function crossValidation(classif,nsteps)

% this function performs crossvalidation using initial classif.trainingset
% to set the size of the training pool

% only for pixel classification for now !

if ~isfield(classif.trainingParam,'CNN_crossvalidation')
classif.trainingParam.CNN_crossvalidation=true;
end
classif.trainingParam.CNN_crossvalidation=true;

for i=1:nsteps
    
    classif.trainClassifier; % this will randomly pick rois among all rois in the @classi, taking numel(@classi.trainingset) as the number of rois
    
    trainingrois=classif.trainingset;
    
    testrois=setxor(1:numel(classif.rois),trainingrois);
    
    evalin('base',['clear ' classif.strid]); % removes existing classifier from workspace
    classif.loadClassifier; 
    
    classif.validateTrainingData(testrois,'RoiWithGT');
    
    str=[num2str(i)];
    
    while numel(str)<3
        str=['0' str];
    end
    
    str=['Step' str '.mat'];
    pth=fulfile(classif.path,'TrainingValidation',str);
    
    classif.stats('Confusion','Classes','Rois',testrois','Force','Export',pth);
end