function load(obj,option)
% load data associated with a given trap

% first load images
%%%%
% to do here : load data for ROIs
%%%%
pathr=obj.path;
resonly=0;

if nargin==2
    if strcmp(option,'results') % load only the results
        resonly=1;
        disp(['Loading results only for ROI ' obj.id]);
    end
end

if numel(obj.path)==0
    disp('ROI is created but has not been extracted from raw image! Quitting....');
    return;
end

 t=replace(obj.path,'\','/');
 
if resonly==0
if exist([obj.path '/im_' obj.id '.mat']) 
    
    
    
    %eval(['load  ' obj.path '/im_' num2str(obj.id) '.mat']);
    
    load([obj.path '/im_' obj.id '.mat']);
    roiobj.path=pathr;
    %obj.image=im;
    
    if exist('im','var') % compatibility with previous roi management: this is ised to load ROI matrix if only the matrix is stored
        obj.image=im;
    end
    
    if exist('roiobj','var')
        obj=propValues(obj,roiobj);
        %obj=roiobj;
        %'ok'
    end
    disp(['ROI loaded from ' t '/im_' obj.id '.mat ' obj.id]);
else
    fprintf(['Error : file not found:   ' t  '/im_' obj.id '.mat failed for ROI ' obj.id '!!!\n']);
end
end

if exist([obj.path '/results_' obj.id '.mat'])
    %disp(['Loading ' t '/results_' obj.id '.mat result struct for ROI ' obj.id]);
    eval(['load  ' '''' obj.path '/results_' obj.id '.mat' '''']);    
    obj.results=results;
    disp(['ROI results loaded from ' t '/results_' obj.id '.mat ' obj.id]);
else
    
    fprintf(['Error: file not found  ' t  '/results_' obj.id '.mat failed for ROI ' obj.id '\n']);
    
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