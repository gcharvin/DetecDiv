function classifyTimeseriesClassifReg(roiobj,classif,classifier,varargin)

%load([path '/netCNN.mat']); % load the googlenet to get the input size of image

% now load and read video
fprintf('Loading and formatting data...\n');

X=[];


strfield=classif.trainingset;
pix=strfind(strfield,'.');

if numel(pix)==0
    str={strfield};
else
    str={strfield(1:pix(1)-1)};
    
    cc=1;
    for i=1:numel(pix)-1
        str{cc+1}=strfield(pix(i)+1:pix(i+1)-1);
        cc=cc+1;
    end
end
str{cc+1}=strfield(pix(cc)+1:end);

% parse fields

    tmp=roiobj;
    for j=1:numel(str)
        tmp=tmp.(str{j});
    end    
    
    X=tmp;

disp('Starting video classification...');

% this function predict  is used instead of 'classify' function which causes an error
% on R2019b

try

    if ~isempty(X)
        prob=predict(classifier,X);
    else
        prob=[];
    end

catch 
    
disp('Error with predict function  : likely out of memory issue with GPU, trying CPU computing...');
prob=predict(classifier,video,'ExecutionEnvironment', 'cpu');
%probCNN=predict(classifierCNN,video,'ExecutionEnvironment', 'cpu');

end
  
if numel(classif.classes)>0
labels = classifier.Layers(end).Classes;
    if size(prob,1) == numel(labels) % adjust matrix depending on matlab version 
       prob=prob';
    end
 [~, idx] = max(prob,[],2);
 label = labels(idx);
else
 label=[];   
end
 
% labels = classifier.Layers(end).Classes;
% if size(prob,1) == numel(labels) % adjust matrix depending on matlab version 
%    prob=prob';
% end
%  [~, idx] = max(prob,[],2);
%  label = labels(idx);
 
 %if size(probCNN,1) == numel(labels) % adjust matrix depending on matlab version 
 %  probCNN=probCNN';
%end
 %[~, idx] = max(probCNN,[],2);
 %labelCNN = labels(idx);
 
%  [~, idx] = max(prob,[],2);
%  label = labels(idx);
% %label = classify(classifier,video,'ExecutionEnvironment', 'cpu'); % in case the gpu crashes because of out of memory
% % prob=activations(classifier,video,'softmax','OutputAs','channels','ExecutionEnvironment', 'cpu');
% end

%label=[];

% lab=[];
% %if size(im,4)>nframes
% for i=1:narr
%    lab = [lab label{i}];
% end
%else
   %label=label{1}; 
%end

%label=lab(1:size(im,4));

results=roiobj.results;

results.(classif.strid)=[];

    results.(classif.strid).labels=label';
    results.(classif.strid).classes=classif.classes;
    results.(classif.strid).prob=prob';
    
    
    if numel(classif.classes)>0
    for i=1:numel(classif.classes)
   pix=label==classif.classes{i};
   results.(classif.strid).id(pix)=i;
    end
    end
    
   % results.(classif.strid).id=prob; %zeros(1,size(im,4));

    %results.(classif.strid).labels=label';
   % results.(classif.strid).classes=classif.classes;
   % results.(classif.strid).prob=prob';
    
%     for i=1:numel(classif.classes)
%    pix=label==classif.classes{i};
%    results.(classif.strid).id(pix)=i;
%     end
    
 
    
    
roiobj.results=results; 

roiobj.save;
roiobj.clear;

%roiout=roiobj;



