function output= formatDeltaTrainingSet(foldername,classif,rois,varargin)

Frames=[];

for i=1:numel(varargin)
    if strcmp(varargin{i},'Frames')
        Frames=varargin{i+1};
    end
end

output=0;
if ~isfolder([classif.path '/' foldername '/images'])
    mkdir([classif.path '/' foldername], 'images');
end
if ~isfolder([classif.path '/' foldername '/labels'])
    mkdir([classif.path '/' foldername], 'labels');
end

if isfield(classif.trainingParam,'imagesize')
    imagesize=classif.trainingParam.imagesize;
else
    imagesize=151;
end

prompt = {'SIze of cropped image (square) used for tracking'};
dlgtitle = 'Input complementary tracking parameter';

dims = [1 100];

definput = {num2str(imagesize)};%, num2str(inte)};
answer = inputdlg(prompt,dlgtitle,dims,definput);

if numel(answer)==0
    return;
else
    imagesize=str2num(answer{1});
    classif.trainingParam.imagesize=imagesize;
    classif.trainingParam.tip{end+1}='enter the size of the image to be cut';
    classif.channel=4; %specifies that 4 channels will be used
    classiSave(classif);
end



cltmp=classif.roi;

%disp('Starting parallelized jobs for data formatting....')

warning off all

channel=classif.channelName; % list of channels used to generate input image

% for delta : ch1 : image at t; ch2: seg of target cell at t; ch3: image at
% t+1; ch4 : seg of all cells

% outpur :  labels for target cell at t+1;

% therefore 2 channels are necessary : first is raw image, second is labels
% channel names must be 1) raw image 2) result of segmentation, because
% this routine will take segmentation results as inputs. Labeled images are
% required here just because they are used to generate the ground truth
% data set. 

% labels must be tracked over time to extract cell numbers

%labelchannel=classif.strid; % image that contains the labels

distance_store=[]; % records the distance for 1 cell in 2 successive frames and store it in the classif folder 

