function key = score_configureLineageDisplay(roiobj, channelName, channelPix, cfg, showBud, showGenealogy)
%SCORE_CONFIGURELINEAGEDISPLAY Bind display to an existing lineage source.
% This function never creates lineage data and never rewrites mother maps.
[binding, key] = score_resolveLineageDisplayConfig( ...
    roiobj, channelName, channelPix, cfg, showBud, showGenealogy);
if ~isempty(key)
    roiobj.display.lineage = binding;
end
end
