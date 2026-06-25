function removeChannel(obj, channel)
%REMOVECHANNEL Remove one logical ROI image channel by name or id.
%
% This updates the image stack, channelid, and ROI display metadata together.

    disp('--- removeChannel called with channel = ---');
    disp(channel)

    if isempty(obj.image)
        obj.load;
    end

    if isstring(channel)
        channel = char(channel);
    end

    if ischar(channel)
        names = localChannelNames(obj);
        idxDisp = find(strcmp(names, channel), 1);
        if isempty(idxDisp)
            disp('removeChannel: name not found in display.channel; quitting.');
            return;
        end
        localRemoveGroup(obj, idxDisp, names, ['Removed channel ' channel ' from ROI']);
        return;
    end

    if isnumeric(channel) && isscalar(channel)
        names = localChannelNames(obj);
        groupID = double(channel);
        if groupID < 1 || groupID > numel(names)
            disp('removeChannel: numeric id not found in display.channel; quitting.');
            return;
        end
        localRemoveGroup(obj, groupID, names, 'Removed channel by numeric id');
        return;
    end

    disp('removeChannel: unsupported channel type; quitting.');
end

function localRemoveGroup(obj, groupID, names, logMessage)
    pixSub = find(obj.channelid == groupID);
    if isempty(pixSub)
        disp('removeChannel: no subchannels found for this channel; quitting.');
        return;
    end

    nC = size(obj.image, 3);
    dimsKeep = setdiff(1:nC, pixSub);
    if isempty(dimsKeep)
        warning('removeChannel: removing this channel would leave zero channels; aborting.');
        return;
    end

    keepDisp = setdiff(1:numel(names), groupID);
    if isempty(keepDisp)
        warning('removeChannel: removing this channel would leave zero display channels; aborting.');
        return;
    end

    obj.image = obj.image(:, :, dimsKeep, :);

    oldID = obj.channelid(dimsKeep);
    uniqueOld = unique(oldID, 'stable');
    newID = zeros(size(oldID));
    for ii = 1:numel(uniqueOld)
        newID(oldID == uniqueOld(ii)) = ii;
    end
    obj.channelid = newID;

    obj.display = localKeepDisplayEntries(obj.display, names, keepDisp, dimsKeep, numel(obj.channelid));
    obj.log(logMessage, 'Processing');
end

function names = localChannelNames(obj)
    names = {};
    if isfield(obj.display, 'channel')
        names = obj.display.channel;
    end
    if ischar(names)
        names = {names};
    elseif isstring(names)
        names = cellstr(names);
    elseif ~iscell(names)
        names = cellstr(string(names));
    end
end

function display = localKeepDisplayEntries(display, names, keepDisp, keepSubchannels, nSubchannels)
    keepDisp = keepDisp(keepDisp >= 1 & keepDisp <= numel(names));
    if isempty(keepDisp)
        return;
    end

    display.channel = names(keepDisp);
    display.intensity = localKeepRows(display, 'intensity', keepDisp, [1 1 1]);
    display.rgb = localKeepRows(display, 'rgb', keepDisp, [1 1 1]);

    display.selectedchannel = localKeepVector(display, 'selectedchannel', keepDisp, true);
    display.indexed = localKeepVector(display, 'indexed', keepDisp, false);
    display.alpha = localKeepVector(display, 'alpha', keepDisp, 1);
    display.contour = localKeepVector(display, 'contour', keepDisp, 0);
    display.width = localKeepVector(display, 'width', keepDisp, 0);
    display.scale = localKeepVector(display, 'scale', keepDisp, false);
    display.log = localKeepVector(display, 'log', keepDisp, false);

    display = localKeepSubchannelField(display, 'displaylim', keepSubchannels, nSubchannels);
    display = localKeepSubchannelField(display, 'stretchlim', keepSubchannels, nSubchannels);
end

function value = localKeepRows(display, fieldName, keepRows, defaultRow)
    nOld = max(keepRows);
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
    if size(value, 1) < nOld
        value(end+1:nOld, :) = repmat(defaultRow, nOld - size(value, 1), 1);
    end
    value = value(keepRows, :);
end

function value = localKeepVector(display, fieldName, keepRows, defaultValue)
    nOld = max(keepRows);
    if isfield(display, fieldName) && ~isempty(display.(fieldName))
        value = display.(fieldName);
        value = value(:).';
    else
        value = zeros(1, 0);
    end
    if numel(value) < nOld
        value(end+1:nOld) = defaultValue;
    end
    value = value(keepRows);
end

function display = localKeepSubchannelField(display, fieldName, keepSubchannels, nSubchannels)
    if ~isfield(display, fieldName) || isempty(display.(fieldName))
        return;
    end
    value = display.(fieldName);
    if ~isnumeric(value) || size(value, 1) ~= 2
        return;
    end
    keepSubchannels = keepSubchannels(keepSubchannels >= 1 & keepSubchannels <= size(value, 2));
    if numel(keepSubchannels) == nSubchannels
        display.(fieldName) = value(:, keepSubchannels);
    elseif size(value, 2) >= nSubchannels
        display.(fieldName) = value(:, 1:nSubchannels);
    else
        display.(fieldName) = value;
    end
end
