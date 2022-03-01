function output=formatImageTrainingSet(foldername,classif,rois)

% optional argument provides the numbers associaed with reach image in case
% of a regression
output=0;

if ~isfolder([classif.path '/' foldername '/images'])
    mkdir([classif.path '/' foldername], 'images');
end

if strcmp(classif.category{1},'Image')
    for i=1:numel(classif.classes)
        if ~isfolder([classif.path '/' foldername '/images/' classif.classes{i}])
            mkdir([classif.path '/' foldername '/images'], classif.classes{i});
        end
    end
end

if strcmp(classif.category{1},'Image Regression')
    if ~isfolder([classif.path '/' foldername '/labels/'])
        mkdir([classif.path '/' foldername], 'labels');
    end
end

cltmp=classif.roi;

disp('Starting parallelized jobs for data formatting....')

warning off all

channel=classif.channelName;
%parfor here
for i=rois
    disp(['Launching ROI ' num2str(i) ': processing...'])
    
    
    if numel(cltmp(i).image)==0
        cltmp(i).load; % load image sequence
    end
    
    
    
    pix=cltmp(i).findChannelID(channel{1});
    
    % normalize intensity levels
    %pix=find(cltmp(i).channelid==classif.channel(1)); % find channel
    
    im=cltmp(i).image(:,:,pix,:);
    
    %lab= categorical(cltmp(i).train.(classif.strid).id,1:numel(classif.classes),classif.classes); % creates labels for classification
    
    reverseStr = '';
    
    
    if   strcmp(classif.category{1},'Image')
        for j=1:size(im,4)

            param=[];
            tmp=cltmp(i).preProcessROIData(pix,j,param);
         %   figure; imshow(tmp)
            tr=num2str(j);
            while numel(tr)<4
                tr=['0' tr];
            end
            
            
            if cltmp(i).train.(classif.strid).id(j)~=0 % if training is done
                % if ~isfile([str '/unbudded/im_' mov.trap(i).id '_frame_' tr '.tif'])
                imwrite(tmp,[classif.path '/' foldername '/images/' classif.classes{cltmp(i).train.(classif.strid).id(j)} '/' cltmp(i).id '_frame_' tr '.tif']);
                output=output+1;
                % end
            end
            
            
            msg = sprintf('Processing frame: %d / %d for ROI %s', j, size(im,4),cltmp(i).id); %Don't forget this semicolon
            fprintf([reverseStr, msg]);
            reverseStr = repmat(sprintf('\b'), 1, length(msg));
        end
        
    end
    
    if  strcmp(classif.category{1},'Image Regression')
        % image regression
      %  tmp=zeros(size(im,1),size(im,2),3,size(im,4));
        
        for j=1:size(im,4)
            % tmp(:,:,:j)=im(:,:,:,j);
            param=[];
            tmp=cltmp(i).preProcessROIData(pix,j,param);
          %  tmp=im(:,:,:,j);
        %    tmp=double(tmp)/65535;
        
        tr=num2str(j);
            while numel(tr)<4
                tr=['0' tr];
            end
           
              if ~isnan(cltmp(i).train.(classif.strid).id(j)) % if training is done
                % if ~isfile([str '/unbudded/im_' mov.trap(i).id '_frame_' tr '.tif'])
                imwrite(tmp,[classif.path '/' foldername '/images/' cltmp(i).id '_frame_' tr '.tif']);
                
                label= cltmp(i).train.(classif.strid).id(j);
                
                save([classif.path '/' foldername '/labels/' cltmp(i).id '_frame_' tr '.mat'],'label');
                output=output+1;
                % end
              end
            
        end
        
        %   if cltmp(i).train.(classif.strid).id(j)~=-1 % if training is done
       % parsaveim([classif.path '/' foldername '/images/' cltmp(i).id '.mat'],tmp);
       % parsave([classif.path '/' foldername '/response/' cltmp(i).id '.mat'],cltmp(i).train.(classif.strid).id);
       % output=output+1;
        %   end
    end
    
    fprintf('\n');
    
    cltmp(i).save;
    
    disp(['Processing ROI: ' num2str(i) ' ... Done !'])
end

warning on all;

for i=rois
    cltmp(i).clear; %%% remove !!!!
end

% function parsaveim(fname, im)
% eval(['save  '  fname  '  im']);
%
% function parsave(fname, response)
% eval(['save  '  fname  '  response']);


function parsaveim(fname, im)
eval(['save  ''''  '  fname  ''''  '  im']);

function parsaveresp(fname, response)
eval(['save  ' '''' fname  ''''  '  response']);




