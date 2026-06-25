function tfm = score_channelValueTransform(roiObj, channelIdx)
% score_channelValueTransform Return display value transform for a logical channel.

tfm = struct( ...
    'mode', 'raw', ...
    'unit', 'raw', ...
    'physicalRange', [0 65535], ...
    'encodedRange', [0 65535], ...
    'transform', 'linear');

try
    if nargin < 2 || isempty(channelIdx) || channelIdx < 1
        return;
    end
    d = roiObj.display;
    nCh = 0;
    if isfield(d, 'channel') && ~isempty(d.channel)
        nCh = numel(d.channel);
    end
    if channelIdx > nCh
        return;
    end

    vt = [];
    if isfield(d, 'valueTransform') && ~isempty(d.valueTransform)
        vt = d.valueTransform;
    elseif isfield(d, 'valueTransforms') && ~isempty(d.valueTransforms)
        vt = d.valueTransforms;
    end
    if isempty(vt) || numel(vt) < channelIdx || ~isstruct(vt)
        return;
    end

    item = vt(channelIdx);
    mode = lower(strtrim(localGetChar(item, {'mode', 'value_mode'}, 'raw')));
    if ~strcmp(mode, 'physical')
        return;
    end

    unit = localGetChar(item, {'unit', 'physical_unit'}, 'physical');
    pr = localGetNumeric(item, {'physicalRange', 'physical_range'}, []);
    er = localGetNumeric(item, {'encodedRange', 'encoded_range'}, []);
    tr = localGetChar(item, {'transform', 'physical_transform'}, 'linear');
    if numel(pr) ~= 2 || numel(er) ~= 2 || any(~isfinite(pr)) || any(~isfinite(er)) || pr(2) <= pr(1) || er(2) <= er(1)
        return;
    end

    tfm.mode = 'physical';
    tfm.unit = char(string(unit));
    tfm.physicalRange = double(pr(:).');
    tfm.encodedRange = double(er(:).');
    tfm.transform = char(string(tr));
catch
    tfm = struct( ...
        'mode', 'raw', ...
        'unit', 'raw', ...
        'physicalRange', [0 65535], ...
        'encodedRange', [0 65535], ...
        'transform', 'linear');
end
end

function out = localGetChar(s, names, defaultValue)
out = defaultValue;
for i = 1:numel(names)
    nm = names{i};
    if isfield(s, nm) && ~isempty(s.(nm))
        out = char(string(s.(nm)));
        return;
    end
end
end

function out = localGetNumeric(s, names, defaultValue)
out = defaultValue;
for i = 1:numel(names)
    nm = names{i};
    if isfield(s, nm) && ~isempty(s.(nm))
        out = double(s.(nm));
        return;
    end
end
end
