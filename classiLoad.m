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

if isnumeric(filename) % loads classi from repository
                    list=listRepositoryClassi;
                    if numel(list)==0
                        classiObj=[];
                        return;
                    end
                    
                    disp(list)
                    
                    prompt='Please enter the number associated with the classification you wish to set from the repository ? (Default:1): ';
                    classitype= input(prompt);
                     if numel(classitype)==0
                        classitype=1;
                     end
                    
                     filename=listRepositoryClassi(classitype);        
end

[path file ext]=fileparts(filename);

%filename
abspath=what(path);
abspath=abspath.path;

filename=fullfile(abspath,[file ext]);

load(filename);
path=abspath;

if ~isa(classiObj,'classi')
    disp('This file does not correspond to a classification object');
end

if isunix || ismac
classiObj.setPath([path '/'],file); % adjust path
else
classiObj.setPath([path '\'],file); % adjust path 
end

classiObj.log(['Classi was loaded with this path: path'],'Creation');

disp(['Successfully loaded classification ' fullfile(path,[file '.mat']) '!']);

