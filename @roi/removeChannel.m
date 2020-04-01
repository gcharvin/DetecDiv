function removeChannel(obj,channel)

% removes indicated channels from the list 

% pix=[];
% for i=1:numel(channels)
%  pix=[pix find(obj.channelid==channels(i))];
% end

if numel(obj.image)==0
    obj.load
end

pix=find(obj.channelid==channel);

remainsdim=setxor(1:size(obj.image,3),pix);

remainsdimid=setxor(1:numel(obj.channelid),pix);

remainscha=setxor(1:numel(obj.display.channel),channel);

% return;

 obj.image=obj.image(:,:,remainsdim,:);
 obj.channelid=obj.channelid(remainsdimid);
% 

 obj.display.channel=obj.display.channel(remainscha);
 obj.display.intensity=obj.display.intensity(remainscha,:);
 obj.display.rgb=obj.display.rgb(remainscha,:);
 obj.display.selectedchannel=obj.display.selectedchannel(remainscha);
