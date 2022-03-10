function paramout=segFluo(param,roiobj,frames)

if nargin==0
    paramout=[];
    
    paramout.input_channel_name='fluo1';
    
    paramout.threshold='1.5';
    
    paramout.output_channel_name='bw_fluo1';
    
    paramout.takeCenter_0or1='1';
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

im=obj.image(:,:,channelID,:);

if nargin<3
    frames=1:size(im,4);
end

if numel(frames)==0
    frames=1:size(im,4);
end

% convert image into binary mask
%% here processing of the image
%imframes=uint16(imframes>=str2num(paramout.threshold));
imframesOuput=uint16(zeros( size(im,1) , size(im,2) , 1 , numel(frames) ));
for fr=1:numel(frames) %adjust boundaries
    tmpimg=preProcessROIData(obj,channelID,frames(fr),0);
    
    T=graythresh(tmpimg); %get otsu threshold
    threshold=str2double(paramout.threshold);
    
    tmpimg=medfilt2(tmpimg,[3 3],'symmetric');
    tmpimg=imbinarize(tmpimg,T*threshold);
    %tmpimg=imbinarize(tmpimg,'adaptive', 'Sensitivity', 0.545);
    tmpimg=bwareaopen(tmpimg, 3);
    
    if str2double(paramout.takeCenter)==1 %takes the most center islet only
        [~,LabeledMask]=bwboundaries(tmpimg); 
        if max(LabeledMask(:))>0
            distCenter=[];
            for pix=1:max(LabeledMask(:))
                mask=LabeledMask;
                mask(mask~=pix)=0;
                mask=uint16(mask/pix);
                centroid=regionprops(mask,'Centroid');
                distCenter(pix)=abs(centroid.Centroid(1)-size(im,1)/2)+abs(centroid.Centroid(2)-size(im,2)/2);
            end
            [~,idxCentered]=min(distCenter);
            tmpimg=LabeledMask;
            tmpimg(tmpimg~=idxCentered)=0;
            tmpimg=uint16(tmpimg/idxCentered);
        end
        %figure; imshowpair(mipmed,mipcrop,'montage')
        %mipwie=wiener2(mip,[4 4]);
        %     h = fspecial('average', [3 3]);
        % 	avmip = imfilter(mip,h);
    end
    imframesOuput(:,:,1,fr)=tmpimg;
end
% img2=im2double(img2);
% img2=img2-min(img2(:));
% img2=img2/max(img2(:));
% T=graythresh(img2); %get otsu threshold
% BW2=imbinarize(img2,T*1);


imframesOuput=imframesOuput*2;
imframesOuput((imframesOuput==0))=1;
%% creates an output channel to update results

pixresults=findChannelID(obj,paramout.output_channel_name);

if numel(pixresults)>0
    %pixresults=find(roiobj.channelid==cc); % find channels corresponding to trained data
    
    obj.image(:,:,pixresults,frames)=imframesOuput; %uint16(zeros(size(obj.image,1),size(obj.image,2),1,size(obj.image,4)));
else
    % add channel is necessary
    
    rgb=[1 1 1];
    intensity=[0 0 0]; % makes the image 'ndexed' and not grayscale in draw.m
    %pixresults=size(obj.image,3)+1;
    obj.addChannel(imframesOuput,paramout.output_channel_name,rgb,intensity);
end
