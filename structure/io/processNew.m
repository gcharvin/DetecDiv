function processObj=processNew(varargin)
% define new processing object
% if a numeric value is entered, it will target the repository

path=pwd; 
filename='myprocess';
id=1;

if nargin~=0
for i=1:numel(varargin)
    
if strcmp(varargin{i},'path')
path=varargin{i+1};
end

if strcmp(varargin{i},'filename')
filename=varargin{i+1};
end

if strcmp(varargin{i},'id')
id=varargin{i+1};
end

end

if numel(filename)==0
    filename=['myprocess ' char(datetime)];
end


else
  [filename,path,rep] = uiputfile('*.mat','File Selection',fullfile(path,[filename '.mat']));
  if isequal(filename,0)
   disp('User selected Cancel');
   processObj=[];
   return;
   else
   disp(['User selected ', fullfile(path, filename)]);
  end
end

if numel(strfind(filename,'.mat'))
    filename=replace(filename,'.mat','');
end


processObj=process(path,filename,id);

processObj.log('Classi creation','Creation')


