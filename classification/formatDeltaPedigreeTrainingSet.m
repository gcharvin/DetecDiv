function output= formatDeltaPedigreeTrainingSet(foldername,classif,rois)

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

 prompt = {'SIze of cropped image (square) used for pedigree'};
            dlgtitle = 'Input complementary tracking parameter';
            
            dims = [1 100];
            
            definput = {num2str(imagesize)};%, num2str(inte)};
            answer = inputdlg(prompt,dlgtitle,dims,definput);
            
            if numel(answer)==0
                return;
            else
                imagesize=str2num(answer{1});
                classif.trainingParam.imagesize=imagesize;
                classif.channel=5; %specifies that 5 channels will be used
                %classiSave(classif);
            end

cltmp=classif.roi;

%disp('Starting parallelized jobs for data formatting....')

warning off all

channel=classif.channelName; % list of channels used to generate input image

% channels for delta pedigree 
%ch1 : image at t-1; 
%ch2: imaghe at t; 
%ch3: image at t+1; 
%ch4: seg of target new bud at t; 
%ch5 :seg of all surrounding cells but the new bud 

% output :  labels for target mother cell at t;

% therefore 2 channels are necessary : first is raw image, second is
% tracked cells

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
    
     label1=im2(:,:,1,1);
    memory=zeros(1,max(label1(:))); % array stores the memory of budding times for all cells 
    mothers=cltmp(rois(i)).train.(classif.strid).mother;
    
    for j=2:size(im,4)-1 % stop 1 image bedfore the end
       % fprintf('.')
        tmp1=im(:,:,1,j-1);
        tmp2=im(:,:,1,j);
        tmp3=im(:,:,1,j+1);
        
        
        label1=im2(:,:,1,j-1);
        label2=im2(:,:,1,j);
        
        % get new born cells 
        n1=unique(label1(:)); n1=n1(n1>0);
        n2=unique(label2(:)); n2=n2(n2>0);
        newcells=setdiff(n2,n1);
       % memory(newcells)=0; % assign zero history for new cells
        
        if sum(label2(:))==0
            disp(['No annotation for frame: ' num2str(j+1)]);
            continue
        end
        
        %figure, imshow(tmp1,[]);
        %figure, imshow(tmp2,[]);
        %return;
        if numel(pix)==1
            
            tmp1 = double(imadjust(tmp1,[meanphc/65535 maxphc/65535],[0 1]))/65535;
            tmp1=uint8(256*tmp1);
            tmp2 = double(imadjust(tmp2,[meanphc/65535 maxphc/65535],[0 1]))/65535;
            tmp2=uint8(256*tmp2);
            tmp3 = double(imadjust(tmp3,[meanphc/65535 maxphc/65535],[0 1]))/65535;
            tmp3=uint8(256*tmp3);
            %tmp=repmat(tmp,[1 1 3]);
            
        end
        
        tr=num2str(j);
        while numel(tr)<4
            tr=['0' tr];
        end

        if max(label1(:))==0 % image is not annotated
             disp(['No annotation for frame: ' num2str(j+1)]);
            continue
        end
        
        
        for k=newcells' % loop on all new buds
            
         %   figure, imshow(label2,[]),k
            bw1=label2==k;
            
            if numel(bw1)==0 % this cell number is not present
                continue
            end
            
            if k>length(mothers)
               continue 
            end
            
            if mothers(k)==0 % not assigned
                continue
            end
            
            stat1=regionprops(bw1,'Centroid');
            
            if numel(stat1)==0
                %    disp('found object with no centroid; skipping....');
                continue
            end
            
            % reference of the image
          %  imagesize
            minex=uint16(max(1,round(stat1.Centroid(1))-imagesize/2));
            miney=uint16(max(1,round(stat1.Centroid(2))-imagesize/2));
            
            maxex=uint16(min(size(tmp1,2),round(stat1.Centroid(1))+imagesize/2-1));
            maxey=uint16(min(size(tmp1,1),round(stat1.Centroid(2))+imagesize/2-1));
            
           % maxey-miney+1,maxex-minex+1
            
            tmpcrop=uint8(zeros(maxey-miney+1,maxex-minex+1,5));
            
            tmpcrop(:,:,1)=tmp1(miney:maxey,minex:maxex);
            tmpcrop(:,:,2)=tmp2(miney:maxey,minex:maxex);
            tmpcrop(:,:,3)=tmp3(miney:maxey,minex:maxex);
            
            tmpcrop(:,:,4)=255*uint8(bw1(miney:maxey,minex:maxex));
           
            l= label2;
            l(bw1)=0;  % removes bud from list; 
            l=l(miney:maxey,minex:maxex);
            lmemory=double(l);
      
            for cc=1:max(l(:))
                b=l==cc;
                
                if cc>numel(memory)
                    memory(cc)=0;
                end
                
                lmemory(b)=1; %(memory(cc)+1)./(memory(cc)+1+6); % memory saturates within 6 frames
            end
                
            tmpcrop(:,:,5)=uint8(255*lmemory);
            
            lab=label2==mothers(k); % HERE
            
            lab=lab(miney:maxey,minex:maxex);
            
         %   figure, imshow(lab,[]);
            
            
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
        
         memory=memory+1;
          
        % newcells,mothers
         newcells= newcells( newcells<=numel(mothers));
         news=[newcells' mothers(newcells)];
        
         if numel(news)
         memory(news~=0)=0;
         end
        
     %   if numel(newmothers)
         
       % end
        
       % msg = sprintf('Processing frame: %d / %d for ROI %s', j, size(im,4),cltmp(i).id); %Don't forget this semicolon
      %  fprintf([reverseStr, msg]);
     %   reverseStr = repmat(sprintf('\b'), 1, length(msg));
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

