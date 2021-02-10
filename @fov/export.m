function export(obj,varargin)
% generates an AVI movie file from FOV

% export trap data as movie
% outputs rgb as a 4-D 8bits rgb matrix for inclusion into a bigger movie


frames=1:numel(obj.srclist{1}); % take the number of frames from the image list
name=[];
ips=10;
framerate=0;
channels=1;

for i=1:numel(varargin)
    
    if strcmp(varargin{i},'Frames')
        frames=varargin{i+1};
    end
    
    if strcmp(varargin{i},'Name')
        name=varargin{i+1};
    end
    
    if strcmp(varargin{i},'IPS')
        ips=varargin{i+1};
    end
    
    if strcmp(varargin{i},'Framerate')
        framerate=varargin{i+1};
    end
    
     if strcmp(varargin{i},'Channel')
        channels=varargin{i+1};
    end
    
end

if numel(name)==0
    filename =  [obj.srcpath '/im_' obj.id '.mp4'];
else
    filename =  [obj.srcpath '/' name '.mp4'];
end

v=VideoWriter(filename,'MPEG-4');

v.FrameRate=ips;
open(v);

cc=1;

% tmp=obj.image(:,:,1,:);
% meangfp=0.3*double(mean(tmp(:)));
% maxgfp=double(meangfp+0.5*(max(tmp(:))-meangfp));
% im=obj.image(:,:,1,:);
  
  disp('Writing video.... Wait!');
  
   im=obj.readImage(1,1);
  imtot=zeros(size(im,1),size(im,2)*numel(channels),1,numel(frames));
  
   reverseStr = '';
   
   cc=1;
  for j=frames
    for k=1:numel(channels) % loop on channels
        
        ch=channels(k);
    im=obj.readImage(nframes(j),ch);
    
    %size(im)
    
    imtot(:,(k-1)*size(im,2)+1:(k)*size(im,2),1,cc)=imresize(im,obj.display.binning(k)/obj.display.binning(1));
   
    
    
    end
    
     if framerate >0
    timestamp=[num2str((j-1)*framerate) 'min'];
     imtot(:,:,:,cc)=insertText( imtot(:,:,:,cc),[10 30],timestamp,'Font','Arial','FontSize',20,'BoxColor',...
    [1 1 1],'BoxOpacity',0.0,'TextColor','white','AnchorPoint','leftcenter');
%fprintf('.');
    end
    
    msg = sprintf('Reading frame: %d / %d for FOV %s', j, numel(frames),obj.id); %Don't forget this semicolon
    fprintf([reverseStr, msg]);
    reverseStr = repmat(sprintf('\b'), 1, length(msg));
    
    cc=cc+1;
  end

%default parameter
% for i=1:size(obj.image,4)
%   im(:,:,1,i)=imadjust(im(:,:,1,i),[meangfp/65535 maxgfp/65535],[0 1]);
% %  fprintf('.');
% end
%  fprintf('\n');
  
im=uint8(double(imtot)/256);
  
 im(:,:,2,:)=im(:,:,1,:);
 im(:,:,3,:)=im(:,:,1,:); 

    writeVideo(v,im);
close(v);
disp('Movie is done !')