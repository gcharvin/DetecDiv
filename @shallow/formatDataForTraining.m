function formatDataForTraining(obj,classiid,option) %mov,trapsid,option)
% saves user annotated data to disk- works for Image, Pixel and LSTM
% classification

disp('Saving user training to disk...');

classif=obj.processing.classification(classiid);
category=classif.category;
category=category{1};

foldername='trainingdataset';

if nargin<3  % removeand recreares all directoires
    
% mk folder to store ground user trained data

if isfolder([classif.path '/' foldername])
    rmdir([classif.path '/' foldername], 's')
end
mkdir(classif.path,foldername)
end

if strcmp(category,'Image') || strcmp(category,'LSTM') || strcmp(category,'Object')
  
        if ~isfolder([classif.path '/' foldername '/images'])
            mkdir([classif.path '/' foldername], 'images');
        end
        
        
        
        for i=1:numel(classif.classes)
            if ~isfolder([classif.path '/' foldername '/images/' classif.classes{i}])
                mkdir([classif.path '/' foldername '/images'], classif.classes{i});
            end
        end
end

defaultclass=[];
if strcmp(category,'Pixel')

        mkdir([classif.path '/' foldername],'images')
        mkdir([classif.path '/' foldername],'labels')
        
         prompt='If there are some unassigned pixels, to which class id number do you want to attribute it ? [Default 1]): ';
defaultclass= input(prompt);
if numel(defaultclass)==0
    defaultclass=1;
end

        % in case of pixels, training data is a list of 3 channels from the
        % roi.image matrix with indexed colors
end  
        
if strcmp(category,'LSTM')
    
    if nargin<3
    prompt='Train googlenet image classifier ? (y / n [Default y]): ';
imageclassifier= input(prompt,'s');
if numel(imageclassifier)==0
    imageclassifier='y';
end

 prompt='Compute activation for google net ? (y / n [Default y]): ';
cactivations= input(prompt,'s');
if numel(cactivations)==0
    cactivations='y';
end

 prompt='Train LSTM network ? (y/n [Default y]): ';
lstmtraining= input(prompt,'s');
if numel(lstmtraining)==0
   lstmtraining='y';
end

 prompt='Assemble full network ? (y/n [Default y] ): ';
assemblenet= input(prompt,'s');
if numel(assemblenet)==0
    assemblenet='y';
end

%  prompt='Validate training data ? (y [Default y]/ n ): ';
% assemblenet= input(prompt,'s');
% if numel(assemblenet)==0
%     validation='y';
% end

save([classif.path '/options.mat'],'cactivations','imageclassifier','lstmtraining','assemblenet'); % save options to be used in training function
    end
    
     if ~isfolder([classif.path '/' foldername '/timeseries'])
            mkdir([classif.path '/' foldername], 'timeseries');
     end
        
end

% look on all ROIs

if nargin<3
rois=1:numel(classif.roi);
else
 rois=option ;  
end

cltmp=classif.roi; 

disp('Starting parallelized jobs for data formatting....')

