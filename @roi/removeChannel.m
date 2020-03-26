function removeChannel(obj,channels)

% removes indicated channels from the list 

pix=[];
for i=1:numel(channels)
 pix=[pix find(obj.channelid==channels(i))];
end

remainsdim=setxor(1:size(obj.image,3),pix);
remainsdimid=setxor(obj.channelid,pix);
remainscha=setxor(1:numel(obj.display.channel),pix)

% return;

obj.image=obj.image(:,:,remainsdim);
obj.channelid=remainsdimid;
obj.display.channel=obj.display.channel{remainscha};
obj.display.intensity=obj.display.intensity(remainscha,:);
obj.display.rgb=obj.display.rgb(remainscha,:);
obj.display.selectedchannel=obj.display.selectedchannel(remainscha);



% then create pipeline to make machine learning : training + classification
% classi class that belongs to shallow object % can be either standard
% machine learning or 

% can be iether image classif, pixel classification, and LSTM