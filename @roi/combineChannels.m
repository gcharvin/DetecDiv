function combineChannels(obj,varargin)

% combine existing channels in ROI
% channels : ids or strid of channels to be merged into one new channel
% number of channels must be either 2 or 3 at the most
% rgb : array that specifies which rgb channel is used for merging : [1 3
% 2] : mean 1 channel is targeted to r, 2 channel to b, and 3 to g. 

channels=[];
rgb=[];
name='CombinedChannel';

for i=1:numel(varargin)
    
    if strcmp(varargin{i},'channels')
        channels=varargin{i+1};
        rgb=1:numel(channels);
    end    
      if strcmp(varargin{i},'rgb')
        rgb=varargin{i+1};
      end   
       if strcmp(varargin{i},'name')
        name=varargin{i+1};
      end   
end

if numel(channels)==0
    disp('no channel defined,; Quitting!')
    return;
end
if numel(rgb)==0
    disp('no rgb array; Quitting!')
    return;
end

if max(rgb)>3
    disp('rgb array is not formatted correctly')
    return
end

if numel(obj.image)==0
    obj.load;
end
if numel(obj.image)==0
    disp('could not load image; quitting');
    return;
end

 matrix=uint16(zeros(size(obj.image,1),size(obj.image,2),3,size(obj.image,4)));
 obj.addChannel(matrix,name,[1 1 1],[0 0 0]);
 pix=obj.findChannelID(name); 
 
for i=1:numel(channels)
    if iscell(channels)
         pix2=obj.findChannelID(channels{i}); 
    else
        pix2=i;
    end
    obj.image(:,:,pix(rgb(i)),:)=obj.image(:,:,channels(pix2),:);
end
