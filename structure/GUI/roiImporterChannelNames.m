function names = roiImporterChannelNames(value)
%ROIIMPORTERCHANNELNAMES Normalize legacy ROI channel catalogs to a row.
% display.channel may be char, string, or a row/column cell array depending
% on the ROI generation path. The importer concatenates catalogs from many
% ROIs, so its internal representation must always be a 1-by-N cellstr.

if isempty(value)
    names = {};
    return;
end
if iscell(value)
    names = cellfun(@(item)char(string(item)), value(:).', ...
        'UniformOutput', false);
else
    names = cellstr(string(value(:))).';
end
names = names(~cellfun(@isempty, names));
end
