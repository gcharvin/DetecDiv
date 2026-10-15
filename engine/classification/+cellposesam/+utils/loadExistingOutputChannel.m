function pix = loadExistingOutputChannel(roiobj, name)
% A missing image plane does not imply a missing logical channel.
% Preserve existing frames by loading the output before a partial rerun.
pix = roiobj.findChannelID(name);
if isempty(pix) && isstruct(roiobj.display) && ...
        isfield(roiobj.display, 'channel') && ...
        any(strcmpi(string(roiobj.display.channel), string(name)))
    try
        roiobj.load('Channel', name, 'Data', false, 'Silent');
    catch ME
        if ~strcmp(ME.identifier, 'loadFromH5_single:NotFound') || ...
                isempty(roiobj.image) || ...
                numel(roiobj.channelid) ~= size(roiobj.image, 3)
            rethrow(ME);
        end
        % Display metadata may advertise an output before its first save,
        % or after extraction replaced the image store. There are no masks
        % on disk to preserve in this specific case. Reuse that logical
        % entry instead of addChannel, which would duplicate its name.
        logicalId = find(strcmpi(string(roiobj.display.channel), string(name)), 1);
        pix = size(roiobj.image, 3) + 1;
        roiobj.image(:,:,pix,:) = zeros(size(roiobj.image,1), ...
            size(roiobj.image,2), 1, size(roiobj.image,4), 'like', roiobj.image);
        roiobj.channelid = [reshape(roiobj.channelid, 1, []) logicalId];
    end
    pix = roiobj.findChannelID(name);
    if isempty(pix)
        error('cellposesam:OutputChannelNotLoaded', ...
            'Existing output channel "%s" could not be loaded.', name);
    end
end
end
