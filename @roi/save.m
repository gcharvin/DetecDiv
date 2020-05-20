function save(obj)
% saves data associated with a given trap and clear memory

im=obj.image;

% save images

if numel(im)~=0
  %   ['save  ' '''' obj.path '/im_' num2str(obj.id) '.mat' ''''  ' im']
  disp('');
 fprintf(['Saving ' obj.path '/im_' obj.id '.mat image file for ROI ' obj.id '\n']);
 
eval(['save  ' '''' obj.path '/im_' obj.id '.mat' ''''  ' im']); 
end

% '''' allows one to use quotes !!!
 
