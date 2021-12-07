function output=formatPedigreeTrainingSet(foldername,classif,rois)

output=0;

if ~isfolder([classif.path '/' foldername '/images'])
    mkdir([classif.path '/' foldername], 'images');
end

for i=1:numel(classif.classes)
    if ~isfolder([classif.path '/' foldername '/images/' classif.classes{i}])
        mkdir([classif.path '/' foldername '/images'], classif.classes{i});
    end
end

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

%save([classif.path '/options.mat'],'cactivations','imageclassifier','lstmtraining','assemblenet'); % save options to be used in training function
save([classif.path '/options.mat'],'cactivations','lstmtraining','assemblenet','imageclassifier'); % save options to be used in training function


if ~isfolder([classif.path '/' foldername '/timeseries'])
    mkdir([classif.path '/' foldername], 'timeseries');
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
    
   
    
    
       % 'ok'
        %vid=uint8(zeros(size(cltmp(i).image,1),size(cltmp(i).image,2),3,size(cltmp(i).image,4)));
        
        %pixb=numel(cltmp(i).train.(classif.strid).id);
        %pixa=find(cltmp(i).train.(classif.strid).id==0);
        
        if numel(cltmp(i).train.(classif.strid).mother)==0
            disp('Error: ROI has not been annotated');
            continue
        end
        
        if sum(cltmp(i).train.(classif.strid).mother)==0
            disp('Error: ROI has not been annotated');
            continue
        end
       % 'pasok'
     
    
    
   
    
    reverseStr = '';
   
    
    
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
%       
%         
%         tr=num2str(j);
%         while numel(tr)<4
%             tr=['0' tr];
%         end
%         
%         
%        msg = sprintf('Processing frame: %d / %d for ROI %s', j, size(im,4),cltmp(i).id); %Don't forget this semicolon
%        fprintf([reverseStr, msg]);
%        reverseStr = repmat(sprintf('\b'), 1, length(msg));
%     end
%     
%     fprintf('\n');
    
    

        msize=[120 120]; % size of window surrounding the bud
        timespan=[-1:2]; % time span before and after bud emergence
        nrot=20; % number of random rotations added to augment datastore
        mother=cltmp(i).train.(classif.strid).mother;
        reverseStr='';
        
        for k=1:numel(mother)
           if  cltmp(i).train.(classif.strid).mother(k)~=0 % cell has a mother
                
                 % imwrite(imcrop,[classif.path '/' foldername '/images/' classif.classes{clas} '/' cltmp(i).id '_frame_' tr '_obj' num2str(k) '.tif']);
                %im : image 
                
                  pixelchannel2=cltmp(i).findChannelID(classif.strid);
                  pix2=find(cltmp(i).channelid==pixelchannel2);
                
                  im2=cltmp(i).image(:,:,pix2,:); % image for objects and annotated pedigree
                  
                  
                  for ll=1:size(im,4) % find first frame at which it appears;
                     tmp=im2(:,:,1,ll)==k;
                    % k,sum(tmp(:))
                     if sum(tmp(:))~=0
                        fr=ll;
                        break
                     end
                  end
                  
                  frtot=fr+timespan;
                  minet=frtot>=1;
                  frtot=frtot(minet);
                  maxet=frtot<=size(im,4);
                  frtot=frtot(maxet); %  the collection of frame to extract 4D volume
                  
                  
                  
                  % idetify neighbors on the frame of appearance 
                  budBW=im2(:,:,1,fr)==k;
                  dil=imdilate(budBW,strel('Disk',10));
                  totObjects=im2(:,:,1,fr);
                  neighbors=totObjects(dil);
                  neighborsList=setxor(unique(neighbors(:)),[0 k]); % remove background and own cell
                  
                  for mm=1:numel(neighborsList)

                  ccc=1;
                  
                  vid=uint8(zeros(msize(1),msize(2),3,numel(frtot)));
                  
                  %k,aa=cltmp(i).train.(classif.strid).mother(k),frtot
                  pasok=0;
                  
                  for ll=frtot % for each bud , extract images with all possible neighbors %extract 4D volume around bud
                   
                      if ll<fr %image is fixed
                          tmp=im2(:,:,1,fr)==k;
                      else % image moves following the bud
                          tmp=im2(:,:,1,ll)==k;
                      end
                  
                      stat=regionprops(tmp,'Centroid');
                      
                      if numel(stat)==0 % the cell is not present on that frame; quitting collecting 4D data
                          pasok=1;
                          break
                      end
                      
                      ox=round(stat(1).Centroid(1));
                      oy=round(stat(1).Centroid(2));
                      %ll
                      
                      arrx=ox-msize(1)/2:ox+msize(1)/2-1;
                      arry=oy-msize(2)/2:oy+msize(2)/2-1;
                      
                      if ll>=fr
                         
                      l1=im2(:,:,1,ll)==k;
                      l2=im2(:,:,1,ll)==neighborsList(mm);
                      
                      bw= l1 | l2; % bw image with pairs


                      thr=5; % threshold to find regions of image close to neighbor
                      bw1=bwdist(l1).*l2;
                      bw1=bw1<thr & bw1>0;
                      bw2=bwdist(l2).*l1;
                      bw2=bw2<thr & bw2>0;
                      bwtot= bw1 | bw2; % objects in close proximity
                      bwtot=imdilate(bwtot,strel('Disk',3));
                      bw= bw | bwtot; % mask with interestings pairs
                     % bw=imdilate(bw,strel('Disk',20)); % dilate the whole mask a bit
                      
                      else % before bud emerges, takes only the mother into account
                      
                        bw=  im2(:,:,1,ll)==neighborsList(mm);
                     %   bw=imdilate(bw,strel('Disk',20)); % dilate the whole mask a bit
                      end
                    
                      imtmp=uint16(zeros(size(im,1),size(im,2)));
                      imtmp2=im(:,:,1,ll);
                      imtmp(bw)=imtmp2(bw); % image in which only pixells associated with the pair are non zeros
                      
                      imcrop=imtmp(arry,arrx); 
                      imcrop=double(imadjust(imcrop,[meanphc/65535 maxphc/65535],[0 1]))/65535;
                      imcrop=repmat(imcrop,[1 1 3]);
                      
                      %now save image in appropriate folder for googlenet
                      %training 
                      
                      if ll>=fr % dont write image in folder if bud is not present
                          
                      if neighborsList(mm)==mother(k)
                         clas=2; % link class
                      else
                         clas=1; 
                      end
                      
                      imwrite(imcrop,[classif.path '/' foldername '/images/' classif.classes{clas} '/' cltmp(i).id '_frame_' num2str(ll) '_obj_' num2str(k) '_neighbor_' num2str(mm) '.tif']);
                       output=output+1;
                      end
                      
                      %imcrop=im(arry,arrx,1,ll);
                      
                      
                      %imcrop = double(imadjust(imcrop,[meanphc/65535 maxphc/65535],[0 1]))/65535;
                      %imcrop=repmat(imcrop,[1 1 3]);
                      
                     % figure, imshow(uint8(256*imcrop),[]);
                    %  return;
                      vid(:,:,:,ccc)=uint8(256*imcrop);
                      ccc=ccc+1;
                  end
                  
                  if pasok==1 % cell is lost during tracking , go to next cell
                      continue;
                  end
                  
                  
                  
                  % compute angle between mother and daughter link 
