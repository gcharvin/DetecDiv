function paramout = setparam(ctx)
% computeMetrics.setparam  Build parameters for computeMetrics processor.

if nargin < 1 || isempty(ctx)
    ctx = struct();
end

listChannels = {};
if isfield(ctx,'channels') && ~isempty(ctx.channels)
    listChannels = normalizeChannelList(ctx.channels);
else
    try
        listChannels = normalizeChannelList(listAvailableChannels);
    catch
        listChannels = {};
    end
end

if isempty(listChannels)
    listChannels = {'N/A'};
else
    listChannels = [{'N/A'}, listChannels(:)'];
end

tip = { ...
    'Name of Mask channel  #1', ...
    'Compute detailed Mask #1 statistics (area, etc)', ...
    'Class number used to identify (cell) contours for Mask #1 (default:2); Put 0 to score all mask values', ...
    'Label of Mask channel  #1 (optional, eg cytoplasm, nucleus, foci, etc...)', ...
    'Name of Mask channel  #2', ...
    'Class number used to identify (subcellular) contours for Mask #2 (default:2)', ...
    'Label of Mask channel  #2 (optional, eg cytoplasm, nucleus, foci, etc...)', ...
    'Compute detailed Mask #2 statistics (area, etc)', ...
    'Channel name #1 to score', ...
    'Channel name #2 to score', ...
    'Channel name #3 to score', ...
    'Channel name #4 to score', ...
    'Number of pixels to consider to calculate mean brightest pixels (default 20)' ...
    };

paramout = struct();
paramout.mask1_name   = [listChannels listChannels{1}];
paramout.mask1_stat   = true;
paramout.mask1_class  = 2;
paramout.mask1_label  = 'cyto';
paramout.mask2_name   = [listChannels listChannels{1}];
paramout.mask2_stat   = true;
paramout.mask2_class  = 2;
paramout.mask2_label  = 'nucl';

paramout.channel1_name = [listChannels listChannels{1}];
paramout.channel2_name = [listChannels listChannels{1}];
paramout.channel3_name = [listChannels listChannels{1}];
paramout.channel4_name = [listChannels listChannels{1}];

paramout.BrightestPixels = 20;
paramout.tip = tip;
end

function out = normalizeChannelList(ch)
    if isempty(ch)
        out = {};
        return;
    end

    if ischar(ch)
        ch = cellstr(ch);
    elseif isstring(ch) || isnumeric(ch) || islogical(ch) || iscategorical(ch)
        ch = cellstr(string(ch(:)));
    elseif ~iscell(ch)
        ch = {char(string(ch))};
    end

    out = {};
    for i = 1:numel(ch)
        item = ch{i};
        if isempty(item)
            continue;
        end
        if ischar(item)
            out{end+1} = item; %#ok<AGROW>
        elseif isstring(item) || isnumeric(item) || islogical(item) || iscategorical(item)
            vals = cellstr(string(item(:)));
            out = [out vals(:)']; %#ok<AGROW>
        end
    end

    if isempty(out)
        out = {};
        return;
    end

    out = cellfun(@(x) char(strtrim(string(x))), out(:)', 'UniformOutput', false);
    out = out(~cellfun(@isempty, out));
    out = unique(out, 'stable');
end
