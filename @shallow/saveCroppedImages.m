function saveCroppedImages(obj,varargin)

% writes ROIs and applies XY drift correction
% cut all frames into small pieces to prevent out of memeoy :

% loop on groups of frames --> loading raw images for designated frames
% into memory
% loop on fov
% parfor on rois

disp('Processing raw images. Wait....');

frames=[];
fovid=1:numel(obj.fov); % All FOVs will be processed
cut=20;
%channelint=ones(1,numel(obj.fov(1).srclist));
 
for i=1:numel(varargin)
    if strcmp(varargin{i},'frames') % frames to be processed
        frames=varargin{i+1};
    end
    
     if strcmp(varargin{i},'fov') % list of fov to be prepared
        fovid=varargin{i+1};
     end
    
      if strcmp(varargin{i},'cut') % number of frames loaded at once to prepare ROI matrices
        cut=varargin{i+1};
      end
    
   %       if strcmp(varargin{i},'channelint') % frames interval
   %     channelint=varargin{i+1};
   %   end
end
% first creat independent fov indentical to obj.fov

tmpfov=fov;
for i=fovid
    tmpfov(i)=obj.fov(i);
    %tmpfov(i)=propValues(tmpfov(i),obj.fov(i));
end

strpath=[obj.io.path obj.io.file];


for i=fovid
    
    if numel(tmpfov(i).roi)==0
        disp('this FOV has no ROI ! Quitting ....');
        %break
        %return
        continue
    end
    if numel(tmpfov(i).roi(1).id)==0
        disp('this FOV has no ROI ! Quitting ....');
        %break
        continue
        %return;
    end
    
    if numel(frames)==0
        nframes=1:tmpfov(i).frames; %numel(tmpfov(i).srclist{1}); % take the number of frames from the image list
    else
        nframes=frames;   % specify a number of images to be applied to all FOVs
    end
    
    % find the number of arrays
    framecell={}; % a cell array that specfifes how to porcess the frames
    
    
    % cutting frames loading into small pieces 
    
    narr= floor(numel(nframes)/cut);
    id=1:narr*cut;
    id=reshape(id,cut,[]);
    
    for iii=1:narr
        framecell{iii}= nframes(id(:,iii));
    end
    
    nrest=mod(numel(nframes),cut);
    if nrest>0
        framecell{end+1}=nframes(narr*cut+1:end);
    end
    
    nframestot=nframes;
    
    % % create fov specific directory
    %
    
    if ~exist(fullfile(strpath,tmpfov(i).id),'dir')
        mkdir(strpath,tmpfov(i).id);
    end
 
    disp('loading reference image to perform XY alignment');
    
    refframe=framecell{1}(1);
    refframeid=refframe;
    refimage=tmpfov(i).readImage(refframe,1);
    
    disp('Loading raw images in memory ....');
    
    for ii=1:numel(framecell) % loop on all blocks of frames on a given FOV
        nframes= framecell{ii};
        list={};
       % refframe=framecell{1}(1);
        
        disp(['Reading group of frames:  ' num2str(ii) ' / ' num2str(numel(framecell)) ]);
        
        for j=1:numel(nframes) % read all images for all channels in this group
            
            disp(['Reading frame: ' num2str(j) ' / '  num2str(numel(nframes)) ' in group of frame : ' num2str(ii) ' / ' num2str(numel(framecell)) ' for FOV:  ' num2str(tmpfov(i).id)]);
            
            for k=1:numel(tmpfov(i).channel) % loop on channels            
                frame=(nframes(j)); %/channelint(k))+1; %  spacing frames when channels are not used with equal time interval
                im=tmpfov(i).readImage(frame,k);
      
                if tmpfov(i).display.binning(k) ~= tmpfov(i).display.binning(1)
                    im=imresize(im,tmpfov(i).display.binning(k)/tmpfov(i).display.binning(1));
                end
                
                list{j,k}=im;
            end
                  
            % msg = sprintf('Reading frame: %d / %d for FOV %s', j, numel(nframes),tmpfov(i).id); %Don't forget this semicolon
            %  fprintf([reverseStr, msg]);
            %  reverseStr = repmat(sprintf('\b'), 1, length(msg));
            
            % cc=cc+1;
        end
        
        fprintf('\n');
        
        disp('Correcting XY drift in images...');
        
        method='circshift';
       % method='subpixel';
        
        tmpfov(i).computeDrift('framesid',nframes,'refframeid',refframeid,'method',method,'refimage',refimage,'images',list(:,1),'fov',i); % compute drift and store in fov.drift
        
        %a= tmpfov(i).drift.x
        
        for j=1:numel(nframes)
            row=tmpfov(i).drift.x(nframes(j));           
            col=tmpfov(i).drift.y(nframes(j));
            
            for k=1:numel(tmpfov(i).channel)
                
                if strcmp(method,'circshift')
                    list{j,k}=circshift( list{j,k},row,1);
                    list{j,k}=circshift( list{j,k},col,2);
                end
                if strcmp(method,'subpixel')
                    list{j,k}=imtranslate(list{j,k},[-col -row]);
                      %  list{j,k}=imtranslate(list{j,k},[row col]);
                end
            end
        end

        disp('Cropping ROIs....');
        
        reverseStr = '';
        
        tmproi=roi;
        for l=1:numel(tmpfov(i).roi)
            tmproi(l)=tmpfov(i).roi(l);
            %tmpfov(i)=propValues(tmpfov(i),obj.fov(i));
        end
        
        % parfor here
        for l=1:numel(tmpfov(i).roi) % loop on all rois
            
            tmproi(l).path=fullfile(strpath,tmpfov(i).id);
            rroi=tmproi(l).value; % cropping data
            
            init=0;
            
            if ii~=1 % if not the first group of frame, re-load the 4D im to append data
               % if numel(tmproi(l).image)==[]
                    tmproi(l).load;
              %  end
            else   % first group of frames, need to create structure 
                init=1;
            end
            
