function export(obj,varargin)

% export specific  movies 
%- array of fovs
% mosaic montage of specific ROIs

 mosaic(obj,varargin{:})
 

% frames=1:numel(obj.fov(1).srclist{1}); % take the number of frames from the image list
% name=[];
% ips=10;
% framerate=10;
% channels=1;
% fontsize=20;
% levels=[4000 15000; 500 1000; 500 1000; 500 1000];
% drawrois=-1;
% exportfovs=1;
% listfovs=1:numel(obj.fov);
% mosaic=[1 1 1; 1 2 3];
% 
% for i=1:numel(varargin)
%     
%     if strcmp(varargin{i},'Frames')
%         frames=varargin{i+1};
%     end
%     
%     if strcmp(varargin{i},'Name')
%         name=varargin{i+1};
%     end
%     
%     if strcmp(varargin{i},'IPS') % number of frames displayed per second
%         ips=varargin{i+1};
%     end
%     
%     if strcmp(varargin{i},'Framerate')
%         framerate=varargin{i+1};
%     end
%     
%     if strcmp(varargin{i},'Channel') % an array that indicates the channels being displayed
%         channels=varargin{i+1};
%     end
%     
%     if strcmp(varargin{i},'Levels') % defines output levels for display
%         levels=varargin{i+1};
%     end
%     
%     if strcmp(varargin{i},'FontSize')
%         fontsize=varargin{i+1};
%     end
%     
%     if strcmp(varargin{i},'DrawROIs') % draws the contour of ROIs on the movie
%         drawrois=varargin{i+1};
%     end
%     
%      if strcmp(varargin{i},'ExportFOVs') % draws the contour of ROIs on the movie
%         listfovs=varargin{i+1};
%         exportfovs=1;
%      end
%     
%       if strcmp(varargin{i},'Mosaic') % draws the contour of ROIs on the movie
%        mosaic=varargin{i+1};
%         exportfovs=0;
%      end
% end
% 
% if exportfovs==1 % export a list of fovs with paramters
%     if numel(name)==0
%         name=[obj.io.path obj.io.file '/FOV_' obj.fov(i).id];
%     end
%     
%     for i=listfovs
%         disp(['Exporting movie for FOV ' num2str(i) ' - '  obj.fov(i).id])
%         obj.fov(i).export('IPS',ips,'Frames',frames,'Framerate',framerate,'FontSize',fontsize,'Levels',levels,'Channel',channels,'DrawROIs',[],'Name',name)
%     end
%     return;
% end
% 
% 
%  % mosaic mode: displays specific ROIs from different FOVs 
%  % find number of lines and columns
% 
% nmov=size(mosaic,2);
% 
% nsize=[1 1; 1 2; 1 3; 2 2; 2 3; 2 3; 3 3; 3 3; 3 3];
% if nmov>9
%    nsize=floor(sqrt(nmov-1))+1; 
%    nsize=[nsize nsize];
% else
%    nsize=nsize(nmov,:); 
% end
% 
% img=obj.fov(mosaic(1,1)).roi(mosaic(2,1)).image;
% 
% if numel(img)==0
%    obj.fov(mosaic(1,1)).roi(mosaic(2,1)).load;
% end
% 
% h=size(img,1);
% w=size(img,2);
% imgout=zeros(nsize(1)*h,nsize(2)*w,3,size(img,4));
% cc=1;
% 
% 
%  for k=1:nsize(1) % include all requested rois
%     for j=1:nsize(2)
%             
%         obj.fov(mosaic(1,cc)).roi(mosaic(2,cc)).load;
%         
%         imtmp=obj.fov(mosaic(1,cc)).roi(mosaic(2,cc)).image;
%         imout=imtmp;
%         for i=1:size(imtmp,4)
%         imout(:,:,1,i)=imadjust(imtmp(:,:,1,i),[levels(1,1)/65535 levels(1,2)/65535],[0 1]);
%         end
%          
%         % add black frame around ROIs
%         imout(1:2,:,1,:)=0;
%          imout(end-1:end,:,1,:)=0;
%           imout(:,1:2,1,:)=0;
%          imout(:,end-1:end,1,:)=0;
%          
% imout(:,:,2,:)=imout(:,:,1,:);
% imout(:,:,3,:)=imout(:,:,1,:);
% imgout(1+(k-1)*h:k*h,1+(j-1)*w:j*w,:,:)=imout;
%         
%         cc=cc+1;
%     end
%  end
%  
%  imgout=imgout(:,:,:,frames);
%   imgout=uint8(double( imgout)/256);
%   
%    for j=1:numel(frames)
%      if framerate >0
%         timestamp=[num2str((j-1)*framerate) 'min'];
%         
%         imgout(:,:,:,j)=insertText( imgout(:,:,:,j),[1 10],timestamp,'Font','Arial','FontSize',fontsize,'BoxColor',...
%             [1 1 1],'BoxOpacity',0.0,'TextColor','red','AnchorPoint','leftcenter');
%         %fprintf('.')
%      end
%  end
%   
%  if numel(name)==0
%         name=[obj.io.path obj.io.file '/Mosaic'];
%         
%         for i=1:nmov
%             name=[name '_' num2str(mosaic(1,i)) '_' num2str(mosaic(2,i)) '-'];
%         end
%  else
%      name=[obj.io.path obj.io.file '/' name];
%  end
%  
% v=VideoWriter(name,'MPEG-4');
% v.FrameRate=ips;
% open(v);
% 
%     %return
%  writeVideo(v,imgout);
% close(v);
% disp('Movie is done !')




