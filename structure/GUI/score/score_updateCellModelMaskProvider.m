function changed = score_updateCellModelMaskProvider(app)
%SCORE_UPDATECELLMODELMASKPROVIDER Change one family's authoritative mask.

changed = false;
[roiobj, channelName] = score_selectedObjectChannel(app);
[model, status] = score_getCellModel(roiobj);
if ~strcmp(status, 'ok')
    return;
end
cfg = score_getObjectDisplayConfig(roiobj, channelName);
[familyIndex, ~] = score_resolveCellModelFamily(model, cfg, channelName);
if isempty(familyIndex)
    return;
end
provider = char(string(app.MaskProviderDropDown.Value));
if any(strcmp(provider, {'', '<family default>'}))
    return;
end
available = cellstr(string(roiobj.display.channel));
if ~any(strcmp(available, provider))
    error('score:UnknownMaskProvider', 'Unknown mask provider: %s', provider);
end
if ~strcmp(model.families.mask_provider{familyIndex}, provider)
    model.families.mask_provider{familyIndex} = provider;
    pix = roiobj.findChannelID(provider);
    for frame = 1:size(roiobj.image,4)
        [model, ~] = cellModel.syncFrame(model, ...
            model.families.family_id(familyIndex), frame, ...
            roiobj.image(:,:,pix(1),frame), ...
            'TrackPolicy', 'preserve_or_label');
    end
    roiobj.saveCellModel(model);
    changed = true;
end
end
