function validateTrainingData(classif,roiobj,varargin)
% high level function to classify data using a classifier on ROIs in a
% @classi object.

% classif is the ref to a @classi object

% 'roilist' is a vector containing ROI  from the classi object

% 'roiwithgt' option only validates rois with  groundth data

%'Classifier' loads the classifier


frames=[];
p=[];
flag=[];
channel=classif.channelName;
roiwithgt=0;
para=0;
classifier=[];
classifierCNN=[];
CNNflag=0;

for i=1:numel(varargin)
    if strcmp(varargin{i},'Classifier')
        classifier=varargin{i+1};
    end
    
    if strcmp(varargin{i},'ClassifierCNN')
       % classifierCNN=varargin{i+1};
        CNNflag=1;
    end
    
    if strcmp(varargin{i},'Frames') % is a numeric array 
        frames=str2num(varargin{i+1});
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
    
    if strcmp(varargin{i},'RoiWithGT') % classify only ROIs and frames that have a groundtruth available
        roiwithgt=1;
    end
end

classifyFun=classif.classifyFun;
fhandle=eval(['@' classifyFun]);

disp(['Classifying data used as groundtruth in ' classif.strid ' for validation purposes using ' classifyFun]);

if numel(p)
    p.Value=0.1;
    p.Message='Preparing classification....';
end

%classif=obj.processing.classification(classiid);


% loading the CNN network as well for comparison purposes

% first load classifier if not loadad to save some time
if numel(classifier)==0
    disp(['Loading classifier: ' classif.strid]);
    % str=[path '/' name '.mat'];
    
    classifier=classif.loadClassifier;
    
    if numel(classifier)==0
        disp('could not load main classifier.... quitting');
        return;
    end
    
end

 if CNNflag==1
        str=fullfile(path,'netCNN.mat');
        if exist(str)
            load(str);
            disp(['Loading CNN classifier: netCNN.mat']);
            classifierCNN=classifier;
        else 
             disp(['Could not find CNN classifier: netCNN.mat']);
            classifierCNN=[];
        end
 else
     classifierCNN=[];
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
    
    goclassif=1;
    
    
    if roiwithgt==1 % checks if goclassif truth data are avaiable for this ROI, otherwise skips the ROI
        switch classif.category{1}
            case 'Pixel' % pixel classification
                
                
                ch= roiobj(i).findChannelID(classif.strid);
                
                if numel(ch)>0 % groundtruth channel exists
                    % checks if at least one image has been annotated  first!
                    
                    if numel( roiobj(i).image)==0 % loads the image
                        roiobj(i).load;
                    end
                    
                    im= roiobj(i).image;
                    fram=1:size(im,4);
                    
                    imch=im(:,:,ch,:);
                    
                    if sum(imch(:))>0 % at least one image was annotated
                        goclassif=1;
                        flag=[];
                        for f=fram
                            if max(max(imch(:,:,1,f)))>0 %takes only frames with cells annotated
                                flag=[flag, f];
                            end
                        end
                        % frames=flag;%frames to classify - disabled to
                        % classify all frames
                        
                    else
                        goclassif=0;
                    end
                end
                
            otherwise % image classification
                classistr=classif.strid;
                % if roi was used for user training, display the training data first
                if numel( roiobj(i).train)~=0
                    if isfield(roiobj(i).train,classistr)
                        if numel(roiobj(i).train.(classistr).id) > 0
                            if sum(roiobj(i).train.(classistr).id)>0 ||  ( numel(roiobj(i).train.(classistr).id)==1 && ~isnan(roiobj(i).train.(classistr).id))  % training exists for this ROI ! put a condition if there is only one element
                                goclassif=1;
                            else
                                goclassif=0;
                            end
                        end
                    end
                end
        end
    end
   
    
    
    if goclassif==1
        
          if numel( roiobj(i).image)==0 % loads the image
                        roiobj(i).load;
          end
        
          im= roiobj(i).image; 
         fra=size(im,4);
    
    if numel(frames)~=0
      %  if iscell(frames)
        %    if numel(frames)>=i
         %       fra=frames{i};
        %    end
      %  else
            fra=frames;
      %  end
    end
    
    if numel(flag)
        fra=intersect(fra,flag);
    end
    
    
        
        if numel(p)
            p.Value=0.9* double(i)./numel(roiobj);
            p.Message=['Classifying ROI  ' roiobj(i).id];
        end
        
        disp('-----------');
        disp(['Classifying ' num2str(roiobj(i).id) ' - ' num2str(i)]);
        
        if para % parallel computing
            if numel(classifierCNN)
                logparf(i)=parfeval(fhandle,0,roiobj(i),classif,classifier,classifierCNN,'Frames',fra,'Channel',channel); % launch the training function for classification
            else
                disp(['Starting classification of ' num2str(roiobj(i).id)]);
                logparf(i)=parfeval(fhandle,0,roiobj(i),classif,classifier,'Frames',fra,'Channel',channel); % launch the training function for classification
            end
        else
            if  numel(classifierCNN)
                feval(fhandle,roiobj(i),classif,classifier,classifierCNN,'Frames',fra,'Channel',channel); % launch the training function for classification
                disp(['Classified with separate CNN ' num2str(roiobj(i).id)]);
            else
                feval(fhandle,roiobj(i),classif,classifier,'Frames',fra,'Channel',channel); % launch the training function for classification
                disp(['Classified' num2str(roiobj(i).id)]);
            end
        end
        
        
    elseif goclassif==0
        disp(['There is no groundtruth available for roi ' num2str(roiobj(i).id) ' , skipping roi...']);
    end
end

%disp('You must save the shallow project to save these classified data !');

