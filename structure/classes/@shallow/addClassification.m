function addClassification(obj,varargin)
% add a classification to an exisiting project

% if option is provided, a classification from the repository is imported
% or a classification is duplicated from exisiting classification 

% get the number of exisiting classification
clas=obj.processing.classification;
n=numel(clas);

pth=fullfile(obj.io.path,obj.io.file);

if n==0
    obj.processing.classification=classi;
    mkdir(pth,'classification');
end

name=[];
for i=1:numel(varargin)
if strcmp(varargin{i},'name')
name=varargin{i+1};
end
end


pth= fullfile(pth,'classification');

if numel(name)==0
 prompt='Please enter the name of the classification (Default: myclassi): ';
        name= input(prompt,'s');
        if numel(name)==0
            name='myclassi';
        end
end

obj.processing.classification(n+1) =  classiNew('path',pth,'filename',name,'id',n+1);

% if nargin==2
% obj.processing.classification(n+1).init(option);
% else
% obj.processing.classification(n+1).init;    
% end
 
% shallowSave(obj);
 
 disp(['Shallow project is saved !']);





