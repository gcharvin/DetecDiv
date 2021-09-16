function formatTimeseriesTrainingSet(foldername,classif,rois)

% if ~isfolder([classif.path '/' foldername '/data'])
%     mkdir([classif.path '/' foldername], 'data');
% end

% get the training data for each ROI and put in a relevant file

XTrain={};
YTrain={};
classes=classif.classes;

strfield=classif.trainingset;
pix=strfind(strfield,'.');

if numel(pix)==0
    str={strfield};
else
    str={strfield(1:pix(1)-1)};
    
    cc=1;
    for i=1:numel(pix)-1
        str{cc+1}=strfield(pix(i)+1:pix(i+1)-1);
        cc=cc+1;
    end
end
str{cc+1}=strfield(pix(cc)+1:end);

% parse fields

cc=1;

for i=rois
    
    tmp=classif.roi(i);
    
  %  str
    for j=1:numel(str)
        tmp=tmp.(str{j});
    end    
    
 %   tmp
    if numel(tmp)
    
    XTrain{cc,1}=tmp;
    YTrain{cc,1}=classif.roi(i).train.(classif.strid).id;
     cc=cc+1;
    end
   
end

save(fullfile(classif.path,foldername,'TrainingData.mat'),'XTrain','YTrain','classes');



