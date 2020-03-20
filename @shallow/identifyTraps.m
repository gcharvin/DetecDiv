function identifyTraps(obj)


if numel(obj.pattern)==0
    disp('There are no patterns available !);
end

% this where I am .... 
% need to identify trap and create ROI on all FOVs, then use a separate function 
%to copy images from sources to roi objects / dedicated places in project
%folders



positions=findTraps(img1,obj.pattern);

%scale=0.5;
scale=1;

scaled=round(scale*positions);

% make all positions uniform
x=round(mean(scaled(:,2)-scaled(:,1)));
y=round(mean(scaled(:,4)-scaled(:,3)));
scaled(:,2)=scaled(:,1)+x;
scaled(:,4)=scaled(:,3)+y;

for i=1:size(scaled,1)
   if  scaled(i,4)>size(img1,2)/2
       scaled(i,4)=scaled(i,4)-1;
       scaled(i,3)=scaled(i,3)-1;
   end
   if  scaled(i,2)>size(img1,1)/2
       scaled(i,1)=scaled(i,1)-1;
       scaled(i,2)=scaled(i,2)-1;
   end
end
% load phase and GFP image to generate small images for each trap

%obj.gfp=zeros(size(img1,1),size(img1,2),obj.nframes,'uint16');

% create trap objects with no image in it


tmp=uint16(zeros((-scaled(1,1)+scaled(1,2)+1),(-scaled(1,3)+scaled(1,4)+1),obj.nframes,length(obj.pathname)));

reverseStr = '';
fprintf('Creating traps....\n');

for i=1:size(positions,1)
    
    obj.trap(i) = trap([obj.id '_' num2str(i)],[scaled(i,1) scaled(i,2) scaled(i,3) scaled(i,4)],tmp);
    
    obj.trap(i).gfpchannel=obj.GFPChannel;
    obj.trap(i).phasechannel=obj.PhaseChannel;
    obj.trap(i).path=obj.path;
    obj.trap(i).intensity=obj.intensity;
    obj.trap(i).div.divisionTime=obj.divisionTime;
    
    % obj.trap(i).gfp=tmp;
    % obj.trap(i).phc=tmp;
    
    
            
    msg = sprintf('%d / %d Traps created', i , size(positions,1) ); %Don't forget this semicolon
    fprintf([reverseStr, msg]);
    reverseStr = repmat(sprintf('\b'), 1, length(msg));
    
end
fprintf('\n');

if dis==1
    obj.viewtraps
end

if ss==1
    return;
end


reverseStr = '';

fprintf('Save images to folder....\n');

for j=1:obj.nframes
    
    if j==1
        list={};
        for k=1:numel(obj.pathname)
        [im tmp]=obj.readImage(j,k);
        
        if obj.GFPChannel==k
           imgfp=im; 
        end
        
        list{k}=tmp;
        end
    end
    
    %imgphase= obj.readImage(j,obj.PhaseChannel);
    %imgfp=obj.readImage(j,obj.GFPChannel);
    %imgphase=imresize(imgphase,[size(imgfp,1) size(imgfp,2)]);
    
    
    for k=1:numel(obj.pathname)
        
        tmp=obj.readImage(j,k,list{k});
       % size(tmp);
        
        if obj.PhaseChannel==k
            tmp=imresize(tmp,[size(imgfp,1) size(imgfp,2)]);
            %figure, imshow(tmp,[]); 
        end
        
       if j==1 && k==1
         reftmp=tmp;
       end
       
%        if j>1 % cropping and registering images
%           crop=1:100;
%           tform=registerImages(reftmp(crop,crop),tmp(crop,crop));
%           
%           moved = imwarp(tmp,tform,'OutputView',imref2d(size(reftmp)));
%   
%           %figure, imshowpair(reftmp,moved);
%          % pause
%           tmp=moved;
%        end
        
       % size(tmp)
        
        for i=1:size(positions,1)
            
            gfp=tmp(scaled(i,1):scaled(i,2),scaled(i,3):scaled(i,4));
            
           % size(gfp)
            %figure, imshow(gfp,[]); 
            %return;
            
           % size(obj.trap(i).gfp)
           
           
            obj.trap(i).gfp(:,:,j,k)=gfp;
            
        end
        
    end
    
    msg = sprintf('Processing frame: %d / %d', j, obj.nframes); %Don't forget this semicolon
    fprintf([reverseStr, msg]);
    reverseStr = repmat(sprintf('\b'), 1, length(msg));
end

fprintf('\n');



% save and clear memory
reverseStr = '';



for i=1:size(positions,1)
    
    % create analysis matrices 
    obj.trap(i).classi=uint8(zeros(size(obj.trap(i).gfp,1),size(obj.trap(i).gfp,2),3,size(obj.trap(i).gfp,3)));
    obj.trap(i).train=uint8(zeros(size(obj.trap(i).gfp,1),size(obj.trap(i).gfp,2),3,size(obj.trap(i).gfp,3)));
    obj.trap(i).traintrack=uint8(zeros(size(obj.trap(i).gfp,1),size(obj.trap(i).gfp,2),3,size(obj.trap(i).gfp,3)));
    obj.trap(i).track=uint8(zeros(size(obj.trap(i).gfp,1),size(obj.trap(i).gfp,2),size(obj.trap(i).gfp,3)));
    
    obj.trap(i).data.fluo=zeros(size(obj.trap(i).gfp,3),numel(obj.pathname));
    
    
    obj.trap(i).save;
    obj.trap(i).clear;
    %%% here : now I need to manage analysis images and then to manage all
    %%% aspects at the movie level 
    
     msg = sprintf('%d / %d Traps saved', i , numel(obj.trap) ); %Don't forget this semicolon
    fprintf([reverseStr, msg]);
    reverseStr = repmat(sprintf('\b'), 1, length(msg));
end
fprintf('\n');

end



function positions=findTraps(img,pattern)

% position provides the list of boundaries for the traps
%img = rgb2gray(img);

c = normxcorr2(pattern,img);

%figure, imshow(img)
%figure, surf(c), shading flat

thr=0.7; % threshold for detected peaks

BW = im2bw(c,thr);

pp = regionprops(BW,'centroid');
pos = round(cat(1, pp.Centroid));
%positions=fliplr(positions);

positions=zeros(1,4);

%positions.minex=[];
%positions.maxex=[];
%positions.miney=[];
%positions.maxey=[];

cc=1;
%figure;

%size(img)
for ex=1:size(pos,1)
    
    minex=pos(ex,2)-size(pattern,2);
    maxex=pos(ex,2);
    miney=pos(ex,1)-size(pattern,1);
    maxey=pos(ex,1);
    
    if minex<1
        continue
    end
    if miney<1
        continue
    end
    if maxex>size(img,2)
        continue
    end
    if maxey>size(img,1)
        continue
    end
    
    positions(cc,1)=minex;
    positions(cc,3)=miney;
    positions(cc,2)=maxex;
    positions(cc,4)=maxey;
    
    %imgout=img(minex:maxex,miney:maxey);
    %imshow(imgout,[]);
    %title(num2str(ex));
    %pause(0.1);
    %close
    
    
    cc=cc+1;
end
end


function tform=registerImages(ref,test)

  [optimizer, metric] = imregconfig('monomodal');
%    optimizer.InitialRadius = 0.01;
%  optimizer.Epsilon = 1.5e-4;
%  optimizer.GrowthFactor = 1.05;
%  optimizer.MaximumIterations = 1000;

%size(img8)
  
 tform=imregtform(test,ref,'translation',optimizer,metric);
  


  
% % shift images to correct for unwanted motion 
% 
% imrefraw=imref;
% 
% maxeref=65535*stretchlim(imref,[0.01 0.999999]);
% %maxeref=65535*stretchlim(imref,[0 0.2]);
% 
% imref=imadjust(imref,[maxeref(1)/65536 maxeref(2)/65535],[0 1]);
% 
% imref8 = uint8(imref/256);
% 
% %imref8=imref;
% 
% cc=1;
% 
%   mov(:,:,1,cc)=imref8;
%   raw(:,:,1,cc)=imrefraw;
% 
% cc=2;
% %h=figure;
% %hi=imshowpair(h,imref8,moved);
% 
% 
% for i=init+1:init+size(mov,4)-1
%    
%     
%   im=imread(filename,i);
%   %im=im(:,1:784);
%   
%  % im=imgradient(im);
%   %max(im(:))
%   %min(im(:))
%   
%   %mine=mean(im(:))
%   
%  % figure, imshow(im,[])
%   
%  % maxe=65535*stretchlim(im,[0.01 0.99]);
%   %maxe
% 
%  
%   %im=imadjust(im,[0 maxeref/65535],[0 1]);
%   
%   raw16=im;
%   im=imadjust(im,[maxeref(1)/65536 maxeref(2)/65536],[]);
%   
%   img8 = uint8(im/256);
% 
% 
%   %img8=im;
%   %mov(:,:,1,i)=img8;
%   
%  % [optimizer, metric] = imregconfig('multimodal');
%  
%  %c = normxcorr2(imref8,img8);
%  c = normxcorr2(imrefraw,raw16);
%   
%  
%  c(size(img8,1), size(img8,2))=c(size(img8,1)-1, size(img8,2)); % remove
%  %white dot in the middle of image
%   
%  %figure, imshow(imref8,[]); 
%  %figure, imshow(img8,[]);
% 
%  %figure, imshow(c,[])
%  
%  cbw=logical(zeros(size(c)));
%  cbw(round(size(cbw,1)/2-size(img8,1)/4):round(size(cbw,1)/2+size(img8,1)/4),round(size(cbw,2)/2-size(img8,2)/2):round(size(cbw,2)/2+size(img8,2)/2))=1;
%  
% % figure, imshow(cbw,[]);
% 
%  %c(~cbw)=0;
%  %figure, imshow(c,[]);
%  %return;
%  
%  [max_num,max_idx] = max(c(:));
% 
% [row col]=ind2sub(size(c),max_idx);
% 
% pos(1)=col;
% pos(2)=row;
% 
% %max_num
% %pos
% 
% 
%  %figure, surf(c), shading flat
%  
%  %figure, imshow(t,[]);
%  
%   %thr=0.28; % threshold for detected peaks
% 
%   %BW = im2bw(c,thr);
% 
%   %pp = regionprops(BW,'centroid');
%   %pos = round(cat(1, pp.Centroid));
% 
%   %figure, imshow(BW,[]);
%   
% %   optimizer.InitialRadius = 0.01;
% % optimizer.Epsilon = 1.5e-4;
% % optimizer.GrowthFactor = 1.05;
% % optimizer.MaximumIterations = 1000;
% 
% %size(img8)
%   
%   %moved=imregister(img8,imref8,'translation',optimizer,metric);
%   %pos
%   
% %  -(pos(1)-size(img8,2))
%  % -(pos(2)-size(img8,1))
%   
%   moved=circshift(img8,-(pos(1)-size(img8,2)),2);
%   moved=circshift(moved,-(pos(2)-size(img8,1)),1);
%   
%   rawmoved=circshift(raw16,-(pos(1)-size(raw16,2)),2);
%   rawmoved=circshift(rawmoved,-(pos(2)-size(raw16,1)),1);
%   
% %-(pos(1)-size(img8,2))
% %-(pos(2)-size(img8,1))
% 
%  % figure, imshowpair(imref8,moved);
%   
%   %return;
%   %pause(0.2);
%   
%  % figure, imshow(moved,[]);
%   
%  % return;
%   %pause
%   %close
%   
%   
%   mov(:,:,1,cc)=moved;
%   raw(:,:,cc)=rawmoved;

end