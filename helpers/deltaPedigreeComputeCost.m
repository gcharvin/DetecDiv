function vec=deltaPedigreeComputeCost(iminput1,iminput2,label1,label2,classifier,id1,imagesize)

bw1=label1==id1;

tmp1=iminput1;
tmp2=iminput2;


%             if numel(bw1)==0 % this cell number is not present
%                 continue
%             end
            
 stat1=regionprops(bw1,'Centroid');
 
%  if numel(stat1)==0
%      
%      figure, imshow(bw1,[])
%      
%  end
            
%             if numel(stat1)==0
%                 %    disp('found object with no centroid; skipping....');
%                 continue
%             end
            
            % reference of the image
            
            minex=uint16(max(1,round(stat1.Centroid(1))-imagesize/2));
            miney=uint16(max(1,round(stat1.Centroid(2))-imagesize/2));
            
            maxex=uint16(min(size(tmp1,2),round(stat1.Centroid(1))+imagesize/2-1));
            maxey=uint16(min(size(tmp1,1),round(stat1.Centroid(2))+imagesize/2-1));
            
            tmpcrop=uint8(zeros(maxey-miney+1,maxex-minex+1,4));
            
            tmpcrop(:,:,1)=tmp1(miney:maxey,minex:maxex);
            tmpcrop(:,:,2)=255*uint8(bw1(miney:maxey,minex:maxex));
            tmpcrop(:,:,3)=tmp2(miney:maxey,minex:maxex);
            tmpcrop(:,:,4)=255*uint8(label2(miney:maxey,minex:maxex)>0);
    
            label2crop=label2(miney:maxey,minex:maxex);
  %  cost=activations(classifier,tmcrop,'prob');
  
  %    figure, imshow(tmpcrop(:,:,3),[]);
    %   figure, imshow(tmpcrop(:,:,4),[]);
       
     netsize=classifier.Layers(1).InputSize;
      tmpcrop=imresize(tmpcrop,netsize(1:2));
      
       [C,score,features]= semanticseg(tmpcrop, classifier);
       
       features=imresize(features, [imagesize imagesize]);
       
     %  figure, imshow(features(:,:,2),[]);
       
       stat2=regionprops(label2,'Centroid');
   
       vec=Inf*ones(1,max(label2(:)));
       
       for i=1:max(label2(:))

           dist=sqrt((stat2(i).Centroid(2)-stat1.Centroid(2)).^2+(stat2(i).Centroid(1)-stat1.Centroid(1)).^2);

            if dist>imagesize% pixel, arbitrarily defined
                continue
            end
           
            bw=label2crop==i;
            
            if sum(bw(:))>0
            proba=features(:,:,2); % cell class proba 
            
            vec(i) = -log(mean(proba(bw)));
            end
            
       end
       
       
       
       



            
          
          
              
               

