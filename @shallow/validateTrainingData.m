function validateTrainingData(obj,classiid,classifier)
% high level function to classify data

% classiid is the index of the classifier to be used 

% roilist is an 2 x N array containing FOV IDs and ROI IDs from the shallow
% object to be classified 

classifyFun=obj.processing.classification(classiid).classifyFun;


disp(['Classifying training data for validation using ' classifyFun]);

classif=obj.processing.classification(classiid);

path=classif.path;
name=classif.strid;

if nargin<3
    classifier=[];
end

% first load classifier if not loadad to save some time 
if numel(classifier)==0
    disp(['Loading classifier: ' name]);
    str=[path '/' name '.mat'];
    load(str); % load classifier 
end

%classifier

for i=1:numel(classif.roi) % loop on all ROIs
   
 roiobj=classif.roi(i);
 
 disp('-----------');
 disp(['Classifying ' num2str(roiobj.id)]);
 
 
%  if strcmp(classif.category{1},'Image') % in this case, the results are provided as a series of labels
%  roiobj.results=zeros(1,size(roiobj.image,4)); % pre allocate results for labels
%  end
 
feval(classifyFun,roiobj,classif,classifier); % launch the training function for classification
% since roiobj is a handle, no need to have an output to this the function
% in roiobj.results

end

disp('Classification job is done...');
