function save(obj)
% saves data associated with a given trap and clear memory

im=obj.image;

% save images

if numel(im)~=0
eval(['save  ' obj.path '/im_' num2str(obj.id) '.mat im']); 
end

% save analysis matrices

%  classi=obj.classi;
%  train=obj.train;
%  traintrack=obj.traintrack;
%  track=obj.track; 
%  
%  if numel(classi)~=0
%  eval(['save  ' obj.path '/an_' num2str(obj.id) '.mat classi train traintrack track']);     
%  end
 
