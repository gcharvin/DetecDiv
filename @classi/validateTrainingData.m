function validateTrainingData(classif,varargin)
% high level function to classify data using a classifier on ROIs in a
% @classi object.

% classif is the ref to a @classi object

% 'roilist' is a vector containing ROI  from the classi object
%'Classifier' loads the classifier
for i=1:numel(varargin)
    if strcmp(varargin{i},'Classifier')
        classifier=varargin{i+1};
    end
end

classifyFun=classif.classifyFun;

disp(['Classifying data used as groundtruth in ' classif.strid ' for validation purposes using ' classifyFun]);

%classif=obj.processing.classification(classiid);

path=classif.path;
name=classif.strid;

% first load classifier if not loadad to save some time 
if exist('classifier','var')==0
    disp(['Loading classifier: ' name]);
    str=[path '/' name '.mat'];
    load(str); % load classifier 
end


for i=1:numel(varargin)
    if strcmp(varargin{i},'roilist')
        roilist=varargin{i+1};
    end
end

%classifier
if exist('roilist','var')==0 %if no roilist is indicated
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
else
    for i=roilist % loop on indicated ROIs
     roiobj=classif.roi(i);
     disp('-----------');
     disp(['Classifying ' num2str(roiobj.id)]);
     feval(classifyFun,roiobj,classif,classifier); % launch the training function for classification
    end
end
    
    

disp('Classification job is done...');
disp('You must save the shallow project to save these classified data');

