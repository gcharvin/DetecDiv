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

for i=1:numel(varargin)
    if strcmp(varargin{i},'classifierCNN')
    net=classifierCNN;
    inputSizeCNN = net.Layers(1).InputSize;
    classNamesCNN = net.Layers(end).ClassNames;
    numClassesCNN = numel(classNamesCNN);
    end
      if strcmp(varargin{i},'Frames')
          % not yet implemented
      end
end


if numel(roiobj.image)==0
    roiobj.load;
end

pix=find(roiobj.channelid==classif.channel(1)); % find channels corresponding to trained data

im=roiobj.image(:,:,pix,:);

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

if numel(pix)==1
    % 'ok'
    param=[];
    totphc=im;
    meanphc=0.5*double(mean(totphc(:)));
    maxphc=double(meanphc+0.7*(max(totphc(:))-meanphc));
    param.meanphc=meanphc;
    param.maxphc=maxphc;
end

vid=uint8(zeros(size(im,1),size(im,2),3,size(im,4)));

for j=1:size(im,4)
    
    if numel(pix)==1
        
        tmp=roiobj.preProcessROIData(pix,j,param);
        
        %tmp = double(imadjust(tmp,[meanphc/65535 maxphc/65535],[0 1]))/65535;
        %tmp=repmat(tmp,[1 1 3]);
        
    else
        tmp=im(:,:,:,j);
        tmp=double(tmp)/65535;
    end
    
    vid(:,:,:,j)=uint8(256*tmp);
    
end


%vid=vid(:,:,:,1:388);

%inputSize
%size(vid)

gfp = imresize(vid,inputSize(1:2));
video = centerCrop(vid,inputSize);


%size(video)
%aa=classifier.Layers

% nframes=inputSize(1);
% narr=floor(size(im,4)/nframes);
% nrem=mod(size(im,4),nframes);
%
% if nrem>0
%     narr=narr+1;
% end
%
% videoout={};
%
% %if size(im,4)>nframes
% for i=1:narr
%     if i==narr
%         ende=(i-1)*nframes+nrem;
%     else
%         ende=i*nframes ;
%     end
%    videoout{i}=video(:,:,:,(i-1)*nframes+1:ende);
% end
% %else
% %   videoout{1}=video;
% %end
%
% %size(videoout)
% %size(videoout{1})
% %size(videoout{3})

disp('Starting video classification...');

% this function predict  is used instead of 'classify' function which causes an error
% on R2019b

try
    
    prob=predict(classifier,video);
    %probCNN=predict(classifierCNN,video);
    if nargin==4
        [labelCNN,probCNN] = classify(classifierCNN,gfp);
    end
catch
    
    disp('Error with predict function  : likely out of memory issue with GPU, trying CPU computing...');
    prob=predict(classifier,video,'ExecutionEnvironment', 'cpu');
    %probCNN=predict(classifierCNN,video,'ExecutionEnvironment', 'cpu');
    if nargin==4
        [labelCNN,probCNN] = classify(classifierCNN,gfp);
    end
end

labels = classifier.Layers(end).Classes;
if size(prob,1) == numel(labels) % adjust matrix depending on matlab version
    prob=prob';
end
[~, idx] = max(prob,[],2);
label = labels(idx);

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

if nargin==4
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