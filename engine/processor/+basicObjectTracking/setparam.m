function paramout = setparam(ctx)
% basicObjectTracking.setparam  Default parameters for basic object tracking.
% ctx.channels (optional) provides channel list from selected ROIs.

    if nargin < 1
        ctx = struct();
    end

    listChannels = {};
    if isfield(ctx,'channels')
        listChannels = normalizeChannelList(ctx.channels);
    end
    if isempty(listChannels) && ~(isfield(ctx,'useProvidedChannels') && ctx.useProvidedChannels)
        try
            listChannels = normalizeChannelList(listAvailableChannels);
        catch
            listChannels = {};
        end
    end
    if isempty(listChannels)
        listChannels = {''};
    end

    % Dropdown choices (last entry is selected).
    choices = [{'none'}, listChannels];

    % Preferred input channel if available.
    preferred = 'results_segcell_simple_3';
    if ~any(strcmp(listChannels, preferred))
        if ~isempty(listChannels) && ~isempty(listChannels{1})
            preferred = listChannels{1};
        else
            preferred = 'none';
        end
    end

    paramout = struct();
    tip = {};

    paramout.inputChannelName = [choices {preferred}];
    tip{end+1} = 'Select a labeled/segmented channel to track (none = skip)'; %#ok<AGROW>

    paramout.coefDist = 1;
    tip{end+1} = 'Distance weight (higher = stronger distance penalty)'; %#ok<AGROW>

    paramout.coefSize = 0.5;
    tip{end+1} = 'Size/area weight (higher = penalize size mismatch)'; %#ok<AGROW>

    paramout.coefIoU = 0.0;
    tip{end+1} = 'IoU weight (higher = favor spatial overlap); set >0 to enable IoU term'; %#ok<AGROW>

    paramout.maxRelativeDistance = 2;
    tip{end+1} = 'Maximum relative distance (in cell-size units) to allow linking'; %#ok<AGROW>

    % Input interpretation mode: auto/binary/label
    paramout.inputMode = {'auto','binary','label','auto'};
    tip{end+1} = 'Input mode: auto (detect), binary, or label'; %#ok<AGROW>

    if strcmp(preferred, 'none') || isempty(preferred)
        paramout.outputChannelName = 'track_objects';
    else
        paramout.outputChannelName = ['track_' preferred];
    end
    tip{end+1} = 'Output channel name for tracking labels'; %#ok<AGROW>

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
