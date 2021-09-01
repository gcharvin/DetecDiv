function result=classifyData2(classiobj,roiobj,varargin)
% high level function to classify data

% classiobj is a @classi obj

% roiobj is an array of @roi

% results outputs the array of future objects with information about errors
% etc... 

%'Classifier' uses a classifier provdied as input

para=0;

for i=1:numel(varargin)
    if strcmp(varargin{i},'Classifier')
        classifierStore=varargin{i+1};
    end
    if strcmp(varargin{i},'ClassifierCNN')
        classifierCNN=varargin{i+1};
    end
    
    if strcmp(varargin{i},'Parallel') % parallel computing
        para=1;
    end
end

classi=classiobj;
classifyFun=classi.classifyFun;
fhandle=eval(['@' classifyFun]);

disp(['Classifying roi data using ' classifyFun]);


path=classi.path;
name=classi.strid;
if exist('classifierStore','var')==0
    % first load classifier if not loadad to save some time
    disp(['Loading classifier: ' name '...']);
    str=[path '/' name '.mat'];
    load(str); % load classifier
    classifierStore=classifier;
end

if classi.typeid==4 % in case of a lstm image classi, a CNN classifier is loaded for comparison, if requested by user
    if exist('classifierCNN','var')==0
        str=[path '/netCNN.mat'];
        if exist(str)
            load(str);
            disp(['Loading CNN classifier: ' name]);
            classifierCNN=classifier;
        else
            classifierCNN=[];
        end
    end
end


disp([num2str(numel(roiobj)) ' ROIs to classify, be patient...']);

% tmp=roi; % build list of rois
% for i=1:size(roilist,2)
%     tmp(i)=obj.fov(roilist(1,i)).roi(roilist(2,i));
% end

if para
result(1:numel(roiobj))= parallel.FevalFuture;
else
result=1;
end


tic

 if exist('classifierCNN','var')
     cnn=1;
 else
     cnn=0;
 end

for i=1:numel(roiobj) %size(roilist,2) % loop on all ROIs using parrallel computing
    %     roiobj=tmp(i);
    %     if numel(roiobj.id)==0
    %         continue;
    %     end
    
    %disp('-----------');
    disp(['Launching classification for ROI ' num2str(roiobj(i).id)]);
  
    %  if strcmp(classif.category{1},'Image') % in this case, the results are provided as a series of labels
    %  roiobj.results=zeros(1,size(roiobj.image,4)); % pre allocate results for labels
    %  end
    
    %if numel(classifierCNN) % in case an LSTM classification is done, validation is performed with a CNN classifier as well
    %mp(i)=feval(classifyFun,roiobj,classif,classifier,classifierCNN); % launch the training function for classification
    %else
    
    if para % parallele computing
        if cnn
            result(i)=parfeval(fhandle,0,roiobj(i),classi,classifierStore,classifierCNN); % launch the training function for classification
            %  feval(fhandle,roiobj(i),classi,classifierStore,classifierCNN); % launch the training function for classification
        else
            result(i)=parfeval(fhandle,0,roiobj(i),classi,classifierStore); % launch the training function for classification
            %  feval(fhandle,roiobj(i),classi,classifierStore); % launch the training function for classification
        end
    else
         if cnn
         feval(fhandle,roiobj(i),classi,classifierStore,classifierCNN); % launch the training function for classification
         else
         feval(fhandle,roiobj(i),classi,classifierStore); % launch the training function for classification
         end
    end
    
    % since roiobj is a handle, no need to have an output to this the function
    % in roiobj.results
    
end
toc

% for i=1:size(roilist,2)
%     obj.fov(roilist(1,i)).roi(roilist(2,i))=tmp(i);
%     obj.fov(roilist(1,i)).roi(roilist(2,i)).save;
%     obj.fov(roilist(1,i)).roi(roilist(2,i)).clear;
% end
%
%
% shallowSave(obj);

