function cleanROI(obj)

% this function adjusts channel names and number to make it consistent. 

% first load image
if numel(obj.image)==0
obj.load;
end

ncha=size(obj.image,4);

if ncha<numel(obj.channelid) 
    disp('data are missing, adjust channelid....');
    obj.channelid=obj.channelid(1:ncha);
end

maxcha=max(obj.channelid);

if size(obj.display.intensity,1)>maxcha
      disp('adjust intensity....');
    obj.display.intensity=obj.display.intensity(1:maxcha,:);
end
if size(obj.display.rgb,1)>maxcha
     disp('adjust rgb....');
    obj.display.rgb=obj.display.rgb(1:maxcha,:);
end
if numel(obj.display.channel)>maxcha
        disp('adjust channel names....');
    obj.display.channel=obj.display.channel(1:maxcha);
end
if numel(obj.display.selectedchannel)>maxcha
    disp('adjust selected channel array....');
    obj.display.selectedchannel=obj.display.selectedchannel(1:maxcha);
end