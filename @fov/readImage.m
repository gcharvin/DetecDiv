function im=readImage(obj,frame,channel)

% read specific images from sources, frames can be an array

im=[];

% first check if the source image belongs to a multiff file.

if channel>numel(obj.channel)
    disp('This channel does not exist; quitting !');
    return;
end

if numel(obj.channel)>numel(obj.srcpath) % in this case , it is likely that a single tiff stores all channel information
    chastr=1;
    
    if numel(obj.srclist{chastr})< obj.frames % in this case , it is likely that a single tiff stores all channel information
        fra=1;
        
        % now find the right image to load 
        pix=channel:numel(obj.channel):numel(obj.channel)*obj.frames;
        pix=pix(frame);
        foldert=obj.srcpath{1};
        liststr=obj.srclist{1};
    end
    
else
chastr=channel;
foldert=obj.srcpath{channel};
pix=[];
    list=obj.srclist{channel};
   if numel( obj.interval)>0
    frame=uint16(ceil(frame./obj.interval(channel))); % in case not every frame was snapped for each channel.   
   end
    
    liststr=list(frame);
end


if isfolder(foldert) % folders are provided with image or based on phylocell project
    
    
    imstr=[fullfile(foldert, liststr.name)];
    
    
    if ~exist(imstr)
        disp('folder exists, but file does not  ! Quitting....');
    else
        
        if numel(pix)==0 % single tiff image
        im=imread(imstr);
        else
        im=imread(imstr,'tif',pix);    % multitiff image
        end
        
     %   figure, imshow(im,[]);
        
        disp(['Reading FOV image ' imstr]);
    end
    
else
    disp('folder does not exist ! Quitting....');
end



% elseif isfile(obj.pathname{channel}) % when an avi movie is loaded for instance
%             v = VideoReader(obj.pathname{channel});
%            vidHeight = v.Height;
%            vidWidth = v.Width;
%
%            totalframes=1:v.Duration*v.FrameRate;
%
%            if numel(frames)==0
%            frames=totalframes;
%            end
%
%            temp=zeros(vidHeight,vidWidth,3,'uint8');
%            im=zeros(vidHeight,vidWidth,length(frames),'uint8');
%
%            cc=1;
%             for k=1:numel(totalframes)
%
%                if k>frames(end)
%                    continue
%                end
%
%                 temp=readFrame(v);
%
%                 if numel(find(frames==k))==0
%                    % 'ok'
%                     continue
%                 end
%
%                % cc
%                 if channel==obj.GFPChannel
%                 im(:,:,cc)=temp(:,:,2);
%                 end
%                 if channel==obj.PhaseChannel
%                 temp=rgb2gray(temp);
%               %  'ok'
%                 im(:,:,cc)=temp;
%                 end
%                 cc=cc+1;
%             end
% else
%    fprintf('Images can not be loaded !!! Chech path !');
% end

%

