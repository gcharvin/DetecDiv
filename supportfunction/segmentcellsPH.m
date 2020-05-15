function segmentcellsPH(obj,frames,channel,strchannel)
% this function assigns pixel values using standard cell segmentation 

% obj : roi object

% look if channel already exists 

if nargin<3
    channel=1;
end

if nargin<4
    strchannel='segmentcellsPH';
end

if numel(obj.image)==0
 obj.load;    
end

pixresults=findChannelID(obj,strchannel);
 
if numel(pixresults)>0
obj.image(:,:,pixresults,frames)=uint16(zeros(size(obj.image,1),size(obj.image,2),1,numel(frames)));
else
   % add channel is necessary 
   matrix=uint16(zeros(size(obj.image,1),size(obj.image,2),1,size(obj.image,4)));
   rgb=[1 1 1];
   intensity=[0 0 0];
   pixresults=size(obj.image,3)+1;
   obj.addChannel(matrix,strchannel,rgb,intensity);
end


for i=frames
img= obj.image(:,:,channel,i);

BW=2*uint16(segmentPhaseContrast(img)); % the '2' factor is just to assign to the second class in case of piel training 

obj.image(:,:,pixresults,i)=BW;
end

function BW=segmentPhaseContrast(img)

param=struct('channel',1,'minSize',100,'maxSize',10000,'thresh',0.25,'display',0,'mask','');

img2=img;

if param.display==1
scr=get(0,'ScreenSize');   
figure('Color','w','Position',[1 scr(3)-500 scr(3) 500]); p=panel; p.de.margin=0; p.pack('h',1); ccc=1; p(ccc).select(); 
p(ccc).marginleft=0;
p(ccc).marginright=0;
imshow(img,[]);
end
  

img = rangefilt(img); 
%[img ~]=imgradient(img);
%figure, imshow(img,[]);

%img=imtophat(img,strel('disk',5));
%img = KuwaharaFast(img, 1);

%[img,Xpad] = kuwahara(1-Iobrcbr);
%figure, imshow(img,[]);

if param.display==1
p.pack('h',1); ccc=ccc+1; p(ccc).select();
p(ccc).marginleft=0;
p(ccc).marginright=0;
imshow((img),[]);
  end
%returns thresh containing N threshold values using Otsu's method

% if param.thresh==0
% level = graythresh(img);
% else
% level=param.thresh;    
% end

%class(img2)
%level2=graythresh(uint16(img2))

T = adaptthresh(uint16(img2),0.5);

BW2=imbinarize(uint16(img2),T);

%BW2 = im2bw(uint16(img2),level2);


if param.display==1
p.pack('h',1); ccc=ccc+1; p(ccc).select();
p(ccc).marginleft=0;
p(ccc).marginright=0;
imshow(BW2,[]);
  end


for j=1:1 % currently, only one loop is necessary 
   % l=0.005-0.001*(j); % for log filter
    
  if param.thresh~=0
     l=param.thresh-0.02*(j-1);
     BW=edge(img,'canny',l); % try other edge detection filters ? 
  else
     BW=edge(img,'canny');    
  end
  
  
  if param.display==1
p.pack('h',1); ccc=ccc+1; p(ccc).select();
p(ccc).marginleft=0;
p(ccc).marginright=0;

imshow(BW,[]);
  end
  
  
%BW = im2bw(img,level);
%BW = BW | BW2;
BW2 = bwareaopen(BW2, 10);

BW = bwareaopen(BW, 10);

%BW=fgm;
%BW = im2bw(img,l);
%BW=BW3;


%BW=imopen(BW,strel('disk',2));

%if param.display
%figure,imshow(BW,[]);
%end

if ~ischar(param.mask)
    BW=BW | param.mask;
    
if param.display==1
p.pack('h',1); ccc=ccc+1; p(ccc).select();
p(ccc).marginleft=0;
p(ccc).marginright=0;
imshow(BW,[]);
  end
end



imdist=bwdist(BW2);
imdist = imclose(imdist, strel('disk',2));
imdist = imhmax(imdist,2);

if param.display==1
p.pack('h',1); ccc=ccc+1; p(ccc).select();
p(ccc).marginleft=0;
p(ccc).marginright=0;
imshow(imdist,[0 30]); colormap(jet)
  end

sous=BW2- imdist;

if ~ischar(param.mask)
   BW2=BW2 | param.mask; 
end


%BW=logical(zeros(size(BW)));
%BW(imdist<60)=1;

%figure, imshow(BW,[]);

labels = double(watershed(sous,8)).* ~BW2;% .* BW % .* param.mask; % watershed
warning off all
tmp = imopen(labels > 0, strel('disk', 4));
warning on all
tmp = bwareaopen(tmp, 50);

newlabels = labels .* tmp; % remove small features
newlabels = bwlabel(newlabels>0);

