function classifyImageLSTMNetFun(roiobj,classif,classifier)

%load([path '/netCNN.mat']); % load the googlenet to get the input size of image

% now load and read video
fprintf('Load videos...\n');

%inputSize = netCNN.Layers(1).InputSize(1:2);

%inputSize=[size(roiobj.image,1) size(roiobj.image,2)];
inputSize = classifier.Layers(140).InputSize(1:2)

%return;
% x y size of the input movie (140th layer)


%for i=id
%fprintf(['Processing video:' num2str(i) '...\n']);
%load([mov.path '/labeled_video_' mov.trap(i).id '.mat']); % loads deep, vid, lab (categories of labels)

if numel(roiobj.image)==0
    roiobj.load;
end

pix=find(roiobj.channelid==classif.channel); % find channels corresponding to trained data
im=roiobj.image(:,:,pix,1:225);

size(im)

if numel(pix)==1
    % 'ok'
    totphc=im;
    meanphc=0.5*double(mean(totphc(:)));
    maxphc=double(meanphc+0.7*(max(totphc(:))-meanphc));
end

vid=uint8(zeros(size(im,1),size(im,2),3,size(im,4)));

for j=1:size(im,4)
    tmp=im(:,:,:,j);
    
    if numel(pix)==1
        
        tmp = double(imadjust(tmp,[meanphc/65535 maxphc/65535],[0 1]))/65535;
        tmp=repmat(tmp,[1 1 3]);
        
    end
    
    vid(:,:,:,j)=uint8(256*tmp);
    
end

%inputSize
%size(vid)
video = centerCrop(vid,inputSize);

size(video)
%aa=classifier.Layers

label = classify(classifier,{video});

label=label{1};

size(label)

results=roiobj.results;
    results.(classif.strid)=[];
    results.(classif.strid).id=zeros(1,size(im,4));
    results.(classif.strid).labels=label;
    
    roiobj.results=results;
    
    for i=1:numel(classif.classes)
        
    pix=label==classif.classes{i};
    roiobj.results.(classif.strid).id(pix)=i;
    
    end
    
    

%
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