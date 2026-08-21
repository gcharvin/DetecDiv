function catalog = annotationCommonInitializationCatalog(catalogs)
%ANNOTATIONCOMMONINITIALIZATIONCATALOG Keep sources usable by every ROI.

if isstruct(catalogs)
    items = num2cell(catalogs);
else
    items = catalogs;
end
if isempty(items)
    error('annotationGUI:MissingInitializationCatalog', ...
        'At least one ROI initialization catalog is required.');
end
catalog = items{1};
if numel(items) == 1, return; end

catalog.prediction.available = logical(catalog.prediction.available);
for i = 2:numel(items)
    other = items{i};
    catalog.prediction.available = catalog.prediction.available && ...
        logical(other.prediction.available) && ...
        sameText(catalog.prediction.family, other.prediction.family) && ...
        sameText(catalog.prediction.maskProvider, other.prediction.maskProvider);
end

keep = false(size(catalog.families));
for familyIndex = 1:numel(catalog.families)
    source = catalog.families(familyIndex);
    if ~source.usable, continue; end
    keep(familyIndex) = true;
    for roiIndex = 2:numel(items)
        other = items{roiIndex};
        match = find(strcmpi({other.families.name}, source.name) & ...
            strcmpi({other.families.maskProvider}, source.maskProvider) & ...
            [other.families.usable], 1, 'first');
        if isempty(match)
            keep(familyIndex) = false;
            break;
        end
    end
end
catalog.families = catalog.families(keep);

channels = catalog.maskChannels;
keep = true(size(channels));
for channelIndex = 1:numel(channels)
    for roiIndex = 2:numel(items)
        if ~any(strcmpi(items{roiIndex}.maskChannels, channels{channelIndex}))
            keep(channelIndex) = false;
            break;
        end
    end
end
catalog.maskChannels = channels(keep);
end

function tf = sameText(left, right)
tf = strcmpi(char(string(left)), char(string(right)));
end
