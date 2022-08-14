function paramout=copyDataFromChannel(param,roiobj,frames)

 listChannels=listAvailableChannels;
% listChannels=['N/A', listChannels];
environment='pc' ;

if nargin==0
    paramout=[];
    
    tip={};
    cc=1;

    listChannels{end+1}=listChannels{1};
        paramout.channelsInput=listChannels;

        tip{1}= 'Selet the channel with data to be transferred';
         paramout.channelDestination='destination';
        tip{2}= 'Selet the channel name to create';



    paramout.tip=tip;
  
    return;
else
paramout=param; 
end


if numel(roiobj.image)==0
    roiobj.load;
end

args={};

inputCha=paramout.channelsInput{end};

pixin=roiobj.findChannelID(inputCha);
selid=roiobj.channelid(pixin(1));

im=roiobj.image(:,:,pixin,:);

destiCha=paramout.channelDestination; 

pix=roiobj.findChannelID(destiCha);

if numel(pix)>0
roiobj.image(:,:,pix,frames)=uint16(zeros(size(roiobj.image,1),size(roiobj.image,2),1:numel(pix),numel(frames)));
pixoutput=pix;
else
   % add channel is necessary 
   matrix=uint16(zeros(size(roiobj.image,1),size(roiobj.image,2),1:numel(pixin),size(roiobj.image,4)));
   rgb=roiobj.display.rgb(selid,:);
   intensity=roiobj.display.intensity(selid,:); %indexed image
   tmp=size(roiobj.image,3);
   pixoutput=1:numel(pixin);
   pixoutput=pixoutput+tmp;
   roiobj.addChannel(matrix,destiCha,rgb,intensity);
end

roiobj.image(:,:,pixoutput,:)=roiobj.image(:,:,pixin,:);

%roiobj.combineChannels({'channels',{'ch000-st000'    'ch000-st001'    'ch000-st002'},'rgb',{[1 0 0] [0 1 0] [0 0 1]}})



