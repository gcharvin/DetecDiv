function paramout = setparam(ctx)
% computeMaxProjection.setparam  Build parameters for max/mean projection.

if nargin < 1 || isempty(ctx)
    ctx = struct();
end

listChannels = {};
if isfield(ctx,'channels') && ~isempty(ctx.channels)
    listChannels = normalizeChannelList(ctx.channels);
else
    try
        listChannels = listAvailableChannels;
    catch
        listChannels = {};
    end
end

uniqueChannels = {};
for i = 1:numel(listChannels)
    currentChannel = listChannels{i};
    idx = strfind(currentChannel, '_z');
    if ~isempty(idx)
        currentChannel = currentChannel(1:idx(1)-1);
    end
    if ~ismember(currentChannel, uniqueChannels)
        uniqueChannels{end+1} = currentChannel; %#ok<AGROW>
    end
end

if isempty(uniqueChannels)
    uniqueChannels = {'N/A'};
end

paramout = struct();
paramout.method = {'Max','Mean','Max'};
paramout.channel = [uniqueChannels uniqueChannels{1}];
paramout.zstacks = '0';
paramout.outputChannelName = 'projectedChannel';

tip = { ...
    'Please choose the projection method; Max: max projection; Mean: mean projection', ...
    'Please select the channel to be projected', ...
    'Please enter 0 if all stacks should be projected; otherwise, enter stack numbers to use', ...
    'Please enter the name of the output channel' ...
    };
paramout.tip = tip;
end

function out = normalizeChannelList(ch)
    if ischar(ch) || isstring(ch)
        ch = cellstr(ch);
    end
    if ~iscell(ch)
        ch = {char(string(ch))};
    end
    out = {};
    for i = 1:numel(ch)
        v = char(string(ch{i}));
        if ~isempty(v)
            out{end+1} = v; %#ok<AGROW>
        end
    end
    out = unique(out, 'stable');
end
