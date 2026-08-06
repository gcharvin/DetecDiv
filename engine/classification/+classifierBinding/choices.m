function result = choices(binding, catalog, currentValue)
%CLASSIFIERBINDING.CHOICES Build dropdown values from a ROI catalog.

if nargin < 3, currentValue = ''; end
values = {};
labels = {};
total = double(catalog.roiCount);

if logical(binding.required) && ~logical(binding.allowAuto)
    values{end+1} = '<unconfigured>'; %#ok<AGROW>
    labels{end+1} = '<select a required resource>'; %#ok<AGROW>
end
if logical(binding.allowAuto)
    values{end+1} = '<auto>'; %#ok<AGROW>
    labels{end+1} = '<auto>'; %#ok<AGROW>
end
if logical(binding.allowNone) || ~logical(binding.required)
    values{end+1} = '<none>'; %#ok<AGROW>
    labels{end+1} = '<none>'; %#ok<AGROW>
end

type = lower(char(string(binding.type)));
role = lower(char(string(binding.role)));
switch type
    case {'channel','mask'}
        rows = compatibleChannels(catalog.channels, role);
        for i = 1:numel(rows)
            values{end+1} = rows(i).name; %#ok<AGROW>
            labels{end+1} = coverageLabel(rows(i).name, rows(i).roiCount, total); %#ok<AGROW>
        end
    case {'cellmodelfamily','family','objectfamily'}
        rows = catalog.families;
        if contains(role, 'lineage') && ~isempty(rows)
            keep = ~cellfun(@isempty, {rows.lineageSource});
            if any(keep), rows = rows(keep); end
        end
        for i = 1:numel(rows)
            values{end+1} = rows(i).name; %#ok<AGROW>
            label = coverageLabel(rows(i).name, rows(i).roiCount, total);
            if rows(i).providerConflict
                label = [label ' - provider conflict'];
            end
            labels{end+1} = label; %#ok<AGROW>
        end
end

currentValues = textList(currentValue);
for i = 1:numel(currentValues)
    current = currentValues{i};
    if ~isempty(current) && ~any(strcmp(values, current))
        values{end+1} = current; %#ok<AGROW>
        labels{end+1} = [current ' (configured; unavailable in selected ROIs)']; %#ok<AGROW>
    end
end
if isempty(values)
    values = {'<missing>'};
    labels = {'<no compatible resource in imported ROIs>'};
end

[values, keep] = unique(values, 'stable');
labels = labels(keep);
result = struct('values', {values}, 'labels', {labels});
end

function values = textList(raw)
if isempty(raw)
    values = {};
elseif ischar(raw)
    values = {raw};
elseif isstring(raw)
    values = cellstr(raw(:).');
elseif iscell(raw)
    values = {};
    for i = 1:numel(raw)
        values = [values textList(raw{i})]; %#ok<AGROW>
    end
else
    values = {char(string(raw))};
end
end

function rows = compatibleChannels(rows, role)
if isempty(rows), return; end
isMaskRole = contains(role, 'mask') || contains(role, 'track') || ...
    contains(role, 'segmentation');
isImageRole = contains(role, 'image') || contains(role, 'fluorescence') || ...
    contains(role, 'brightfield') || contains(role, 'nucleus') || ...
    contains(role, 'bud_neck');
if isMaskRole
    keep = [rows.indexedRoiCount] > 0;
elseif isImageRole
    keep = [rows.imageRoiCount] > 0;
else
    keep = true(size(rows));
end
filtered = rows(keep);
% Older ROIs sometimes lack indexed display metadata.  Do not make the UI
% unusable: retain the complete inventory when semantic filtering is empty.
if isempty(filtered), filtered = rows; end
rows = filtered;
end

function label = coverageLabel(name, count, total)
if total > 0
    label = sprintf('%s (%d/%d ROI)', name, count, total);
else
    label = name;
end
end
