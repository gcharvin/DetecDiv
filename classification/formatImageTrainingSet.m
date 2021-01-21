function formatImageTrainingSet(foldername,classif,rois)

if ~isfolder([classif.path '/' foldername '/images'])
    mkdir([classif.path '/' foldername], 'images');
end

for i=1:numel(classif.classes)
    if ~isfolder([classif.path '/' foldername '/images/' classif.classes{i}])
        mkdir([classif.path '/' foldername '/images'], classif.classes{i});
    end
end


cltmp=classif.roi;

disp('Starting parallelized jobs for data formatting....')

warning off all
parfor i=rois
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
    
    lab= categorical(cltmp(i).train.(classif.strid).id,1:numel(classif.classes),classif.classes); % creates labels for classification
    
    reverseStr = '';
    
    for j=1:size(im,4)
        tmp=im(:,:,:,j);
        
        if numel(pix)==1
            
               [tmp, Gdir] = imgradient(tmp,'prewitt');
           % figure, imshow(tmp,[]);
            
            
            
            tmp=uint16(tmp-mean(tmp(:)));
            
           % figure, imshow(tmp,[]);
%             pause
%             close
           % max(tmp(:))
            %tmp = double(imadjust(tmp,[meanphc/65535 maxphc/65535],[0 1]))/65535;
            tmp = double(imadjust(tmp,[0/65535 max(double(tmp(:)))/65535],[0 1]))/65535;
            
            
           % tmp = double(imadjust(tmp,[meanphc/65535 maxphc/65535],[0 1]))/65535;
            tmp=repmat(tmp,[1 1 3]);
            
            
            %max(tmp(:))
            %return
        end
        
%         figure, imshow(tmp,[]);
%         return;
        
        tr=num2str(j);
        while numel(tr)<4
            tr=['0' tr];
        end
        
        
        if cltmp(i).train.(classif.strid).id(j)~=0 % if training is done
            % if ~isfile([str '/unbudded/im_' mov.trap(i).id '_frame_' tr '.tif'])
            imwrite(tmp,[classif.path '/' foldername '/images/' classif.classes{cltmp(i).train.(classif.strid).id(j)} '/' cltmp(i).id '_frame_' tr '.tif']);
            % end
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



