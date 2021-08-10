function formatDataForTraining(classif) %mov,trapsid,option)
% saves user annotated data to disk- works for Image, Pixel and LSTM
% classification



str=fullfile(classif.path,'trainingParam.mat');
if exist(str)
load(str);
else
    disp('There are not training parameters defined yet: first use the classif.setTrainingParam function !');
    return;
end

disp('Saving user training to disk...');
%classif=obj.processing.classification(classiid);
category=classif.category;
category=category{1};

foldername='trainingdataset';

% remove and recreates all directoires
% mk folder to store ground user trained data

if isfolder([classif.path '/' foldername])
    try
        rmdir([classif.path '/' foldername], 's')
    catch
        disp('Error: did not manage to remove directory !');
    end
end
mkdir(classif.path,foldername)

rois=trainingParam.rois;
% if nargin<3
% rois=1:numel(classif.roi);
% else
%  rois=option ;  
% end


switch category
    case 'Image'
        formatImageTrainingSet(foldername,classif,rois)    
    case 'LSTM'
        formatLSTMTrainingSet(foldername,classif,rois)
    case 'Pixel'
        formatPixelTrainingSet(foldername,classif,rois)
    case 'Object'
        formatObjectTrainingSet(foldername,classif,rois)
    case 'Pedigree'
        formatPedigreeTrainingSet(foldername,classif,rois) 
    case 'Tracking'
        formatTrackingTrainingSet(foldername,classif,rois) 
    case 'Timeseries'
        formatTimeseriesTrainingSet(foldername,classif,rois)  
end




% 
% if strcmp(category,'Image') || strcmp(category,'LSTM') || strcmp(category,'Object') || strcmp(category,'Pedigree')
%   
%         if ~isfolder([classif.path '/' foldername '/images'])
%             mkdir([classif.path '/' foldername], 'images');
%         end
% 
%         for i=1:numel(classif.classes)
%             if ~isfolder([classif.path '/' foldername '/images/' classif.classes{i}])
%                 mkdir([classif.path '/' foldername '/images'], classif.classes{i});
%             end
%         end
% end


% defaultclass=[];
% if strcmp(category,'Pixel')
% 
%         mkdir([classif.path '/' foldername],'images')
%         mkdir([classif.path '/' foldername],'labels')
%         
%          prompt='If there are some unassigned pixels, to which class id number do you want to attribute it ? [Default 1]): ';
% defaultclass= input(prompt);
% if numel(defaultclass)==0
%     defaultclass=1;
% end
% 
%         % in case of pixels, training data is a list of 3 channels from the
%         % roi.image matrix with indexed colors
% end  
        
% if strcmp(category,'Pedigree')
%     
%     if nargin<3
%      prompt='Train googlenet image classifier ? (y / n [Default y]): ';
%  imageclassifier= input(prompt,'s');
%  if numel(imageclassifier)==0
%      imageclassifier='y';
%  end
% 
%  prompt='Compute activation for google net ? (y / n [Default y]): ';
% cactivations= input(prompt,'s');
% if numel(cactivations)==0
%     cactivations='y';
% end
% 
%  prompt='Train LSTM network ? (y/n [Default y]): ';
% lstmtraining= input(prompt,'s');
% if numel(lstmtraining)==0
%    lstmtraining='y';
% end
% 
%  prompt='Assemble full network ? (y/n [Default y] ): ';
% assemblenet= input(prompt,'s');
% if numel(assemblenet)==0
%     assemblenet='y';
% end
% 
% %  prompt='Validate training data ? (y [Default y]/ n ): ';
% % assemblenet= input(prompt,'s');
% % if numel(assemblenet)==0
% %     validation='y';
% % end
% 
% %save([classif.path '/options.mat'],'cactivations','imageclassifier','lstmtraining','assemblenet'); % save options to be used in training function
% save([classif.path '/options.mat'],'cactivations','lstmtraining','assemblenet','imageclassifier'); % save options to be used in training function
%     end
%     
%      if ~isfolder([classif.path '/' foldername '/timeseries'])
%             mkdir([classif.path '/' foldername], 'timeseries');
%      end
%         
% end


