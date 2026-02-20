function classiObj=classiNew(varargin)
% define new classification object
% if a numeric value is entered, it will target the repository

path=pwd; 
filename='myclassi';
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
    filename=['myclassi ' char(datetime)];
end


else
  [filename,path,rep] = uiputfile('*.mat','File Selection',fullfile(path,[filename '.mat']));
  if isequal(filename,0)
   disp('User selected Cancel');
   classiObj=[];
   return;
   else
   disp(['User selected ', fullfile(path, filename)]);
  end
end

if numel(strfind(filename,'.mat'))
    filename=replace(filename,'.mat','');
end


classiObj=classi(path,filename,id);

classiObj.log('Classi creation','Creation')

%classiSave(classiObj);


%mkdir(path,filename);
%classiObj.setPath(fullfile(path,filename),filename);

%save(fullfile(path,filename,[filename '_classification.mat']),'classiObj');

%disp(['Classification ' fullfile(path,[filename '_' num2str(id) '.mat']) ' is created and saved !']);
%disp([ 'To add image / phyloCell project to the data, use the addData function']);