for i=1:numel(rois)
    disp(['Launching ROI ' num2str(i) : ' processing...']);

    if numel(cltmp(rois(i)).image)==0
        cltmp(rois(i)).load; % load image sequence
    end

    % normalize intensity levels

    pix=cltmp(rois(i)).findChannelID(channel{1});

    ch=cltmp(rois(i)).channelid;
    obj=cltmp(rois(i));

    cmpt=0;
    if (~isfield(obj.display,'stretchlim') && ~isprop(obj.display,'stretchlim')) || size(obj.display.stretchlim,2)~=numel(obj.channelid)
        cmpt=1;
    else
        for j=1:numel(ch)
            if obj.display.stretchlim(2,ch(j))==0
                cmpt=1;
            end
        end
    end

    if cmpt==1
        disp(['No stretch limits found for ROI ' num2str(obj.id) ', computing them...']);
        obj.computeStretchlim;
    end

    % HERE
  %  i
  %  bb=rois(i)
  %  aa=cltmp(rois(i))

 %size(cltmp(rois(i)).image)

    im=cltmp(rois(i)).image(:,:,pix,:); % raw image
    strchlm=cltmp(rois(i)).display.stretchlim(:,pix);

    %     if numel(pix)==1
    %         'ok'
    %         totphc=im;
    %         meanphc=0.5*double(mean(totphc(:)));
    %         maxphc=double(meanphc+0.7*(max(totphc(:))-meanphc));
    %     end


    %pixelchannel2=cltmp(i).findChannelID(classif.strid);
    pix2=cltmp(rois(i)).findChannelID(classif.strid); %channel{2})
    % label channel
   % strchlm2=cltmp(rois(i)).display.stretchlim(:,pix2);

    % find channel associated with user classified objects
    im2=cltmp(rois(i)).image(:,:,pix2,:);

    %  if max(im2(:))>1 % check if bw image is encoded between levels 0 and 1 or 1 and 2
    %  im2=im2-1;
    % end

    %figure, imshow(im2(:,:,1,1),[]);

    reverseStr = '';

    if numel(Frames)==0
        fra=1:size(im,4)-1;
    else
        fra=Frames(1:end-1);
    end

    ccc=1;
    for j=fra % stop 1 image bedfore the end
        %j
        tmp1=im(:,:,1,j);
        tmp2=im(:,:,1,j+1);

        % images must be labeled already = ground truth , otherwise no
        % training set can be made
        label1=im2(:,:,1,j);
        label2=im2(:,:,1,j+1);

        %         if max(label1(:))==1 % bw image or image with no pattern
        %             if min(label1(:))==0 % bw image
        %                      label1=bwlabel(label1);
        %                      label2=bwlabel(label2);
        %             else %there is no contour , continue
        %                     continue
        %             end
        %         end
        %         if max(label1(:))==2 % segmented image or labeled imaged
        %                    if min(label1(:))==1 % segmented image
        %                             label1=bwlabel(label1-1);
        %                             label2=bwlabel(label2-1);
        %                          %   'ok'
        %                    else
        % % indexed image, do nothing
        %                    end
        %         end


        if sum(label2(:))==0
            continue
        end

        %figure, imshow(tmp1,[]);
        %figure, imshow(tmp2,[]);
        %return;
        if numel(pix)==1

            tmp1 = double(imadjust(tmp1,[strchlm(1) strchlm(2)],[0 1]))/65535;
            tmp1=uint8(256*tmp1);
            tmp2 = double(imadjust(tmp2,[strchlm(1) strchlm(2)],[0 1]))/65535;
            tmp2=uint8(256*tmp2);

          
            %tmp=repmat(tmp,[1 1 3]);

        end

        tr=num2str(j);
        while numel(tr)<4
            tr=['0' tr];
        end

        % labelout
        %l1=bwlabel(label1);
        %l2=bwlabel(label2);

        if max(label1(:))==0 % image is not annotated
            continue
        end

        for k=1:max(label1(:))% loop on all present objects

            bw1=label1==k;

            if numel(bw1)==0 % this cell number is not present
                continue
            end

            stat1=regionprops(bw1,'Centroid','Area');

            if numel(stat1)==0
                %    disp('found object with no centroid; skipping....');
                continue
            end

            if stat1.Area< 200 % object is too small
                continue
            end

            % reference of the image
            % stat1

            %     try
            minex=uint16(max(1,round(stat1.Centroid(1))-imagesize/2));
            miney=uint16(max(1,round(stat1.Centroid(2))-imagesize/2));

            %             catch
            %                 figure,imshow(bw1,[])
            %                 figure,imshow(label1,[])
            %
            %                 return
            %             end

            maxex=uint16(min(size(tmp1,2),round(stat1.Centroid(1))+imagesize/2-1));
            maxey=uint16(min(size(tmp1,1),round(stat1.Centroid(2))+imagesize/2-1));

            tmpcrop=uint8(zeros(maxey-miney+1,maxex-minex+1,4));

            tmpcrop(:,:,1)=tmp1(miney:maxey,minex:maxex);
            tmpcrop(:,:,2)=255*uint8(bw1(miney:maxey,minex:maxex));
            tmpcrop(:,:,3)=tmp2(miney:maxey,minex:maxex);
            tmpcrop(:,:,4)=255*uint8((label2(miney:maxey,minex:maxex))>0);
          

            lab=label2==k;

            stat2=regionprops(lab,'Centroid');

            if numel(stat2)==0
                continue
            end

            dist = sqrt( (stat1.Centroid(1)-stat2.Centroid(1)).^2+ (stat1.Centroid(2)-stat2.Centroid(2)).^2);

            if dist > 100 % objects moves too much, probably mistracked 
                    continue; 
            end

            distance_store=[ distance_store dist];
            
            lab=lab(miney:maxey,minex:maxex);

         %   figure, imshow(lab,[])
            

            labels= double(zeros(size(lab,1),size(lab,2),3));
            %   size(labels)

            for cc=1:numel(classif.classes)
                %  if cc==1 %
                %       pixz=lab==cc | lab=; % WARNING !!!! add unassigned pixels to this class
                %   else
                pixz=lab==cc-1;
                %   end

                labtmp2=double(zeros(size(lab,1),size(lab,2),1));
                labtmp2(pixz)=1;
                %  figure, imshow(labtmp2);
                for  ck=1:3
                    labels(:,:,ck)=labels(:,:,ck)+classif.colormap(cc+1,ck)*labtmp2;
                end
            end

            %   figure, imshow(labels);
            %    return;
            output=output+1;

            pth=fullfile(classif.path,foldername,[ 'images/' cltmp(rois(i)).id '_frame_' tr '_object' num2str(k) '.mat']);

            save(pth,'tmpcrop');

            pth=fullfile(classif.path,foldername,[ 'labels/' cltmp(rois(i)).id '_frame_' tr '_object' num2str(k) '.tif']);

            imwrite(labels,pth);

        end

        msg = sprintf('Processing frame: %d / %d for ROI %s', ccc, numel(fra),cltmp(rois(i)).id); %Don't forget this semicolon
        fprintf([reverseStr, msg]);
        reverseStr = repmat(sprintf('\b'), 1, length(msg));
        ccc=ccc+1;
    end


    fprintf('\n');


    cltmp(i).save;

    disp(['Processing ROI: ' num2str(i) ' ... Done !'])
end

hh=histogram(distance_store); % displays the distribution of distances between objects
 pth=fullfile(classif.path,foldername,'distances.pdf');
exportgraphics(hh,pth)


warning on all;

for i=rois
    cltmp(i).clear; %%% remove !!!!
end

end

