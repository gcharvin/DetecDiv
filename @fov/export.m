function export(obj,varargin)
% generates an AVI movie file from FOV

% export trap data as movie
% outputs rgb as a 4-D 8bits rgb matrix for inclusion into a bigger movie


frames=1:numel(obj.srclist{1}); % take the number of frames from the image list
name=[];
ips=10;
framerate=0;
channels=1;
fontsize=20;
levels=[3500 23000; 500 1000; 500 1000; 500 1000];
drawrois=-1;
drift=[];
crop=[];


for i=1:numel(varargin)
    
    if strcmp(varargin{i},'Frames')
        frames=varargin{i+1};
    end
    
    if strcmp(varargin{i},'Name')
        name=varargin{i+1};
    end
    
    if strcmp(varargin{i},'IPS') % number of frames displayed per second
        ips=varargin{i+1};
    end
    
    if strcmp(varargin{i},'Framerate')
        framerate=varargin{i+1};
    end
    
    if strcmp(varargin{i},'Channel') % an array that indicates the channels being displayed
        channels=varargin{i+1};
    end
    
    if strcmp(varargin{i},'Levels') % defines output levels for display
        levels=varargin{i+1};
    end
    
    if strcmp(varargin{i},'FontSize')
        fontsize=varargin{i+1};
    end
    
    if strcmp(varargin{i},'DrawROIs') % draws the contour of ROIs on the movie
        drawrois=varargin{i+1};
    end
    
     if strcmp(varargin{i},'Drift') % correction of XY drift
        drift=1;% varargin{i+1};
     end

       if strcmp(varargin{i},'Crop') % correction of XY drift
        crop=varargin{i+1};% varargin{i+1};
     end
    
end

if numel(drawrois)==0
    drawrois=1:numel(obj.roi); % all rois are displayed
end

if any(drawrois==0)
    drawrois=[];
end


if numel(name)==0
    pth=pwd;
    filename =  [pth '/im_' obj.id '.mp4'];
else
    filename =  [name '.mp4'];
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


if numel(crop)
    im=im(crop(2,1):crop(2,2),crop(1,1):crop(1,2));
 end

imtot=zeros(size(im,1),size(im,2)*numel(channels),1,numel(frames),'single');

reverseStr = '';

cc=1;

if numel(drift)
    refframe= obj.readImage(frames(1),1);

    if numel(crop)
    refframe=refframe(crop(2,1):crop(2,2),crop(1,1):crop(1,2));
 end
end

for j=frames
    
    if numel(drift)
        test=obj.readImage(j,1);
           if numel(crop)
   test=test(crop(2,1):crop(2,2),crop(1,1):crop(1,2));
           end

    c = normxcorr2(refframe,test);

[mx ix]=max(c(:));
 [row col]=ind2sub(size(c),ix);
  row=row-size(refframe,1);
  col=col-size(refframe,2);
    end
  
  % figure, imshowpair(refframe, list{j,1});
%   figure, imshowpair(refframe, tmp);

    for k=1:numel(channels) % loop on channels
        
        ch=channels(k);
        im=obj.readImage(j,ch);
        im=imresize(im,obj.display.binning(k)/obj.display.binning(1));

          if numel(crop)
    im=im(crop(2,1):crop(2,2),crop(1,1):crop(1,2));
          end

        
        if numel(drift)
         im=circshift( im,-row,1);
         im=circshift( im,-col,2);
        end
        
        %size(im)
       
        imtmp=imadjust(im,[levels(k,1)/65535 levels(k,2)/65535],[0 1]);
        
        imtot(:,(k-1)*size(im,2)+1:(k)*size(im,2),1,cc)=imtmp;
        
    end
    
    msg = sprintf('Reading frame: %d / %d for FOV %s', j, numel(frames),obj.id); %Don't forget this semicolon
    fprintf([reverseStr, msg]);
    reverseStr = repmat(sprintf('\b'), 1, length(msg));
    
    cc=cc+1;
end

fprintf('\n');

%default parameter
% for i=1:size(obj.image,4)
%   im(:,:,1,i)=imadjust(im(:,:,1,i),[meangfp/65535 maxgfp/65535],[0 1]);
% %  fprintf('.');
% end
%  fprintf('\n');

%   tmp=imtot(:,:,1,:);
% meangfp=0.3*double(mean(tmp(:)));
%  maxgfp=double(meangfp+0.5*(max(tmp(:))-meangfp));
%
%   for j=1:size(imtot,4)
%
%   end

im=uint8(double(imtot)/256);

im(:,:,2,:)=im(:,:,1,:);
im(:,:,3,:)=im(:,:,1,:);

for j=1:size(im,4)
    
    %==TIMESTAMP==
    if framerate >0
        timestamp=[num2str((j-1)*framerate) 'min'];
        
        im(:,:,:,j)=insertText( im(:,:,:,j),[10 40],timestamp,'Font','Arial','FontSize',fontsize,'BoxColor',...
            [1 1 1],'BoxOpacity',0.5,'TextColor','white','AnchorPoint','leftcenter');
        %fprintf('.')
    end
    
    %==ROIS==
    if numel(drawrois)>0 & drawrois>0
        for i=drawrois
            if i<=length(obj.roi)
        roitmp=obj.roi(i).value;

        if numel(crop)
roitmp(1)=roitmp(1)-crop(1,1);
roitmp(2)=roitmp(2)-crop(2,1);
        end

       % roitmp=[roitmp(1) roitmp(2) roitmp(1)+ roitmp(3) roitmp(2)+ roitmp(4)];
       % h=patch([roitmp(1) roitmp(3) roitmp(3) roitmp(1) roitmp(1)],[roitmp(2) roitmp(2) roitmp(4) roitmp(4) roitmp(2)],[1 0 0],'FaceAlpha',0.3,'Tag',['roitag_' num2str(i)],'UserData',i);
        
        im(:,:,:,j) = insertShape( im(:,:,:,j),'FilledRectangle',[roitmp(1) roitmp(2) roitmp(3) roitmp(4)],...
    'Color', {'red'},'Opacity',0.3);

        im(:,:,:,j)=insertText( im(:,:,:,j),[roitmp(1) roitmp(2)],num2str(i),'Font','Arial','FontSize',20,'BoxColor',...
            [1 1 1],'BoxOpacity',0.0,'TextColor','red','AnchorPoint','leftcenter');

      roitmp(1)=roitmp(1)+size(im,1);
          im(:,:,:,j) = insertShape( im(:,:,:,j),'FilledRectangle',[roitmp(1) roitmp(2) roitmp(3) roitmp(4)],...
    'Color', {'red'},'Opacity',0.3);

        im(:,:,:,j)=insertText( im(:,:,:,j),[roitmp(1) roitmp(2)],num2str(i),'Font','Arial','FontSize',20,'BoxColor',...
            [1 1 1],'BoxOpacity',0.0,'TextColor','red','AnchorPoint','leftcenter');


      %  htext=text(roitmp(1),roitmp(2), num2str(i), 'Color','r','FontSize',10,'Tag',['roitext_' num2str(i)]);
            end
        end
        
    end
end

writeVideo(v,im);
close(v);
disp('Movie is done !')