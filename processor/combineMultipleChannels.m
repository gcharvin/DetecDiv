function [paramout,dataout,imageout] = combineMultipleChannels(param, roiobj, frames)

environment = 'pc'; %#ok<NASGU>

if nargin==0
    listChannels = listAvailableChannels;
    paramout = [];

    tip = {};
    cc = 1;
    for i = 1:numel(listChannels)
        tip{cc} = 'Check this box if this channel should be combined into a new channel'; cc=cc+1;
        paramout.(listChannels{i}) = false;

        tip{cc} = 'Enter the RGB triplet for this channel in the output channel eg: [1 0 0]; Discard if channel is not selected'; cc=cc+1;
        paramout.(['RGB_' listChannels{i}]) = [0 0 0];
    end

    paramout.outputChannelName = 'CombinedChannel';
    tip{end+1} = 'Please enter the name of the output channel';

    paramout.listChannelName = [listChannels listChannels{end}];
    tip{end+1} = 'Do not edit';

    % optional (not used by GUI unless you add it)
    paramout.debug = false;
    tip{end+1} = 'Optional: set debug=true for verbose console logs';

    paramout.tip = tip;
    return;
else
    paramout = param;
end

dataout  = [];
imageout = [];

fprintf('[combineMultipleChannels] ---- START output="%s" ----\n', string(param.outputChannelName));

% get listChannels
listChannels = param.listChannelName(1:end-1);
fprintf('[combineMultipleChannels] listChannels count=%d\n', numel(listChannels));

% collect selection
cha = {};
rgb = {};

for i = 1:numel(listChannels)
    chName = listChannels{i};
    flagField = chName;
    rgbField  = ['RGB_' chName];

    if isfield(param, flagField) && isequal(param.(flagField), true)
        cha{end+1} = chName; %#ok<AGROW>

        if isfield(param, rgbField)
            rgb{end+1} = param.(rgbField); %#ok<AGROW>
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

% sanitize rgb
for k = 1:numel(rgb)
    if isempty(rgb{k}) || ~isnumeric(rgb{k})
        fprintf('[combineMultipleChannels] WARNING rgb{%d} invalid -> [1 1 1]\n', k);
        rgb{k} = [1 1 1];
    end
    if isvector(rgb{k}) && numel(rgb{k})==3
        rgb{k} = reshape(rgb{k},1,3);
    end
end

doDebug = false;
if isfield(param,'debug')
    doDebug = logical(param.debug);
end

fprintf('[combineMultipleChannels] calling roiobj.combineChannels with %d channels (debug=%d)\n', numel(cha), doDebug);

roiobj.combineChannels('channels', cha, 'rgb', rgb, 'name', param.outputChannelName, 'debug', doDebug);

dataout  = roiobj.data;
imageout = roiobj.image;

fprintf('[combineMultipleChannels] ---- DONE output="%s" ----\n', string(param.outputChannelName));

end
