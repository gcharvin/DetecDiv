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

    mode = 'additive';
    if isfield(paramout, 'mode') && ~isempty(paramout.mode)
        mode = lower(strtrim(char(string(paramout.mode))));
    end
    switch mode
        case {'add','sum','rgb'}
            mode = 'additive';
        case {'subtract','difference'}
            mode = 'subtraction';
        case {'divide','ratio','quotient'}
            mode = 'division';
        case {'additive','subtraction','division'}
            % keep
        otherwise
            warning('[combineMultipleChannels] Unknown mode "%s" -> using additive.', mode);
            mode = 'additive';
    end
    paramout.mode = mode;
    if any(strcmp(mode, {'subtraction','division'}))
        paramout.requiredChannelCount = 2;
    end

    fprintf('[combineMultipleChannels] ---- START output="%s" ----\n', string(paramout.outputChannelName));
    fprintf('[combineMultipleChannels] mode="%s"\n', mode);

    maxSlots = 5;
    if any(strcmp(mode, {'subtraction','division'}))
        maxSlots = 2;
    end
    if isfield(paramout, 'requiredChannelCount') && ~isempty(paramout.requiredChannelCount)
        try
            requestedSlots = double(paramout.requiredChannelCount);
        catch
            requestedSlots = 0;
        end
        if isscalar(requestedSlots) && isfinite(requestedSlots) && requestedSlots > 0
            if strcmp(mode, 'additive')
                maxSlots = min(maxSlots, max(1, round(requestedSlots)));
            end
        end
    end
    cha = {};
    rgb = {};
    offsets = {};

    for i = 1:maxSlots
        key = sprintf('Channel%d', i);
        rgbKey = sprintf('RGB_Channel%d', i);
        offsetKey = sprintf('Offset_Channel%d', i);

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

        if strcmp(mode, 'additive')
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
        else
            offsetVal = 0;
            if isfield(paramout, offsetKey)
                offsetVal = paramout.(offsetKey);
            end
            if ischar(offsetVal) || isstring(offsetVal)
                try
                    offsetVal = str2double(char(string(offsetVal)));
                catch
                    offsetVal = 0;
                end
            end
            if isempty(offsetVal) || ~isnumeric(offsetVal) || ~isscalar(offsetVal) || ~isfinite(double(offsetVal))
                offsetVal = 0;
            end
            offsets{end+1} = double(offsetVal); %#ok<AGROW>
            fprintf('[combineMultipleChannels] SELECT ch="%s" offset=%g\n', chName, double(offsetVal));
        end
    end

    if isempty(cha)
        error('combineMultipleChannels:NoChannel', ...
            'No input channel selected. Please choose at least one channel.');
    end

    requiredCount = 0;
    if isfield(paramout, 'requiredChannelCount') && ~isempty(paramout.requiredChannelCount)
        requiredCount = double(paramout.requiredChannelCount);
        if ~isfinite(requiredCount)
            requiredCount = 0;
        end
        requiredCount = max(0, round(requiredCount));
    end
    if strcmp(mode, 'additive') && requiredCount > 0 && numel(cha) ~= requiredCount
        error('combineMultipleChannels:WrongChannelCount', ...
            'Expected exactly %d selected channel(s), but got %d.', requiredCount, numel(cha));
    elseif any(strcmp(mode, {'subtraction','division'})) && numel(cha) ~= 2
        error('combineMultipleChannels:WrongChannelCount', ...
            'Mode "%s" requires exactly 2 selected channels, but got %d.', mode, numel(cha));
    end

    doDebug = false;
    if isfield(paramout,'debug')
        doDebug = logical(paramout.debug);
    end

    fprintf('[combineMultipleChannels] calling roiobj.combineChannels with %d channels (debug=%d)\n', numel(cha), doDebug);

    combineArgs = {'channels', cha, 'name', paramout.outputChannelName, 'debug', doDebug, 'mode', mode};
    if strcmp(mode, 'additive')
        combineArgs = [combineArgs, {'rgb', rgb}];
    else
        combineArgs = [combineArgs, {'offsets', offsets}];
    end
    roiobj.combineChannels(combineArgs{:});

    dataout  = roiobj.data;
    imageout = roiobj.image;

    fprintf('[combineMultipleChannels] ---- DONE output="%s" ----\n', string(paramout.outputChannelName));
end
