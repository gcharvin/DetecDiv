function [paramout, dataout, imageout] = process(param, roiobj, frames)
% combineMultipleChannels.process  Combine selected channels into one.

    if nargin == 0 || isempty(param)
        paramout = combineMultipleChannels.setparam();
        dataout = [];
        imageout = [];
        return;
    end

    if nargin < 3
        frames = []; %#ok<NASGU>
    end

    paramout = param;
    dataout  = [];
    imageout = [];

    if ~isfield(paramout, 'outputChannelName')
        paramout.outputChannelName = 'CombinedChannel';
    end

    fprintf('[combineMultipleChannels] ---- START output="%s" ----\n', string(paramout.outputChannelName));

    listChannels = {};
    if isfield(paramout, 'listChannelName')
        listChannels = paramout.listChannelName(1:end-1);
    end
    fprintf('[combineMultipleChannels] listChannels count=%d\n', numel(listChannels));

    cha = {};
    rgb = {};

    for i = 1:numel(listChannels)
        chName = listChannels{i};
        flagField = chName;
        rgbField  = ['RGB_' chName];

        if isfield(paramout, flagField) && isequal(paramout.(flagField), true)
            cha{end+1} = chName; %#ok<AGROW>

            if isfield(paramout, rgbField)
                rgb{end+1} = paramout.(rgbField); %#ok<AGROW>
            else
                rgb{end+1} = [1 1 1]; %#ok<AGROW>
                fprintf('[combineMultipleChannels] WARNING missing field "%s" -> using [1 1 1]\n', rgbField);
            end

            fprintf('[combineMultipleChannels] SELECT ch="%s" rgb=%s\n', chName, mat2str(rgb{end}));
        end
    end

    if isempty(cha)
        fprintf('[combineMultipleChannels] no channel selected -> no-op\n');
        dataout  = roiobj.data;
        imageout = roiobj.image;
        return
    end

    for k = 1:numel(rgb)
        if isempty(rgb{k}) || ~isnumeric(rgb{k})
            fprintf('[combineMultipleChannels] WARNING rgb{%d} invalid -> [1 1 1]\n', k);
            rgb{k} = [1 1 1];
        end
        if isvector(rgb{k}) && numel(rgb{k}) == 3
            rgb{k} = reshape(rgb{k}, 1, 3);
        end
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
