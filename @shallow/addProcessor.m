function addProcessor(obj,varargin)
% add a classification to an exisiting project

% if option is provided, a classification from the repository is imported
% or a classification is duplicated from exisiting classification 

% get the number of exisiting classification
clas=obj.processing.processor;
n=numel(clas);

pth=fullfile(obj.io.path,obj.io.file);

if n==0
    obj.processing.processor=process;
    mkdir(pth,'processor');
end

name=[];
for i=1:numel(varargin)
if strcmp(varargin{i},'name')
name=varargin{i+1};
end
end


pth= fullfile(pth,'processor');

if numel(name)==0
 prompt='Please enter the name of the processor (Default: myprocess): ';
        name= input(prompt,'s');
        if numel(name)==0
            name='myprocess';
        end
end

obj.processing.processor(n+1) =  processNew('path',pth,'filename',name,'id',n+1);

% if nargin==2
% obj.processing.classification(n+1).init(option);
% else
% obj.processing.classification(n+1).init;    
% end
 
% shallowSave(obj);
 
% disp(['Shallow project is saved !']);





