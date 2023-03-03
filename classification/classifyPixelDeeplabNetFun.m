function [results,image]=classifyPixelDeeplabNetFun(roiobj,classif,classifier,varargin)

% this function can be used to classify any roi object, by providing the
% classi object and the classifier




if numel(classifier)==0 % loading the classifier // not recommende because it takes time
    path=classif.path;
    name=classif.strid;
    str=[path '/' name '.mat'];
    load(str); % load classifier
end
% classify new images

frames=[];
channel=classif.channelName;

for i=1:numel(varargin)
    if strcmp(varargin{i},'Frames')
        frames=varargin{i+1};
    end
    
    if strcmp(varargin{i},'Channel')
        channel=varargin{i+1};
    end
end


net=classifier;

inputSize = net.Layers(1).InputSize;
% classNames = net.Layers(end).ClassNames;
% numClasses = numel(classNames);

if numel(roiobj.image)==0 % load stored image in any case
    roiobj.load;
end

pix=roiobj.findChannelID(channel);

    if iscell(pix)
            pix=cell2mat(pix);
    end

%pix=find(roiobj.channelid==classif.channel(1)); % find channels corresponding to trained data

gfp=roiobj.image(:,:,pix,:);

if numel(frames)==0
    frames=1:numel(gfp(1,1,1,:));
end


% BEWARE : rather use formatted image in lstm .mat variable
% need to distinguish between formating for training versus validation
% function --> formatfordeepclassification

% check whether output is segmentation, proba, or postprocessing

switch classif.outputType
    case 'proba' % outputs proba of classes
        pixresults=[];
        for i=1:numel(classif.classes)
            pixresultstmp=findChannelID(roiobj,['results_' classif.strid '_' classif.classes{i}]); % gather all channels associated with proba
            
            if numel(pixresultstmp)==0 % channel does not exist, hence create them
                matrix=uint16(zeros(size(gfp,1),size(gfp,2),1,size(gfp,4)));
                rgb=[1 1 1];
                intensity=[1 1 1]; % used to display grayscale image in .view
                
                roiobj.addChannel(matrix,['results_' classif.strid '_' classif.classes{i}],rgb,intensity);
                
                pixresults=[pixresults size(roiobj.image,3)];
            else
                
                roiobj.image(:,:,pixresultstmp,:)=uint16(zeros(size(gfp,1),size(gfp,2),1,size(gfp,4)));
                pixresults=[pixresults pixresultstmp];
            end
        end
        
    otherwise %  outputs segmentation or segmentation after postprocessing
        pixresults=findChannelID(roiobj,['results_' classif.strid]);
        
        if numel(pixresults)==0 % channels do not exist, hence create them
            matrix=uint16(zeros(size(gfp,1),size(gfp,2),1,size(gfp,4)));
            rgb=[1 1 1];
            intensity=[0 0 0]; % used to display indexed image in .view
            
            roiobj.addChannel(matrix,['results_' classif.strid],rgb,intensity);
            
            pixresults=size(roiobj.image,3);
        else
            roiobj.image(:,:,pixresults,:)=uint16(zeros(size(gfp,1),size(gfp,2),1,size(gfp,4)));
        end
end

for fr=frames % remove the loop on frames here !!!! andtry ti use a gpu array 
    fprintf('.');
    % fr
    %tmp=gfp(:,:,:,fr);
    
   % if numel(pix)==1
        param=[];
        tmp=roiobj.preProcessROIData(pix,fr,param);
        
        tmp=uint8(tmp*256);
  %  end
    
    if size(tmp,1)<inputSize(1) | size(tmp,2)<inputSize(2)
        tmp=imresize(tmp,inputSize(1:2));
    end
    
    
    %C = semanticseg(tmp, net); % this is no longer required if we extract the probabilities from the previous layer
    %    if numel(gpuDeviceCount)==0
    %     features = activations(net,tmp,'softmax-out'); % this is used to get the probabilities rather than the classification itself
    %    else
    %     features = activations(net,tmp,'softmax-out','Acceleration','mex');
    %    end
    
    [C,score,features]= semanticseg(tmp, net);%,'Acceleration','mex'); % this is no longer required if we extract the probabilities from the previous layer
    if size(gfp,1)<inputSize(1) | size(gfp,2)<inputSize(2)
        features=imresize(features,size(gfp,1:2));
        C=imresize(C,size(gfp,1:2));
    end
    
    % figure, imshow(features(:,:,2),[]);
    
    tmpout=uint16(zeros(size(roiobj.image(:,:,pixresults,fr))));
    
    image=roiobj.image; 

    switch classif.outputType
        case 'proba' % outputs proba
            
            for i=1:numel(classif.classes)
                tmpout(:,:,i)=65535*features(:,:,i);
            end
            
        case 'segmentation'
            
            for i=2:numel(classif.classes) % 1 st class is considered default class
                BW=features(:,:,i)>0.9;
                res=uint16(uint16(BW)*(i));
                tmpout=tmpout+res;
            end
            
            tmpout(tmpout==0)=1; %fill background
            
            
        case 'postprocessing'
            
            
            if numel(classif.outputFun)==0
                classif.outputFun='post';
            end
            if numel(classif.outputArg)==0
                classif.outputArg={ 'threshold'  '0.9'};
            end
            
            tmpout= feval(classif.outputFun,features,classif.classes,classif.outputArg{:});
    end
    
    %      figure, imshow(tmpout,[]);
    
    image(:,:,pixresults,fr)=tmpout;
end

results=roiobj.results; 

%roiobj.save;
%roiobj.clear;
fprintf('\n');


