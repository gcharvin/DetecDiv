function pix = loadExistingOutputChannel(roiobj, name)
% A missing image plane does not imply a missing logical channel.
% Preserve existing frames by loading the output before a partial rerun.
pix = roiobj.findChannelID(name);
if isempty(pix) && isstruct(roiobj.display) && ...
        isfield(roiobj.display, 'channel') && ...
        any(strcmpi(string(roiobj.display.channel), string(name)))
    roiobj.load('Channel', name, 'Data', false, 'Silent');
    pix = roiobj.findChannelID(name);
    if isempty(pix)
        error('cellposesam:OutputChannelNotLoaded', ...
            'Existing output channel "%s" could not be loaded.', name);
    end
end
end
