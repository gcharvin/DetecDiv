function loadtraps(obj,display)
% load trap objects into movi object

% this function should no longer be used !!! 

positions=identifyTraps(img1,pattern);


for i=1:size(positions,1)
    
    gfp=[];
    phc=[];
    
    scale=0.5;%%%%%%%%%0.5;%%%%%%
    
    % phc is 1024x1024 , resized to 512 x 512
    phc=obj.phc(positions(i,1):positions(i,2),positions(i,3):positions(i,4),:);
    %size(phc)
    
    
    % positions resize to the scale 
    temp=round(scale*positions);
    gfp=obj.gfp(temp(i,1):temp(i,2),temp(i,3):temp(i,4),:);
    
    %figure, imshow(gfp(:,:,1),[]);
    phc=imresize(phc,[size(gfp,1) size(gfp,2)]);
     
    obj.trap(i) = trap(i,[positions(i,1) positions(i,2) positions(i,3) positions(i,4)],gfp,phc);
end


obj.viewtraps
end


function positions=identifyTraps(img,pattern)

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

