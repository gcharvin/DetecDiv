function frames = normalizeTrainingFrameSelection(spec, frameCount, varargin)
% normalizeTrainingFrameSelection  Normalize training frame selectors.
%
% Accepted selectors:
%   [] / "all" / 0 / -1  -> 1:frameCount
%   "1:10:200"           -> numeric MATLAB-style range
%   "1,5,8,20"           -> explicit list
%   numeric/logical      -> filtered positive frame indices
%   cell                 -> per-ROI selector, indexed by RoiPosition
%   struct               -> fields roi<N>, <split>_roi<N>, split name, or frames

p = inputParser;
p.addParameter('RoiId', [], @(x) isempty(x) || isnumeric(x));
p.addParameter('RoiPosition', [], @(x) isempty(x) || isnumeric(x));
p.addParameter('SplitName', '', @(x) ischar(x) || isstring(x));
p.parse(varargin{:});

roiId = p.Results.RoiId;
roiPosition = p.Results.RoiPosition;
splitName = char(string(p.Results.SplitName));

if isempty(spec)
    frames = 1:frameCount;
    return;
end

if isstruct(spec)
    candidates = {};
    if ~isempty(roiId)
        candidates{end+1} = sprintf('roi%d', round(double(roiId)));
        if ~isempty(splitName)
            candidates{end+1} = sprintf('%s_roi%d', splitName, round(double(roiId)));
        end
    end
    if ~isempty(splitName)
        candidates{end+1} = splitName;
    end
    candidates{end+1} = 'frames';

    selected = [];
    for k = 1:numel(candidates)
        if isfield(spec, candidates{k})
            selected = spec.(candidates{k});
            break;
        end
    end
    frames = normalizeTrainingFrameSelection(selected, frameCount, varargin{:});
    return;
end

if iscell(spec)
    if ~isempty(roiPosition) && numel(spec) >= roiPosition && ~isempty(spec{roiPosition})
        frames = normalizeTrainingFrameSelection(spec{roiPosition}, frameCount, varargin{:});
    else
        frames = 1:frameCount;
    end
    return;
end

if (isnumeric(spec) || islogical(spec)) && isscalar(spec) && double(spec) <= 0
    frames = 1:frameCount;
    return;
end

if ischar(spec) || isstring(spec)
    txt = strtrim(char(string(spec)));
    if isempty(txt) || any(strcmpi(txt, {'all', '0', '-1'}))
        frames = 1:frameCount;
        return;
    end
    txt = strrep(txt, ',', ' ');
    frames = str2num(txt); %#ok<ST2NM>
elseif islogical(spec)
    frames = find(spec);
else
    frames = double(spec);
end

frames = unique(round(frames(:).'), 'stable');
frames = frames(isfinite(frames) & frames >= 1 & frames <= frameCount);
end
