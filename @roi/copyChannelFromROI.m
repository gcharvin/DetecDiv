function copyChannelFromROI(obj,deststr,roitocopy, sourcestr)

% copies a given channel in one roi to another roi
% if option provided, then the channel is ocpied to channelstr "option"

ch2id=roitocopy.findChannelID(sourcestr);
if numel(ch2id)==0
    disp('Channel string in the source roi does not exist. Exit !'); 
    return; 
end 

roitocopy.load; 

im2=roitocopy.image;
if numel(im2)==0
    disp('could not load image ! Exit!');
    return;
end

im2=roitocopy.image(:,:,ch2id,:);

ch1id=obj.findChannelID(deststr);

obj.load;

if numel(ch1id)==0
    prompt='Channel string in the destination roi  does not exist. Creating ? [y/n] : Default: y';
    str= input(prompt,'s');
    if numel(str)==0
        str='y';
    end
    
    if ~strcmp(str,'y')
        disp('Exiting !');
        return;
    end
    
    obj.addChannel(uint16(zeros(size(im2,1),size(im2,2),numel(ch2id),size(im2,4))),deststr,[1 1 1],[1 1 1]) 
    ch1id=obj.findChannelID(deststr);
end

obj.image(:,:,ch1id,:)=im2;



