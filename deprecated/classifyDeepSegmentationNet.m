function classifyDeepSegmentationNet(mov,id,net)

% classify new images 

% mov is the current project
% id is an array that contains all the traps to be processed 

% output : mov.trap.div.deep variales is filled


if nargin ==2 % load exisiting cnn net
    load([mov.path '/netDeepLab.mat']); 
    net=netDeepLab;
end

% inputSize = net.Layers(1).InputSize;
% classNames = net.Layers(end).ClassNames;
% numClasses = numel(classNames);

phasechannel=1;

for i=1:numel(id)
    
    t=id(i);  
    mov.trap(t).traintrack=uint8(zeros(size(mov.trap(t).classi))); % clear object training
    
    fprintf(['Entering trap' mov.trap(t).id '\n']); 
    
    if numel(mov.trap(t).gfp)==0
    mov.trap(t).load;
    end
    
    gfp=mov.trap(t).gfp(:,:,:,phasechannel);
    gfp=formatImage(gfp,phasechannel);
    fprintf('\n');
  %  fr=51;
    
  %  figure,imshow(gfp(:,:,:,fr),[]);

    % gfp = imresize(gfp,inputSize(1:2));
     
  %   class(gfp)
  %   trm=gfp(:,:,:,fr);
  %   max(trm(:))
    % BEWARE : rather use formatted image in lstm .mat variable
    % need to distinguish between formating for training versus validation
    % function --> formatfordeepclassification
    %size(gfp)
    for fr=1:size(gfp,4)
    fprintf('.'); 
    % fr
    tmp=gfp(:,:,:,fr);
   % size(tmp)
   % tmp=permute(tmp,[1 2 4 3]);
   % size(tmp)
    C = semanticseg(tmp, net); % this is no longer required if we extract the probabilities from the previous layer
    
    features = activations(net,tmp,'softmax-out'); % this is used to get the probabilities 
    
    BW=features(:,:,2)>0.9; % mark as cell when probability is higher than 0.9
    
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
    
 % return
    
%     pix=label=='largebudded';
%     mov.trap(t).div.deepCNN(pix)=2;
% 
%     pix=label=='smallbudded';
%     mov.trap(t).div.deepCNN(pix)=1;
%     
%     pix=label=='unbudded';
%     mov.trap(t).div.deepCNN(pix)=0;
    end
    mov.trap(t).traintrack(:,:,2,:)=0.5*mov.trap(t).classi(:,:,2,:);
    fprintf('\n');
end




function im=formatImage(gfp,phasechannel)

    totphc=gfp(:,:,:,phasechannel);
    meanphc=0.5*double(mean(totphc(:)));
    maxphc=double(meanphc+0.7*(max(totphc(:))-meanphc));
    
    im=zeros(size(gfp,1),size(gfp,2),3,size(gfp,3));
    
    for j=1:size(gfp,3)
    fprintf('.');   
    
    a=gfp(:,:,j,phasechannel);
    b=gfp(:,:,j,phasechannel);
    c=gfp(:,:,j,phasechannel);
    
    a = double(imadjust(a,[meanphc/65535 maxphc/65535],[0 1]))/256;
    b = a; %double(imadjust(b,[meanphc/65535 maxphc/65535],[0 1]))/65535;
    c = a; %double(imadjust(c,[meanphc/65535 maxphc/65535],[0 1]))/65535;
    
    
    
    im(:,:,1,j)=a;im(:,:,2,j)=b;im(:,:,3,j)=c;
    im=uint8(im);
    end

    fprintf('\n');
    