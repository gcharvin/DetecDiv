function removeChannel(obj,channel)
%can only remove one channel at a time !
% channel is either a char represnting the name of the channel to delete,
% or the channel id number as in @roi.channelid array 

% pix=[];
% for i=1:numel(channels)
%  pix=[pix find(obj.channelid==channels(i))];
% end

if numel(obj.image)==0
    obj.load
end

if iscell(channel) || ischar(channel)
     pix=obj.findChannelID(channel);
else
   % pix=find(obj.channelid==channel);
   disp('this is not allowed; quitting....')
  return;
end

if numel(pix)==0
    disp('Channel was not found; quitting !');
    return;
end

%pix
pix2=find(matches(obj.display.channel,channel));

remainsdim=setxor(1:size(obj.image,3),pix);



channelid=obj.channelid(pix(1));
remainsdimid=obj.channelid==channelid;


newchannelid=obj.channelid(~remainsdimid);

if pix<=numel(newchannelid)
newchannelid(pix:end)=newchannelid(pix:end)-1;
end

%newchannelid
remainscha=setxor(1:numel(obj.display.channel),pix2);

%newchannelid

val=[];
for i=1:numel(remainscha)
    pix=find(obj.channelid==remainscha(i));
    val=[val pix];
end
dims=val;

%return;

% update structure 

obj.channelid=newchannelid;
 obj.image=obj.image(:,:,dims,:);

 obj.display.channel=obj.display.channel(remainscha);
 obj.display.intensity=obj.display.intensity(remainscha,:);
 obj.display.rgb=obj.display.rgb(remainscha,:);
 obj.display.selectedchannel=obj.display.selectedchannel(remainscha);
 obj.log(['Removed channel from ROI'],'Processing');