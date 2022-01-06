function [classifierout, status]=loadClassifier(classif,option)
% load classifier (network) associated with a given @classi

path=classif.path;
name=classif.strid;

force=false;
check=false;
status=false;

if nargin==2
    if strcmp(option,'force')
        % force reloading of classifier
        force=true;
    end
    
      if strcmp(option,'check')
        % force reloading of classifier
        check=true;
    end
end
 

W = evalin('base','whos') ;
doesExist = ismember(name,{W(:).name});

if check
    if doesExist
     tmp=evalin('base',name);   
    status=doesExist & strcmp(class(tmp),'DAGNetwork');
    end
     classifierout=[];
    return;
end


if doesExist & ~force
     tmp=evalin('base',name);   
     
    if strcmp(class(tmp),'DAGNetwork')
    disp('Classifier is already loaded in the workspace');
    classifierout= evalin('base',name);
    status=true;
    return;
    end
    
end

 disp(['Loading classifier: ' name]);
    
 str=[path '/' name '.mat'];
     
 if exist(str)
    load(str); % load classifier 
 else
    disp('Classifier does not exist ! Has training been done?');
    classifierout=[];
    check=false;
    return;
 end
 

 classifierout=classifier;
 check=true;
assignin('base',name',classifier);

