function [cost,tmcrop]=trackingComputeCost(iminput1,iminput2,bwobject1,bwobject2,classifier,thr)

cost=1000;
stat1=regionprops(bwobject1,'Centroid');
stat2=regionprops(bwobject2,'Centroid');

dist=sqrt((stat2.Centroid(2)-stat1.Centroid(2)).^2+(stat2.Centroid(1)-stat1.Centroid(1)).^2);

if dist<thr % pixel, arbitrarily defined
    
%     % print image with appropriate masking
%     % in case an effective mapping is observed put it in the
%     % appropriate class
%     
     bwobject1dil=imdilate(bwobject1,strel('Disk',10));
     stat1b=regionprops(bwobject1dil,'BoundingBox');
     
     %imout=uint8(zeros(size(iminput1,1),size(iminput1,2),3));
     
     
% 
     bwobject2dil=imdilate(bwobject2,strel('Disk',10));
     stat2b=regionprops(bwobject2dil,'BoundingBox');
     
     
%     tm=uint8(zeros(size(iminput1,1),size(iminput1,2)));
%     
%     tm(bwobject1dil)=iminput1(bwobject1dil); % write object of interest on image
%     imout(:,:,1)=tm;
%     
%     % figure, imshow(imout,[]);
%     tm=uint8(zeros(size(iminput1,1),size(iminput1,2)));
%     tm(bwobject2dil)=iminput2(bwobject2dil); % write object of interest on image
%     imout(:,:,2)=tm;
    
    % test if objects correspond
   
    %imout(:,:,3)=iminput1;
    
     wid=max(stat1b.BoundingBox(4),stat2b.BoundingBox(4));
               hei=max(stat1b.BoundingBox(3),stat2b.BoundingBox(3));
               
               if mod(wid,2)==0
                   wid=wid+ 1;
               end
               if mod(hei,2)==0
                   hei=hei+ 1;
               end
               
               tmcrop=uint8(zeros(wid,hei,3));
               
               tm=uint8(zeros(size(iminput1,1),size(iminput1,2)));
               
               tm(bwobject1dil)=iminput1(bwobject1dil); % write object of interest on image
               
               if mod(stat1b.BoundingBox(4),2)==1
                   stat1b.BoundingBox(4)=stat1b.BoundingBox(4)-1;
               end
               if mod(stat1b.BoundingBox(3),2)==1
                   stat1b.BoundingBox(3)=stat1b.BoundingBox(3)-1;
               end
               
               minex=stat1b.BoundingBox(2);
               miney=stat1b.BoundingBox(1);
               maxex=stat1b.BoundingBox(2)+stat1b.BoundingBox(4);
               maxey=stat1b.BoundingBox(1)+stat1b.BoundingBox(3);
               
               midx=(wid-1)/2;
               midy=(hei-1)/2;
               
               tmcrop(1+midx-stat1b.BoundingBox(4)/2:1+midx+stat1b.BoundingBox(4)/2,1+midy-stat1b.BoundingBox(3)/2:1+midy+stat1b.BoundingBox(3)/2,1)= tm(minex:maxex,miney:maxey);
               
               %imout(:,:,1)=tm;
               
               
              % figure, imshow(imout,[]);
               tm=uint8(zeros(size(iminput1,1),size(iminput1,2)));
               tm(bwobject2dil)=iminput2(bwobject2dil); % write object of interest on image
               
               if mod(stat2b.BoundingBox(4),2)==1
                   stat2b.BoundingBox(4)=stat2b.BoundingBox(4)-1;
               end
               if mod(stat2b.BoundingBox(3),2)==1
                   stat2b.BoundingBox(3)=stat2b.BoundingBox(3)-1;
               end
               
               minex=stat2b.BoundingBox(2);
               miney=stat2b.BoundingBox(1);
               maxex=stat2b.BoundingBox(2)+stat2b.BoundingBox(4);
               maxey=stat2b.BoundingBox(1)+stat2b.BoundingBox(3);
               
% midx-stat2(l).BoundingBox(4)/2
% midx+stat2(l).BoundingBox(4)/2
% midy-stat2(l).BoundingBox(3)/2
% midy+stat2(l).BoundingBox(3)/2

               tmcrop(midx-stat2b.BoundingBox(4)/2+1:midx+stat2b.BoundingBox(4)/2+1,1+midy-stat2b.BoundingBox(3)/2:1+midy+stat2b.BoundingBox(3)/2,2)= tm(minex:maxex,miney:maxey);
               
               tmcrop=imresize(tmcrop,classifier.Layers(1).InputSize(1:2));
    
    cost=activations(classifier,tmcrop,'prob');
    
    % compute the proba of associstaiton; 
    cost=cost(1); % cost has 2 outputs, corresponding to 2 classes : link, vs no link
    
end



            
          
               % print image with appropriate masking
               % in case an effective mapping is observed put it in the
               % appropriate class
               
              
               
               
               
               
               % create image of the right size
              
               

