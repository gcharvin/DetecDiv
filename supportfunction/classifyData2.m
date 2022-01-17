function logparf=classifyData2(classiobj,roiobj,varargin)
% high level function to classify data

% classiobj is a @classi obj
% roiobj is an array of @roi

% varargin : 

% 'Classifier'  : specify a valid classifier object

%'ClassifierCNN' : in case a cnn and an lstm are to be compared

% 'Frames': input an array of frame numbers or a cell array of frames with
% the same size as the array of @roi

% 'Channel' : a cell array of channel strings to be used as input for
% classification . If not provided, will use the channelName of the
% @classiObj
% The channel can have the same number of items as the @roi array. If only
% one item is provided, it will be used for 

% HERE : implement channels  + correct channels in classifier GUI

% 'Progress' : specifiy a handle to a progree bar to be updated during
% classification 

% 'Parallel' : usd for parallele computing




% results outputs the array of future objects with information about errors
% etc... 

%'Classifier' uses a classifier provdied as input

para=0;
skipCNN=1;
frames=[];
p=[];
channel=[];


for i=1:numel(varargin)
    if strcmp(varargin{i},'Classifier')
        classifierStore=varargin{i+1};
    end
    if strcmp(varargin{i},'ClassifierCNN')
        classifierCNN=varargin{i+1};
    end
    
    if strcmp(varargin{i},'Frames') % is a cell array with the same number of elements as FOVs
        frames=varargin{i+1};
    end
    
  if strcmp(varargin{i},'Progress') % update progress bar
        p=varargin{i+1};
  end
    
     if strcmp(varargin{i},'Channel') % specify a different channel to classify
        channel=varargin{i+1}; % channel must have the same size as Fovs
     end
     
    if strcmp(varargin{i},'Parallel') % parallel computing
        para=1;
    end
end

classi=classiobj;
classifyFun=classi.classifyFun;
fhandle=eval(['@' classifyFun]);

disp(['Classifying roi data using ' classifyFun]);

if numel(p)
    p.Value=0.1;
    p.Message='Preparing classification....';
end


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

if numel(p)
    p.Value=0.2;
    p.Message='Classifier is loaded.';
end

disp([num2str(numel(roiobj)) ' ROIs to classify, be patient...']);

if para
    logparf(1:numel(roiobj))= parallel.FevalFuture;
else

    logparf=1;
end


for i=1:numel(roiobj) %size(roilist,2) % loop on all ROIs using parrallel computing

    if numel(roiobj(i).image)==0
        roiobj(j).load;
    end
    
    fra=size(roiobj(i).image,4);
    
    if numel(frames)~=0
        if iscell(frames)
            if numel(frames)>=i
             fra=frames{i};
            end
        else
             fra=frames;
        end
    end
    
    
    
     if numel(p)
    p.Value=0.9* double(i)./double(size(roilist,2));
    
    p.Message=['Classifying ROI  ' roiobj.id];
     end
    
     
    if para % parallele computing
        if exist('classifierCNN','var')  && skipCNN==0
            logparf(i)=parfeval(fhandle,0,roiobj(i),classi,classifierStore,classifierCNN,'Frames',fra{i}); % launch the training function for classification
        else
            %disp(['Starting classification of ' num2str(roiobj(i).id)]);
            logparf(i)=parfeval(fhandle,0,roiobj(i),classi,classifierStore,'Frames',fra{i}); % launch the training function for classification
        end
    else
        if exist('classifierCNN','var') && skipCNN==0
            feval(fhandle,roiobj(i),classi,classifierStore,classifierCNN,'Frames',fra{i}); % launch the training function for classification
            disp(['Classified ' num2str(roiobj(i).id)]);
        else
            feval(fhandle,roiobj(i),classi,classifierStore,'Frames',fra{i}); % launch the training function for classification
            disp(['Classified without CNN' num2str(roiobj(i).id)]);
        end
    end
    
end

  if numel(p)
    p.Value=0.9;
    p.Message='Saving project...Please wait...';
  end
  

