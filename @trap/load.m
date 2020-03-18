function load(obj)
% load data associated with a given trap 

% first load images


if exist([obj.path '/im_' num2str(obj.id) '.mat'])
 fprintf(['Loading  ' obj.path '/im_' num2str(obj.id) '.mat image file for trap ' obj.id '\n']);   
eval(['load  ' obj.path '/im_' num2str(obj.id) '.mat']); 
obj.gfp=gfp;
else
 fprintf(['!!! Loading  ' obj.path '/im_' num2str(obj.id) '.mat failed for trap !!!' obj.id '\n']);   
end

% load  analyses matrices

if exist([obj.path '/an_' num2str(obj.id) '.mat'])
 fprintf(['Loading  ' obj.path '/im_' num2str(obj.id) '.mat analysis file for trap ' obj.id '\n']); 
eval(['load  ' obj.path '/an_' num2str(obj.id) '.mat']); 
 obj.classi=classi;
 obj.train=train;
 obj.traintrack=traintrack;
 obj.track=track; 
else
 fprintf(['!!! Loading  ' obj.path '/an_' num2str(obj.id) '.mat failed for trap !!!' obj.id '\n']);  
 
end