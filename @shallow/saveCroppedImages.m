function saveCroppedImages(obj,fovid,frameid)

fprintf('Cropping and saving images to folder....\n');

if nargin==1
    fovid=1:numel(obj.fov); % All FOVs will be processed 
    frameid=[];
end

if nargin==2
    frameid=[];
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
        disp('thid FOV has no ROI ! Quitting ....');
        %break
        %return
        continue
    end
    if numel(tmpfov(i).roi(1).id)==0
        disp('thid FOV has no ROI ! Quitting ....');
        %break 
        continue
        %return;
    end
    
    if numel(frameid)==0
    nframes=1:numel(tmpfov(i).srclist{1}); % take the number of frames from the image list
    else
    nframes=frameid;   % specify a number of images to be applied to all FOVs
    end

 reverseStr = '';
%  
% cc=1;
% 
% % create fov specific directory 
% 
 mkdir(strpath,tmpfov(i).id);
list={};

for j=1:numel(nframes)
    for k=1:numel(tmpfov(i).srclist) % loop on channels
        
    im=tmpfov(i).readImage(nframes(j),k);
    
    %size(im)
    
    im=imresize(im,tmpfov(i).display.binning(k)/tmpfov(i).display.binning(1));
    
    list{j,k}=im;
    
    end
    
    msg = sprintf('Reading frame: %d / %d for FOV %s', j, numel(nframes),tmpfov(i).id); %Don't forget this semicolon
    fprintf([reverseStr, msg]);
    reverseStr = repmat(sprintf('\b'), 1, length(msg));
    
   % cc=cc+1;
end
fprintf('\n');

reverseStr = '';

for l=1:numel(tmpfov(i).roi)
    tmpfov(i).roi(l).path=[strpath '/' tmpfov(i).id];
    rroi=tmpfov(i).roi(l).value; % cropping data
    tmpfov(i).roi(l).image=uint16(zeros(rroi(4),rroi(3),numel(tmpfov(i).srclist),numel(nframes)));
    
    tmpfov(i).roi(l).display.channel={};
    %tmpfov(i).roi(l).display.settings={};
   temp=[1 1 1];
   %temp=temp';
   
    for k=1:numel(tmpfov(i).srclist)
        tmpfov(i).roi(l).display.channel{k}=['Channel ' num2str(k)];
        tmpfov(i).roi(l).display.intensity(k,:)=temp;
        tmpfov(i).roi(l).channelid(k)=k;
        tmpfov(i).roi(l).display.selectedchannel(k)=1;
        tmpfov(i).roi(l).display.rgb(k,:)=temp;
    end
    
    %cc=1;
    for j=1:numel(nframes)
        
    for k=1:numel(tmpfov(i).srclist)
        
        tmp=list{j,k};
        
       % size(tmp)
      %  size(tmpfov(i).roi(l).image)
       % rroi
        tmpfov(i).roi(l).image(:,:,k,j)=tmp(rroi(2):rroi(2)+rroi(4)-1,rroi(1):rroi(1)+rroi(3)-1);
        
    end
    %cc=cc+1;
    end
    
    
    tmpfov(i).roi(l).save;
    %tmpfov(i).roi(l).clear;
    
     msg = sprintf('Images in %d / %d ROIs saved for FOV %s', l , numel(tmpfov(i).roi), tmpfov(i).id); %Don't forget this semicolon
    fprintf([reverseStr, msg]);
    reverseStr = repmat(sprintf('\b'), 1, length(msg));
end
fprintf('\n');
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
        
        


