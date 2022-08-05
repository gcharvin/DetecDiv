function classifyImageRegressionFun(roiobj,classif,classifier,varargin)

% this function can be used to classify any roi object, by providing the
% classi object and the classifier

if numel(classifier)==0 % loading the classifier // not recommended because it takes time
    path=classif.path;
    name=classif.strid;
    str=[path '/' name '.mat'];
    load(str); % load classifier
end
% classify new images

channel=classif.channelName;

for i=1:numel(varargin)
      if strcmp(varargin{i},'Frames')
          % not yet implemented
      end
        if strcmp(varargin{i},'Channel')
           channel=varargin{i+1};
       end
end

net=classifier;
inputSize = net.Layers(1).InputSize;
%classNames = net.Layers(end).ClassNames;
numClasses = 1;%numel(classNames);

if numel(roiobj.image)==0
    roiobj.load;
end

pix=roiobj.findChannelID(channel);

    if iscell(pix)
            pix=cell2mat(pix);
    end
%pix=find(roiobj.channelid==classif.channel(1)); % find channels corresponding to trained data
gfp=roiobj.image(:,:,pix,:);



im=uint8(zeros(size(gfp,1),size(gfp,2),3,size(gfp,4)));
   
%if numel(pix)==1
    for j=1:size(gfp,4)        
        param=[];
        tmp=roiobj.preProcessROIData(pix,j,param);
        im(:,:,:,j)=uint8(256*tmp);        
    end
    gfp=im;
%end

gfp = imresize(gfp,inputSize(1:2));

%   class(gfp)
%   trm=gfp(:,:,:,fr);
%   max(trm(:))
% BEWARE : rather use formatted image in lstm .mat variable
% need to distinguish between formating for training versus validation
% function --> formatfordeepclassification

% [label,scores] = classify(net,gfp);

%    if numel(gpuDeviceCount)==0
predi= predict(net,gfp); % this is used to get the probabilities rather than the classification itself
% else
% [label,scores] = classify(net,gfp,'Acceleration','mex');
%end

% upload results into roi obj;

results=roiobj.results;
results.(classif.strid)=[];
results.(classif.strid).id=predi;
results.(classif.strid).labels=predi';

roiobj.results=results;

% for i=1:numel(classif.classes)
%     
%     pix=label==classif.classes{i};
%     roiobj.results.(classif.strid).id(pix)=i;
%     
% end

roiobj.save;
roiobj.clear;

%roiout=roiobj;
% roiobj.clear;










