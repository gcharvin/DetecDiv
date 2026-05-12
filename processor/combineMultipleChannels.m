function [paramout,dataout,imageout] = combineMultipleChannels(param, roiobj, frames)

environment = 'pc'; %#ok<NASGU>

if nargin==0
    listChannels = listAvailableChannels;
    listChannels = reshape(listChannels, 1, []);
    if isempty(listChannels)
        listChannels = {'Channel1'};
    end

    channelChoices = [{'none'} listChannels];
    defaultRGB = {
        [1 0 0]
        [0 1 0]
        [0 0 1]
        [1 1 0]
        [1 0 1]
        };

    paramout = [];
    tip = {};
    cc = 1;

    nSlots = max(5, min(numel(listChannels), 8));
    for i = 1:nSlots
        if i <= numel(listChannels)
            defaultChannel = listChannels{i};
        else
            defaultChannel = 'none';
        end

        tip{cc} = 'Select a channel to combine, or none to ignore this slot'; cc=cc+1;
        paramout.(sprintf('Channel%d', i)) = [channelChoices defaultChannel];

        tip{cc} = 'Enter the RGB triplet for this channel in the output channel eg: [1 0 0]; Discard if channel is none'; cc=cc+1;
        paramout.(sprintf('RGB_Channel%d', i)) = defaultRGB{min(i, numel(defaultRGB))};
    end

    paramout.outputChannelName = 'CombinedChannel';
    tip{end+1} = 'Please enter the name of the output channel';

    paramout.listChannelName = [listChannels listChannels{end}];
    tip{end+1} = 'Do not edit';

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

[cha, rgb] = collectSelectedChannels(param);

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

function [cha, rgb] = collectSelectedChannels(param)
cha = {};
rgb = {};

slotFields = regexp(fieldnames(param), '^Channel\d+$', 'match');
slotFields = [slotFields{:}];

if ~isempty(slotFields)
    slotNums = cellfun(@(s) sscanf(s, 'Channel%d'), slotFields);
    [~, ord] = sort(slotNums);
    slotFields = slotFields(ord);

    for i = 1:numel(slotFields)
        chName = selectedChannelValue(param.(slotFields{i}));
        if isempty(chName) || strcmpi(chName, 'none')
            continue;
        end

        rgbField = sprintf('RGB_%s', slotFields{i});
        cha{end+1} = chName; %#ok<AGROW>
        if isfield(param, rgbField)
            rgb{end+1} = param.(rgbField); %#ok<AGROW>
        else
            rgb{end+1} = [1 1 1]; %#ok<AGROW>
            fprintf('[combineMultipleChannels] WARNING missing field "%s" -> using [1 1 1]\n', rgbField);
        end
        fprintf('[combineMultipleChannels] SELECT ch="%s" rgb=%s\n', chName, mat2str(rgb{end}));
    end
    return;
end

% Legacy schema: one logical field per channel name. This is kept for old
% saved processors whose channel names were valid MATLAB struct fields.
listChannels = {};
if isfield(param, 'listChannelName') && iscell(param.listChannelName)
    listChannels = param.listChannelName(1:end-1);
end
fprintf('[combineMultipleChannels] legacy listChannels count=%d\n', numel(listChannels));

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
end

function chName = selectedChannelValue(value)
chName = '';
if iscell(value)
    if isempty(value)
        return;
    end
    chName = char(string(value{end}));
elseif ischar(value) || isstring(value)
    chName = char(string(value));
end
end
