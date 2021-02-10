function [rgb fr]=export(obj,varargin)
% generates an AVI movie file from ROI


% export trap data as movie
% outputs rgb as a 4-D 8bits rgb matrix for inclusion into a bigger movie

if numel(obj.image)==0
    obj.load
end
if numel(obj.image)==0
    disp('Could not load roi image : quitting...!');
    return;
end

%default parameters

frames= 1:size(obj.image,4);
name=[];
ips=10;
framerate=0;

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
    
end

if numel(name)==0
    filename =  [obj.path '/im_' obj.id '.mp4'];
else
    filename =  [obj.path '/' name '.mp4'];
end


v=VideoWriter(filename,'MPEG-4');

v.FrameRate=ips;
open(v);

cc=1;

tmp=obj.image(:,:,1,:);
meangfp=0.3*double(mean(tmp(:)));
 maxgfp=double(meangfp+0.5*(max(tmp(:))-meangfp));
  im=obj.image(:,:,1,:);
  
  disp('Writing video.... Wait!');
  
  %size(obj.image,4)
  
for i=1:size(obj.image,4)
  im(:,:,1,i)=imadjust(im(:,:,1,i),[meangfp/65535 maxgfp/65535],[0 1]);
%  fprintf('.');
end
%  fprintf('\n');
  
im=uint8(double(im)/256);
  
 im(:,:,2,:)=im(:,:,1,:);
 im(:,:,3,:)=im(:,:,1,:); 
 
for f=frames
    if framerate >0
    timestamp=[num2str((f-1)*framerate) 'min'];
     im(:,:,:,f)=insertText( im(:,:,:,f),[1 10],timestamp,'Font','Arial','FontSize',10,'BoxColor',...
    [1 1 1],'BoxOpacity',0.0,'TextColor','white','AnchorPoint','leftcenter');
%fprintf('.');
    end
end
  %  fprintf('\n');
    
im=im(:,:,:,frames);
    %return
    writeVideo(v,im);
close(v);
disp('Movie is done !')


