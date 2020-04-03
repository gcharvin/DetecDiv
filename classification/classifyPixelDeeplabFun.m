function classifyPixelDeeplabFun(roiobj,classif,classifier)

% this function can be used to classify any roi object, by providing the
% classi object and the classifier

if numel(classifier)==0 % loading the classifier // not recommende because it takes time
    path=classif.path;
    name=classif.strid;
    str=[path '/' name '.mat'];
    load(str); % load classifier
end
% classify new images

net=classifier;

inputSize = net.Layers(1).InputSize;
% classNames = net.Layers(end).ClassNames;
% numClasses = numel(classNames);

if numel(roiobj.image)==0
    roiobj.load;
end

pix=find(roiobj.channelid==classif.channel); % find channels corresponding to trained data
gfp=roiobj.image(:,:,pix,:);

if numel(pix)==1
    gfp=formatImage(gfp);
end

gfp = imresize(gfp,inputSize(1:2));

% BEWARE : rather use formatted image in lstm .mat variable
% need to distinguish between formating for training versus validation
% function --> formatfordeepclassification

for fr=1:size(gfp,4)
    fprintf('.');
    % fr
    tmp=gfp(:,:,:,fr);
    % size(tmp)
    % tmp=permute(tmp,[1 2 4 3]);
    % size(tmp)
    
    
    C = semanticseg(tmp, net); % this is no longer required if we extract the probabilities from the previous layer
    
    features = activations(net,tmp,'softmax-out'); % this is used to get the probabilities rather than the classification itself
    
    % to be troubleshooted from here , because each class will have a
    % probability , not onyl the cell class 
    
    BW=features(:,:,2)>0.9; % mark as cell when probability is higher than 0.9
    
    % post processing --> watershed segmentation to be performed in a later
    % step 
    
    % class(features), size(features)
    %figure, imshow(features(:,:,1),[]);
    % figure, imshow(features(:,:,2),[]);
    %return;
    
    
    %BW=logical(C=="Cell");
    
    BW=~BW;
    
    imdist=bwdist(BW);
    imdist = imclose(imdist, strel('disk',2));
    imdist = imhmax(imdist,1);
    
    sous=- imdist;
    
    %figure, imshow(BW,[]);
    
    labels = double(watershed(sous,8)).* ~BW;% .* BW % .* param.mask; % watershed
    warning off all
    %tmp = imopen(labels > 0, strel('disk', 4));
    warning on all
    %tmp = bwareaopen(tmp, 50);
    
    newlabels = labels;% .* tmp; % remove small features
    newlabels = newlabels>0;
    
    %figure, imshow(newlabels,[]);
    %return
    
    imtemp=255*uint8(newlabels);
    mov.trap(t).classi(:,:,2,fr)=imtemp;
    % imtemp=255*uint8(C=="Background");
    imtemp=255*uint8(~newlabels);
    mov.trap(t).classi(:,:,1,fr)=imtemp;
    
    
    %[label,scores] = classify(net,gfp);
    
  
end
%mov.trap(t).traintrack(:,:,2,:)=0.5*mov.trap(t).classi(:,:,2,:);
fprintf('\n');


function im=formatImage(gfp)


totphc=gfp;
meanphc=0.5*double(mean(totphc(:)));
maxphc=double(meanphc+0.7*(max(totphc(:))-meanphc));

im=zeros(size(gfp,1),size(gfp,2),3,size(gfp,4));

for j=1:size(gfp,4)
    fprintf('.');
    
    a=gfp(:,:,1,:);
    
    a = double(imadjust(a,[meanphc/65535 maxphc/65535],[0 1]))/256;
    a= repmat(a,[1 1 3]);
    
    % im(:,:,1,j)=a;im(:,:,2,j)=b;im(:,:,3,j)=c;
    im(:,:,1,j)=uint8(a);
end

fprintf('\n');


%
% function im=formatImage(gfp,phasechannel)
%
%     totphc=gfp(:,:,:,phasechannel);
%     meanphc=0.5*double(mean(totphc(:)));
%     maxphc=double(meanphc+0.7*(max(totphc(:))-meanphc));
%
%     im=zeros(size(gfp,1),size(gfp,2),3,size(gfp,3));
%
%     for j=1:size(gfp,3)
%     fprintf('.');
%
%     a=gfp(:,:,j,phasechannel);
%     b=gfp(:,:,j,phasechannel);
%     c=gfp(:,:,j,phasechannel);
%
%     a = double(imadjust(a,[meanphc/65535 maxphc/65535],[0 1]))/256;
%     b = a; %double(imadjust(b,[meanphc/65535 maxphc/65535],[0 1]))/65535;
%     c = a; %double(imadjust(c,[meanphc/65535 maxphc/65535],[0 1]))/65535;
%
%
%
%     im(:,:,1,j)=a;im(:,:,2,j)=b;im(:,:,3,j)=c;
%     im=uint8(im);
%     end
%
%     fprintf('\n');