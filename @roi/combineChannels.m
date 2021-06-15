function combineChannels(obj,varargin)

% combine existing channels in ROI

% channels : ids or strid of channels to be merged into one new channel
% number of channels must be either 2 or 3 at the most
% rgb : cell array hat specifies the [r g b] triplet for each channel to be
% added: { [1 1 0], [1 0 1] }
% the output channel is an rgb image


channels=[];
rgb={};
name='CombinedChannel';

for i=1:numel(varargin)
    
    if strcmp(varargin{i},'channels')
        channels=varargin{i+1};
        rgb=cell(numel(channels),1);
        for j=1:numel(channels)
           rgb{j}=[1 1 1]; 
        end
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

for i=1:numel(channels)
    if iscell(channels)
         pix2=obj.findChannelID(channels{i}); 
    else
        pix2=i;
    end
    
    if numel(pix2)==0
        disp('Channel does not exist; quitting !');
        return;
    end
    if numel(pix2)> size(obj.image,3)
        dsp('Channel number does not exist; Quitting !');
        return;
    end
    
    imtmp= obj.image(:,:,pix2,:);
    if numel(pix2)==1 % one single channel
      imtmp=repmat(imtmp,[1 1 3 1]);
    end
    
    for k=1:3
        imtmp(:,:,k,:)=rgb{i}(k)*imtmp(:,:,k,:);
    end
    
    matrix=imadd(matrix,imtmp);
end
    
 obj.addChannel(matrix,name,[1 1 1],[0 0 0]);