% if strcmp(category,'LSTM')
%     if nargin<3
%     prompt='Train googlenet image classifier ? (y / n [Default y]): ';
% imageclassifier= input(prompt,'s');
% if numel(imageclassifier)==0
%     imageclassifier='y';
% end
% 
%  prompt='Compute activation for google net ? (y / n [Default y]): ';
% cactivations= input(prompt,'s');
% if numel(cactivations)==0
%     cactivations='y';
% end
% 
%  prompt='Train LSTM network ? (y/n [Default y]): ';
% lstmtraining= input(prompt,'s');
% if numel(lstmtraining)==0
%    lstmtraining='y';
% end
% 
%  prompt='Assemble full network ? (y/n [Default y] ): ';
% assemblenet= input(prompt,'s');
% if numel(assemblenet)==0
%     assemblenet='y';
% end
% 
% %  prompt='Validate training data ? (y [Default y]/ n ): ';
% % assemblenet= input(prompt,'s');
% % if numel(assemblenet)==0
% %     validation='y';
% % end
% 
% save([classif.path '/options.mat'],'cactivations','imageclassifier','lstmtraining','assemblenet'); % save options to be used in training function
%     end
%     
%      if ~isfolder([classif.path '/' foldername '/timeseries'])
%             mkdir([classif.path '/' foldername], 'timeseries');
%      end
%         
% end



% look on all ROIs

% if nargin<3
% rois=1:numel(classif.roi);
% else
%  rois=option ;  
% end


