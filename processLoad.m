function [processObj msg]=processLoad(filename)

msg=[];

if nargin==0
   [file,path] = uigetfile('*.mat','Select a processor (i.e. a XXXXX_processor.mat file)',pwd);
   if isequal(file,0)
   disp('User selected Cancel')
   processObj=[];
   return;
   else
   disp(['User selected ', fullfile(path, file)]); 
   filename=fullfile(path, file);
   end
end

% if isnumeric(filename) % loads classi from repository
%                     list=listRepositoryClassi;
%                     if numel(list)==0
%                         processObj=[];
%                         return;
%                     end
%                     
%                     disp(list)
%                     
%                     prompt='Please enter the number associated with the processor you wish to set from the repository ? (Default:1): ';
%                     classitype= input(prompt);
%                      if numel(classitype)==0
%                         classitype=1;
%                      end
%                     
%                      filename=listRepositoryClassi(classitype);        
% end

[path file ext]=fileparts(filename);

%filename
abspath=what(path);
abspath=abspath.path;

filename=fullfile(abspath,[file ext]);

load(filename);
path=abspath;

if ~isa(processObj,'process')
    msg='This file does not correspond to a processot object';
    disp('This file does not correspond to a processor object');
    processObj=[];
    return;
    
end

% check if classi is already open in the workspace
varlist=evalin('base','who');
     for i=1:numel(varlist)
                
                if strcmp(varlist{i},'ans')
                        continue;
                end
                
                 tmp=evalin('base',varlist{i});
                 if isa(tmp,'process')
                     % check path & filenemae
                  %   path,file
                  %   a=tmp.path, b=tmp.strid
                     if strcmp(path,tmp.path(1:end-1)) & strcmp(file, [tmp.strid  '_processor']) % var exists already
                         msg=['Processor is already in the workspace under the var name:' varlist{i} '; Quitting...'];
                         disp(msg);
                         processObj=[];
                         return
                     end
                 end
    end
     

if isunix || ismac
processObj.setPath([path '/'],file); % adjust path
else
processObj.setPath([path '\'],file); % adjust path 
end

msg=['Process was loaded with this path:' path];

processObj.log(['Process was loaded with this path:' path],'Creation');

disp(['Successfully loaded processor ' fullfile(path,[file '.mat']) '!']);

