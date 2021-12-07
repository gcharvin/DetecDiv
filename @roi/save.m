function save(obj,option)
% saves data associated with a given trap and clear memory
% option==results : saves the roi.result only

im=obj.image;
roiobj=obj;
results=obj.results;
% save images

resonly=0;
if nargin==2
    if strcmp(option,'results') % load only the results
        resonly=1;
        disp(['Saving results only for ROI ' obj.id]);
    end
end

if resonly==1
    obj.log(['Saving results only to ' obj.path '/results_' obj.id '.mat'],'Saving')
    disp(['Saving ROI results ' obj.id ' to ' obj.path '/results_' obj.id '.mat']);
    eval(['save  ' '''' obj.path '/results_' obj.id '.mat' ''''  ' results']);
    return;
end

if numel(im)~=0
    %   ['save  ' '''' obj.path '/im_' num2str(obj.id) '.mat' ''''  ' im']
    %  disp('');
    disp(['Saving ROI ' obj.id ' to ' obj.path '/im_' obj.id '.mat']);   
    obj.log(['Saving ROI to ' obj.path '/im_' obj.id '.mat'],'Saving')
    obj.log(['Saving results to ' obj.path '/results_' obj.id '.mat'],'Saving')
    
    if isfolder(obj.path)
    eval(['save  ' '''' obj.path '/im_' obj.id '.mat' ''''  ' roiobj']);   
    disp(['Saving ROI results ' obj.id ' to ' obj.path '/results_' obj.id '.mat']);
    eval(['save  ' '''' obj.path '/results_' obj.id '.mat' ''''  ' results']);
    else
       disp('ERROR: Could not find / access the requested folder !!! ');
    end
    
else
   disp('Image is not loaded ; Load image first ...');
end
% '''' allows one to use quotes !!!