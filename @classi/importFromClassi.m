function importFromClassi(obj,classitocopy,option,varargin)

% if option is provided and option(4), then rois must be an array of roi

% id.
%if nargin<4
%    option=[0 0 0 0];
%end


if nargin<3
    option=[0 0 0 0];
    %   rois=1:numel(classitocopy.roi);
end

rois=[];
convert={};

for i=1:numel(varargin)
    if strcmp(varargin{i},'rois')
        rois=varargin{i+1};
    end
    if strcmp(varargin{i},'convert')
        convert=varargin{i+1};
    end
end

if option(4)==1 & numel(rois)==0
    rois=1:numel(classitocopy.roi);
end

%option 1: transfer training parameters
%option 2: transfer trained classifier
%option 3: transferr formatted groundtruth
%option 4; transffer unformatted ROIs

disp(['Transferring parameters and data from classification: ' num2str(classitocopy.strid)]);

fi=fieldnames(obj);
%history_store=obj.history;

for i=1:numel(fi)
    if ~strcmp(fi{i},'path') && ~strcmp(fi{i},'strid') && ~strcmp(fi{i},'id') && ~strcmp(fi{i},'roi')  && ~strcmp(fi{i},'history') && ~strcmp(fi{i},'trainingParam') 
        obj.(fi{i})=classitocopy.(fi{i});
    end
end

% obj.history=history_store;

% training param

    if option(1)==1
      obj.trainingParam=classitocopy.trainingParam;
    end
    
% classifier
if exist([classitocopy.path '/' classitocopy.strid '.mat']) % copy the classifier variable to the new classif
    
    disp(['Found classifier file in the original ' classitocopy.strid ' classi']);
    
    %             prompt=['Transfer classifier from ' classitocopy.strid ' classification to '  obj.strid  '  [y/n] (Default: y): '];
    %             prevclas= input(prompt,'s');
    %             if numel(prevclas)==0
    %                 prevclas='y';
    %             end
    %             if strcmp(prevclas,'y')
    if option(2)==1
        copyfile([classitocopy.path '/' classitocopy.strid '.mat'],[obj.path '/' obj.strid '.mat']);
        obj.log(['Imported training parameters from '  classitocopy.strid],'Creation')
    end
    
end

% groundtruth data / images
if exist([classitocopy.path, '/trainingdataset/'])
    %             prompt=['Transfer trainingdataset folder with exported groundtruth data from ' num2str(classitocopy.strid) ' classification [y/n] (Default: y): '];
    %             prevclas= input(prompt,'s');
    %             if numel(prevclas)==0
    %                 prevclas='y';
    %             end
    %             if strcmp(prevclas,'y')
    if option(3)==1
        mkdir(obj.path,'trainingdataset')
        copyfile([classitocopy.path '/trainingdataset/*'],[obj.path '/trainingdataset/']);
        obj.log(['Transfered trainingdatset folder from '  classitocopy.strid],'Creation')
    end
end


% ROIs
%         prompt=['Transfer ROIs from ' num2str(classitocopy.strid) ' classification [y/n] (Default: y): '];
%         prevclas= input(prompt,'s');
%         if numel(prevclas)==0
%             prevclas='y';
%         end
%
%
%  if strcmp(prevclas,'y')
if option(4)==1
    
    % preserve ROI !!!
    
    convert
    obj.addROI(classitocopy,'rois',rois,'convert',convert); % import ROis from classification option
    obj.trainingset=1:numel(rois);
end

%   for i=1:numel(obj.roi) % remove irrelevant training and results data
%       obj.roi(i).removeData('train',classitocopy.strid);
%       obj.roi(i).removeData('results',classitocopy.strid);
%   end


