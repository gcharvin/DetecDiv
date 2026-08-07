function report = score_copyROIChannelPreset(sourceROI, targetROI)
%SCORE_COPYROICHANNELPRESET Copy display settings between matching channels.
% Channel counts and order may differ. Properties are copied along their
% documented channel dimension: rows for RGB/intensity, columns for limits.

report = struct('matched', {{}}, 'sourceCount', 0, 'targetCount', 0);
if isempty(sourceROI) || isempty(targetROI) || isequal(sourceROI, targetROI) || ...
        ~isprop(sourceROI, 'display') || ~isstruct(sourceROI.display) || ...
        ~isprop(targetROI, 'display') || ~isstruct(targetROI.display) || ...
        ~isfield(sourceROI.display, 'channel') || ...
        ~isfield(targetROI.display, 'channel')
    return;
end

sourceNames = cellstr(string(sourceROI.display.channel(:)));
targetNames = cellstr(string(targetROI.display.channel(:)));
report.sourceCount = numel(sourceNames);
report.targetCount = numel(targetNames);
matchedTarget = false(1, numel(targetNames));
fields = {'intensity', 'rgb', 'displaylim', 'indexed', 'alpha', ...
    'contour', 'log', 'scale', 'width', 'colorMode', 'colormapName'};

for sourceIdx = 1:numel(sourceNames)
    targetIdx = find(strcmp(targetNames, sourceNames{sourceIdx}), 1, 'first');
    if isempty(targetIdx), continue; end
    matchedTarget(targetIdx) = true;
    report.matched{end+1} = sourceNames{sourceIdx};
    for f = 1:numel(fields)
        fieldName = fields{f};
        if ~isfield(sourceROI.display, fieldName) || ...
                ~isfield(targetROI.display, fieldName)
            continue;
        end
        targetROI.display = copyField(sourceROI.display, targetROI.display, ...
            fieldName, sourceIdx, targetIdx, numel(sourceNames), ...
            numel(targetNames));
    end
end

if any(matchedTarget) && isfield(targetROI.display, 'selectedchannel')
    selected = false(1, numel(targetNames));
    for sourceIdx = 1:numel(sourceNames)
        targetIdx = find(strcmp(targetNames, sourceNames{sourceIdx}), 1, 'first');
        if ~isempty(targetIdx) && isfield(sourceROI.display, 'selectedchannel') && ...
                numel(sourceROI.display.selectedchannel) >= sourceIdx
            selected(targetIdx) = logical( ...
                sourceROI.display.selectedchannel(sourceIdx));
        end
    end
    targetROI.display.selectedchannel = selected;
end
end

function targetDisplay = copyField(sourceDisplay, targetDisplay, fieldName, ...
        sourceIdx, targetIdx, sourceCount, targetCount)
value = sourceDisplay.(fieldName);
if isempty(value), return; end

if isnumeric(value) || islogical(value)
    targetValue = targetDisplay.(fieldName);
    if any(strcmp(fieldName, {'intensity','rgb'}))
        if size(value,1) >= sourceIdx && size(targetValue,1) >= targetIdx && ...
                size(value,2) == size(targetValue,2)
            targetValue(targetIdx,:) = value(sourceIdx,:);
        end
    elseif strcmp(fieldName, 'displaylim')
        canonicalColumns = size(value,2) == sourceCount && ...
            size(targetValue,2) == targetCount && ...
            size(value,1) == size(targetValue,1);
        legacyRows = size(value,1) == sourceCount && ...
            size(targetValue,1) == targetCount && ...
            size(value,2) == size(targetValue,2);
        if canonicalColumns
            targetValue(:,targetIdx) = value(:,sourceIdx);
        elseif legacyRows
            targetValue(targetIdx,:) = value(sourceIdx,:);
        end
    elseif numel(value) >= sourceIdx && numel(targetValue) >= targetIdx
        targetValue(targetIdx) = value(sourceIdx);
    end
    targetDisplay.(fieldName) = targetValue;
elseif iscell(value)
    if numel(value) >= sourceIdx && numel(targetDisplay.(fieldName)) >= targetIdx
        targetDisplay.(fieldName){targetIdx} = value{sourceIdx};
    end
elseif isstring(value)
    if numel(value) >= sourceIdx && numel(targetDisplay.(fieldName)) >= targetIdx
        targetDisplay.(fieldName)(targetIdx) = value(sourceIdx);
    end
end
end
