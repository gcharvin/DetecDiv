function paramout=segFoci(param,roiobj,frames)

if nargin==0
    paramout=[];
        
    %paramout.kmaxcell='60';
    paramout.stdfoci='3';
    
    paramout.mask_channel_name='bw_seg';
    paramout.fluo_channel_name='fluo1';
    paramout.output_channel_name='bw_foci1';
    paramout.keeplargest0or1='0';
    paramout.sizethreshold='3';
    return;
else
    paramout=param;
end

obj=roiobj;

channelstr=param.fluo_channel_name;
channelstrmsk=param.mask_channel_name;
channelID=obj.findChannelID(channelstr);
channelIDmask=obj.findChannelID(channelstrmsk);

stdfoci=str2double(param.stdfoci);
keeplargest=str2double(param.keeplargest0or1);
sizethreshold=str2double(param.sizethreshold);

if numel(channelID)==0 % this channel contains the segmented objects
    disp([' This channel ' channelstr ' does not exist ! Quitting ...']) ;
    return;
end

if numel(obj.image)==0
    obj.load
end

im=obj.image(:,:,channelID,:);
mask=obj.image(:,:,channelIDmask,:);

if nargin<3
    frames=1:size(im,4);
end

if numel(frames)==0
    frames=1:size(im,4);
end

% convert image into binary mask
%% here processing of the image
imframesOuput=uint16(zeros( size(im,1) , size(im,2) , 1 , numel(frames) ));
for fr=1:numel(frames) %adjust boundaries
    tmpimg=preProcessROIData(obj,channelID,frames(fr),0);
    tmpmask=mask(:,:,1,fr);
    tmpmask(tmpmask==1)=0;
    tmpmask(tmpmask==3)=0;
    tmpmask(tmpmask==2)=1;
    tmpmask=logical(tmpmask);
    tmpmasked=tmpimg.*tmpmask;
    
    %kmaxcell=str2double(paramout.kmaxcell);
    
    meanimg=mean(tmpimg(tmpmask));
    stdimg=std(tmpimg(tmpmask));
    
    foci=tmpmasked(:,:)>(meanimg+stdfoci*stdimg);
    
    % size filtering
    if numel(keeplargest) || numel(sizethreshold)        
        %BW=bwareaopen(BW,10);
        CC= bwconncomp(foci);
        numPixels = cellfun(@numel,CC.PixelIdxList);
        
        %keep largest islet
        if numel(keeplargest) & numel(numPixels)>1 % if several objects are presents
                [~,idx] = max(numPixels);
                foci(CC.PixelIdxList{setxor(1:numel(numPixels),idx)}) = 0;
        end
        
        %remove smaller objects
            idx=find(numPixels<sizethreshold);
            % objects numbers smallers than threshold
            for k=1:numel(idx)
                foci(CC.PixelIdxList{idx(k)}) = 0;
            end
    end
    
    %tmpmasked=medfilt2(tmpmasked,[3 3],'symmetric');
    foci=uint16(foci);
    imframesOuput(:,:,1,fr)=imframesOuput(:,:,1,fr)+foci;
end

imframesOuput=imframesOuput*2;
imframesOuput((imframesOuput==0))=1;
%% creates an output channel to update results

pixresults=findChannelID(obj,paramout.output_channel_name);

if numel(pixresults)>0    
    obj.image(:,:,pixresults,frames)=imframesOuput; %uint16(zeros(size(obj.image,1),size(obj.image,2),1,size(obj.image,4)));
else
    % add channel is necessary
    rgb=[1 1 1];
    intensity=[0 0 0]; % makes the image 'ndexed' and not grayscale in draw.m
    obj.addChannel(imframesOuput,paramout.output_channel_name,rgb,intensity);
end

obj.save;
obj.clear;
