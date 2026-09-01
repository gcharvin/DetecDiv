function [outImage,name] = materializeTracks(roiobj,tracks,name,frames)
%MATERIALIZETRACKS Persist stable IDs in one indexed ROI channel.
% Compact ROI loads can expose a logical channel in display.channel without
% loading its physical plane. Reuse that logical identity instead of adding
% a second channel with the same name.

if max(tracks(:))>intmax('uint16')
    error('cellLatentModel:TooManyTracks', ...
        'Predicted stable track ID exceeds uint16 ROI storage.');
end
outImage=roiobj.image;
if isempty(outImage)
    error('cellLatentModel:InvalidROIImage', ...
        'Track materialization requires a loaded four-dimensional ROI image.');
end
if size(tracks,1)~=size(outImage,1)|| ...
        size(tracks,2)~=size(outImage,2)||size(tracks,3)~=numel(frames)
    error('cellLatentModel:TrackShapeMismatch', ...
        'Predicted tracks do not match ROI width, height and selected frames.');
end
if any(frames<1)||any(frames>size(outImage,4))||numel(unique(frames))~=numel(frames)
    error('cellLatentModel:InvalidTrackFrames', ...
        'Track frames must be unique valid ROI frame indices.');
end

logicalIdx=findLogicalChannel(roiobj,name);
if numel(logicalIdx)>1
    error('cellLatentModel:DuplicateTrackChannelNames', ...
        'ROI display contains duplicate logical channel name "%s".',name);
end
idx=findChannel(roiobj,name);
if isempty(idx)
    if ~isempty(logicalIdx)
        % Prefer the persisted plane when this is a compact HDF5 load. This
        % preserves unselected frames and lets roi.load maintain channelid.
        try
            roiobj.load('Channel',name,'Data',false,'Silent');
        catch ME
            if ~strcmp(ME.identifier,'loadFromH5_single:NotFound')
                rethrow(ME);
            end
        end
        if isempty(findChannel(roiobj,name))
            attachEmptyPlane(roiobj,logicalIdx);
        end
    else
        empty=zeros(size(outImage,1),size(outImage,2),1, ...
            size(outImage,4),'uint16');
        roiobj.addChannel(empty,name,[1 1 1],[0 0 0]);
    end
    outImage=roiobj.image;
    idx=findChannel(roiobj,name);
    if isempty(idx)
        error('cellLatentModel:TrackChannelCreationFailed', ...
            'Track channel "%s" has no physical ROI plane after loading.',name);
    end
end
idx=idx(1);
if idx<1||idx>size(outImage,3)
    error('cellLatentModel:TrackChannelCreationFailed', ...
        'Resolved track channel index %d is outside the ROI image.',idx);
end
outImage(:,:,idx,frames)=reshape(uint16(tracks), ...
    size(tracks,1),size(tracks,2),1,size(tracks,3));
roiobj.image=outImage;
end

function idx = findChannel(roiobj,name)
try
    idx=roiobj.findChannelID(name,'exact');
catch
    idx=roiobj.findChannelID(name);
end
end

function idx=findLogicalChannel(roiobj,name)
idx=[];
if ~isstruct(roiobj.display)||~isfield(roiobj.display,'channel')|| ...
        isempty(roiobj.display.channel)
    return;
end
names=cellstr(string(roiobj.display.channel));
idx=find(strcmpi(strtrim(names),strtrim(char(string(name)))));
end

function attachEmptyPlane(roiobj,logicalIdx)
% The logical channel can pre-exist without a persisted HDF5 dataset (for
% example in a newly initialized compact ROI). Attach one physical plane to
% that identity without modifying display.channel.
image=roiobj.image;
if numel(roiobj.channelid)~=size(image,3)
    error('cellLatentModel:InvalidCompactChannelMapping', ...
        ['ROI image contains %d physical planes but channelid contains %d ' ...
         'entries.'],size(image,3),numel(roiobj.channelid));
end
image(:,:,end+1,:)=zeros(size(image,1),size(image,2),1,size(image,4), ...
    'like',image);
roiobj.image=image;
roiobj.channelid=[reshape(roiobj.channelid,1,[]) logicalIdx];
end
