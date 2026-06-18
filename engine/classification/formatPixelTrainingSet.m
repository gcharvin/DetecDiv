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

mkdir([classif.path '/' foldername],'images');
mkdir([classif.path '/' foldername],'labels');

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
isDeepLabSemantic = false;
try
    isDeepLabSemantic = isprop(classif, 'classifierPkg') && ...
        strcmpi(char(string(classif.classifierPkg)), 'deeplab_pixel_classification');
catch
end

for i=1:numel(rois)

    disp(['Launching ROI ' num2str(rois(i)) ': processing...'])

    % find image channel associated with training
    %pixe = strfind(cltmp(i).display.channel, classif.strid);

    if strcmp(classif.description{1},'Image pixel regression')
    cc=cltmp(rois(i)).findChannelID(channel{2}); % second channel is used as output
    else
    cc=cltmp(rois(i)).findChannelID(classif.strid); % classical labeled channel
    end

    if numel(cc) == 0
        cltmp(rois(i)).load;
        if strcmp(classif.description{1},'Image pixel regression')
            cc=cltmp(rois(i)).findChannelID(channel{2});
        else
            cc=cltmp(rois(i)).findChannelID(classif.strid);
        end
    end

    if numel(cc) == 0
        disp(['Processing ROI: ' num2str(rois(i)) ' ... Annotation channel not found, skipped.']);
        continue;
    end

    
    if numel(cc)>0

        if numel(cltmp(rois(i)).image)==0
            cltmp(rois(i)).load; % load image sequence
        end


        if strcmp(classif.description{1},'Image pixel regression')
        pix=cltmp(rois(i)).findChannelID(channel{1});
        else
        pix=cltmp(rois(i)).findChannelID(channel);
        % new multichannel mode
        end

        if iscell(pix)
            pix=cell2mat(pix);
        end

        
      

        %         pix=[];
        %         for j=1:numel(channel) % loop on all selected channels
        %             pix=[pix cltmp(i).findChannelID(channel{j})];
        %         end

        maxChannelNeeded = max([pix(:); cc(:)]);
        if maxChannelNeeded > size(cltmp(rois(i)).image, 3)
            cltmp(rois(i)).image = [];
            cltmp(rois(i)).load;
        end

        if maxChannelNeeded > size(cltmp(rois(i)).image, 3)
            warning('Skipping ROI %s: requested channel index %d exceeds loaded image channel count %d.', ...
                char(string(cltmp(rois(i)).id)), maxChannelNeeded, size(cltmp(rois(i)).image, 3));
            continue;
        end

        %         if numel(pix)==1
        %             % 'ok'
        %             totphc=im;
        %             meanphc=0.5*double(mean(totphc(:)));
        %             maxphc=double(meanphc+0.7*(max(totphc(:))-meanphc));
        %         end


        %pixcc=find(cltmp(i).channelid==cc)

        lab=cltmp(rois(i)).image(:,:,cc,:);
        if isDeepLabSemantic && ~any(lab(:) > 0)
            disp(['Processing ROI: ' num2str(rois(i)) ' ... No annotated frame, skipped.']);
            continue;
        end

        % pix=find(cltmp(rois(i)).channelid==classif.channel(1)); % find channel
        im=cltmp(rois(i)).image(:,:,pix,:);

        if strcmp(classif.description{3},'Solov2') % classical labeled image
            %resize images to multile of 32 in case of solov2
            % Load your image
            [M, N, ~] = size(im);

            newM = ceil(M / 32) * 32;
            newN = ceil(N / 32) * 32;

            im= imresize(im, [newM newN]);
            %     lab= imresize(lab, [newM newN]);
            % labels_solo= double(zeros(size(lab,1),size(lab,2),3,size(lab,4)));
        end

        

        if strcmp(classif.description{1},'Image pixel regression')
         %   labels=repmat(lab,1,1,3,1);
        elseif isDeepLabSemantic
            labels = double(zeros(size(lab,1), size(lab,2), 3, size(lab,4)));
            bgColor = classif.colormap(2,:);
            fgColor = classif.colormap(min(3, size(classif.colormap,1)),:);
            fg = lab(:,:,1,:) > 0;
            bg = ~fg;
            for k = 1:3
                labels(:,:,k,:) = labels(:,:,k,:) + double(bg) * bgColor(k);
                labels(:,:,k,:) = labels(:,:,k,:) + double(fg) * fgColor(k);
            end
        else
            labels= double(zeros(size(lab,1),size(lab,2),3,size(lab,4)));

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
    end
    reverseStr = '';

    for j=1:size(im,4) %time
        if strcmp(classif.description{1},'Image pixel regression')
            tmplab = [];
            hasLabeledPixels = true;
        else
            tmplab=lab(:,:,:,j);
            hasLabeledPixels = max(tmplab(:)) > 1;
            if isDeepLabSemantic
                hasLabeledPixels = any(tmplab(:) > 0);
            end
        end

        if ~hasLabeledPixels && ~strcmp(classif.description{3},'Solov2')
            continue;
        end

        tmp=im(:,:,:,j);

        

      %  if strcmp(classif.description{1},'Image pixel regression')
      %  labtmp= lab(:,:,:,j);
      %  end

        %TODO: preProcessROIData(pix,j,param);
        if numel(pix)<=3
            param=[];

            tmp=cltmp(rois(i)).preProcessROIData(pix,j,param);

            % if strcmp(classif.description{3}{1},'Solov2') % classical labeled image
            %     %resize images to multile of 32 in case of solov2
            %     % Load your image
            %     [M, N, ~] = size(tmp);
            % 
            %     newM = ceil(M / 32) * 32;
            %     newN = ceil(N / 32) * 32;
            % 
            %     tmp= imresize(tmp, [newM newN]);
            % end

           

             if strcmp(classif.description{1},'Image pixel regression')
                tmplab= cltmp(rois(i)).preProcessROIData(cc,j,param);
              %  figure, imshow(tmplab(:,:,1,1),[])
             end
        end

        %tmp=uint8(256*tmp);

        tr=num2str(j);
        while numel(tr)<4
            tr=['0' tr];
        end

        %           if ~strcmp(classif.description{3}{1},'Solov2') % classical labeled image
        % minval=1;
        %           else
        % minval=0;
        %           end

        if numel(cc)>0

            if ~strcmp(classif.description{3},'Solov2') % classical labeled image

                if hasLabeledPixels | strcmp(classif.description{1},'Image pixel regression') % image has labeled pixels or is a regression

                    if numel(pix)<=3
                       
                        imwrite(tmp,[classif.path '/' foldername '/images/' cltmp(rois(i)).id '_frame_' tr '.tif']);

                    else % multispectral image
                        save([classif.path '/' foldername '/images/' cltmp(rois(i)).id '_frame_' tr '.mat'],tmp); % WARNING no preprocessing is performed in that case
                    end

                    if strcmp(classif.description{1},'Image pixel regression')
                    imwrite(tmplab,[classif.path '/' foldername '/labels/' cltmp(rois(i)).id '_frame_' tr '.tif']); % raw image
                    else
                    imwrite(labels(:,:,:,j),[classif.path '/' foldername '/labels/' cltmp(rois(i)).id '_frame_' tr '.tif']); % labeled image
                    end
                    output=output+1;

                end

            else % solov2 model + data augmentation

                tmplab=lab(:,:,1,j);

                 if max(tmplab(:))>0 % image has labeled pixels

                  [M, N, ~] = size(tmp);

                newM = ceil(M / 32) * 32;
                newN = ceil(N / 32) * 32;

                tmpstore=tmp;
                tmplabstore=tmplab;

                for jj=1:classif.trainingParam.CNN_augmentation_scale
                
                 tmp=tmpstore;
                 tmplab=tmplabstore;

                if classif.trainingParam.CNN_augmentation_scale>1
                        
                    if rand>0.5
                        tmp= fliplr(tmp);
                        tmplab=fliplr(tmplab);
                    end
                    if rand>0.5
                        tmp= flipud(tmp);
                        tmplab=flipud(tmplab);
                    end

                    if classif.trainingParam.CNN_translation_augmentation
                            ix=randi(size(tmp,2));
                            iy=randi(size(tmp,1));
                            tmp=circshift(tmp,[iy ix]);
                          %  tmp=circshift(tmp,iy,1);
                         %   tmplab=circshift(tmplab,ix,2);
                            tmplab=circshift(tmplab,[iy ix]);
                    end
                end
                
               

                tmp= imresize(tmp, [newM newN]);
               % tmplab= imresize(tmplab, [newM newN]);

                imwrite(tmp,[classif.path '/' foldername '/images/' cltmp(rois(i)).id '_frame_' tr '_aug' num2str(jj) '.tif']);


                   boxes=[];
                    imageFile=[classif.path '/' foldername '/images/' cltmp(rois(i)).id '_frame_' tr '_aug' num2str(jj) '.tif'];
                    labels=categorical([]);

                    masks=false([newM newN 1]);
                    nmask=1;

                    %     figure, imshow(lab(:,:,1,1),[])

                    for k=1:numel(classif.classes)
                        %    if k==defaultclass %
                        %           pixz=lab(:,:,1,j)==k | lab(:,:,1,j)==0; % WARNING !!!! add unassigned pixels to this class
                        %   else
                        pixz=tmplab==k;
                        %     end
                        %  labtmp2=double(zeros(size(lab,1),size(lab,2),1,size(lab,4)));
                        %  labtmp2(pixz)=1;

                        pixz= imresize(pixz, [newM newN]); % resize only logical images, otherwise get anti aliasing effects

                        stats=regionprops(pixz,"BoundingBox","Area");
                        [L n]=bwlabel(pixz);
                        for l=1:n
                          %  stats=regionprops(L==l,"BoundingBox","Area");

                            if stats(l).Area<10
                                continue
                            end

                            masks(:,:,nmask)=L==l;
                            boxes(nmask,1:4)=stats(l).BoundingBox;
                            labels(nmask)=categorical(classif.classes(k));
                            nmask=nmask+1;
                        end
                    end

                    labels=labels';

                    save([classif.path '/' foldername '/labels/' cltmp(rois(i)).id '_frame_' tr '_aug' num2str(jj) '.mat'],'boxes','imageFile','labels','masks');

                output=output+1;
                end

                end
            end




            % if max(tmplab(:))>minval % test if image has been manually annotated and remove empty frames
            % 
            %     % pads images - the traininer network expects images bigger or
            %     % equal to 500 x 500.
            %     % For images smaller than that, image padding is achieved to
            %     % enlarge it.
            %     %  exptmp=tmp;
            %     if numel(pix)<=3
            %         imwrite(tmp,[classif.path '/' foldername '/images/' cltmp(rois(i)).id '_frame_' tr '.tif']);
            % 
            %     else % multispectral image
            %         save([classif.path '/' foldername '/images/' cltmp(rois(i)).id '_frame_' tr '.mat'],tmp); % WARNING no preprocessing is performed in that case
            %     end
            % 
            %     if ~strcmp(classif.description{3}{1},'Solov2') % classical labeled image
            %         imwrite(labels(:,:,:,j),[classif.path '/' foldername '/labels/' cltmp(rois(i)).id '_frame_' tr '.tif']);
            %     else % specific formatting for solov2
            %         boxes=[];
            %         imageFile=[classif.path '/' foldername '/images/' cltmp(rois(i)).id '_frame_' tr '.tif'];
            %         labels=categorical([]);
            % 
            %         masks=false([newM newN 1]);
            %         nmask=1;
            % 
            %         %     figure, imshow(lab(:,:,1,1),[])
            % 
            %         for k=1:numel(classif.classes)
            %             %    if k==defaultclass %
            %             %           pixz=lab(:,:,1,j)==k | lab(:,:,1,j)==0; % WARNING !!!! add unassigned pixels to this class
            %             %   else
            %             pixz=lab(:,:,1,j)==k;
            %             %     end
            %             %  labtmp2=double(zeros(size(lab,1),size(lab,2),1,size(lab,4)));
            %             %  labtmp2(pixz)=1;
            % 
            %             pixz= imresize(pixz, [newM newN]); % resize only logical images, otherwise get anti aliasing effects
            % 
            %             stats=regionprops(pixz,"BoundingBox");
            %             [L n]=bwlabel(pixz);
            %             for l=1:n
            %                 masks(:,:,nmask)=L==l;
            %                 boxes(nmask,1:4)=stats(l).BoundingBox;
            %                 labels(nmask)=categorical(classif.classes(k));
            %                 nmask=nmask+1;
            %             end
            %         end
            %         labels=labels';
            % 
            %         save([classif.path '/' foldername '/labels/' cltmp(rois(i)).id '_frame_' tr '.mat'],'boxes','imageFile','labels','masks');
            % 
            %     end
            % 
            %     output=output+1;
        end

        msg = sprintf('Processing frame: %d / %d for ROI %s', j, size(im,4),cltmp(rois(i)).id); %Don't forget this semicolon
        fprintf([reverseStr, msg]);
        reverseStr = repmat(sprintf('\b'), 1, length(msg));
    end
    fprintf('\n');
   % cltmp(rois(i)).save; %why saving ROIs ? 
    disp(['Processing ROI: ' num2str(rois(i)) ' ... Done !'])
end

warning on all;

for i=rois
    cltmp(i).clear; %%% remove !!!!
end

% saving classification  for training
classiSave(classif);
%save([classif.path '/classification.mat'],'classification');
