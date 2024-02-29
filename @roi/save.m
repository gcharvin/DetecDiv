function save(obj,option)
% saves data associated with a given trap and clear memory
% option==results : saves the roi.result only

im=obj.image;
roiobj=obj;
results=obj.results;
data=obj.data;
% save images

resonly=0;
if nargin==2
    if strcmp(option,'data') % load only the results
        resonly=1;
        disp(['Saving data only for ROI ' obj.id]);
    end
end

if resonly==1
    obj.log(['Saving data only to ' obj.path '/data_' obj.id '.mat'],'Saving')
    disp(['Saving ROI data ' obj.id ' to ' obj.path '/data_' obj.id '.mat']);
    eval(['save  ' '''' obj.path '/data_' obj.id '.mat' ''''  ' data']);
    return;
end

if numel(im)~=0
    %   ['save  ' '''' obj.path '/im_' num2str(obj.id) '.mat' ''''  ' im']
    %  disp('');
    disp(['Saving ROI image and data to ' obj.id ' to ' obj.path '/im_' obj.id '.mat']);   
    obj.log(['Saving ROI to ' obj.path '/im_' obj.id '.mat'],'Saving')
    obj.log(['Saving data to ' obj.path '/data_' obj.id '.mat'],'Saving')
    
else
   disp('Image is not loaded ; Load image first ...');
   return;
end

if numel(obj.path)
   if isfolder(obj.path)
    eval(['save  ' '''' obj.path '/im_' obj.id '.mat' ''''  ' roiobj']);   
    disp(['Saving ROI data to ' obj.id ' to ' obj.path '/data_' obj.id '.mat']);
    eval(['save  ' '''' obj.path '/data_' obj.id '.mat' ''''  ' data']);
    else
       disp('ERROR: Could not find / access the requested folder !!! ');
   end
end

% '''' allows one to use quotes !!!


 