warning off all
parfor i=rois
    disp(['Launching ROI: ' num2str(i) ' processing...'])
    
    
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
    
    if strcmp(category,'LSTM')
       % 'ok'
        vid=uint8(zeros(size(cltmp(i).image,1),size(cltmp(i).image,2),3,size(cltmp(i).image,4)));
        
        pixb=numel(cltmp(i).train.(classif.strid).id);
        pixa=find(cltmp(i).train.(classif.strid).id==0);
        
        if numel(pixa)>0 || numel(pixa)==0 && pixb==0 % some images are not labeled, quitting ...
            disp('Error: some images are not labeled in this ROI - LSTM requires all images to be labeled in the timeseries!');
            continue
        end
       % 'pasok'
    end
    
    if strcmp(category,'Pixel') % get the training data for pixel classification
        
        % find image channel associated with training
        %pixe = strfind(cltmp(i).display.channel, classif.strid);
        cc=cltmp(i).findChannelID(classif.strid);
        
        if numel(cc)>0
        pixcc=find(cltmp(i).channelid==cc);
        % size(cltmp(i).image)
        lab=cltmp(i).image(:,:,pixcc,:);
        
        labels= double(zeros(size(lab,1),size(lab,2),3,size(lab,4)));
        
       % figure, imshow(lab(:,:,:,9),[]);
        % return;
        
        for j=1:numel(classif.classes)
            
            if j==defaultclass % 
            pixz=lab(:,:,1,:)==j | lab(:,:,1,:)==0; % WARNING !!!! add unassigned pixels to this class
            else
            pixz=lab(:,:,1,:)==j;   
            end
            
            labtmp2=double(zeros(size(lab,1),size(lab,2),1,size(lab,4)));
            labtmp2(pixz)=1;
            
            for  k=1:3
                labels(:,:,k,:)=labels(:,:,k,:)+classif.colormap(j+1,k)*labtmp2;
            end
            
        end
        end
        
        
        % figure, imshow(labels(:,:,:,10),[]);
        % return;
        
        %labels=labtmp;
         
    end
    
    
    
    if strcmp(category,'Image') || strcmp(category,'LSTM')
      % classif
      % cltmp(i)
        lab= categorical(cltmp(i).train.(classif.strid).id,1:numel(classif.classes),classif.classes); % creates labels for classification
           
    end
    
    reverseStr = '';
    
    if strcmp(category,'Object')
    pixelchannel2=cltmp(i).findChannelID(classif.strid);
    pix2=find(cltmp(i).channelid==pixelchannel2);
                
    % find channel associated with user classified objects
    im2=cltmp(i).image(:,:,pix2,:);
    end
    
    

    
    for j=1:size(im,4)
        tmp=im(:,:,:,j);
        
        if numel(pix)==1
            
            tmp = double(imadjust(tmp,[meanphc/65535 maxphc/65535],[0 1]))/65535;
            tmp=repmat(tmp,[1 1 3]);
            
            
            %max(tmp(:))
            %return
        end
        
        if strcmp(category,'Pixel')
            %tmp=uint8(256*tmp);
            
        end
        
        if strcmp(category,'LSTM')
            vid(:,:,:,j)=uint8(256*tmp);
        end
        % figure, imshow(im,[])
        % return;
        
        tr=num2str(j);
        while numel(tr)<4
            tr=['0' tr];
        end
        
        if strcmp(category,'Image') || strcmp(category,'LSTM')
            if cltmp(i).train.(classif.strid).id(j)~=0 % if training is done
                % if ~isfile([str '/unbudded/im_' mov.trap(i).id '_frame_' tr '.tif'])
                imwrite(tmp,[classif.path '/' foldername '/images/' classif.classes{cltmp(i).train.(classif.strid).id(j)} '/' cltmp(i).id '_frame_' tr '.tif']);
                % end
            end
        end
        
          if strcmp(category,'Object') 
            %if cltmp(i).train.(classif.strid).id(j)~=0 % if training is done
                % if ~isfile([str '/unbudded/im_' mov.trap(i).id '_frame_' tr '.tif'])
                %make a loop on all objects of each image
                labeledobjects=im2(:,:,:,j);
                
                if max(labeledobjects(:))==0 % image is not annotated
                    continue
                end
                
               
                [l no]=bwlabel(labeledobjects>0);
                 pr=regionprops(l,'BoundingBox');
                
                for k=1:no % loop on all present objects
                    
                    bw=l==k;
                    
                  %  if j==16
                    bbox=round(pr(k).BoundingBox);
                    clas=round(mean(labeledobjects(bw)));
                    
                    imcrop=tmp(bbox(2):bbox(2)+bbox(4),bbox(1):bbox(1)+bbox(3),:);
                    
                   % figure, imshow(imcrop,[]);
                   % figure, imshow(tmp,[]);
                     imwrite(imcrop,[classif.path '/' foldername '/images/' classif.classes{clas} '/' cltmp(i).id '_frame_' tr '_obj' num2str(k) '.tif']);
                %    end
                    
                    
                end
                
                 % end
            %end
          end
        
        
        if strcmp(category,'Pixel')
            if numel(cc)>0
            tmplab=lab(:,:,:,j);
            if max(tmplab(:))>0 % test if image has been manually annotated
           %  'ok'
                imwrite(tmp,[classif.path '/' foldername '/images/' cltmp(i).id '_frame_' tr '.tif']);
                imwrite(labels(:,:,:,j),[classif.path '/' foldername '/labels/' cltmp(i).id '_frame_' tr '.tif']);
                
                
            end
            end
        end
        
       msg = sprintf('Processing frame: %d / %d for ROI %s', j, size(im,4),cltmp(i).id); %Don't forget this semicolon
       fprintf([reverseStr, msg]);
       reverseStr = repmat(sprintf('\b'), 1, length(msg));
    end
    
    fprintf('\n');
    
    
    
    if strcmp(category,'LSTM')
        deep=cltmp(i).train.(classif.strid).id;
        parsave([classif.path '/' foldername '/timeseries/lstm_labeled_' cltmp(i).id '.mat'],'deep','vid','lab');
    end
    
    cltmp(i).save;

    disp(['Processing ROI: ' num2str(i) ' ... Done !'])
end
warning on all;

for i=rois
    cltmp(i).clear;
end

if strcmp(category,'Pixel') % saving classification  for training
        classification=classif;
        
        save([classif.path '/classification.mat'],'classification');
end
end

function parsave(fname, deep,vid,lab)
  save(fname, 'deep', 'vid','lab')
end



