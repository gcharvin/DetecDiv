function shallowObj=shallowNew(varargin)
% define new analysis project
% varargin: 'Path' 'Filename' to input the location and path of the
% project. 

path=pwd; 
filename='myproject';

if nargin~=0
for i=1:numel(varargin)
    
if strcmp(varargin{i},'path')
path=varargin{i+1};
end

if strcmp(varargin{i},'filename')
filename=varargin{i+1};
end
end
else
  [filename,path,rep] = uiputfile('*.mat','File Selection',fullfile(path,[filename '.mat']));
  if isequal(filename,0)
   disp('User selected Cancel');
   shallowObj=[];
   return;
   else
   disp(['User selected ', fullfile(path, filename)]);
  end
end

if numel(strfind(filename,'.mat'))
    filename=replace(filename,'.mat','');
end

shallowObj=shallow;
shallowObj.setPath(path,filename);

mkdir(path,filename);

save(fullfile(path,[filename '.mat']),'shallowObj');

disp(['Shallow project ' fullfile(path,[filename '.mat']) ' is created and saved !']);
disp([ 'To add image / phyloCell project to the data, use the addData function']);

