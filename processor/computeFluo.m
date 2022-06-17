function paramout=binarize(param,roiobj,frames)

if nargin==0
    paramout=[];
    
     tip={'Choose the analysis method: Full: total fluorescence in ROI; oneMask: fluorescence within a mask; twoMask: fluorescence ',...
            'Choose the size of the mini batch; Higher values require more memory and are prone to errors',...
            'Enter the number of epochs'};
        
    paramout.method={'full','oneMask','TwoMask','volume','fociOrNot','OneMask'};
    paramout.kMaxPixels='20';

    paramout.channel=
    paramout.output_channel_name='bw_cells1';
    paramout.tip=tip;

      
    
    return;
else
paramout=param; 
end

obj=roiobj;

channelstr=param.input_channel_name;
channelID=obj.findChannelID(channelstr);

if numel(channelID)==0 % this channel contains the segmented objects
   disp([' This channel ' channelstr ' does not exist ! Quitting ...']) ;
   return;
end

if numel(obj.image)==0
    obj.load
end

if nargin<3
    frames=1:size(im,4);
end

if numel(frames)==0
   frames=1:size(im,4);  
end


im=obj.image(:,:,channelID,:);

imframes=im(:,:,:,frames);

%figure, imshow(imframes(:,:,1,1),[])
% convert image into binary mask

imframes=uint16(imframes>=str2num(paramout.threshold));

%figure, imshow(imframes(:,:,1,1),[])

%creates an output channel to update results

pixresults=findChannelID(obj,paramout.output_channel_name);

if numel(pixresults)>0
%pixresults=find(roiobj.channelid==cc); % find channels corresponding to trained data

obj.image(:,:,pixresults,frames)=imframes; %uint16(zeros(size(obj.image,1),size(obj.image,2),1,size(obj.image,4)));
else
   % add channel is necessary 
   matrix=uint16(zeros(size(im))); %uint16(zeros(size(obj.image,1),size(obj.image,2),1,size(obj.image,4)));
   matrix(:,:,:,frames)=imframes;
   rgb=[1 1 1];
   intensity=[0 0 0]; % makes the image 'ndexed' and not grayscale in draw.m
   pixresults=size(obj.image,3)+1;
   obj.addChannel(matrix,paramout.output_channel_name,rgb,intensity);
end
