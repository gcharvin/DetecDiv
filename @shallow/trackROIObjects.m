function trackROIObjects(obj,channelstr,inputchannelstr,roilist,classifier)
% high level function to track objects

%channelstr is a string that identifies the semgmented objects
% inputchannelstr is a string that iddentifies the apparence image 

% roilist is an 2 x N array containing FOV IDs and ROI IDs from the shallow
% object to be classified 

if nargin<5
   classifier=[];
end

if nargin==3 | numel(roilist)==0
   % classify all ROIs
   roilist=[];
   roilist2=[];
   
   for i=1:length(obj.fov)
      % for j=1:numel(obj.fov(i).roi)
     %size( ones(1,length(obj.fov(i).roi)) )
           roilist = [roilist i*ones(1,length(obj.fov(i).roi)) ];
           roilist2 = [roilist2  1:length(obj.fov(i).roi) ]; 
      % end
   end
  
roilist(2,:)=roilist2;
end

disp('Starting object tracking....');

% first load classifier if not loadad to save some time 
if numel(classifier)==0
   classifier=resnet50;
end

disp([num2str(size(roilist,2)) ' ROIs to track, be patient...']);

tmp=roi; % build list of rois
for i=1:size(roilist,2)
tmp(i)=obj.fov(roilist(1,i)).roi(roilist(2,i));
end

parfor i=1:size(roilist,2) % loop on all ROIs using parrallel computing
    
 roiobj=tmp(i);

 if numel(roiobj.id)==0
     continue;
 end
 
  disp('-----------');
  disp(['Classifying ' num2str(roiobj.id)]);
 
%  if strcmp(classif.category{1},'Image') % in this case, the results are provided as a series of labels
%  roiobj.results=zeros(1,size(roiobj.image,4)); % pre allocate results for labels
%  end
 
tmp(i)=roiobj.trackObjects(channelstr,inputchannelstr,[],classifier); % launch the training function for classification
% since roiobj is a handle, no need to have an output to this the function
% in roiobj.results

end

for i=1:size(roilist,2)
obj.fov(roilist(1,i)).roi(roilist(2,i))=tmp(i);
obj.fov(roilist(1,i)).roi(roilist(2,i)).save;
obj.fov(roilist(1,i)).roi(roilist(2,i)).clear;
end


shallowSave(obj);

