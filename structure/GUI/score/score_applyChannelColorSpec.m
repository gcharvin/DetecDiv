function [ok, message] = score_applyChannelColorSpec(roiObj, channelIndex, spec)
% score_applyChannelColorSpec Set a channel color from an RGB triplet or colormap name.

ok = false;
message = '';

if nargin < 3 || isempty(roiObj) || channelIndex < 1
    message = 'Invalid channel.';
    return;
end

spec = strtrim(char(string(spec)));
if isempty(spec)
    message = 'Color spec cannot be empty.';
    return;
end

nCh = numel(roiObj.display.channel);
roiObj.display = localEnsureColorFields(roiObj.display, nCh);

rgbValues = sscanf(strrep(spec, ',', ' '), '%f');
if numel(rgbValues) == 3 && all(isfinite(rgbValues)) && all(rgbValues >= 0 & rgbValues <= 1)
    roiObj.display.rgb(channelIndex, :) = rgbValues(:).';
    roiObj.display.colorMode{channelIndex} = 'rgb';
    roiObj.display.colormapName{channelIndex} = '';
    ok = true;
    return;
end

try
    score_colormapFromName(spec, 8);
    roiObj.display.colorMode{channelIndex} = 'colormap';
    roiObj.display.colormapName{channelIndex} = lower(spec);
    ok = true;
catch
    message = ['Use an RGB triplet between 0 and 1, or a colormap name: ' ...
        'parula, jet, turbo, hot, gray, bone, copper, pink, spring, summer, autumn, winter, cool, hsv.'];
end
end

function displayStruct = localEnsureColorFields(displayStruct, nCh)
if ~isfield(displayStruct, 'rgb') || size(displayStruct.rgb, 1) < nCh
    rgb = [1 1 1];
    if isfield(displayStruct, 'rgb') && ~isempty(displayStruct.rgb)
        rgb = displayStruct.rgb;
    end
    if size(rgb, 1) < nCh
        rgb(end+1:nCh,:) = repmat([1 1 1], nCh - size(rgb, 1), 1);
    end
    displayStruct.rgb = rgb(1:nCh,:);
end
displayStruct.colorMode = localEnsureCell(displayStruct, 'colorMode', nCh, 'rgb');
displayStruct.colormapName = localEnsureCell(displayStruct, 'colormapName', nCh, '');
end

function value = localEnsureCell(displayStruct, fieldName, nCh, defaultValue)
if isfield(displayStruct, fieldName) && ~isempty(displayStruct.(fieldName))
    rawValue = displayStruct.(fieldName);
    if isstring(rawValue)
        value = cellstr(rawValue(:).');
    elseif ischar(rawValue)
        value = {rawValue};
    elseif iscell(rawValue)
        value = rawValue(:).';
    else
        value = {};
    end
else
    value = {};
end
if numel(value) < nCh
    value(end+1:nCh) = {defaultValue};
elseif numel(value) > nCh
    value = value(1:nCh);
end
end
