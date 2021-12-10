function output=formatPixelTrainingSet(foldername,classif,rois)

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

cltmp=classif.roi;
disp('Starting parallelized jobs for data formatting....')

warning off all

for i=1:numel(rois)
    disp(['Launching ROI ' num2str(rois(i)) :' processing...'])
 

    if numel(cltmp(rois(i)).image)==0
        cltmp(rois(i)).load; % load image sequence
    end
    
    % normalize intensity levels
    pix=find(cltmp(rois(i)).channelid==classif.channel(1)); % find channel
    im=cltmp(rois(i)).image(:,:,pix,:);
    
    if numel(pix)==1
        % 'ok'
        totphc=im;
        meanphc=0.5*double(mean(totphc(:)));
        maxphc=double(meanphc+0.7*(max(totphc(:))-meanphc));
    end
    
    % find image channel associated with training
    %pixe = strfind(cltmp(i).display.channel, classif.strid);
    cc=cltmp(rois(i)).findChannelID(classif.strid);
    
    if numel(cc)>0
        %pixcc=find(cltmp(i).channelid==cc)
        pixcc=cc;
        lab=cltmp(rois(i)).image(:,:,pixcc,:);

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
%         if numel(pix)==1
            %tmp = double(imadjust(tmp,[meanphc/65535 maxphc/65535],[0 1]))/65535;
            tmp = double(imadjust(tmp));
            tmp = double(tmp)/65535; %no intensity adjustment
            tmp=repmat(tmp,[1 1 3]);
            %max(tmp(:))
            %return
%         else
%             tmp=double(tmp)/65535;
%         end
        %tmp=uint8(256*tmp);
        
        tr=num2str(j);
        while numel(tr)<4
            tr=['0' tr];
        end
        
        if numel(cc)>0
            tmplab=lab(:,:,:,j);
            if max(tmplab(:))>1 % test if image has been manually annotated and remove empty frames
                %  'ok'
                % pads images - the traininer network expects images bigger or
                % equal to 500 x 500.
                % For images smaller than that, image padding is achieved to
                % enlarge it.
                %  exptmp=tmp;
                imwrite(tmp,[classif.path '/' foldername '/images/' cltmp(rois(i)).id '_frame_' tr '.tif']);
                imwrite(labels(:,:,:,j),[classif.path '/' foldername '/labels/' cltmp(rois(i)).id '_frame_' tr '.tif']);
                output=output+1;
            end
        end
        
        msg = sprintf('Processing frame: %d / %d for ROI %s', j, size(im,4),cltmp(rois(i)).id); %Don't forget this semicolon
        fprintf([reverseStr, msg]);
        reverseStr = repmat(sprintf('\b'), 1, length(msg));
    end
    fprintf('\n');
    cltmp(rois(i)).save;
    disp(['Processing ROI: ' num2str(rois(i)) ' ... Done !'])
end

warning on all;

for i=rois
    cltmp(i).clear; %%% remove !!!!
end

% saving classification  for training
classiSave(classif);
%save([classif.path '/classification.mat'],'classification');

