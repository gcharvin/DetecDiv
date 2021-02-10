function export(obj,varargin)

% export specific  movies 
%- array of fovs
% mosaic montage of specific ROIs


frames=1:numel(obj.fov(1).srclist{1}); % take the number of frames from the image list
name=[];
ips=10;
framerate=0;
channels=1;
fontsize=20;
levels=[4000 15000; 500 1000; 500 1000; 500 1000];
drawrois=-1;
exportfovs=1;
listfovs=1:numel(obj.fov);
mosaic=[];

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
    
     if strcmp(varargin{i},'ExportFOVs') % draws the contour of ROIs on the movie
        listfovs=varargin{i+1};
        exportfovs=1;
     end
    
      if strcmp(varargin{i},'Mosaic') % draws the contour of ROIs on the movie
       mosaic=varargin{i+1};
        exportfovs=0;
     end
end

if exportfovs==1 % export a list of fovs with paramters
    for i=listfovs
        obj.fov(i).export('IPS',ips,'Frames',frames,'Framerate',framerate,'FontSize',fontsize,'Levels',levels,'Channel',channels,'DrawROIs',[],'Name',[obj.io.path obj.io.file '/' obj.fov(i).id])
    end
end