%             % create new image if first item in group of frames
%             if numel(tmproi(l).image)==[]
%             %    init=1;
%             end
            
            if init==1
                tmproi(l).image=uint16(zeros(rroi(4),rroi(3),numel(tmpfov(i).srclist),numel(nframestot)));
                tmproi(l).display.channel={};
                tmproi(l).display.frame=1;
                 tmproi(l).display.intensity=[];
               tmproi(l).display.selectedchannel=[];   
                tmproi(l).display.rgb=[];
                 tmproi(l).channelid=[];
                %tmpfov(i).roi(l).display.settings={};
                temp=[1 1 1];
                %temp=temp';
                
                for k=1:numel(tmpfov(i).channel)
                    tmproi(l).display.channel{k}=tmpfov(i).channel{k}; %['Channel ' num2str(k)];
                    tmproi(l).display.intensity(k,:)=temp;
                    tmproi(l).channelid(k)=k;
                    tmproi(l).display.selectedchannel(k)=1;
                    tmproi(l).display.rgb(k,:)=temp;
                end
                
                tmproi(l).save;
         %       tmproi(l).clear;
            end
            
            %cc=1;
            for j=1:numel(nframes)
                
                for k=1:numel(tmpfov(i).channel)
                    
                    tmp=list{j,k};
                    
                    % size(tmp)
                    %  size(tmpfov(i).roi(l).image)
                    % rroi
                    % make a test on ROI value
                    rroitmp=[];
                    rroitmp(1)=max(rroi(1),1);
                    rroitmp(2)=max(rroi(2),1);
                    rroitmp(3)=min(rroi(1)+rroi(3)-1,size(tmp,2));
                    rroitmp(4)=min(rroi(2)+rroi(4)-1,size(tmp,1));

                    % rroitmp
                    % size(tmpfov(i).roi(l).image,1:2)
                    
                    tmproi(l).image(:,:,k,nframes(j))=tmp(rroitmp(2):rroitmp(4),rroitmp(1):rroitmp(3));
                 %   tt= tmproi(l).image(:,:,k,nframes(j));                
                end
                %cc=cc+1;
            end
            
            tmproi(l).save;
        %    tmproi(l).clear;          
            %tmpfov(i).roi(l).clear;
            
            disp(['Saved images for ROI ' tmproi(l).id ' in FOV : ' tmpfov(i).id]); %d / %d ROIs saved for FOV %s', l , numel(tmpfov(i).roi), tmpfov(i).id); %Don't forget this semicolon
            
            % msg = sprintf('Images in %d / %d ROIs saved for FOV %s', l , numel(tmpfov(i).roi), tmpfov(i).id); %Don't forget this semicolon
            % fprintf([reverseStr, msg]);
            %  reverseStr = repmat(sprintf('\b'), 1, length(msg));
        end
       % fprintf('\n');
    end
    
    % restore roi object structure
    for l=1:numel(tmpfov(i).roi)
        tmpfov(i).roi(l)=tmproi(l);
        %tmpfov(i)=propValues(tmpfov(i),obj.fov(i));
    end 
end

for i=fovid % restore obj structure
    obj.fov(i)=tmpfov(i);
    for l=1:numel(obj.fov(i).roi)
        obj.fov(i).roi(l).clear;
    end
end

disp('Saving project...');
shallowSave(obj)


function newObj=propValues(newObj,orgObj)
pl = properties(orgObj);
for k = 1:length(pl)
    if isprop(newObj,pl{k})
        newObj.(pl{k}) = orgObj.(pl{k});
    end
end




