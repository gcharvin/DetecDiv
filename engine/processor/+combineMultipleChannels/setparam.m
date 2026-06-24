function paramout = setparam(ctx)
% combineMultipleChannels.setparam  Default parameters for channel combining.
% ctx.channels (optional) provides channel list from selected ROIs.

    if nargin < 1
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
    end
    channelChoices = [{'none'}, listChannels(:)'];

    paramout = struct();
    tip = {};

    paramout.mode = 'additive';
    tip{end+1} = 'Combination mode: additive RGB, subtraction grayscale, or division/ratio grayscale.'; %#ok<AGROW>

    % fixed max number of channels
    maxSlots = 5;
    defaultRGB = [ ...
        1 0 0; ...
        0 1 0; ...
        0 0 1; ...
        1 1 0; ...
        1 0 1];

    for i = 1:maxSlots
        key = sprintf('Channel%d', i);
        tip{end+1} = sprintf('Binding slot %d: select one input channel (none = skip).', i); %#ok<AGROW>
        paramout.(key) = [channelChoices {'none'}];

        rgbKey = sprintf('RGB_Channel%d', i);
        tip{end+1} = 'RGB triplet for this channel eg: [1 0 0]'; %#ok<AGROW>
        if i <= size(defaultRGB,1)
            paramout.(rgbKey) = defaultRGB(i,:); %#ok<AGROW>
        else
            paramout.(rgbKey) = [1 1 1]; %#ok<AGROW>
        end
    end

    for i = 1:maxSlots
        offsetKey = sprintf('Offset_Channel%d', i);
        tip{end+1} = sprintf('Division offset for slot %d. Used only in division/ratio mode; default is 0.', i); %#ok<AGROW>
        paramout.(offsetKey) = 0;
    end

    paramout.requiredChannelCount = 0;
    tip{end+1} = 'Optional fixed input count. Set 3 to require exactly 3 selected channels; keep 0 to accept any non-zero count.'; %#ok<AGROW>

    paramout.outputChannelName = 'CombinedChannel';
    tip{end+1} = 'Please enter the name of the output channel'; %#ok<AGROW>

    paramout.debug = false;
    tip{end+1} = 'Optional: set debug=true for verbose console logs'; %#ok<AGROW>

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
