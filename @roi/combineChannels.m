function combineChannels(obj,varargin)

% combine existing channels in ROI

% channels : ids or strid of channels to be merged into one new channel
% number of channels must be either 2 or 3 at the most
% rgb : cell array hat specifies the [r g b] triplet for each channel to be
% added: { [1 1 0], [1 0 1] }
% if channel is an indexed image , specify rgb color by adding a colormap for each channel with an indexed image : { [1 1 1], [1 0
% 0; 0 1 0; 0 0 1]} , 
% levels : cell array that specifies the levels of the target channel in
% the final image: { [ 4000 40000] , [ 0 3 ] };

% the output channel is an rgb image

channels=[];
rgb={};
levels={};
name='CombinedChannel';

for i=1:numel(varargin)
    
    if strcmp(varargin{i},'channels')
        channels=varargin{i+1};
        rgb=cell(numel(channels),1);
        for j=1:numel(channels)
           rgb{j}=[1 1 1]; 
           levels{j}=[0 65535];
        end
    end    
      if strcmp(varargin{i},'rgb')
        rgb=varargin{i+1};
        
      end   
      
       if strcmp(varargin{i},'levels')
        levels=varargin{i+1};
      end   
       if strcmp(varargin{i},'name')
        name=varargin{i+1};
      end   
end

if numel(levels)==0
     for j=1:numel(channels)
           levels{j}=[0 65535];
        end
end

if numel(channels)==0
    disp('no channel defined; Quitting!')
    return;
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
         pix2=find(obj.channelid==channels(i));
    end
    
    if numel(pix2)==0
        disp('Channel does not exist; quitting !');
        return;
    end
    if any(pix2> size(obj.image,3))
        disp('Channel number does not exist; Quitting !');
        return;
    end
    
    imtmp= obj.image(:,:,pix2,:);
    
    if size(rgb{i},1)==1 % image is not indexed , therefore there is only one triplet
    if numel(pix2)==1 % one single channel
      for j=1:size(imtmp,4)
          imtmp(:,:,1,j)=imadjust(imtmp(:,:,1,j),[levels{i}(1)/65535 levels{i}(2)/65535]);
      end
      imtmp=repmat(imtmp,[1 1 3 1]);
    end
    
    for k=1:3
        imtmp(:,:,k,:)=rgb{i}(k)*imtmp(:,:,k,:);
    end
    
    matrix=imadd(matrix,imtmp);
    else % provide specific color for each object in the colormap 
        
        
        for ii=1:size(rgb{i},1)
            imtmp2=uint16(zeros(size(imtmp)));
            imtmp2=repmat(imtmp2,[1 1 3 1]);
            
            for j=1:size(imtmp,4)
                bw=uint16(imtmp(:,:,1,j)==ii); 
                if numel(bw)==0
                    continue
                end
                
                bw=65535*levels{i}(2)*bw;
                
                imtmp2(:,:,1,j)=rgb{i}(ii,1)*bw;
                imtmp2(:,:,2,j)=rgb{i}(ii,2)*bw;
                imtmp2(:,:,3,j)=rgb{i}(ii,3)*bw;
            end
       
            matrix=imadd(matrix,imtmp2);
        end
    end
end

%figure, imshow(matrix(:,:,:,1));
 obj.addChannel(matrix,name,[1 1 1],[0 0 0]);
 
 obj.log(['Combined channels'],'Processing');


