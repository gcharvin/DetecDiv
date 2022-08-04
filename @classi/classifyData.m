function logparf=classifyData(classiobj,roiobj,varargin)
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

% 'Progress' : specifiy a handle to a progree bar to be updated during
% classification 

% 'Parallel' : usd for parallele computing




% results outputs the array of future objects with information about errors
% etc... 

%'Classifier' uses a classifier provdied as input

para=0;
frames=[];
p=[];
channel=[]; %classiobj.channelName;
classifierCNN=[];
classifier=[];
CNNflag=0;


for i=1:numel(varargin)
    if strcmp(varargin{i},'Classifier')
        classifier=varargin{i+1};
    end
    if strcmp(varargin{i},'ClassifierCNN')
       % classifierCNN=varargin{i+1};
        CNNflag=1;
    end
    
    if strcmp(varargin{i},'Frames') % is a cell array with the same number of elements as number of rois. If it s a numeric array, then apply to all rois
        frames=varargin{i+1};
    end
    
  if strcmp(varargin{i},'Progress') % update progress bar
        p=varargin{i+1};
  end
    
     if strcmp(varargin{i},'Channel') % specify a different channel to classify
        channel=varargin{i+1}; % channel is a cell array with the same size as the number of rois; if not, will apply the same number to all ROIs
     end
     
    if strcmp(varargin{i},'Parallel') % parallel computing
        para=1;
    end
end

classifierStore=classifier; 

classi=classiobj;
classifyFun=classi.classifyFun;
fhandle=eval(['@' classifyFun]);

disp(['Classifying roi data using ' classifyFun]);

if numel(p)
    p.Value=0.1;
    p.Message='Preparing classification....';
end

mustload=0;
if numel(classifier)==0
    mustload=1;
end

 if CNNflag==1
        str=fullfile(classi.path,['netCNN_' classi.strid '.mat']);
        if exist(str)   
            load(str);
            disp(['Loading CNN classifier: ' str]);
            classifierCNN=classifier;
        else 
            classifierCNN=[];
        end
 else
      classifierCNN=[];
 end
 
 if mustload==1
     disp(['Loading classifier: ' classi.strid]);
    % str=[path '/' name '.mat'];
    classifier=[];
    classifier=classi.loadClassifier;
    classifierStore=classifier; 

    if numel(classifierStore)==0
        disp('could not load main classifier.... quitting');
        %% 
        return;
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
        roiobj(i).load;
    end
    
    fra=1:size(roiobj(i).image,4);
    
    if numel(frames)>0
        if iscell(frames)
            if numel(frames)>=i
             fra=frames{i};
            end
        else
             fra=frames;
        end
    end
    
    if numel(channel)==0
        cha=classiobj.channelName;
    else
        cha=channel{i};
    end
    
     if numel(p)
    p.Value=0.9* double(i)./numel(roiobj);
    
    p.Message=['Classifying ROI  ' roiobj(i).id];
     end
    
     
    if para % parallel computing
        if numel(classifierCNN)
            logparf(i)=parfeval(fhandle,0,roiobj(i),classi,classifierStore,'classifierCNN',classifierCNN,'Frames',fra,'Channel',cha); % launch the training function for classification
        else
            %disp(['Starting classification of ' num2str(roiobj(i).id)]);
            logparf(i)=parfeval(fhandle,0,roiobj(i),classi,classifierStore,'Frames',fra,'Channel',cha); % launch the training function for classification
        end
    else
        if  numel(classifierCNN)
            feval(fhandle,roiobj(i),classi,classifierStore,'classifierCNN',classifierCNN,'Frames',fra,'Channel',cha); % launch the training function for classification
            disp(['Classified with separate CNN ' num2str(roiobj(i).id)]);
        else
            feval(fhandle,roiobj(i),classi,classifierStore,'Frames',fra,'Channel',cha); % launch the training function for classification
            disp(['Classified' num2str(roiobj(i).id)]);
        end
    end
    
end

% if para  % not implemented
%     maxFuture = afterEach(logparf, @(r) max(r), 1);
%     
%     minFuture = afterAll(maxFuture, @(r) min(r), 1);
%     
% end

  if numel(p)
    p.Value=0.9;
    p.Message='Saving project...Please wait...';
  end
  
  
  
%disp('You must save the shallow project to save these classified data !');
