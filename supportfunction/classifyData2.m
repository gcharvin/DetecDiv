function logparf=classifyData2(classiobj,roiobj,varargin)
% high level function to classify data

% classiobj is a @classi obj

% roiobj is an array of @roi

% results outputs the array of future objects with information about errors
% etc... 

%'Classifier' uses a classifier provdied as input

para=0;
skipCNN=1;

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

if para
    logparf(1:numel(roiobj))= parallel.FevalFuture;
else

    logparf=1;
end


for i=1:numel(roiobj) %size(roilist,2) % loop on all ROIs using parrallel computing

    if para % parallele computing
        if exist('classifierCNN','var')  && skipCNN==0
            logparf(i)=parfeval(fhandle,0,roiobj(i),classi,classifierStore,classifierCNN); % launch the training function for classification
        else
            %disp(['Starting classification of ' num2str(roiobj(i).id)]);
            logparf(i)=parfeval(fhandle,0,roiobj(i),classi,classifierStore); % launch the training function for classification
        end
    else
        if exist('classifierCNN','var') && skipCNN==0
            feval(fhandle,roiobj(i),classi,classifierStore,classifierCNN); % launch the training function for classification
            disp(['Classified ' num2str(roiobj(i).id)]);
        else
            feval(fhandle,roiobj(i),classi,classifierStore); % launch the training function for classification
            disp(['Classified without CNN' num2str(roiobj(i).id)]);
        end
    end
    
end

end

