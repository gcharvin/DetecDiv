function pretrainobjects(obj,frames,option)
% this function assigns a training flag to all objects in the middle of the
% image

if nargin==1
frames=1:size(obj.traintrack,4);
end

for i=frames
    obj.traintrack(:,:,3,i)=uint8(zeros(size(obj.gfp,1),size(obj.gfp,2)));
end

if nargin==3
    return; % with this option, this remoces the training... 
end

for i=frames
    
    n=bwlabel(obj.traintrack(:,:,2,i)>0);
    p=regionprops(n,'Centroid');
    
    %p.Centroid
    
    if numel(p)==0
        continue
    end
    
    d=[];
    for j=1:numel(p)
       % j
        d(j)=sqrt((p(j).Centroid(1)-size(obj.gfp,2)/2)^2+(p(j).Centroid(2)-size(obj.gfp,1)/2)^2);
    end
    
   %d
  
    [dmin ix]=min(d);
    nc=n==ix;
    
    obj.traintrack(:,:,3,i)=255*uint8(nc);
end
