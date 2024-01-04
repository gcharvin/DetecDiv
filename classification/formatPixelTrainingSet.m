function output=formatPixelTrainingSet(foldername,classif,rois)

% formats training set as tif images if number of channels is smaller or
% equal than 3, otherwise as multidemensionnal .mat file

% if instance segmentaiton (solov2), data are formatted as follows : 
% the training image is stores in the images folder
% a mat file is stores in the labels folder as a cell array: 
%out{1} = im;
%out{2} = Nx4 double bounding boxes
% Convert the dataset into 1 class
%out{3} = repmat(categorical("Object"), [numObjects 1]);       % Nx1 categorical object labels
%out{4} = data.masks;        % HxWxN logical mask arrays

output=0;

mkdir([classif.path '/' foldername],'images')
mkdir([classif.path '/' foldername],'labels')

%defaultclass=[];

%prompt='If there are some unassigned pixels, to which class id number do you want to attribute it ? [Default 1]): ';
%defaultclass= input(prompt);
%if numel(defaultclass)==0
defaultclass=1;
%end

% in case of pixels, training data is a list of 3 channels from the
% roi.image matrix with indexed colors
% if there are more input channels, image will be saved as a .mat file.

cltmp=classif.roi;
%disp('Starting parallelized jobs for data formatting....')

warning off all

channel=classif.channelName;

for i=1:numel(rois)

    disp(['Launching ROI ' num2str(rois(i)) ': processing...'])
    
    % find image channel associated with training
    %pixe = strfind(cltmp(i).display.channel, classif.strid);
    cc=cltmp(rois(i)).findChannelID(classif.strid);
    
    if numel(cc)>0
        
        if numel(cltmp(rois(i)).image)==0
            cltmp(rois(i)).load; % load image sequence
        end
        
  
        pix=cltmp(rois(i)).findChannelID(channel);
        % new multichannel mode

    if iscell(pix)
            pix=cell2mat(pix);
    end

%         pix=[];
%         for j=1:numel(channel) % loop on all selected channels
%             pix=[pix cltmp(i).findChannelID(channel{j})];
%         end
        
        % pix=find(cltmp(rois(i)).channelid==classif.channel(1)); % find channel
        im=cltmp(rois(i)).image(:,:,pix,:);
        
%         if numel(pix)==1
%             % 'ok'
%             totphc=im;
%             meanphc=0.5*double(mean(totphc(:)));
%             maxphc=double(meanphc+0.7*(max(totphc(:))-meanphc));
%         end
        
        
        %pixcc=find(cltmp(i).channelid==cc)

        lab=cltmp(rois(i)).image(:,:,cc,:);
        
        labels= double(zeros(size(lab,1),size(lab,2),3,size(lab,4)));
        %   size(labels)
        
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
    reverseStr = '';
    
    for j=1:size(im,4) %time
        tmp=im(:,:,:,j);
        

        %TODO: preProcessROIData(pix,j,param);
        if numel(pix)<=3            
            param=[];

            tmp=cltmp(rois(i)).preProcessROIData(pix,j,param);
        end
        
        %tmp=uint8(256*tmp);
        
        tr=num2str(j);
        while numel(tr)<4
            tr=['0' tr];
        end
        
          if ~strcmp(classif.description{3}{1},'Solov2') % classical labeled image
minval=1;
          else
minval=0;
          end

        if numel(cc)>0
            tmplab=lab(:,:,:,j);
            if max(tmplab(:))>minval % test if image has been manually annotated and remove empty frames

               
                % pads images - the traininer network expects images bigger or
                % equal to 500 x 500.
                % For images smaller than that, image padding is achieved to
                % enlarge it.
                %  exptmp=tmp;
                if numel(pix)<=3
                    imwrite(tmp,[classif.path '/' foldername '/images/' cltmp(rois(i)).id '_frame_' tr '.tif']);
                else % multispectral image
                    save([classif.path '/' foldername '/images/' cltmp(rois(i)).id '_frame_' tr '.mat'],tmp); % WARNING no preprocessing is performed in that case 
                end

                 if ~strcmp(classif.description{3}{1},'Solov2') % classical labeled image
                imwrite(labels(:,:,:,j),[classif.path '/' foldername '/labels/' cltmp(rois(i)).id '_frame_' tr '.tif']);
                 else % specific formatting for solov2
                     boxes=[];
                     imageFile=[classif.path '/' foldername '/images/' cltmp(rois(i)).id '_frame_' tr '.tif'];
                     labels=categorical([]);
        
                     masks=false(size(lab,1:2));

                     nmask=1;
                      for k=1:numel(classif.classes)
                      %    if k==defaultclass %
                      %           pixz=lab(:,:,1,j)==k | lab(:,:,1,j)==0; % WARNING !!!! add unassigned pixels to this class
                      %   else
                                  pixz=lab(:,:,1,j)==k;
                     %     end
                       %  labtmp2=double(zeros(size(lab,1),size(lab,2),1,size(lab,4)));
                       %  labtmp2(pixz)=1;

                  %     figure, imshow(pixz)
                       stats=regionprops(pixz,"BoundingBox");
                       [L n]=bwlabel(pixz);
                       for l=1:n
                            masks(:,:,nmask)=L==l;
                            boxes(nmask,1:4)=stats(l).BoundingBox;
                            labels(nmask)=categorical(classif.classes(k));
                           nmask=nmask+1;
                       end
                      end


                     save([classif.path '/' foldername '/labels/' cltmp(rois(i)).id '_frame_' tr '.mat'],'boxes','imageFile','labels','masks');

                 end

                output=output+1;
            end
        end
        
        msg = sprintf('Processing frame: %d / %d for ROI %s', j, size(im,4),cltmp(rois(i)).id); %Don't forget this semicolon
        fprintf([reverseStr, msg]);
        reverseStr = repmat(sprintf('\b'), 1, length(msg));
    end
    fprintf('\n');
    %  cltmp(rois(i)).save;
    disp(['Processing ROI: ' num2str(rois(i)) ' ... Done !'])
end

warning on all;

for i=rois
    cltmp(i).clear; %%% remove !!!!
end

% saving classification  for training
classiSave(classif);
%save([classif.path '/classification.mat'],'classification');

