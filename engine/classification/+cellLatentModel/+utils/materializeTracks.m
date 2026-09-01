function [outImage,name] = materializeTracks(roiobj,tracks,name,frames)
%MATERIALIZETRACKS Persist stable IDs in one indexed ROI channel.
% Compact ROI loads can temporarily expose incomplete logical-channel
% metadata. The newly appended physical plane remains authoritative and is
% therefore used as a checked fallback when lookup by name is unavailable.

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

idx=findChannel(roiobj,name);
if isempty(idx)
    oldPlaneCount=size(outImage,3);
    empty=zeros(size(outImage,1),size(outImage,2),1, ...
        size(outImage,4),'uint16');
    roiobj.addChannel(empty,name,[1 1 1],[0 0 0]);
    outImage=roiobj.image;
    newPlaneCount=size(outImage,3);
    if newPlaneCount~=oldPlaneCount+1
        error('cellLatentModel:TrackChannelCreationFailed', ...
            ['Adding track channel "%s" changed the physical-plane count ' ...
             'from %d to %d; expected exactly one new plane.'], ...
            name,oldPlaneCount,newPlaneCount);
    end
    idx=findChannel(roiobj,name);
    if isempty(idx)
        % The channel plane was appended successfully, but a compact ROI's
        % logical metadata has not made it searchable yet. Never index an
        % empty lookup result: use the uniquely verified appended plane.
        idx=newPlaneCount;
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
