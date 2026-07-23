function cfg = score_setObjectDisplayConfig(roiobj, channelName, updates)
%SCORE_SETOBJECTDISPLAYCONFIG Persist a small per-channel UI/render preset.

channelName = char(string(channelName));
cfg = score_getObjectDisplayConfig(roiobj, channelName);
if nargin >= 3 && isstruct(updates)
    fields = fieldnames(updates);
    for i = 1:numel(fields)
        cfg.(fields{i}) = updates.(fields{i});
    end
end

% Reuse the reader as the single normalization point without modifying the
% ROI until the complete record is ready.
shadow = roiobj.display;
shadow.objectDisplay = struct('version', 1, 'channels', cfg);
original = roiobj.display;
cleanup = onCleanup(@() restoreDisplay(roiobj, original));
roiobj.display = shadow;
cfg = score_getObjectDisplayConfig(roiobj, channelName);
clear cleanup;
roiobj.display = original;

store = struct('version', 1, 'channels', struct([]));
if isfield(roiobj.display, 'objectDisplay') && isstruct(roiobj.display.objectDisplay)
    store = roiobj.display.objectDisplay;
    if isfield(store, 'channels') && ~isempty(store.channels) && isstruct(store.channels)
        existingNames = string({store.channels.channelName});
        normalized = struct([]);
        for i = 1:numel(existingNames)
            record = score_getObjectDisplayConfig(roiobj, existingNames(i));
            if isempty(normalized)
                normalized = record;
            else
                normalized(end+1) = record; %#ok<AGROW>
            end
        end
        store.channels = normalized;
    end
end
store.version = 1;
if ~isfield(store, 'channels') || isempty(store.channels)
    store.channels = cfg;
else
    names = string({store.channels.channelName});
    hit = find(strcmpi(names, string(channelName)), 1, 'first');
    if isempty(hit)
        store.channels(end+1) = cfg;
    else
        store.channels(hit) = cfg;
    end
end

displayState = roiobj.display;
displayState.objectDisplay = store;
roiobj.display = displayState;
end

function restoreDisplay(roiobj, displayState)
try
    roiobj.display = displayState;
catch
end
end
