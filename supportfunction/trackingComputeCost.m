function [cost,imout]=trackingComputeCost(iminput1,iminput2,bwobject1,bwobject2,classifier,thr)

cost=1000;
stat1=regionprops(bwobject1,'Centroid');
stat2=regionprops(bwobject2,'Centroid');

dist=sqrt((stat2.Centroid(2)-stat1.Centroid(2)).^2+(stat2.Centroid(1)-stat1.Centroid(1)).^2);

if dist<thr % pixel, arbitrarily defined
    
    % print image with appropriate masking
    % in case an effective mapping is observed put it in the
    % appropriate class
    
    bwobject1dil=imdilate(bwobject1,strel('Disk',10));
    imout=uint8(zeros(size(iminput1,1),size(iminput1,2),3));

    bwobject2dil=imdilate(bwobject2,strel('Disk',10));
    
    tm=uint8(zeros(size(iminput1,1),size(iminput1,2)));
    
    tm(bwobject1dil)=iminput1(bwobject1dil); % write object of interest on image
    imout(:,:,1)=tm;
    
    % figure, imshow(imout,[]);
    tm=uint8(zeros(size(iminput1,1),size(iminput1,2)));
    tm(bwobject2dil)=iminput2(bwobject2dil); % write object of interest on image
    imout(:,:,2)=tm;
    % test if objects correspond
   
    %imout(:,:,3)=iminput1;
    
    cost=activations(classifier,imout,'prob');
    
    % compute the proba of associstaiton; 
    cost=cost(1); % cost has 2 outputs, corresponding to 2 classes : link, vs no link
    
end



