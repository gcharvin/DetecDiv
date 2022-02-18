function output= formatDeltaTrainingSet(foldername,classif,rois)
output=0;
if ~isfolder([classif.path '/' foldername '/images'])
    mkdir([classif.path '/' foldername], 'images');
end
if ~isfolder([classif.path '/' foldername '/labels'])
    mkdir([classif.path '/' foldername], 'labels');
end

offset=10; % offset used to increase image size around object

imagesize=151;

cltmp=classif.roi;

%disp('Starting parallelized jobs for data formatting....')

warning off all

channel=classif.channelName; % list of channels used to generate input image
% for delta : ch1 : image at t; ch2: seg of target cell at t; ch3: image at
% t+1; ch4 : seg of all cells

% outpur :  labels for target cell at t+1; 

% therefore 2 channels are necessary : first is raw image, second is labels

% labels must ber tracked over time to extract cell numbers

%labelchannel=classif.strid; % image that contains the labels

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
     pix2=cltmp(rois(i)).findChannelID(channel{2}); % label channel
    
    % find channel associated with user classified objects
    im2=cltmp(i).image(:,:,pix2,:);
    %figure, imshow(im2(:,:,1,1),[]);
    
    reverseStr = '';
    
    for j=1:size(im,4)-1 % stop 1 image bedfore the end
        tmp1=im(:,:,1,j);
        tmp2=im(:,:,1,j+1);
        
         tmcrop=uint8(zeros(imagesize,imagesize,4));
         tmcroplabel=uint8(zeros(imagesize,imagesize,3));
         
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
        
        tr=num2str(j);
        while numel(tr)<4
            tr=['0' tr];
        end
        
        
        label1=im2(:,:,1,j);
        label2=im2(:,:,1,j+1);
        
       % labelout
        %l1=bwlabel(label1);
        %l2=bwlabel(label2);
        
        if max(label1(:))==0 % image is not annotated
            continue
        end
        
        
        % HERE 
        
        for k=1:max(label1(:))% loop on all present objects
            
            bw1=label1==k;

            if numel(bw1)==0 % this cell number is not present
                continue
            end
            
            stat1=regionprops(bw1,'Centroid'); % reference of the image
            
            minex=uint16(max(1,round(stat1.Centroid(1))-imagesize/2));
            miney=uint16(max(1,round(stat1.Centroid(2))-imagesize/2));
            
            maxex=uint16(min(size(tmp,2),round(stat1.Centroid(1))+imagesize/2-1));
            maxey=uint16(min(size(tmp,1),round(stat1.Centroid(2))+imagesize/2-1));
            
            tmpcrop(:,:,1)=tmp1(miney:maxey,minex:maxex);
            tmpcrop(:,:,2)=255*uint8(bw1(miney:maxey,minex:maxex));
            tmpcrop(:,:,3)=tmp2(miney:maxey,minex:maxex);
            tmpcrop(:,:,4)=label2(miney:maxey,minex:maxex);
            
        
               
               %imcrop=uint8(256*imout);
               imcrop=tmcrop;
             %  figure, imshow(imcrop,[]);
               imwrite(imcrop,[classif.path '/' foldername '/images/' classif.classes{clas} '/' cltmp(i).id '_frame_' tr '_obj' num2str(val1) '_obj' num2str(val2) '.tif']);
                output=output+1;
               
            end
                
            
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

