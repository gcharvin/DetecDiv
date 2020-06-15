function formatTrackingTrainingSet(foldername,classif,rois)

if ~isfolder([classif.path '/' foldername '/images'])
    mkdir([classif.path '/' foldername], 'images');
end

for i=1:numel(classif.classes)
    if ~isfolder([classif.path '/' foldername '/images/' classif.classes{i}])
        mkdir([classif.path '/' foldername '/images'], classif.classes{i});
    end
end


% for i=1:size(im,4)
%    
%     stats=regionprops(im(:,:,1,i)>0,'Area');
%     tmp=[stats.Area];
%    % size(tmp)
%     area=[area; tmp'];
% end
% 
% area=area';
% areamean=mean(area);
% distancemean=2*sqrt(areamean)*2/pi;


cltmp=classif.roi;

disp('Starting parallelized jobs for data formatting....')

warning off all
for i=rois
    disp(['Launching ROI ' num2str(i) :' processing...'])
    
    
    if numel(cltmp(i).image)==0
        cltmp(i).load; % load image sequence
    end
    
    
    % normalize intensity levels
    pix=find(cltmp(i).channelid==classif.channel(1)); % find channel
    im=cltmp(i).image(:,:,pix,:);
    
    if numel(pix)==1
        % 'ok'
        totphc=im;
        meanphc=0.5*double(mean(totphc(:)));
        maxphc=double(meanphc+0.7*(max(totphc(:))-meanphc));
    end
    
    
    % 'ok'
    %vid=uint8(zeros(size(cltmp(i).image,1),size(cltmp(i).image,2),3,size(cltmp(i).image,4)));
    
    %pixb=numel(cltmp(i).train.(classif.strid).id);
    %pixa=find(cltmp(i).train.(classif.strid).id==0);
    
    % make a test
    %         if numel(cltmp(i).train.(classif.strid).mother)==0
    %             disp('Error: ROI has not been annotated');
    %             continue
    %         end
    
    %pixelchannel2=cltmp(i).findChannelID(classif.strid);
    pix2=find(cltmp(i).channelid==classif.channel(2));
    
    % find channel associated with user classified objects
    im2=cltmp(i).image(:,:,pix2,:);
    %figure, imshow(im2(:,:,1,1),[]);
    
    reverseStr = '';
    
    for j=1:20%size(im,4)-1 % stop 1 image bedfore the end
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
        
        
        %make a loop on all objects of each image
        label1=im2(:,:,1,j);
        label2=im2(:,:,1,j+1);
        
        
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
            imout=uint8(zeros(size(im,1),size(im,2),3));
            
            for l=1:max(l2(:))
                
            dist=sqrt((stat2(l).Centroid(2)-stat1.Centroid(2)).^2+(stat2(l).Centroid(1)-stat1.Centroid(1)).^2);

            if dist<100 % pixel, arbitrarily defined 
                
               % print image with appropriate masking
               % in case an effective mapping is observed put it in the
               % appropriate class
               
               bw2=l2==l;
               bw2dil=imdilate(bw2,strel('Disk',10));
               
               tm=uint8(zeros(size(im,1),size(im,2)));
               
               tm(bw1dil)=tmp1(bw1dil); % write object of interest on image
               imout(:,:,1)=tm;
               
               
              % figure, imshow(imout,[]);
               tm=uint8(zeros(size(im,1),size(im,2)));
               tm(bw2dil)=tmp2(bw2dil); % write object of interest on image
               imout(:,:,2)=tm;
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
               imcrop=imout;
             %  figure, imshow(imcrop,[]);
               imwrite(imcrop,[classif.path '/' foldername '/images/' classif.classes{clas} '/' cltmp(i).id '_frame_' tr '_obj' num2str(val1) '_obj' num2str(val2) '.tif']);
               
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
    %cltmp(i).clear; %%% remove !!!!
end

end

