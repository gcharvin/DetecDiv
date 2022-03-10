function classifyImageLSTMNetFun(roiobj,classif,classifier,varargin)

%load([path '/netCNN.mat']); % load the googlenet to get the input size of image

% now load and read video
fprintf('Load videos...\n');

%inputSize = netCNN.Layers(1).InputSize(1:2);

for i=1:numel(classifier.Layers)
    if strcmp(class(classifier.Layers(i)), 'nnet.cnn.layer.SequenceInputLayer')
        inputSize = classifier.Layers(i).InputSize(1:2);
        break
    end
end

channel=classif.channelName;
frames=[];
classifierCNN=[];

for i=1:numel(varargin)
    if strcmp(varargin{i},'classifierCNN')        
        classifierCNN=varargin{i+1};
        net=classifierCNN;
        inputSizeCNN = net.Layers(1).InputSize;
        classNamesCNN = net.Layers(end).ClassNames;
        numClassesCNN = numel(classNamesCNN);
    end
      if strcmp(varargin{i},'Frames')
          frames=varargin{i+1};
          % not yet implemented
      end
        if strcmp(varargin{i},'Channel')
           channel=varargin{i+1};
       end
end


if numel(roiobj.image)==0
    roiobj.load;
end

pix=roiobj.findChannelID(channel{1});

%pix=find(roiobj.channelid==classif.channel(1)); % find channels corresponding to trained data
if numel(frames)==0
    frames=1:size(roiobj.image,4);
end

im=roiobj.image(:,:,pix,frames);
%im=roiobj.image(:,:,pix,:);

% if exist('frames','var')
%     if frames==0
%         frames=1:numel(im(1,1,1,:)); %classify only frames with GT
%     end
% else
%     frames=1:numel(im(1,1,1,:));
% end

%im=roiobj.image(:,:,pix,frames);

disp('Formatting video before classification....');
%size(im)

vid=uint8(zeros(size(im,1),size(im,2),3,numel(frames)));

for j=frames
    param=[];   
        
    tmp=roiobj.preProcessROIData(pix,j,param);
    
    %tmp = double(imadjust(tmp,[meanphc/65535 maxphc/65535],[0 1]))/65535;
    %tmp=repmat(tmp,[1 1 3]);        
    vid(:,:,:,j)=uint8(256*tmp);
    
end


%vid=vid(:,:,:,1:388);

%inputSize
%size(vid)

%gfp = imresize(vid,inputSize(1:2));
video = centerCrop(vid,inputSize);

disp('Starting video classification...');

% this function predict  is used instead of 'classify' function which causes an error
% on R2019b


 try   
    prob=predict(classifier,video,'ExecutionEnvironment', classif.trainingParam.execution_environment{end});
    %probCNN=predict(classifierCNN,video);
    if numel(classifierCNN)
       % [labelCNN,probCNN] = classify(classifierCNN,gfp);
         % [labelCNN,probCNN] = classify(classifierCNN,video);
             probCNN=predict(classifierCNN,video);
    end
    catch
    
    disp('Error with predict function  : likely out of memory issue with GPU, trying CPU computing...');
    prob=predict(classifier,video,'ExecutionEnvironment', 'cpu');
    %probCNN=predict(classifierCNN,video,'ExecutionEnvironment', 'cpu');
    if numel(classifierCNN)
      %  [labelCNN,probCNN] = classify(classifierCNN,gfp);
          probCNN=predict(classifierCNN,video,'ExecutionEnvironment', 'cpu');
    end

end

labels = classifier.Layers(end).Classes;
if size(prob,1) == numel(labels) % adjust matrix depending on matlab version
    prob=prob';
end
[~, idx] = max(prob,[],2);
label = labels(idx);

if numel(classifierCNN)
    labelCNN = classifierCNN.Layers(end).Classes;
    if size(probCNN,1) == numel(labelCNN) % adjust matrix depending on matlab version
        probCNN=probCNN';
    end
    [~, idx] = max(probCNN,[],2);
    labelCNN = labelCNN(idx);
end

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



if classif.output==0
    results.(classif.strid).id=zeros(1,size(im,4));
else
    results.(classif.strid).id =0;
end


results.(classif.strid).labels=label';
results.(classif.strid).classes=classif.classes;
results.(classif.strid).prob=prob';

for i=1:numel(classif.classes)
    pix=label==classif.classes{i};
    results.(classif.strid).id(pix)=i;
end

if numel(classifierCNN)
    if classif.output==0
        results.(classif.strid).idCNN=zeros(1,size(im,4));
    else
        results.(classif.strid).idCNN=0;
    end
    
    results.(classif.strid).labelsCNN=labelCNN';
    results.(classif.strid).classesCNN=classif.classes;
    
    results.(classif.strid).probCNN=flipud(probCNN'); % fix orientation of array here !!!!
    
    for i=1:numel(classif.classes)
        pix=labelCNN==classif.classes{i};
        results.(classif.strid).idCNN(pix)=i;
    end
end

roiobj.results=results;
roiobj.save;
roiobj.clear;


%roiout=roiobj;

%roiobj.clear;

% results.id=roiobj.id;
% results.path=roiobj.path;
% results.parent=roiobj.parent;
%
% % stores results locally during classification
%
% if exist([classif.path '/' classif.strid '_results.mat']) % this filles needs to be removed when classification starts ?
%     load([classif.path '/' classif.strid '_results.mat']) % load res variable
%     n=length(res);
%     res(n+1)={results};
% else
%
%    res={results};
% end
% save([classif.path '/' classif.strid '_results.mat'],'res');
% pix=label=='largebudded';
% mov.trap(i).div.deepLSTM(pix)=2;
%
% pix=label=='smallbudded';
% mov.trap(i).div.deepLSTM(pix)=1;
%
% pix=label=='unbudded';
% mov.trap(i).div.deepLSTM(pix)=0;


%mov.trap(i).div.deepLSTM=YPred;



function videoResized = centerCrop(video,inputSize)

sz = size(video);

if sz(1) < sz(2)
    % Video is landscape
    idx = floor((sz(2) - sz(1))/2);
    video(:,1:(idx-1),:,:) = [];
    video(:,(sz(1)+1):end,:,:) = [];
    
elseif sz(2) < sz(1)
    % Video is portrait
    idx = floor((sz(1) - sz(2))/2);
    video(1:(idx-1),:,:,:) = [];
    video((sz(2)+1):end,:,:,:) = [];
end

videoResized = imresize(video,inputSize(1:2));


%analyzeNetwork(lgraph)




%etc ...