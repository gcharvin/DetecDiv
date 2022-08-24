function paramout=deleteChannels(param,roiobj,frames)

 listChannels=listAvailableChannels;
% listChannels=['N/A', listChannels];
environment='pc' ;

if nargin==0
    paramout=[];
    
    tip={};
    cc=1;

    listChannels{end+1}=listChannels{1};

        paramout.channelMask=listChannels;
        tip{1}= 'Selet the channel to be used as a mask';
        paramout.maskIndex=2;
        tip{2}= 'Selet the index value of the object to be used as mask in the channel; most likely: 1 or 2';
           paramout.channelData=listChannels;
        tip{3}= 'Selet the channel to mask';
         paramout.outputChannelName='outputchannel';
        tip{4}= 'Selet the channel name to create for the output';

    paramout.tip=tip;
  
    return;
else
paramout=param; 
end

if numel(roiobj.image)==0
    roiobj.load;
end


args={};

inputMask=paramout.channelMask{end};
pixmask=roiobj.findChannelID(inputMask);

inputData=paramout.channelData{end};
pixdata=roiobj.findChannelID(inputData);

selid=roiobj.channelid(pixdata(1));

%im=roiobj.image(:,:,pixin,:);

destiCha=paramout.outputChannelName;

pix=roiobj.findChannelID(destiCha);



if numel(pix)>0
roiobj.image(:,:,pix,frames)=uint16(zeros(size(roiobj.image,1),size(roiobj.image,2),1:numel(pix),numel(frames)));
pixoutput=pix;
else
   % add channel is necessary 
   matrix=uint16(zeros(size(roiobj.image,1),size(roiobj.image,2),1:numel(pixdata),size(roiobj.image,4)));
   rgb=roiobj.display.rgb(selid,:);
   intensity=roiobj.display.intensity(selid,:); %indexed image
   tmp=size(roiobj.image,3);
   pixoutput=1:numel(pixdata);
   pixoutput=pixoutput+tmp;
   roiobj.addChannel(matrix,destiCha,rgb,intensity);
end

bw= roiobj.image(:,:,pixmask,:)==paramout.maskIndex;
%roiobj.display.stretchlim(:,pixoutput)=[0;1];

roiobj.image(:,:,pixoutput,:)=roiobj.image(:,:,pixdata,:) .* uint16(bw);
roiobj.computeStretchlim;





