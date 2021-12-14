function classifyDeepNet(mov,id,net)

% classify new images 

% mov is the current project
% id is an array that contains all the traps to be processed 

% output : mov.trap.div.deep variales is filled


if nargin ==2 % load exisiting cnn net
    load([mov.path '/netCNN.mat']); 
    net=netCNN;
end

inputSize = net.Layers(1).InputSize;
classNames = net.Layers(end).ClassNames;
numClasses = numel(classNames);

phasechannel=1;

for i=1:numel(id)
   
    t=id(i);  
    
    if numel(mov.trap(t).gfp)==0
    mov.trap(t).load;
    end
    
    gfp=mov.trap(t).gfp(:,:,:,phasechannel);
    gfp=formatImage(gfp,phasechannel);
    
  %  fr=51;
    
  %  figure,imshow(gfp(:,:,:,fr),[]);

     gfp = imresize(gfp,inputSize(1:2));
     
  %   class(gfp)
  %   trm=gfp(:,:,:,fr);
  %   max(trm(:))
    % BEWARE : rather use formatted image in lstm .mat variable
    % need to distinguish between formating for training versus validation
    % function --> formatfordeepclassification
    
    [label,scores] = classify(net,gfp);
    
    pix=label=='largebudded';
    mov.trap(t).div.deepCNN(pix)=2;

    pix=label=='smallbudded';
    mov.trap(t).div.deepCNN(pix)=1;
    
    pix=label=='unbudded';
    mov.trap(t).div.deepCNN(pix)=0;
    
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
    