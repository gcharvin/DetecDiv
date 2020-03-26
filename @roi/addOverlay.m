function addOverlay(obj,channels)

% overlay alls channels based on channel IDs and create an extra channel
% based on this 

if numel(obj.image)==0
    obj.load
end

if max(channels)> size(obj.image,3)
    disp('Error : channel number requested does not exist !');
    return;
end

imtot=[];
str='Overlay: ';

sz=size(obj.image)


for i=1:numel(channels)
    pix=find(obj.channelid==channels(i))
    im=obj.image(:,:,pix,:);
    
    if numel(pix)==1
    im=repmat(im,[1 1 3 1]);
    end
    
    %size(im)
    %size(tmp)
    tmp=uint16(ones(sz(1),sz(2),3,sz(4)));
    tmp(:,:,1,:)=tmp(:,:,1,:)*obj.display.rgb(channels(i),1);
    tmp(:,:,2,:)=tmp(:,:,2,:)*obj.display.rgb(channels(i),2);
    tmp(:,:,3,:)=tmp(:,:,3,:)*obj.display.rgb(channels(i),3);
    
    im=im.*tmp;
    
    %figure, imshow(im(:,:,:,1),[0 4000]);
    if i==1
    imtot=im;
    else
    imtot=imtot+im;   
    end
    
    %figure, imshow(im(:,:,:,1),[]);
    str=[str obj.display.channel{channels(i)}];
    
    if i<numel(channels)
        str=[str '+'];
    end
end

%figure, imshow(imtot(:,:,:,1),[0 4000]);

obj.addChannel(imtot,str,[1 1 1],[1 1 1]);
%addChannel(obj,matrix,str,rgb,intensity)
