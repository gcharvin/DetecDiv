function bounds = parse(raw, varargin)
%TRAININGBOUNDS.PARSE Parse an inclusive frame interval or "all".

p = inputParser;
p.addParameter('FrameCount', [], @(x) isempty(x) || ...
    (isnumeric(x) && isscalar(x) && isfinite(x) && x >= 0));
p.parse(varargin{:});
frameCount = round(double(p.Results.FrameCount));

if isempty(raw)
    bounds = [];
    return;
end
if iscell(raw)
    if isempty(raw), bounds = []; return; end
    raw = raw{1};
end
if ischar(raw) || isstring(raw)
    text = strtrim(char(string(raw)));
    if isempty(text) || any(strcmpi(text, {'all','all frames','0','-1','[]'}))
        bounds = [];
        return;
    end
    values = regexp(text, '[-+]?\d+(?:\.\d+)?', 'match');
    if numel(values) ~= 2
        error('trainingBounds:InvalidText', ...
            'Enter an inclusive range such as 100:500, or "all".');
    end
    raw = [str2double(values{1}) str2double(values{2})];
end
if ~isnumeric(raw) && ~islogical(raw)
    error('trainingBounds:InvalidValue', ...
        'Frame bounds must be two frame numbers or "all".');
end
raw = double(raw(:).');
if isempty(raw) || (isscalar(raw) && raw(1) <= 0)
    bounds = [];
    return;
end
if numel(raw) ~= 2 || any(~isfinite(raw))
    error('trainingBounds:InvalidValue', ...
        'Frame bounds must contain exactly two finite frame numbers.');
end
bounds = round(raw);
if bounds(1) < 1 || bounds(2) < 1
    error('trainingBounds:InvalidValue', ...
        'Frame bounds must be positive; use "all" to clear them.');
end
if bounds(2) < bounds(1)
    bounds = bounds([2 1]);
end
if ~isempty(frameCount) && frameCount > 0 && any(bounds > frameCount)
    error('trainingBounds:OutOfRange', ...
        'This ROI contains %d frames; requested bounds are %d:%d.', ...
        frameCount, bounds(1), bounds(2));
end
end
