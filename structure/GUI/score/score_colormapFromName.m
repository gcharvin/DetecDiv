function cmap = score_colormapFromName(name, n)
% score_colormapFromName Return a MATLAB colormap by name, with a safe fallback.

if nargin < 2 || isempty(n)
    n = 256;
end
n = max(2, round(double(n)));

name = lower(strtrim(char(string(name))));
if isempty(name)
    name = 'parula';
end

allowed = {'parula','jet','turbo','hot','gray','bone','copper','pink','spring', ...
    'summer','autumn','winter','cool','hsv'};
if ~any(strcmp(name, allowed))
    error('score_colormapFromName:UnknownColormap', ...
        'Unknown colormap "%s". Use one of: %s.', name, strjoin(allowed, ', '));
end

try
    cmap = feval(name, n);
catch ME
    if strcmp(name, 'turbo')
        cmap = jet(n);
    else
        rethrow(ME);
    end
end

cmap = min(max(double(cmap), 0), 1);
end
