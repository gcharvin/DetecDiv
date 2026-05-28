function normalizeDisplayCache(obj)
% normalizeDisplayCache Keep lightweight display metadata coherent in memory.

if ~isprop(obj, 'display') || isempty(obj.display) || ~isstruct(obj.display)
    return;
end
if ~isfield(obj.display, 'channel') || isempty(obj.display.channel)
    return;
end

names = obj.display.channel;
if isstring(names), names = cellstr(names); end
if ischar(names), names = {names}; end
if ~iscell(names)
    return;
end

nLog = numel(names);
hadContour = isfield(obj.display, 'contour') && numel(obj.display.contour) >= nLog;
hadAlpha = isfield(obj.display, 'alpha') && numel(obj.display.alpha) >= nLog;
hadWidth = isfield(obj.display, 'width') && numel(obj.display.width) >= nLog;
obj.display.intensity = localEnsureRows(obj.display, 'intensity', nLog, [1 1 1]);
obj.display.indexed = localEnsureVector(obj.display, 'indexed', nLog, 0);
obj.display.contour = localEnsureVector(obj.display, 'contour', nLog, 0);
obj.display.alpha = localEnsureVector(obj.display, 'alpha', nLog, 1);
obj.display.width = localEnsureVector(obj.display, 'width', nLog, 0);
obj.display.selectedchannel = localEnsureVector(obj.display, 'selectedchannel', nLog, 1);
obj.display.rgb = localEnsureRows(obj.display, 'rgb', nLog, [1 1 1]);

for i = 1:nLog
    isIndexed = localShouldForceIndexed(names{i}) || all(double(obj.display.intensity(i,:)) == 0);
    if ~isIndexed
        continue;
    end
    obj.display.intensity(i,:) = [0 0 0];
    obj.display.indexed(i) = 1;
    if ~hadContour
        obj.display.contour(i) = 1;
    end
    if ~hadAlpha || obj.display.alpha(i) <= 0
        obj.display.alpha(i) = 0.35;
    end
    if ~hadWidth || (obj.display.contour(i) ~= 0 && obj.display.width(i) <= 0)
        obj.display.width(i) = 1.5;
    end
end
end

function value = localEnsureRows(display, fieldName, nLog, defaultRow)
if isfield(display, fieldName) && ~isempty(display.(fieldName))
    value = double(display.(fieldName));
else
    value = zeros(0, numel(defaultRow));
end
if isvector(value) && numel(value) == numel(defaultRow)
    value = reshape(value, 1, []);
end
if size(value, 2) ~= numel(defaultRow)
    value = reshape(value, [], numel(defaultRow));
end
if size(value, 1) < nLog
    value(end+1:nLog,:) = repmat(defaultRow, nLog - size(value, 1), 1);
elseif size(value, 1) > nLog
    value = value(1:nLog,:);
end
end

function value = localEnsureVector(display, fieldName, nLog, defaultValue)
if isfield(display, fieldName) && ~isempty(display.(fieldName))
    value = display.(fieldName);
    value = value(:).';
else
    value = zeros(1, 0);
end
if numel(value) < nLog
    value(end+1:nLog) = defaultValue;
elseif numel(value) > nLog
    value = value(1:nLog);
end
end

function tf = localShouldForceIndexed(channelName)
tf = false;
try
    name = lower(string(channelName));
    tf = startsWith(name, "results_") || contains(name, "mask") || ...
        contains(name, "track") || contains(name, "viterbi") || ...
        contains(name, "lineage") || endsWith(name, "_cell") || ...
        endsWith(name, "_conf");
catch
    tf = false;
end
end
