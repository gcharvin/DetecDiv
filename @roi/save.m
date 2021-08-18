function save(obj)
% saves data associated with a given trap and clear memory

im=obj.image;

% save images

if numel(im)~=0
  %   ['save  ' '''' obj.path '/im_' num2str(obj.id) '.mat' ''''  ' im']
  disp('');
 disp(['Saving ' obj.path '/im_' obj.id '.mat image file for ROI ' obj.id]);
 obj.log(['Saving ROI image to ' obj.path '/im_' obj.id '.mat'],'Saving')
 
eval(['save  ' '''' obj.path '/im_' obj.id '.mat' ''''  ' im']); 
end



% '''' allows one to use quotes !!!
 