warning off all
%figure, imshow(newlabels,[]);
warning on all


% if j>1
%     %figure, imshow(oldlabels,[]);
%     %figure, imshow(newlabels,[]);
%     
%     M=buildMatrix(oldlabels,newlabels);
%    [Matching,Cost] = Hungarian(M);
%    %[row,col] = find(Matching);
%    newlabels=updateLabels(oldlabels,newlabels,Matching);
%    
%     %figure, imshow(newlabels,[]);
% end

oldlabels = newlabels;
end

if param.display==1
p.pack('h',1); ccc=ccc+1; p(ccc).select();
p(ccc).marginleft=0;
p(ccc).marginright=0;
imshow(newlabels,[]);
  end

% if sca~=1
%  img=imresize(img,sca);
% end
 
 %newlabels=imresize(newlabels,2);
 
 %newlabels=uint16(newlabels);



% tic;
stat = regionprops(newlabels, 'Area','Eccentricity','BoundingBox');

%phy_Objects = phy_Object();

npoints=32; cc=1;

newlabels2=uint8(zeros(size(newlabels)));

cc=1;

for i=1:numel(stat)
   tmp=newlabels==i;
   %if i==59
   %a=stat(i).Area
   %end
   
   
   bb=stat(i).BoundingBox;
   
   if bb(1)<1
       %newlabels(tmp)=0;
       continue
   end
   if bb(2)<1
       %newlabels(tmp)=0;
       continue
   end
   if bb(2)+bb(4)>size(newlabels,2)
       %newlabels(tmp)=0;
       continue
   end
   if bb(1)+bb(3)>size(newlabels,2)
       %newlabels(tmp)=0;
       continue
   end
   
   if stat(i).Area <param.minSize || stat(i).Area >param.maxSize %|| stat(i).Eccentricity>0.9
      
   %newlabels(tmp)=0;
   continue
   else
   %contours= bwboundaries(tmp);
   %contour = contours{1};
   %[xnew, ynew]=phy_changePointNumber(contour(:, 2),contour(:, 1),npoints);
   
   %if min(sca*xnew)>1 && min(sca*ynew)>1 && max(sca*xnew)<size(img,2) && max(sca*ynew)<size(img,1)
   %phy_Objects(cc) = phy_Object(cc, sca*(xnew+1), sca*(ynew+1),0,0,mean(sca*(xnew+1)),mean(sca*(ynew+1)),0);
   
  
   %phy_Objects(cc).fluoMean(1)=mean(stat(i).PixelValues);
   %phy_Objects(cc).fluoVar(1)=std(double(stat(i).PixelValues));
   
   %if param.display
   %    line( phy_Objects(cc).x,phy_Objects(cc).y,'Color','r','LineWidth',2);
      % text(phy_Objects(cc).ox,phy_Objects(cc).oy,num2str(phy_Objects(cc).n),'Color','r','FontSize',24);
   %end
   
   %cc=cc+1;
   %end
   end
  % newlabels2(tmp)=cc;
   newlabels2(tmp)=1;
   cc=cc+1;
end

% stat = regionprops(newlabels2, 'Area','Eccentricity','BoundingBox');
% 
% ypos=[];
% 
% for i=1:numel(stat)
%     tmp=newlabels2==i;
%     bb=stat(i).BoundingBox;
%     ypos= [ypos bb(2)];
% end
% 
% 
% [ypos ix]=sort(ypos)
% 
% tmp=newlabels2==ix(1);
% newlabels2(tmp)=0;
% 
% 
% tmp=newlabels2==ix(4);
% newlabels2(tmp)=0;


OK=1;


BW=newlabels2;

if param.display==1
p.pack('h',1); ccc=ccc+1; p(ccc).select();
p(ccc).marginleft=0;
p(ccc).marginright=0;
imshow(BW,[]);
end
  

if param.display
p.marginleft=0;
p.marginright=0;
end


% 
% if nargin==1
% frames=1:size(obj.traintrack,4);
% end
% 
% for i=frames
%     obj.traintrack(:,:,3,i)=uint8(zeros(size(obj.gfp,1),size(obj.gfp,2)));
% end
% 
% if nargin==3
%     return; % with this option, this remoces the training... 
% end
% 
% for i=frames
%     
%     n=bwlabel(obj.traintrack(:,:,2,i)>0);
%     p=regionprops(n,'Centroid');
%     
%     %p.Centroid
%     
%     if numel(p)==0
%         continue
%     end
%     
%     d=[];
%     for j=1:numel(p)
%        % j
%         d(j)=sqrt((p(j).Centroid(1)-size(obj.gfp,2)/2)^2+(p(j).Centroid(2)-size(obj.gfp,1)/2)^2);
%     end
%     
%    %d
%   
%     [dmin ix]=min(d);
%     nc=n==ix;
%     
%     obj.traintrack(:,:,3,i)=255*uint8(nc);
% end
