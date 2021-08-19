function classiObj=classiLoad(filename)


if nargin==0
   [file,path] = uigetfile('*.mat','Select a classification project',pwd);
   if isequal(file,0)
   disp('User selected Cancel')
   classiObj=[];
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
classiObj.setPath([path '/'],file); % adjust path
else
classiObj.setPath([path '\'],file); % adjust path 
end

disp(['Successfully loaded classification project ' fullfile(path,[file '.mat']) '!']);
disp('');