% cltmp=classif.roi; 
% 
% disp('Starting parallelized jobs for data formatting....')
% 
% warning off all
% parfor i=rois
%     disp(['Launching ROI ' num2str(i) :' processing...'])
%     
%     
%     if numel(cltmp(i).image)==0
%         cltmp(i).load; % load image sequence
%     end
%     
%   
%     % normalize intensity levels
%     pix=find(cltmp(i).channelid==classif.channel(1)); % find channel
%     im=cltmp(i).image(:,:,pix,:);
%     
%     if numel(pix)==1
%         % 'ok'
%         totphc=im;
%         meanphc=0.5*double(mean(totphc(:)));
%         maxphc=double(meanphc+0.7*(max(totphc(:))-meanphc));
%     end
%     
%     if strcmp(category,'LSTM')
%        % 'ok'
%         vid=uint8(zeros(size(cltmp(i).image,1),size(cltmp(i).image,2),3,size(cltmp(i).image,4)));
%         
%         pixb=numel(cltmp(i).train.(classif.strid).id);
%         pixa=find(cltmp(i).train.(classif.strid).id==0);
%         
%         if numel(pixa)>0 || numel(pixa)==0 && pixb==0 % some images are not labeled, quitting ...
%             disp('Error: some images are not labeled in this ROI - LSTM requires all images to be labeled in the timeseries!');
%             continue
%         end
%        % 'pasok'
%     end
%     
%      if strcmp(category,'Pedigree')% test if ROI has been annotated
%        % 'ok'
%         %vid=uint8(zeros(size(cltmp(i).image,1),size(cltmp(i).image,2),3,size(cltmp(i).image,4)));
%         
%         %pixb=numel(cltmp(i).train.(classif.strid).id);
%         %pixa=find(cltmp(i).train.(classif.strid).id==0);
%         
%         if numel(cltmp(i).train.(classif.strid).mother)==0
%             disp('Error: ROI has not been annotated');
%             continue
%         end
%         
%         if sum(cltmp(i).train.(classif.strid).mother)==0
%             disp('Error: ROI has not been annotated');
%             continue
%         end
%        % 'pasok'
%      end
%     
%     
%     if strcmp(category,'Pixel') % get the training data for pixel classification
%         
%         % find image channel associated with training
%         %pixe = strfind(cltmp(i).display.channel, classif.strid);
%         cc=cltmp(i).findChannelID(classif.strid);
%         
%         if numel(cc)>0
%         pixcc=find(cltmp(i).channelid==cc);
%         
%         lab=cltmp(i).image(:,:,pixcc,:);
%         
%         % changes from here
% % %         lab=lab>1; % takes only the second class into account
% % %         lab=~lab;
% % %         dist= double(zeros(size(lab,1),size(lab,2),1,size(lab,4)));
% % %         
% % %         for k=1:size(dist,4)
% % %             dist(:,:,1,k)=round(bwdist(lab(:,:,1,k))/2); % distance transform
% % %         end
% % %         
% % %          % distance transform
% % %         
% % %         labels= double(zeros(size(lab,1),size(lab,2),3,size(lab,4)));
% % %        
% % %         
% % %         for j=1:numel(classif.classes)
% % %             
% % %             switch j
% % %                 case numel(classif.classes) % las class contains all
% % %             pixz=dist(:,:,1,:)>=j-1 % WARNING !!!! add unassigned pixels to this class
% % %          
% % %                 case 1
% % %             pixz=dist(:,:,1,:)==0;   
% % %             
% % %                 otherwise
% % %             pixz=dist(:,:,1,:)==j-1;       
% % %             
% % %             end
% % %             
% % %             labtmp2=double(zeros(size(lab,1),size(lab,2),1,size(lab,4)));
% % %             labtmp2(pixz)=1;
% % %             
% % %             for  k=1:3
% % %                 labels(:,:,k,:)=labels(:,:,k,:)+classif.colormap(j+1,k)*labtmp2;
% % %             end
% % %             
% % %         end
% 
% 
%  %       % to here 
%         
% %         
%         labels= double(zeros(size(lab,1),size(lab,2),3,size(lab,4)));
%        
%         
%         for j=1:numel(classif.classes)
%             
%             if j==defaultclass % 
%             pixz=lab(:,:,1,:)==j | lab(:,:,1,:)==0; % WARNING !!!! add unassigned pixels to this class
%             else
%             pixz=lab(:,:,1,:)==j;   
%             end
%             
%             labtmp2=double(zeros(size(lab,1),size(lab,2),1,size(lab,4)));
%             labtmp2(pixz)=1;
%             
%             for  k=1:3
%                 labels(:,:,k,:)=labels(:,:,k,:)+classif.colormap(j+1,k)*labtmp2;
%             end
%             
%         end
%         end  
%     end
%     
%     if strcmp(category,'Image') || strcmp(category,'LSTM')
%       % classif
%       % cltmp(i)
%         lab= categorical(cltmp(i).train.(classif.strid).id,1:numel(classif.classes),classif.classes); % creates labels for classification
%            
%     end
%     
%     reverseStr = '';
%     
%     if strcmp(category,'Object')
%     pixelchannel2=cltmp(i).findChannelID(classif.strid);
%     pix2=find(cltmp(i).channelid==pixelchannel2);
%                 
%     % find channel associated with user classified objects
%     im2=cltmp(i).image(:,:,pix2,:);
%     end
%     
%     
%     for j=1:size(im,4)
%         tmp=im(:,:,:,j);
%         
%         if numel(pix)==1
%             
%             tmp = double(imadjust(tmp,[meanphc/65535 maxphc/65535],[0 1]))/65535;
%             tmp=repmat(tmp,[1 1 3]);
%             
%             
%             %max(tmp(:))
%             %return
%         end
%         
%         if strcmp(category,'Pixel')
%             %tmp=uint8(256*tmp);
%             
%         end
%         
%         if strcmp(category,'LSTM')
%             vid(:,:,:,j)=uint8(256*tmp);
%         end
%         % figure, imshow(im,[])
%         % return;
%         
%         tr=num2str(j);
%         while numel(tr)<4
%             tr=['0' tr];
%         end
%         
%         if strcmp(category,'Image') || strcmp(category,'LSTM')
%             if cltmp(i).train.(classif.strid).id(j)~=0 % if training is done
%                 % if ~isfile([str '/unbudded/im_' mov.trap(i).id '_frame_' tr '.tif'])
%                 imwrite(tmp,[classif.path '/' foldername '/images/' classif.classes{cltmp(i).train.(classif.strid).id(j)} '/' cltmp(i).id '_frame_' tr '.tif']);
%                 % end
%             end
%         end
%         
%           if strcmp(category,'Object') 
%             %if cltmp(i).train.(classif.strid).id(j)~=0 % if training is done
%                 % if ~isfile([str '/unbudded/im_' mov.trap(i).id '_frame_' tr '.tif'])
%                 %make a loop on all objects of each image
%                 labeledobjects=im2(:,:,:,j);
%                 
%                 if max(labeledobjects(:))==0 % image is not annotated
%                     continue
%                 end
%                 
%                
%                 [l no]=bwlabel(labeledobjects>0);
%                  pr=regionprops(l,'BoundingBox');
%                 
%                 for k=1:no % loop on all present objects
%                     
%                     bw=l==k;
%                     
%                   %  if j==16
%                     bbox=round(pr(k).BoundingBox);
%                     clas=round(mean(labeledobjects(bw)));
%                     
%                     imcrop=tmp(bbox(2):bbox(2)+bbox(4),bbox(1):bbox(1)+bbox(3),:);
%                     
%                    % figure, imshow(imcrop,[]);
%                    % figure, imshow(tmp,[]);
%                      imwrite(imcrop,[classif.path '/' foldername '/images/' classif.classes{clas} '/' cltmp(i).id '_frame_' tr '_obj' num2str(k) '.tif']);
%                 %    end
%                     
%                     
%                 end
%                 
%                  % end
%             %end
%           end
%         
%         
%         if strcmp(category,'Pixel')
%             if numel(cc)>0
%             tmplab=lab(:,:,:,j);
%             if max(tmplab(:))>0 % test if image has been manually annotated
%            %  'ok'
%            
%            % pads images - the traininer network expects images bigger or
%            % equal to 500 x 500. 
%            % For images smaller than that, image padding is achieved to
%            % enlarge it. 
%            
%          %  exptmp=tmp;
%            
% 
%            
%                 imwrite(tmp,[classif.path '/' foldername '/images/' cltmp(i).id '_frame_' tr '.tif']);
%                 
%                 imwrite(labels(:,:,:,j),[classif.path '/' foldername '/labels/' cltmp(i).id '_frame_' tr '.tif']);
%                 
%                 
%             end
%             end
%         end
%         
%        msg = sprintf('Processing frame: %d / %d for ROI %s', j, size(im,4),cltmp(i).id); %Don't forget this semicolon
%        fprintf([reverseStr, msg]);
%        reverseStr = repmat(sprintf('\b'), 1, length(msg));
%     end
%     
%     fprintf('\n');
%     
%     
%     
%     if strcmp(category,'LSTM')
%         deep=cltmp(i).train.(classif.strid).id;
%         parsave([classif.path '/' foldername '/timeseries/lstm_labeled_' cltmp(i).id '.mat'],deep,vid,lab);
%     end
%     
%     if strcmp(category,'Pedigree') %loop on all newly created objects, check if they have a mother assigned and save
%     
%         msize=[120 120]; % size of window surrounding the bud
%         timespan=[-1:2]; % time span before and after bud emergence
%         nrot=20; % number of random rotations added to augment datastore
%         mother=cltmp(i).train.(classif.strid).mother;
%         reverseStr='';
%         
%         for k=1:numel(mother)
%            if  cltmp(i).train.(classif.strid).mother(k)~=0 % cell has a mother
%                 
%                  % imwrite(imcrop,[classif.path '/' foldername '/images/' classif.classes{clas} '/' cltmp(i).id '_frame_' tr '_obj' num2str(k) '.tif']);
%                 %im : image 
%                 
%                   pixelchannel2=cltmp(i).findChannelID(classif.strid);
%                   pix2=find(cltmp(i).channelid==pixelchannel2);
%                 
%                   im2=cltmp(i).image(:,:,pix2,:); % image for objects and annotated pedigree
%                   
%                   
%                   for ll=1:size(im,4) % find first frame at which it appears;
%                      tmp=im2(:,:,1,ll)==k;
%                     % k,sum(tmp(:))
%                      if sum(tmp(:))~=0
%                         fr=ll;
%                         break
%                      end
%                   end
%                   
%                   frtot=fr+timespan;
%                   minet=frtot>=1;
%                   frtot=frtot(minet);
%                   maxet=frtot<=size(im,4);
%                   frtot=frtot(maxet); %  the collection of frame to extract 4D volume
%                   
%                   
%                   
%                   % idetify neighbors on the frame of appearance 
%                   budBW=im2(:,:,1,fr)==k;
%                   dil=imdilate(budBW,strel('Disk',10));
%                   totObjects=im2(:,:,1,fr);
%                   neighbors=totObjects(dil);
%                   neighborsList=setxor(unique(neighbors(:)),[0 k]); % remove background and own cell
%                   
%                   for mm=1:numel(neighborsList)
% 
%                   ccc=1;
%                   
%                   vid=uint8(zeros(msize(1),msize(2),3,numel(frtot)));
%                   
%                   %k,aa=cltmp(i).train.(classif.strid).mother(k),frtot
%                   pasok=0;
%                   
%                   for ll=frtot % for each bud , extract images with all possible neighbors %extract 4D volume around bud
%                    
%                       if ll<fr %image is fixed
%                           tmp=im2(:,:,1,fr)==k;
%                       else % image moves following the bud
%                           tmp=im2(:,:,1,ll)==k;
%                       end
%                   
%                       stat=regionprops(tmp,'Centroid');
%                       
%                       if numel(stat)==0 % the cell is not present on that frame; quitting collecting 4D data
%                           pasok=1;
%                           break
%                       end
%                       
%                       ox=round(stat(1).Centroid(1));
%                       oy=round(stat(1).Centroid(2));
%                       %ll
%                       
%                       arrx=ox-msize(1)/2:ox+msize(1)/2-1;
%                       arry=oy-msize(2)/2:oy+msize(2)/2-1;
%                       
%                       if ll>=fr
%                          
%                       l1=im2(:,:,1,ll)==k;
%                       l2=im2(:,:,1,ll)==neighborsList(mm);
%                       
%                       bw= l1 | l2; % bw image with pairs
% 
% 
%                       thr=5; % threshold to find regions of image close to neighbor
%                       bw1=bwdist(l1).*l2;
%                       bw1=bw1<thr & bw1>0;
%                       bw2=bwdist(l2).*l1;
%                       bw2=bw2<thr & bw2>0;
%                       bwtot= bw1 | bw2; % objects in close proximity
%                       bwtot=imdilate(bwtot,strel('Disk',3));
%                       bw= bw | bwtot; % mask with interestings pairs
%                      % bw=imdilate(bw,strel('Disk',20)); % dilate the whole mask a bit
%                       
%                       else % before bud emerges, takes only the mother into account
%                       
%                         bw=  im2(:,:,1,ll)==neighborsList(mm);
%                      %   bw=imdilate(bw,strel('Disk',20)); % dilate the whole mask a bit
%                       end
%                     
%                       imtmp=uint16(zeros(size(im,1),size(im,2)));
%                       imtmp2=im(:,:,1,ll);
%                       imtmp(bw)=imtmp2(bw); % image in which only pixells associated with the pair are non zeros
%                       
%                       imcrop=imtmp(arry,arrx); 
%                       imcrop=double(imadjust(imcrop,[meanphc/65535 maxphc/65535],[0 1]))/65535;
%                       imcrop=repmat(imcrop,[1 1 3]);
%                       
%                       %now save image in appropriate folder for googlenet
%                       %training 
%                       
%                       if ll>=fr % dont write image in folder if bud is not present
%                           
%                       if neighborsList(mm)==mother(k)
%                          clas=2; % link class
%                       else
%                          clas=1; 
%                       end
%                       
%                       imwrite(imcrop,[classif.path '/' foldername '/images/' classif.classes{clas} '/' cltmp(i).id '_frame_' num2str(ll) '_obj_' num2str(k) '_neighbor_' num2str(mm) '.tif']);
%                       end
%                       
%                       %imcrop=im(arry,arrx,1,ll);
%                       
%                       
%                       %imcrop = double(imadjust(imcrop,[meanphc/65535 maxphc/65535],[0 1]))/65535;
%                       %imcrop=repmat(imcrop,[1 1 3]);
%                       
%                      % figure, imshow(uint8(256*imcrop),[]);
%                     %  return;
%                       vid(:,:,:,ccc)=uint8(256*imcrop);
%                       ccc=ccc+1;
%                   end
%                   
%                   if pasok==1 % cell is lost during tracking , go to next cell
%                       continue;
%                   end
%                   
%                   
%                   
%                   % compute angle between mother and daughter link 
% %                   tmp1=im2(:,:,1,fr)==k;
% %                   tmp2=im2(:,:,1,fr)==cltmp(i).train.(classif.strid).mother(k);
% %                   
% %                   stat1=regionprops(tmp1,'Centroid');
% %                   ox1=round(stat1(1).Centroid(1));
% %                   oy1=round(stat1(1).Centroid(2));
% %                   
% %                   stat2=regionprops(tmp2,'Centroid');
% %                   ox2=round(stat2(1).Centroid(1));
% %                   oy2=round(stat2(1).Centroid(2));
% %                   
% %                   %return;
% %                   
% %                   lab=360*atan2(oy2-oy1,ox2-ox1)/(2*pi);
%                   
%                   if neighborsList(mm)==mother(k)
%                          lab= categorical({classif.classes{2}}); % link class
%                       else
%                         lab= categorical({classif.classes{1}}); % no link class
%                   end
%                       
%                   deep=[];
%                   parsave([classif.path '/' foldername '/timeseries/lstm_labeled_' cltmp(i).id '_cell_' num2str(k) '_neighbor_' num2str(mm)  '.mat'],deep,vid,lab);
%                   % saves original video
%                  
%                   
%                   
%                   
% %                   angle=360*rand(1,nrot);
% %                   
% %                   for jk=1:nrot % perform random rotation of this 4D volume to augment
% %                      
% %                       vidtmp=uint8(zeros(size(vid)));
% %                       angletmp=angle(jk);
% %                       
% %                       if lab+angletmp>180
% %                          labtmp=lab+angletmp-360; 
% %                       else
% %                          labtmp=lab+angletmp; 
% %                       end
% %                       
% %                       
% %                       for jkl=1:size(vidtmp,4)
% % 
% %                           vidtmp(:,:,:,jkl)=imrotate(vid(:,:,:,jkl),-angletmp,'crop');
% %                           
% %                       end
% %                       
% %                       parsave([classif.path '/' foldername '/timeseries/lstm_labeled_' cltmp(i).id '_cell_' num2str(k) '_rotation_' num2str(jk) '.mat'],deep,vidtmp,labtmp);
% %                       
% %                      % frtmp=find(frtot==fr);
% %                       
% %                       
% %                  % imtmp=vidtmp(:,:,:,frtmp);
% %                   
% %                  % size(imtmp)
% %                   %figure, imshow(imtmp); hold on;
% %                   %line([msize(1)/2 msize(1)/2+ox2-ox1 ],[msize(2)/2 msize(2)/2+oy2-oy1],'Color','r');
% %                  % line([msize(1)/2 msize(1)/2+10*cos(2*pi*labtmp/360) ],[msize(2)/2 msize(1)/2+10*sin(2*pi*labtmp/360) ],'Color','g');
% %                  % pause
% %                  % close
% %                   
% %                   end
%                 
%                   
%                   %fr=find(frtot==fr);
%                   %imtmp=vid(:,:,:,fr);
%                   
%                  % figure, imshow(imtmp); hold on;
%                   %line([msize(1)/2 msize(1)/2+ox2-ox1 ],[msize(2)/2 msize(2)/2+oy2-oy1],'Color','r');
%                   %line([msize(1)/2 msize(1)/2+10*cos(2*pi*lab/360) ],[msize(2)/2 msize(1)/2+10*sin(2*pi*lab/360) ],'Color','g');
%                   %pause
%                   %close
%                   % angl in degrees
%                   
%                   end
%            end
%            msg = sprintf('Pedigree: Processing bud: %d / %d for ROI %s', k, numel(mother),cltmp(i).id); %Don't forget this semicolon
%        fprintf([reverseStr, msg]);
%        reverseStr = repmat(sprintf('\b'), 1, length(msg));
%         end
%         
%     end
%     
%     cltmp(i).save;
% 
%     disp(['Processing ROI: ' num2str(i) ' ... Done !'])
% end
% 
% warning on all;
% 
% for i=rois
%     cltmp(i).clear; %%% remove !!!!
% end
% 
% if strcmp(category,'Pixel') % saving classification  for training
%         classification=classif;
%         
%         save([classif.path '/classification.mat'],'classification');
% end
% end
% 
% function parsave(fname, deep,vid,lab)
% eval(['save  '  fname  '  deep vid lab']); 
% end




