function saveCroppedImages(obj,fovid,frameid)




fprintf('Cropping and saving images to folder....\n');

if nargin==1
    fovid=1:numel(obj.fov); % All FOVs will be processed 
    frameid=[];
end

for i=fovid
    if numel(frameid==0)
    nframes=1:numel(obj.fov(i).srclist{1}); % take the number of frames from the image list
    else
    nframes=framesid;   % specify a number of images to be applied to all FOVs
    end

 reverseStr = '';
 
for j=nframes 
    
%     if j==1
%         list={};
%         for k=1:numel(obj.pathname)
%         [im tmp]=obj.readImage(j,k);
%         
%         if obj.GFPChannel==k
%            imgfp=im; 
%         end
%         
%         list{k}=tmp;
%         end
%     end
%     
%     %imgphase= obj.readImage(j,obj.PhaseChannel);
%     %imgfp=obj.readImage(j,obj.GFPChannel);
%     %imgphase=imresize(imgphase,[size(imgfp,1) size(imgfp,2)]);
%     
%     
%     for k=1:numel(obj.pathname)
%         
%         tmp=obj.readImage(j,k,list{k});
%        % size(tmp);
%         
%         if obj.PhaseChannel==k
%             tmp=imresize(tmp,[size(imgfp,1) size(imgfp,2)]);
%             %figure, imshow(tmp,[]); 
%         end
%         
%        if j==1 && k==1
%          reftmp=tmp;
%        end
%        
% %        if j>1 % cropping and registering images
% %           crop=1:100;
% %           tform=registerImages(reftmp(crop,crop),tmp(crop,crop));
% %           
% %           moved = imwarp(tmp,tform,'OutputView',imref2d(size(reftmp)));
% %   
% %           %figure, imshowpair(reftmp,moved);
% %          % pause
% %           tmp=moved;
% %        end
%         
%        % size(tmp)
%         
%         for i=1:size(positions,1)
%             
%             gfp=tmp(scaled(i,1):scaled(i,2),scaled(i,3):scaled(i,4));
%             
%            % size(gfp)
%             %figure, imshow(gfp,[]); 
%             %return;
%             
%            % size(obj.trap(i).gfp)
%            
%            
%             obj.trap(i).gfp(:,:,j,k)=gfp;
%             
%         end
%         
%     end
    
    msg = sprintf('Processing frame: %d / %d for FOV %d', i, obj.nframes,j); %Don't forget this semicolon
    fprintf([reverseStr, msg]);
    reverseStr = repmat(sprintf('\b'), 1, length(msg));
end

end

fprintf('\n');

return;

% save and clear memory
reverseStr = '';

for i=1:size(positions,1)
    
    % create analysis matrices 
    obj.trap(i).classi=uint8(zeros(size(obj.trap(i).gfp,1),size(obj.trap(i).gfp,2),3,size(obj.trap(i).gfp,3)));
    obj.trap(i).train=uint8(zeros(size(obj.trap(i).gfp,1),size(obj.trap(i).gfp,2),3,size(obj.trap(i).gfp,3)));
    obj.trap(i).traintrack=uint8(zeros(size(obj.trap(i).gfp,1),size(obj.trap(i).gfp,2),3,size(obj.trap(i).gfp,3)));
    obj.trap(i).track=uint8(zeros(size(obj.trap(i).gfp,1),size(obj.trap(i).gfp,2),size(obj.trap(i).gfp,3)));
    
    obj.trap(i).data.fluo=zeros(size(obj.trap(i).gfp,3),numel(obj.pathname));
    
    
    obj.trap(i).save;
    obj.trap(i).clear;
    %%% here : now I need to manage analysis images and then to manage all
    %%% aspects at the movie level 
    
     msg = sprintf('%d / %d Traps saved', i , numel(obj.trap) ); %Don't forget this semicolon
    fprintf([reverseStr, msg]);
    reverseStr = repmat(sprintf('\b'), 1, length(msg));
end
fprintf('\n');

end

