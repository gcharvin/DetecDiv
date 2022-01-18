function classifyObjectGoogleNetFun(roiobj,classif,classifier,varargin)

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
classNames = net.Layers(end).ClassNames;
numClasses = numel(classNames);

if numel(roiobj.image)==0
    roiobj.load;
end


channel=classif.channelName;
for i=1:numel(varargin)
      if strcmp(varargin{i},'Frames')
          % not yet implemented
      end
        if strcmp(varargin{i},'Channel')
           channel=varargin{i+1};
       end
end

pix=roiobj.findChannelID(channel{1});
%pix=find(roiobj.channelid==classif.channel(1)); % find channels corresponding to trained data
gfp=roiobj.image(:,:,pix,:);

if numel(pix)==1
    gfp=formatImage(gfp);
end

% look if an results channel is already avaialble, otherwise, create it

pixresults=findChannelID(roiobj,['results_' classif.strid]);

if numel(pixresults)>0
%pixresults=find(roiobj.channelid==cc); % find channels corresponding to trained data
roiobj.image(:,:,pixresults,:)=uint16(zeros(size(gfp,1),size(gfp,2),1,size(gfp,4)));
else
   % add channel is necessary 
   matrix=uint16(zeros(size(gfp,1),size(gfp,2),1,size(gfp,4)));
   rgb=[1 1 1];
   intensity=[0 0 0];
   pixresults=size(roiobj.image,3)+1;
   roiobj.addChannel(matrix,['results_' classif.strid],rgb,intensity);
end


% cut test image into objects
pix2=find(roiobj.channelid==classif.channel(2)); % find channels corresponding to trained data
obj=roiobj.image(:,:,pix2,:);


% build label id
strclasses=[];
for i=1:numel(classif.classes)
    strclasses.(classif.classes{i})=i;
end


for j=1:size(roiobj.image,4)
    fprintf('.');
    
    imlist=uint16(zeros(inputSize(1),inputSize(2),3));
    tmp=obj(:,:,:,j);
    
   % size(tmp)
    
    if max(tmp(:))==0 % no object is present on frame
        continue
    end
    
    
    [l no]=bwlabel(tmp>0);
    pr=regionprops(l,'BoundingBox');
    
    for k=1:no % loop on all present objects
        
        bbox=round(pr(k).BoundingBox);
        
        imcrop=gfp(bbox(2):bbox(2)+bbox(4),bbox(1):bbox(1)+bbox(3),:,j);
        
        imcrop = imresize(imcrop,inputSize(1:2));
        
        imlist(:,:,:,k)=imcrop;
        % figure, imshow(imcrop,[]);
        % figure, imshow(tmp,[]);
        %imwrite(imcrop,[classif.path '/' foldername '/images/' classif.classes{clas} '/' classif.roi(i).id '_frame_' tr '_obj' num2str(k) '.tif']);
        %    end

    end
    
    % [label,scores] = classify(net,imlist);
     
       if numel(gpuDeviceCount)==0
    [label,scores] = classify(net,imlist); % this is used to get the probabilities rather than the classification itself
   else
    [label,scores] = classify(net,imlist,'Acceleration','mex');   
   end
     %label
     
     ob2=tmp;
     for k=1:no
         ob=l==k; % pixels for object k;
         
        % aa=char(label(k))
          
         ob2(ob)=strclasses.(char(label(k))); %id assigned to object
         
     end
     
     roiobj.image(:,:,pixresults,j)=ob2;
end

roiobj.save;
roiobj.clear;

%roiout=roiobj;
% roiobj.save;
% roiobj.clear;
    
   
    fprintf('\n');
    
    
    function im=formatImage(gfp)
    
    
    totphc=gfp;
    meanphc=0.5*double(mean(totphc(:)));
    maxphc=double(meanphc+0.7*(max(totphc(:))-meanphc));
    
    im=zeros(size(gfp,1),size(gfp,2),3,size(gfp,4));
    
    for j=1:size(gfp,4)
      %  fprintf('.');
        
        a=gfp(:,:,1,j);
        
        a = double(imadjust(a,[meanphc/65535 maxphc/65535],[0 1]))/256;
        a= repmat(a,[1 1 3]);
        
        % im(:,:,1,j)=a;im(:,:,2,j)=b;im(:,:,3,j)=c;
        im(:,:,:,j)=uint8(a);
    end
    
    fprintf('\n');
    
