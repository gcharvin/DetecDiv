function processData(obj,classiid,varargin)
% high level function to classify data

% classiid is the index of the classifier to be used

% roilist is an 2 x N array containing FOV IDs and ROI IDs from the shallow
% object to be classified
%'Classifier' loads the classifier


rois=[];
fovs=[];

p=[];

channel=[];
frames=[];

for i=1:numel(varargin)
    if strcmp(varargin{i},'Rois')
        rois=varargin{i+1};
    end
    
    if strcmp(varargin{i},'Fovs')
        fovs=varargin{i+1};
    end
    
    if strcmp(varargin{i},'Frames') % is a cell array with the same number of elements as FOVs
        frames=varargin{i+1};
    end
    
  if strcmp(varargin{i},'Progress') % update progress bar
        p=varargin{i+1};
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
roilist3=[];


for i=1:numel(fovs)
    
    ro= rois{i};
    
    roilist=[roilist fovs(i)*ones(1,numel(ro))];
    roilist3=[roilist3 i*ones(1,numel(ro))];
    roilist2=[roilist2 ro];
    
    
end

roilist(2,:)=roilist2;

if numel(frames)
 fra={};
for i=1:size(roilist,2)
    fra{i}= frames{roilist3(i)};
end
end

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



classifyFun=obj.processing.processor(classiid).processFun;
       param= obj.processing.processor(classiid).processArg;

if numel(p)
    p.Value=0.2;
    p.Message='Loading processing function....';
end

disp(['Processing new data using ' classifyFun]);

classi=obj.processing.processor(classiid);

% 

disp([num2str(size(roilist,2)) ' ROIs to process with processor, be patient...']);

tmp=roi; % build list of rois
for i=1:size(roilist,2)
    tmp(i)=obj.fov(roilist(1,i)).roi(roilist(2,i));
end


%try 

parfor i=1:size(roilist,2) % loop on all ROIs using parrallel computing   
    roiobj=tmp(i);
    if numel(roiobj.id)==0
        continue;
    end
    
    disp('-----------');
    disp(['Processing ' num2str(roiobj.id)]);
    
%     if numel(p)
%     p.Value=0.9* double(i)./double(size(roilist,2));
%     
%     p.Message=['Processing ROI  ' roiobj.id];
%     end


   
   if numel(frames)==0
   out= feval(classifyFun,param,roiobj); % launch the training function for classification
   else
    out=feval(classifyFun,param,roiobj,fra{i});    
   end
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


  if numel(p)
    p.Value=0.9;
    p.Message='Saving project...Please wait...';
  end
    
  
%shallowSave(obj);

