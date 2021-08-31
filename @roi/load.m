function load(obj)
% load data associated with a given trap 

% first load images
%%%%
% to do here : load data for ROIs 
%%%%

if exist([obj.path '/im_' obj.id '.mat'])

 disp(['Loading ' obj.path '/im_' obj.id '.mat image file for ROI ' obj.id]);   
 
%eval(['load  ' obj.path '/im_' num2str(obj.id) '.mat']); 

eval(['load  ' '''' obj.path '/im_' obj.id '.mat' '''']); 

%obj.image=im;

if exist('im','var') % compatibility with previous roi management: this is ised to load ROI matrix if only the matrix is stored
    obj.image=im;
end

if exist('roiobj','var')
    obj=propValues(obj,roiobj);
%obj=roiobj;
%'ok'
end

else
 fprintf(['ERROR: Loading  ' obj.path '/im_' obj.id '.mat failed for ROI ' obj.id '!!!\n']);   
end

obj.log(['Loading ROI image from ' obj.path],'Loading')

function newObj=propValues(newObj,orgObj)
pl = properties(orgObj);
for k = 1:length(pl)
    if isprop(newObj,pl{k})
        newObj.(pl{k}) = orgObj.(pl{k});
    end
end

% load  analyses matrices

% if exist([obj.path '/an_' num2str(obj.id) '.mat'])
%  fprintf(['Loading  ' obj.path '/im_' num2str(obj.id) '.mat analysis file for trap ' obj.id '\n']); 
% eval(['load  ' obj.path '/an_' num2str(obj.id) '.mat']); 
%  obj.classi=classi;
%  obj.train=train;
%  obj.traintrack=traintrack;
%  obj.track=track; 
% else
%  fprintf(['!!! Loading  ' obj.path '/an_' num2str(obj.id) '.mat failed for trap !!!' obj.id '\n']);  
%  
% end