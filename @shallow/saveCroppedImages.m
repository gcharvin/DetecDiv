function saveCroppedImages(obj,fovid,frameid)

fprintf('Cropping and saving images to folder....\n');

if nargin==1
    fovid=1:numel(obj.fov); % All FOVs will be processed 
    frameid=[];
end

if nargin==2
    frameid=[];
end

for i=fovid
    
    if numel(obj.fov(i).roi)==0
        disp('thid FOV has no ROI ! Quitting ....');
        %break
        return
    end
    if numel(obj.fov(i).roi(1).id)==0
        disp('thid FOV has no ROI ! Quitting ....');
        %break 
        return;
    end
    
    if numel(frameid)==0
    nframes=1:numel(obj.fov(i).srclist{1}); % take the number of frames from the image list
    else
    nframes=frameid;   % specify a number of images to be applied to all FOVs
    end

 reverseStr = '';
 
cc=1;

% create fov specific directory 

strpath=[obj.io.path obj.io.file];
mkdir(strpath,obj.fov(i).id);
list={};

for j=nframes 
    for k=1:numel(obj.fov(i).srclist) % loop on channels
        
    im=obj.fov(i).readImage(j,k);
    
    im=imresize(im,obj.fov(i).display.binning(k)/obj.fov(i).display.binning(1));
    
    list{cc,k}=im;
    
    end
    
    msg = sprintf('Reading frame: %d / %d for FOV %s', cc, numel(nframes),obj.fov(i).id); %Don't forget this semicolon
    fprintf([reverseStr, msg]);
    reverseStr = repmat(sprintf('\b'), 1, length(msg));
    
    cc=cc+1;
end
fprintf('\n');

reverseStr = '';

for l=1:numel(obj.fov(i).roi)
    obj.fov(i).roi(l).path=[strpath '/' obj.fov(i).id];
    rroi=obj.fov(i).roi(l).value; % cropping data
    obj.fov(i).roi(l).image=uint16(zeros(rroi(4),rroi(3),numel(obj.fov(i).srclist),numel(nframes)));
    
    obj.fov(i).roi(l).display.channel={};
    %obj.fov(i).roi(l).display.settings={};
   temp=[1 1 1];
   %temp=temp';
   
    for k=1:numel(obj.fov(i).srclist)
        obj.fov(i).roi(l).display.channel{k}=['Channel ' num2str(k)];
        obj.fov(i).roi(l).display.intensity(k,:)=temp;
        obj.fov(i).roi(l).channelid(k)=k;
        obj.fov(i).roi(l).display.selectedchannel(k)=1;
        obj.fov(i).roi(l).display.rgb(k,:)=temp;
    end
    
    cc=1;
    for j=nframes 
    for k=1:numel(obj.fov(i).srclist)
        
        tmp=list{cc,k};
        
       % size(tmp)
      %  size(obj.fov(i).roi(l).image)
       % rroi
        obj.fov(i).roi(l).image(:,:,k,cc)=tmp(rroi(2):rroi(2)+rroi(4)-1,rroi(1):rroi(1)+rroi(3)-1);
        
    end
    cc=cc+1;
    end


% save and clear memory
    % create analysis matrices 
  %  obj.trap(i).classi=uint8(zeros(size(obj.trap(i).gfp,1),size(obj.trap(i).gfp,2),3,size(obj.trap(i).gfp,3)));
  %  obj.trap(i).train=uint8(zeros(size(obj.trap(i).gfp,1),size(obj.trap(i).gfp,2),3,size(obj.trap(i).gfp,3)));
  %  obj.trap(i).traintrack=uint8(zeros(size(obj.trap(i).gfp,1),size(obj.trap(i).gfp,2),3,size(obj.trap(i).gfp,3)));
  %  obj.trap(i).track=uint8(zeros(size(obj.trap(i).gfp,1),size(obj.trap(i).gfp,2),size(obj.trap(i).gfp,3)));
    
  %  obj.trap(i).data.fluo=zeros(size(obj.trap(i).gfp,3),numel(obj.pathname));
    
    
    obj.fov(i).roi(l).save;
    obj.fov(i).roi(l).clear;
    
     msg = sprintf('Images in %d / %d ROIs saved for FOV %s', l , numel(obj.fov(i).roi), obj.fov(i).id); %Don't forget this semicolon
    fprintf([reverseStr, msg]);
    reverseStr = repmat(sprintf('\b'), 1, length(msg));
end
fprintf('\n');
end


