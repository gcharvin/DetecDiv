function spec = score_channelColorSpec(displayStruct, channelIndex)
% score_channelColorSpec Human-readable color field for Score channel table.

spec = '1.00 1.00 1.00';
if nargin < 2 || isempty(displayStruct) || channelIndex < 1
    return;
end

mode = 'rgb';
if isfield(displayStruct, 'colorMode') && numel(displayStruct.colorMode) >= channelIndex
    mode = lower(strtrim(char(string(displayStruct.colorMode{channelIndex}))));
end

if strcmp(mode, 'colormap')
    cmapName = 'parula';
    if isfield(displayStruct, 'colormapName') && numel(displayStruct.colormapName) >= channelIndex && ...
            strlength(string(displayStruct.colormapName{channelIndex})) > 0
        cmapName = char(string(displayStruct.colormapName{channelIndex}));
    end
    spec = cmapName;
    return;
end

if isfield(displayStruct, 'rgb') && size(displayStruct.rgb, 1) >= channelIndex
    rgb = double(displayStruct.rgb(channelIndex, :));
    spec = sprintf('%.2f %.2f %.2f', rgb(1), rgb(2), rgb(3));
end
end
