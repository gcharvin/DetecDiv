function D=testimage(obj,classifier)

fr=22;
im1=obj.image(:,:,1,fr);
im2=obj.image(:,:,1,fr+1);

im1b=obj.image(:,:,5,fr);
im2b=obj.image(:,:,5,fr+1);

imtmp=uint8(im1b>0);
im1b=255*uint8(im1b>0);
im2b=255*uint8(im2b>0);

%imshowpair(im1,im2)

%im2 = imhistmatch(im2,im1);

[D,moving] = imregdemons(im2,im1,100);

m=sqrt(D(:,:,1).^2+D(:,:,2).^2);

figure, imshow(uint8(m)+10*imtmp,[]);




% rawim=obj.image(:,:,1,:);
% objim=obj.image(:,:,5,:);
% 
% 
% totphc=rawim;
% meanphc=0.5*double(mean(totphc(:)));
% maxphc=double(meanphc+0.5*(max(totphc(:))-meanphc));
% 
% x=zeros(1,2048);
% 
% %x=1;
% 
% cc=1;
% for i=1:30
%     im1=objim(:,:,1,i);
%     im2=rawim(:,:,1,i);
%     
% cells=getCells(im1,im2,classifier,meanphc,maxphc);
% 
% for j=1:numel(cells)
%     %tmp=cells(j).ac
% x(cc,:)=cells(j).ac;
% cc=cc+1;
% end
% 
% fprintf('.');
% 
% end
% 
% d=1;
% cc=1;
% for i=1:numel(cells)
%     for j=1:numel(cells)
%         d(cc)=pdist([cells(i).ac;cells(j).ac], 'cosine');    
%         cc=cc+1;
%     end
% end
% 
% 
% figure, hist(d);
% fprintf('\n');





function cells=getCells(l,rawimage,net,meanphc,maxphc)
% create cell structure from image


r=regionprops(l,'Centroid','Area','BoundingBox');

cells=struct('ox',[],'oy',[],'area',[],'n',[],'ac',[]);

inputSize = net.Layers(1).InputSize(1:2);

%layerName = "pool5-7x7_s1"; % googlenet;
layerName = "avg_pool"; %resnet50 or inceptionresnetv2
%layerName = "pool5"; %resnet101

%rawimage=repmat(rawimage,[1 1 3]);
rawimage = double(imadjust(rawimage,[meanphc/65535 maxphc/65535],[0 1]))/256;

for i=1:max(l(:))
    
    cells(i).ox=r(i).Centroid(1);
    cells(i).oy=r(i).Centroid(2);
    cells(i).area=r(i).Area;
    cells(i).n=i;%round(mean(l==i));
    
    tmp=round(r(i).BoundingBox);
    
    %meanphc,maxphc,max(rawimage(:))
    
    offset=10;%5
    %figure, imshow(rawimage,[]);
    bw=imdilate(l==i,strel('Disk',offset));
    %bw=l==i;
    imtmp=rawimage;
    imtmp(~bw)=0;
    
    minex=max(1,tmp(2)-offset);
    maxex=min(size(imtmp,1),tmp(2)+tmp(4)-1+offset);
    
    miney=max(1,tmp(1)-offset);
    maxey=min(size(imtmp,2),tmp(1)+tmp(3)-1+offset);
    
    im=imtmp(minex:maxex,miney:maxey);
    
    % figure, imshow(im,[]);
     
    % max(im(:))
%     nsize=100;
%     imout=uint8(zeros(nsize,nsize));
%     % adjust all cell masks into a 100x100 mask to preserve the respective
%     % sizes of images
%     % resize im if odd numbers
%     siz=size(im);
%     im=imresize(im,[siz(1) + mod(siz(1),2) , siz(2) + mod(siz(2),2)]);
%     
%     %size(im)
%     arrx=nsize/2-size(im,1)/2:nsize/2+size(im,1)/2-1;
%     arry=nsize/2-size(im,2)/2:nsize/2+size(im,2)/2-1;
%     imout(arrx,arry)=im;
%     im=imout;

    % adjust the image to fit the network input size (224 x 224 x 3for
    % goooglenet)
    
    %figure, imshow(im,[]);
    
    im=repmat(im,[1 1 3]);
    im=imresize(im,inputSize);

    % figure, imshow(im,[]);
    %pause
    
    cells(i).ac = activations(net,im,layerName,'OutputAs','rows');
    % HERE : take an image of the same size for each cell to be able to compare for different sizes
    % of images , like 224 x 224
   % sum(cells(i).ac)
end





% bw1=obj.image(:,:,5,12);
% bw2=obj.image(:,:,5,13);
% 
% res = imwarp(bw1,D);
% 
% %figure, imshow(bw1,[]);
% %figure, imshow(bw2,[]);
% %
% figure, imshowpair(bw2,bw1)
% figure, imshowpair(bw2,res)

% im=obj.image(:,:,5,10);
% 
% l1=im==6;
% l2=im==3;
% 
% il=logical(imdilate(l1,strel('Disk',10)));
% 
% mat=im(il);
% pix=setxor(unique(mat(:)),0)
% 
% bw= l1 | l2;
% 
% %figure, imshow(bw,[]);
% thr=5;
% bw1=bwdist(l1).*l2;
% bw1=bw1<thr & bw1>0;
% bw2=bwdist(l2).*l1;
% bw2=bw2<thr & bw2>0;
% 
% bwtot= bw1 | bw2;
% 
% bwtot=imdilate(bwtot,strel('Disk',3));
% 
% bw= bw | bwtot;
% 
% figure, imshow(bw,[]);

% ----

%bw=bwmorph(bw,'majority');

%figure, imshow(bw,[]);
%stat=regionprops(bw,'ConvexImage');
%stat
%figure, imshow(stat.ConvexImage,[]);