%                   tmp1=im2(:,:,1,fr)==k;
%                   tmp2=im2(:,:,1,fr)==cltmp(i).train.(classif.strid).mother(k);
%                   
%                   stat1=regionprops(tmp1,'Centroid');
%                   ox1=round(stat1(1).Centroid(1));
%                   oy1=round(stat1(1).Centroid(2));
%                   
%                   stat2=regionprops(tmp2,'Centroid');
%                   ox2=round(stat2(1).Centroid(1));
%                   oy2=round(stat2(1).Centroid(2));
%                   
%                   %return;
%                   
%                   lab=360*atan2(oy2-oy1,ox2-ox1)/(2*pi);
                  
                  if neighborsList(mm)==mother(k)
                         lab= categorical({classif.classes{2}}); % link class
                      else
                        lab= categorical({classif.classes{1}}); % no link class
                  end
                      
                  deep=[];
                  parsave([classif.path '/' foldername '/timeseries/lstm_labeled_' cltmp(i).id '_cell_' num2str(k) '_neighbor_' num2str(mm)  '.mat'],deep,vid,lab);
                  % saves original video
                 
                  
                  
                  
%                   angle=360*rand(1,nrot);
%                   
%                   for jk=1:nrot % perform random rotation of this 4D volume to augment
%                      
%                       vidtmp=uint8(zeros(size(vid)));
%                       angletmp=angle(jk);
%                       
%                       if lab+angletmp>180
%                          labtmp=lab+angletmp-360; 
%                       else
%                          labtmp=lab+angletmp; 
%                       end
%                       
%                       
%                       for jkl=1:size(vidtmp,4)
% 
%                           vidtmp(:,:,:,jkl)=imrotate(vid(:,:,:,jkl),-angletmp,'crop');
%                           
%                       end
%                       
%                       parsave([classif.path '/' foldername '/timeseries/lstm_labeled_' cltmp(i).id '_cell_' num2str(k) '_rotation_' num2str(jk) '.mat'],deep,vidtmp,labtmp);
%                       
%                      % frtmp=find(frtot==fr);
%                       
%                       
%                  % imtmp=vidtmp(:,:,:,frtmp);
%                   
%                  % size(imtmp)
%                   %figure, imshow(imtmp); hold on;
%                   %line([msize(1)/2 msize(1)/2+ox2-ox1 ],[msize(2)/2 msize(2)/2+oy2-oy1],'Color','r');
%                  % line([msize(1)/2 msize(1)/2+10*cos(2*pi*labtmp/360) ],[msize(2)/2 msize(1)/2+10*sin(2*pi*labtmp/360) ],'Color','g');
%                  % pause
%                  % close
%                   
%                   end
                
                  
                  %fr=find(frtot==fr);
                  %imtmp=vid(:,:,:,fr);
                  
                 % figure, imshow(imtmp); hold on;
                  %line([msize(1)/2 msize(1)/2+ox2-ox1 ],[msize(2)/2 msize(2)/2+oy2-oy1],'Color','r');
                  %line([msize(1)/2 msize(1)/2+10*cos(2*pi*lab/360) ],[msize(2)/2 msize(1)/2+10*sin(2*pi*lab/360) ],'Color','g');
                  %pause
                  %close
                  % angl in degrees
                  
                  end
           end
           msg = sprintf('Pedigree: Processing bud: %d / %d for ROI %s', k, numel(mother),cltmp(i).id); %Don't forget this semicolon
       fprintf([reverseStr, msg]);
       reverseStr = repmat(sprintf('\b'), 1, length(msg));
        end
      
    cltmp(i).save;

    disp(['Processing ROI: ' num2str(i) ' ... Done !'])
end

warning on all;

for i=rois
    cltmp(i).clear; %%% remove !!!!
end


end

function parsave(fname, deep,vid,lab)
eval(['save  '  fname  '  deep vid lab']); 
end


