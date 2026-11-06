function score_updateEmptyImageNotice(fig, roiObj, opts, frame)
%SCORE_UPDATEEMPTYIMAGENOTICE Explain an all-zero intensity frame in Score.
% Missing source chunks can leave allocated HDF5 frames filled with zeros.
% Never infer availability from masks (an empty mask is valid), change the
% ROI length, or substitute the last nonempty image for a missing frame.
tag='ScoreEmptyImageNotice';
if isempty(fig)||~isgraphics(fig),return;end
notice=findall(fig,'Tag',tag);
emptyIntensity=true;hasIntensity=false;
if ~isempty(roiObj.image)&&frame>=1&&frame<=size(roiObj.image,4)
    channels=opts.channel;
    if ischar(channels)||isstring(channels),channels=cellstr(string(channels));end
    for k=1:numel(channels)
        if iscell(channels),channel=channels{k};else,channel=channels(k);end
        if ischar(channel)||isstring(channel)
            index=find(strcmp(string(roiObj.display.channel),string(channel)),1);
        else
            index=double(channel);
        end
        if isempty(index)||~isscalar(index)||index<1||index>numel(roiObj.display.channel),continue;end
        if isfield(roiObj.display,'indexed')&&numel(roiObj.display.indexed)>=index&&roiObj.display.indexed(index),continue;end
        planes=roiObj.findChannelID(roiObj.display.channel{index},'exact');
        if isempty(planes)||any(planes>size(roiObj.image,3)),continue;end
        hasIntensity=true;
        pixels=roiObj.image(:,:,planes,frame);
        if any(pixels(:)~=0),emptyIntensity=false;break;end
    end
end
if ~hasIntensity||~emptyIntensity
    delete(notice);return;
end
message=sprintf(['All selected intensity images contain only zeros at frame %d.\n' ...
    'Check the source images and ROI extraction.'],frame);
if isempty(notice)
    annotation(fig,'textbox',[.08 .88 .84 .10],'String',message, ...
        'Tag',tag,'Color',[1 .75 .2],'BackgroundColor',[.12 .12 .12], ...
        'EdgeColor','none','HorizontalAlignment','center', ...
        'VerticalAlignment','middle','Interpreter','none','FontWeight','bold');
else
    set(notice,'String',message);
end
end
