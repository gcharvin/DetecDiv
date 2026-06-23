function paramout = setparam(ctx)
% computeMetrics.setparam  Build parameters for computeMetrics processor.

if nargin < 1 || isempty(ctx)
    ctx = struct();
end

ctxParam = struct();
if isstruct(ctx) && isfield(ctx, 'params') && isstruct(ctx.params)
    ctxParam = ctx.params;
end

maskChannelCount = localCountParam(ctxParam, {'maskChannelCount','maskCount'}, 2, 1, 8);
scoreChannelCount = localCountParam(ctxParam, {'scoreChannelCount','channelCount'}, 4, 0, 12);

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

paramout = struct();
paramout.maskChannelCount = maskChannelCount;
paramout.scoreChannelCount = scoreChannelCount;
for i = 1:maskChannelCount
    paramout.(sprintf('mask%d_name', i)) = [listChannels listChannels{1}];
    paramout.(sprintf('mask%d_stat', i)) = true;
    paramout.(sprintf('mask%d_label', i)) = defaultMaskLabel(i);
    paramout.(sprintf('mask%d_backgroundLabel', i)) = {'auto','0','1','auto'};
    paramout.(sprintf('mask%d_scoreLabel', i)) = 'all';
end
for i = 1:scoreChannelCount
    paramout.(sprintf('channel%d_name', i)) = [listChannels listChannels{1}];
end
paramout.BrightestPixels = 20;
paramout.computeMaskCombinations = true;
paramout.tip = buildTips(maskChannelCount, scoreChannelCount);
end

function n = localCountParam(params, keys, defaultValue, minValue, maxValue)
    n = defaultValue;
    for i = 1:numel(keys)
        key = keys{i};
        if isstruct(params) && isfield(params, key) && ~isempty(params.(key))
            try
                n = double(params.(key));
                break;
            catch
                n = defaultValue;
            end
        end
    end
    if isempty(n) || ~isscalar(n) || ~isfinite(n)
        n = defaultValue;
    end
    n = min(maxValue, max(minValue, round(n)));
end

function label = defaultMaskLabel(i)
    defaults = {'cyto','nucleus'};
    if i <= numel(defaults)
        label = defaults{i};
    else
        label = sprintf('mask%d', i);
    end
end

function tip = buildTips(maskChannelCount, scoreChannelCount)
    tip = { ...
        'Number of mask channels used for measurements', ...
        'Number of image channels scored inside each selected mask' ...
        };
    for i = 1:maskChannelCount
        tip = [tip, { ...
            sprintf('Name of Mask channel #%d', i), ...
            sprintf('Compute detailed Mask #%d statistics (area, etc)', i), ...
            sprintf('Label of Mask channel #%d', i), ...
            sprintf('Background label for Mask channel #%d: auto, 0 for instance masks, or 1 for U-Net/pixel-classifier maps', i), ...
            sprintf('Foreground label to score for Mask channel #%d: all/empty/0 scores every non-background label separately; a numeric index scores only that label and enables mask combinations', i) ...
            }]; %#ok<AGROW>
    end
    for i = 1:scoreChannelCount
        tip{end+1} = sprintf('Channel name #%d to score', i); %#ok<AGROW>
    end
    tip{end+1} = 'Number of brightest pixels used for top-pixel intensity metrics';
    tip{end+1} = 'When multiple masks are selected, compute pairwise AND and NOT composite-mask fluorescence metrics';
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
