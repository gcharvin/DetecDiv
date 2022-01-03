function classifyData(obj,classiid,varargin)
% high level function to classify data

% classiid is the index of the classifier to be used

% roilist is an 2 x N array containing FOV IDs and ROI IDs from the shallow
% object to be classified
%'Classifier' loads the classifier


rois=[];
fovs=[];

p=[];

channel=[];
for i=1:numel(varargin)
    if strcmp(varargin{i},'Classifier')
        classifierStore=varargin{i+1};
    end

    if strcmp(varargin{i},'Rois')
        rois=varargin{i+1};
    end
    if strcmp(varargin{i},'Fovs')
        fovs=varargin{i+1};
    end
    
  if strcmp(varargin{i},'Progress') % update progress bar
        p=varargin{i+1};
  end
    
     if strcmp(varargin{i},'Channel') % specify a different channel to classify
        channel=varargin{i+1}; % channel must have the same size as Fovs
     end
    
end


if numel(p)
    p.Value=0.1;
    p.Message='Preparing classification....';
end

if numel(fovs) == 0 % then take all the fovs; 
    fovs=1:numel(obj.fov);
end


if numel(rois)==0
    rois={};
    for i = 1:numel(fovs)
        rois{i}=numel(obj.fov(fovs(i)).roi);
    end
end

roilist=[];
roilist2=[];

chan=[];

for i=1:numel(fovs)
    
    ro= rois{i};
    
    roilist=[roilist fovs(i)*ones(1,numel(ro))];
    roilist2=[roilist2 ro];
    
    if numel(channel)
    chan=[chan channel(i)*ones(1,numel(ro))];
    end
end

roilist(2,:)=roilist2;

%     for i=fovs
%             % for j=1:numel(obj.fov(i).roi)
%             %size( ones(1,length(obj.fov(i).roi)) )
%             roilist = [roilist i*ones(1,length(obj.fov(i).roi)) ];
%             roilist2 = [roilist2  1:length(obj.fov(i).roi) ];
%             % end
%         end
%     else
%         % classify all ROIs
%         for i=1:length(obj.fov)
%             % for j=1:numel(obj.fov(i).roi)
%             %size( ones(1,length(obj.fov(i).roi)) )
%             roilist = [roilist i*ones(1,length(obj.fov(i).roi)) ];
%             roilist2 = [roilist2  1:length(obj.fov(i).roi) ];
%             % end
%         end
%     end
%     roilist(2,:)=roilist2;



classifyFun=obj.processing.classification(classiid).classifyFun;

if numel(p)
    p.Value=0.2;
    p.Message='Loading classifier file....';
end

disp(['Classifying new data using ' classifyFun]);

classi=obj.processing.classification(classiid);
channelstore=classi.channel;

path=classi.path;
name=classi.strid;
if exist('classifierStore','var')==0
    % first load classifier if not loadad to save some time
    disp(['Loading classifier: ' name '...']);
    str=[path '/' name '.mat'];
    load(str); % load classifier
    classifierStore=classifier;
end
% 

disp([num2str(size(roilist,2)) ' ROIs to classify, be patient...']);

tmp=roi; % build list of rois
for i=1:size(roilist,2)
    tmp(i)=obj.fov(roilist(1,i)).roi(roilist(2,i));
end


%try 
for i=1:size(roilist,2) % loop on all ROIs using parrallel computing   
    roiobj=tmp(i);
    if numel(roiobj.id)==0
        continue;
    end
    
    disp('-----------');
    disp(['Classifying ' num2str(roiobj.id)]);
    
    if numel(p)
    p.Value=0.9* double(i)./double(size(roilist,2));
    
    p.Message=['Classifying ROI  ' roiobj.id];
    end

    
    %  if strcmp(classif.category{1},'Image') % in this case, the results are provided as a series of labels
    %  roiobj.results=zeros(1,size(roiobj.image,4)); % pre allocate results for labels
    %  end
    
    %if numel(classifierCNN) % in case an LSTM classification is done, validation is performed with a CNN classifier as well
    %mp(i)=feval(classifyFun,roiobj,classif,classifier,classifierCNN); % launch the training function for classification
    %else
   % classifyFun,roiobj,classi,classifierStore
    
   if numel(channel)~=0 % channel number was changed
    classi.channel=chan(i);
   end

    feval(classifyFun,roiobj,classi,classifierStore); % launch the training function for classification
    %end
    
    % since roiobj is a handle, no need to have an output to this the function
    % in roiobj.results
    
end
% 
% for i=1:size(roilist,2)
%     obj.fov(roilist(1,i)).roi(roilist(2,i))=tmp(i);
%     obj.fov(roilist(1,i)).roi(roilist(2,i)).save;
%     obj.fov(roilist(1,i)).roi(roilist(2,i)).clear;
% end


% catch
%     disp('Did not manage to classify.... ')
%     classi.channel=channelstore;
% end

classi.channel=channelstore;

  if numel(p)
    p.Value=0.9;
    p.Message='Saving project...Please wait...';
  end
    
  
shallowSave(obj);

