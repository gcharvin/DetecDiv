function [providerName, displayIndex, pix, familyId] = ...
        score_resolveMaskProvider(roiobj, channelName)
%SCORE_RESOLVEMASKPROVIDER Resolve the authoritative mask for a display channel.

providerName = char(string(channelName));
displayIndex = [];
pix = [];
familyId = [];
if isempty(roiobj) || isempty(providerName)
    return;
end

cfg = score_getObjectDisplayConfig(roiobj, channelName);
configuredProvider = char(string(cfg.maskProvider));
if ~any(strcmp(configuredProvider, {'', '<family default>'}))
    providerName = configuredProvider;
end
[model, status] = score_getCellModel(roiobj);
if strcmp(status, 'ok')
    [~, familyId, ~, familyProvider] = ...
        score_resolveCellModelFamily(model, cfg, channelName);
    if ~isempty(familyProvider)
        providerName = familyProvider;
    end
end

try
    displayIndex = find(strcmp(cellstr(string(roiobj.display.channel)), ...
        providerName), 1, 'first');
    pix = roiobj.findChannelID(providerName);
    if ~isempty(pix), pix = pix(1); end
catch
    displayIndex = [];
    pix = [];
end
end
