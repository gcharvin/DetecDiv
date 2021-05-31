function validateTrainingData(classif,varargin)
% high level function to classify data using a classifier on ROIs in a
% @classi object.

% classif is the ref to a @classi object

% 'roilist' is a vector containing ROI  from the classi object
%'Classifier' loads the classifier
for i=1:numel(varargin)
    if strcmp(varargin{i},'Classifier')
        classifierStore=varargin{i+1};
    end
     if strcmp(varargin{i},'ClassifierCNN')
        classifierCNN=varargin{i+1};
    end
end

classifyFun=classif.classifyFun;

disp(['Classifying data used as groundtruth in ' classif.strid ' for validation purposes using ' classifyFun]);

%classif=obj.processing.classification(classiid);

path=classif.path;
name=classif.strid;


   % loading the CNN network as well for comparison purposes

% first load classifier if not loadad to save some time 
if exist('classifierStore','var')==0
    disp(['Loading classifier: ' name]);
    str=[path '/' name '.mat'];
    load(str); % load classifier 
    classifierStore=classifier;
end

if exist('classifierCNN','var')==0 
    
    

     str=[path '/netCNN.mat'];
     if exist(str)
     load(str);
     classifierCNN=classifier; 
     else
       classifierCNN=[];
     end
end

classifier=classifierStore; %either loaded or provided as an argument 

for i=1:numel(varargin)
    if strcmp(varargin{i},'roilist')
        roilist=varargin{i+1};
    end
end

%classifier
if exist('roilist','var')==0 %if no roilist is indicated
    roilist=1:numel(classif.roi);
end

disp([num2str(length(roilist)) ' ROIs to classify, be patient...']);

tmp=roi; % build list of rois
for i=1:length(roilist)
tmp(i)=classif.roi(roilist(i));
end

for i=1:length(roilist) % loop on all ROIs using parrallel computing
    
 roiobj=tmp(i);

 if numel(roiobj.id)==0
     continue;
 end
 
  disp('-----------');
  disp(['Classifying ' num2str(roiobj.id)]);
 
%  if strcmp(classif.category{1},'Image') % in this case, the results are provided as a series of labels
%  roiobj.results=zeros(1,size(roiobj.image,4)); % pre allocate results for labels
%  end

 if numel(classifierCNN) % in case an LSTM classification is done, validation is performed with a CNN classifier as well 
tmp(i)=feval(classifyFun,roiobj,classif,classifier,classifierCNN); % launch the training function for classification
 else
 tmp(i)=feval(classifyFun,roiobj,classif,classifier); % launch the training function for classification   
 end
 
end

 for i=1:length(roilist)
 classif.roi(roilist(i))=tmp(i);
 
% classif.roi(i).save;
 %classif.roi(i).clear;
 end

% disp('Classification job is done and saved...');
disp('You must save the shallow project to save these classified data !');

