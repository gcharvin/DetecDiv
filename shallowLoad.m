function [shallowObj msg]=shallowLoad(filename)


if nargin==0
   [file,path] = uigetfile('*.mat','Select a shallow project',pwd);
   if isequal(file,0)
   disp('User selected Cancel')
   msg=[];
   shallowObj=[];
   return;
   else
   disp(['User selected ', fullfile(path, file)]); 
   filename=fullfile(path, file);
   end
end

[path file ext]=fileparts(filename);

%filename
abspath=what(path);
abspath=abspath.path;

filename=fullfile(abspath,[file ext]);

load(filename);
path=abspath;

if isunix || ismac
shallowObj.setPath([path '/'],file); % adjust path
else
shallowObj.setPath([path '\'],file); % adjust path 
end

% check if project is already open in the workspace
varlist=evalin('base','who');
     for i=1:numel(varlist)
                
                if strcmp(varlist{i},'ans')
                        continue;
                end
                
                 tmp=evalin('base',varlist{i});
                 if isa(tmp,'shallow')
                     % check path & filenemae
                     if strcmp(path, tmp.io.path(1:end-1)) & strcmp(file, tmp.io.file) % var exists already
                         msg=['Project is already in the workspace under the var name:' varlist{i} '; Quitting...'];
                         disp(msg);
                         shallowObj=[];
                         return
                     end
                 end
     end

msg=['Successfully loaded shallow project ' fullfile(path,[file '.mat']) '!'];
disp(msg);
disp('');

% now loading saved classi objects attached to project 

% here browse the classification folder and load all avaiable classifiers 

listclassi=dir(fullfile(path,file,'classification'));
listclassi=listclassi(~contains({listclassi.name},{'.','..'}));
listclassi=listclassi(find(arrayfun(@(x) x.isdir==1,listclassi)));

% sort the classi by ending number

if numel(listclassi)
 shallowObj.processing.classification=classi;
end
 
arr=[];
for j=1:numel(listclassi)
tmp=regexp(listclassi(j).name, '\d+$','match') ;
arr(j)=str2num(tmp{1});
end

[s ix]=sort(arr);

listclassi=listclassi(ix);

for j=1:numel(listclassi)
    
    name=listclassi(j).name;
    str=fullfile(path,file,'classification',name,[name '_classification.mat']);
    
    [classiObj msg]=classiLoad(str);
    
     shallowObj.processing.classification(j)=classiObj;
end

% for i=1:numel(shallowObj.processing.classification)
%     [pathc,filec]=shallowObj.processing.classification(i).getPath;
%     
%  [classiObj msg]=classiLoad(fullfile(pathc,[filec '_classification.mat']));
%  
% 
% end

if numel(shallowObj.fov(1).srcpath{1})~=0 % srce path has been set for at leats one FOV; update ? 
disp('* Warning *');
disp('* This project contains at least one FOV wit the following path');
disp('* The current path are:*');
for i=1:numel(shallowObj.fov)
disp([shallowObj.fov(i).srcpath{1}]);
end
disp('* Need to update the path of the source images ?');
disp('* To do so, use the shallowObj.setSrcPath function');
end

