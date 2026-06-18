function changed = score_applyDefaultChannelSelection(roiObj)
% Keep score responsive when a ROI exposes many logical channels.
%
% Legacy ROI display metadata often defaults selectedchannel to all true.
% For high-channel ROIs this makes score try to load/render everything. If
% the selection still looks like that default state, keep only the first
% channel selected. User-edited partial selections are preserved.

changed = false;

if isempty(roiObj) || ~isprop(roiObj, 'display') || ~isstruct(roiObj.display)
    return;
end
if ~isfield(roiObj.display, 'channel') || isempty(roiObj.display.channel)
    return;
end

nCh = numel(roiObj.display.channel);
if nCh <= 10
    return;
end

if ~isfield(roiObj.display, 'selectedchannel') || isempty(roiObj.display.selectedchannel)
    sel = true(1, nCh);
else
    sel = logical(roiObj.display.selectedchannel(:)');
    sel = sel(1:min(numel(sel), nCh));
    if numel(sel) < nCh
        sel(end+1:nCh) = true;
    end
end

if all(sel)
    sel(:) = false;
    sel(1) = true;
    roiObj.display.selectedchannel = sel;
    changed = true;
else
    roiObj.display.selectedchannel = sel;
end
end
