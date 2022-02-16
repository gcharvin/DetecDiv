function output= formatDeltaTrainingSet(foldername,classif,rois)
output=0;
if ~isfolder([classif.path '/' foldername '/images'])
    mkdir([classif.path '/' foldername], 'images');
end
if ~isfolder([classif.path '/' foldername '/labels'])
    mkdir([classif.path '/' foldername], 'labels');
end

offset=10; % offset used to increase image size around object

cltmp=classif.roi;

disp('Starting parallelized jobs for data formatting....')

warning off all

channel=classif.channelName; % list of channels used to generate input image
% for delta : ch1 : image at t; ch2: seg at t; ch3: image at t+1; ch4 :
% labels at t+1; 
% therefore 2 channels are necessary : first is raw image, second is labels
% labels must ber tracked over time to extract cell number hy

labelchannel=classif.strid; % image that contains the labels

for i=rois
    disp(['Launching ROI ' num2str(i) : ' processing...']);
    
    if numel(cltmp(i).image)==0
        cltmp(i).load; % load image sequence
    end
    
    % normalize intensity levels
     pix=cltmp(rois(i)).findChannelID(channel{1});
     
    im=cltmp(i).image(:,:,pix,:); % raw image
    
    if numel(pix)==1
        % 'ok'
        totphc=im;
        meanphc=0.5*double(mean(totphc(:)));
        maxphc=double(meanphc+0.7*(max(totphc(:))-meanphc));
    end
    
    %pixelchannel2=cltmp(i).findChannelID(classif.strid);
     pix2=cltmp(rois(i)).findChannelID(channel{2}); % segmented channel
    
    % find channel associated with user classified objects
    im2=cltmp(i).image(:,:,pix2,:);
    %figure, imshow(im2(:,:,1,1),[]);
    
    reverseStr = '';
    
    for j=1:size(im,4)-1 % stop 1 image bedfore the end
        tmp1=im(:,:,1,j);
        tmp2=im(:,:,1,j+1);
        
        %figure, imshow(tmp1,[]);
        %figure, imshow(tmp2,[]);
        %return;
        if numel(pix)==1
            
            tmp1 = double(imadjust(tmp1,[meanphc/65535 maxphc/65535],[0 1]))/65535;
            tmp1=uint8(256*tmp1);
            tmp2 = double(imadjust(tmp2,[meanphc/65535 maxphc/65535],[0 1]))/65535;
            tmp2=uint8(256*tmp2);
            %tmp=repmat(tmp,[1 1 3]);
            
        end
        
        % figure, imshow(im,[])
        % return;
        
        tr=num2str(j);
        while numel(tr)<4
            tr=['0' tr];
        end
        
        
        label1=im2(:,:,1,j);
        label2=im2(:,:,1,j+1);
        
        labelout
        l1=bwlabel(label1);
        l2=bwlabel(label2);
        
        if max(label1(:))==0 % image is not annotated
            continue
        end
        
        
        for k=1:max(l1(:))% loop on all present objects
            
            bw1=l1==k;

            if numel(bw1)==0 % this cell number is not present
                continue
            end
            
            stat1=regionprops(bw1,'Centroid');
            stat2=regionprops(l2,'Centroid');

            
            bw1dil=imdilate(bw1,strel('Disk',10));
            stat1b=regionprops(bw1dil,'BoundingBox');
            %imout=uint8(zeros(size(im,1),size(im,2),3));
            
            for l=1:max(l2(:))
                
            dist=sqrt((stat2(l).Centroid(2)-stat1.Centroid(2)).^2+(stat2(l).Centroid(1)-stat1.Centroid(1)).^2);

            if dist<100 % pixel, arbitrarily defined 
                
               % print image with appropriate masking
               % in case an effective mapping is observed put it in the
               % appropriate class
               
               bw2=l2==l;
               bw2dil=imdilate(bw2,strel('Disk',10));
               
               stat2b=regionprops(bw2dil,'BoundingBox');
               
               % create image of the right size
               wid=max(stat1b.BoundingBox(4),stat2b.BoundingBox(4));
               hei=max(stat1b.BoundingBox(3),stat2b.BoundingBox(3));
               
               if mod(wid,2)==0
                   wid=wid+ 1;
               end
               if mod(hei,2)==0
                   hei=hei+ 1;
               end
               
               tmcrop=uint8(zeros(wid,hei,3));
               
               tm=uint8(zeros(size(im,1),size(im,2)));
               
               tm(bw1dil)=tmp1(bw1dil); % write object of interest on image
               
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
               tm=uint8(zeros(size(im,1),size(im,2)));
               tm(bw2dil)=tmp2(bw2dil); % write object of interest on image
               
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
               
             % figure, imshow(tmcrop);
             % pause
             % close
    
    
               % test if objects correspond
               
              % imout(:,:,3)=tmp1;
               %l
               val1=round(mean(label1(bw1)));
               val2=round(mean(label2(bw2)));
               
               if val1==val2 % obects match
                   clas=2;
               else % they don't 
                   clas=1;
               end
               
               %imcrop=uint8(256*imout);
               imcrop=tmcrop;
             %  figure, imshow(imcrop,[]);
               imwrite(imcrop,[classif.path '/' foldername '/images/' classif.classes{clas} '/' cltmp(i).id '_frame_' tr '_obj' num2str(val1) '_obj' num2str(val2) '.tif']);
                output=output+1;
               
            end
                
            end
            %return;
            % find all cell numbers in the next frame
            
            
            %  if j==16
            
            % bbox=round(pr(k).BoundingBox);
            % clas=round(mean(labeledobjects(bw)));
            
            %imcrop=tmp(bbox(2):bbox(2)+bbox(4),bbox(1):bbox(1)+bbox(3),:);
            
            % figure, imshow(imcrop,[]);
            % figure, imshow(tmp,[]);
           
            %    end
            
        end
        
        msg = sprintf('Processing frame: %d / %d for ROI %s', j, size(im,4),cltmp(i).id); %Don't forget this semicolon
        fprintf([reverseStr, msg]);
        reverseStr = repmat(sprintf('\b'), 1, length(msg));
    end
    
    fprintf('\n');
    
    
    
    
 
    
    cltmp(i).save;
    
    disp(['Processing ROI: ' num2str(i) ' ... Done !'])
end

warning on all;

for i=rois
    cltmp(i).clear; %%% remove !!!!
end

end

