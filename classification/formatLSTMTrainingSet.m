function output=formatLSTMTrainingSet(foldername,classif,rois)

output=0;
if ~isfolder([classif.path '/' foldername '/images'])
    mkdir([classif.path '/' foldername], 'images');
end

if classif.typeid~=12 % if classif
    for i=1:numel(classif.classes)
        if ~isfolder([classif.path '/' foldername '/images/' classif.classes{i}])
            mkdir([classif.path '/' foldername '/images'], classif.classes{i});
        end
    end
else % regression
    if ~isfolder([classif.path '/' foldername '/response/'])
        mkdir([classif.path '/' foldername], 'response');
    end
end

if ~isfolder([classif.path '/' foldername '/timeseries'])
    mkdir([classif.path '/' foldername], 'timeseries');
end

cltmp=classif.roi;

disp('Starting parallelized jobs for data formatting....')

warning off all
%for i=rois

 channel=classif.channelName;
 
parfor i=rois
    disp(['Launching ROI ' num2str(i) :' processing...'])
    
    if numel(cltmp(i).image)==0
        cltmp(i).load; % load image sequence
    end
    
    % normalize intensity levels
       
    pix=cltmp(i).findChannelID(channel{1});
    
  %  pix=find(cltmp(i).channelid==classif.channel(1)); % find channel
    im=cltmp(i).image(:,:,pix,:);
    
    if numel(pix)==1
        param=[];
        % 'ok'
        totphc=im;
        meanphc=0.5*double(mean(totphc(:)));
        maxphc=double(meanphc+0.7*(max(totphc(:))-meanphc));
        
        param.meanphc=meanphc;
        param.maxphc =maxphc;
        
    end
    
    if numel(classif.trainingset)==0
        param.nframes=1; % number of temporal frames per frame
        else
        param.nframes=classif.trainingset; % number of temporal frames per frame  
    end
        
    
   if  numel(pix)==1
     imtest=cltmp(i).preProcessROIData(pix,1,param); % done to determine image size
     % this preprocessing can only be performed on grayscale images
     % numel(pix)=1
   else
     imtest=im;  
   end
    
   %  figure, imshow(imtest,[]);
   %  return;
    % 'ok'
    
    vid=uint8(zeros(size(imtest,1),size(imtest,2),3,size(imtest,4)));
    
    if classif.typeid~=12 % only for  image classif
        pixb=numel(cltmp(i).train.(classif.strid).id);
        pixa=find(cltmp(i).train.(classif.strid).id==0);
        
        if numel(pixa)>0 || numel(pixa)==0 && pixb==0 % some images are not labeled, quitting ...
            disp('Error: some images are not labeled in this ROI - LSTM requires all images to be labeled in the timeseries!');
            continue
        end
        
        % 'pasok'
        
        lab= categorical(cltmp(i).train.(classif.strid).id,1:numel(classif.classes),classif.classes); % creates labels for classification
    else
        lab=[];
    end
    
    if classif.typeid~=12 % image classif
        reverseStr = '';
        for j=1:size(im,4)

            if numel(pix)==1
                tmp=cltmp(i).preProcessROIData(pix,j,param);
            else
                tmp=im(:,:,:,j);
                tmp=double(tmp)/65535;
            end
            
            %figure, imshow(tmp);
            %pause;
            %close;
            
            vid(:,:,:,j)=uint8(256*tmp);
            
            tr=num2str(j);
            while numel(tr)<4
                tr=['0' tr];
            end
            
            if classif.output==0
                cmp=cltmp(i).train.(classif.strid).id(j); % seuquence-to-sequence classif
            else
                cmp=cltmp(i).train.(classif.strid).id; % sequence-to-one classif
            end
            
            if cmp~=0 % if training is done
                % if ~isfile([str '/unbudded/im_' mov.trap(i).id '_frame_' tr '.tif'])
                imwrite(tmp,[classif.path '/' foldername '/images/' classif.classes{cmp} '/' cltmp(i).id '_frame_' tr '.tif']);
                 output=output+1;
                % end
            end
            
            msg = sprintf('Processing frame: %d / %d for ROI %s', j, size(im,4),cltmp(i).id); %Don't forget this semicolon
            fprintf([reverseStr, msg]);
            reverseStr = repmat(sprintf('\b'), 1, length(msg));
        end
        
    else % image regression
        tmp=zeros(size(im,1),size(im,2),3,size(im,4));
        
        for j=1:size(im,4)
            % tmp(:,:,:j)=im(:,:,:,j);
            
             if numel(pix)==1
                tmp=cltmp(i).preProcessROIData(pix,j,param);
            else
                tmp=im(:,:,:,j);
                tmp=double(tmp)/65535;
            end
            
             vid(:,:,:,j)=uint8(256*tmp);
        end
        
      %  if cltmp(i).train.(classif.strid).id(j)~=-1 % if training is done
            parsaveim([classif.path '/' foldername '/images/' cltmp(i).id '.mat'],tmp);
            
            parsaveresp([classif.path '/' foldername '/response/' cltmp(i).id '.mat'],cltmp(i).train.(classif.strid).id);
             output=output+1;
     %   end
    end
    
    fprintf('\n');
    
    deep=cltmp(i).train.(classif.strid).id;
    parsave([classif.path '/' foldername '/timeseries/lstm_labeled_' cltmp(i).id '.mat'],deep,vid,lab);
    
    cltmp(i).save;
    
    disp(['Processing ROI: ' num2str(i) ' ... Done !'])
end


warning on all;

for i=rois
    cltmp(i).clear; %%% remove !!!!
end


function parsaveim(fname, im)
eval(['save  ''''  '  fname  ''''  '  im']);

function parsaveresp(fname, response)
eval(['save  ' '''' fname  ''''  '  response']); 

  function parsave(fname, deep,vid,lab)
        
     %   fname
   eval(['save  ' ''''  fname  ''''  '  deep vid lab']);
      
      
    