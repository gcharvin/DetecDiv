function [familyIndex, familyId, familyName, maskProvider] = ...
        score_resolveCellModelFamily(model, cfg, channelName)
%SCORE_RESOLVECELLMODELFAMILY Resolve a channel preset to one model family.

familyIndex = [];
familyId = [];
familyName = '';
maskProvider = '';
if isempty(model)
    return;
end

requested = char(string(cfg.objectFamily));
if ~isempty(requested) && ~strcmp(requested, '<auto>')
    [familyIndex, familyId] = cellModel.familyIndex(model, requested);
end

if isempty(familyIndex)
    provider = char(string(cfg.maskProvider));
    if any(strcmp(provider, {'', '<family default>'}))
        provider = char(string(channelName));
    end
    [familyIndex, familyId] = cellModel.familyIndex(model, provider);
end
if isempty(familyIndex)
    [familyIndex, familyId] = cellModel.familyIndex(model, channelName);
end
if isempty(familyIndex)
    return;
end

familyName = model.families.name{familyIndex};
maskProvider = model.families.mask_provider{familyIndex};
end
