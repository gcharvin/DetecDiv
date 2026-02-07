function paramout = setparam()
% combineMultipleChannels.setparam  Default parameters for channel combining.

    listChannels = listAvailableChannels;
    if isempty(listChannels)
        listChannels = {''};
    end

    paramout = struct();
    tip = {};
    cc = 1;

    for i = 1:numel(listChannels)
        ch = listChannels{i};

        tip{cc} = 'Check this box if this channel should be combined into a new channel'; %#ok<AGROW>
        paramout.(ch) = false; %#ok<AGROW>
        cc = cc + 1;

        tip{cc} = 'Enter the RGB triplet for this channel in the output channel eg: [1 0 0]; Discard if channel is not selected'; %#ok<AGROW>
        paramout.(['RGB_' ch]) = [0 0 0]; %#ok<AGROW>
        cc = cc + 1;
    end

    paramout.outputChannelName = 'CombinedChannel';
    tip{end+1} = 'Please enter the name of the output channel'; %#ok<AGROW>

    % Keep legacy GUI behavior: listChannelName has a duplicate last entry
    paramout.listChannelName = [listChannels listChannels{end}];
    tip{end+1} = 'Do not edit'; %#ok<AGROW>

    paramout.debug = false;
    tip{end+1} = 'Optional: set debug=true for verbose console logs'; %#ok<AGROW>

    paramout.tip = tip;
end
