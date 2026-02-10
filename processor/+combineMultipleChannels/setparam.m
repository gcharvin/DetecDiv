function paramout = setparam(ctx)
% combineMultipleChannels.setparam  Default parameters for channel combining.
% ctx.channels (optional) provides channel list from selected ROIs.

    if nargin < 1
        ctx = struct();
    end

    listChannels = {};
    if isfield(ctx,'channels')
        listChannels = ctx.channels;
    end
    if isempty(listChannels) && ~(isfield(ctx,'useProvidedChannels') && ctx.useProvidedChannels)
        listChannels = listAvailableChannels;
    end
    if isempty(listChannels)
        listChannels = {''};
    end

    % dropdown choices (last entry is selected)
    choices = [{'none'}, listChannels];

    paramout = struct();
    tip = {};

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
        tip{end+1} = 'Select a channel to combine (none = skip)'; %#ok<AGROW>
        paramout.(key) = [choices {'none'}]; %#ok<AGROW>

        rgbKey = sprintf('RGB_Channel%d', i);
        tip{end+1} = 'RGB triplet for this channel eg: [1 0 0]'; %#ok<AGROW>
        if i <= size(defaultRGB,1)
            paramout.(rgbKey) = defaultRGB(i,:); %#ok<AGROW>
        else
            paramout.(rgbKey) = [1 1 1]; %#ok<AGROW>
        end
    end

    paramout.outputChannelName = 'CombinedChannel';
    tip{end+1} = 'Please enter the name of the output channel'; %#ok<AGROW>

    paramout.debug = false;
    tip{end+1} = 'Optional: set debug=true for verbose console logs'; %#ok<AGROW>

    paramout.tip = tip;
end
