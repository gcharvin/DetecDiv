function save(obj)
% saves data associated with a given trap and clear memory

im=obj.image;
roiobj=obj;
results=obj.results; 
% save images

if numel(im)~=0
  %   ['save  ' '''' obj.path '/im_' num2str(obj.id) '.mat' ''''  ' im']
  disp('');
 disp(['Saving ROI ' obj.id ' to ' obj.path '/im_' obj.id '.mat']);

 
 obj.log(['Saving ROI to ' obj.path '/im_' obj.id '.mat'],'Saving')
 obj.log(['Saving results to ' obj.path '/results_' obj.id '.mat'],'Saving')
 
eval(['save  ' '''' obj.path '/im_' obj.id '.mat' ''''  ' roiobj']); 

 disp(['Saving ROI results ' obj.id ' to ' obj.path '/results_' obj.id '.mat']);
eval(['save  ' '''' obj.path '/results_' obj.id '.mat' ''''  ' results']); 

end



% '''' allows one to use quotes !!!
 
