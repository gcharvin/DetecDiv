function paramout=segFoci(param,roiobj,frames)

if nargin==0
    paramout=[];
        
    paramout.stdfoci='3';
    
    paramout.mask_channel_name='bw_seg';
    paramout.class_bck='1';
    paramout.class_mother='2';
    paramout.class_other='3';
    paramout.fluo_channel_name='fluo1';
    paramout.output_channel_name='bw_foci1';
    paramout.keeplargest0or1='0';
    paramout.sizethreshold='3';
    return;
else
    paramout=param;
end

obj=roiobj;

channeloutstr=param.output_channel_name;
channelstr=param.fluo_channel_name;
channelstrmsk=param.mask_channel_name;
channelID=obj.findChannelID(channelstr);
channelIDmask=obj.findChannelID(channelstrmsk);


stdfoci=str2double(param.stdfoci);
keeplargest=str2double(param.keeplargest0or1);
sizethreshold=str2double(param.sizethreshold);

class_bck=str2double(param.class_bck);
class_mother=str2double(param.class_mother);
class_other=str2double(param.class_other);

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
    tmpmaskMother=zeros(size(tmpmask));
    tmpmaskMother(tmpmask==class_bck)=0;
    tmpmaskMother(tmpmask==class_other)=0;
    tmpmaskMother(tmpmask==class_mother)=1;
    tmpmaskMother=logical(tmpmaskMother);

    tmpmaskBck=zeros(size(tmpmask));
    tmpmaskBck(tmpmask==class_bck)=1;
    tmpmaskBck(tmpmask==class_other)=0;
    tmpmaskBck(tmpmask==class_other)=0;    
    tmpmaskBck=logical(tmpmaskBck);
    
    tmpmaskedMother=tmpimg.*tmpmaskMother;
    
    meanimgBck=mean(tmpimg(tmpmaskBck));
    
    meanimg=mean(tmpmaskedMother(tmpmaskedMother>0))-meanimgBck;
    stdimg=std(tmpmaskedMother(tmpmaskedMother>0));
%     meanimg=mean(tmpmaskedMother(tmpmaskedMother>0))-meanimgBck;
%     stdimg=std(tmpmaskedMother(tmpmaskedMother>0));


    focimask=tmpmaskedMother>(meanimg+stdfoci*stdimg);
    
    % size filtering
    if keeplargest==1 || sizethreshold>0        
        %BW=bwareaopen(BW,10);
        CC= bwconncomp(focimask,4);
        numPixels = cellfun(@numel,CC.PixelIdxList);
        
        %keep largest islet
        if keeplargest==1 && numel(numPixels)>1 % if several objects are presents
                [~,idx] = max(numPixels);
                focimask(vertcat(CC.PixelIdxList{setxor(1:numel(numPixels),idx)})) = 0;
        end
        
        %remove smaller objects
            idx=find(numPixels<sizethreshold);
            % objects numbers smallers than threshold
            for k=1:numel(idx)
                focimask(CC.PixelIdxList{idx(k)}) = 0;
            end
    end
    
    %tmpmasked=medfilt2(tmpmasked,[3 3],'symmetric');
    focimask=uint16(focimask);
    imframesOuput(:,:,1,fr)=imframesOuput(:,:,1,fr)+focimask;
        
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
