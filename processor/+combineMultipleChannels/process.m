function [paramout, dataout, imageout] = process(param, roiobj, ctx)
% combineMultipleChannels.process  Combine selected channels into one.
% Supports ctx struct for pipeline-style execution.

    if nargin < 3
        ctx = struct();
    elseif ~isstruct(ctx)
        % Back-compat: third argument was "frames" (unused here)
        ctx = struct('frames', ctx);
    end

    if nargin == 0 || isempty(param)
        paramout = combineMultipleChannels.setparam(ctx);
        dataout = [];
        imageout = [];
        return;
    end

    paramout = param;
    dataout  = [];
    imageout = [];

    if ~isfield(paramout, 'outputChannelName')
        paramout.outputChannelName = 'CombinedChannel';
    end
    if isfield(ctx,'outputName') && ~isempty(ctx.outputName)
        if isempty(paramout.outputChannelName)
            paramout.outputChannelName = ctx.outputName;
        end
    end
    if isfield(paramout,'outputChannelName')
        paramout.outputChannelName = strtrim(paramout.outputChannelName);
    end

    fprintf('[combineMultipleChannels] ---- START output="%s" ----\n', string(paramout.outputChannelName));

    maxSlots = 5;
    cha = {};
    rgb = {};

    for i = 1:maxSlots
        key = sprintf('Channel%d', i);
        rgbKey = sprintf('RGB_Channel%d', i);

        if ~isfield(paramout, key)
            continue;
        end

        chVal = paramout.(key);
        if iscell(chVal)
            chName = chVal{end};
        else
            chName = char(string(chVal));
        end

        if isempty(chName) || strcmpi(chName,'none')
            continue;
        end

        cha{end+1} = chName; %#ok<AGROW>

        if isfield(paramout, rgbKey)
            rgbVal = paramout.(rgbKey);
        else
            rgbVal = [1 1 1];
            fprintf('[combineMultipleChannels] WARNING missing field "%s" -> using [1 1 1]\n', rgbKey);
        end

        if ischar(rgbVal) || isstring(rgbVal)
            try
                rgbVal = str2num(char(string(rgbVal))); %#ok<ST2NM>
            catch
            end
        end
        if isempty(rgbVal) || ~isnumeric(rgbVal)
            rgbVal = [1 1 1];
        end
        if isvector(rgbVal) && numel(rgbVal) == 3
            rgbVal = reshape(rgbVal, 1, 3);
        end

        rgb{end+1} = rgbVal; %#ok<AGROW>
        fprintf('[combineMultipleChannels] SELECT ch="%s" rgb=%s\n', chName, mat2str(rgbVal));
    end

    if isempty(cha)
        error('combineMultipleChannels:NoChannel', ...
            'No input channel selected. Please choose at least one channel.');
    end

    doDebug = false;
    if isfield(paramout,'debug')
        doDebug = logical(paramout.debug);
    end

    fprintf('[combineMultipleChannels] calling roiobj.combineChannels with %d channels (debug=%d)\n', numel(cha), doDebug);

    roiobj.combineChannels('channels', cha, 'rgb', rgb, 'name', paramout.outputChannelName, 'debug', doDebug);

    dataout  = roiobj.data;
    imageout = roiobj.image;

    fprintf('[combineMultipleChannels] ---- DONE output="%s" ----\n', string(paramout.outputChannelName));
end
