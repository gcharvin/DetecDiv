function p = setparam(p)
% roiGrid.setparam  Default parameters for grid/full-frame ROI generation.

    if nargin < 1 || isempty(p) || ~isstruct(p)
        p = struct();
    end

    defaults = struct( ...
        'fovIndex', [], ...
        'mode', 'fullframe', ...
        'gridCount', 1, ...
        'keepExisting', false, ...
        'skipExisting', false, ...
        'errorOnExisting', false);

    fn = fieldnames(defaults);
    for i = 1:numel(fn)
        k = fn{i};
        if ~isfield(p, k) || isempty(p.(k))
            p.(k) = defaults.(k);
        end
    end

    p.mode = normalizeModeLocal(p.mode);
    if isempty(p.gridCount) || ~isscalar(p.gridCount) || ~isfinite(p.gridCount) || p.gridCount < 1
        p.gridCount = 1;
    end
    p.gridCount = round(double(p.gridCount));
end

function mode = normalizeModeLocal(mode)
    mode = lower(strrep(char(string(mode)), ' ', ''));
    if any(strcmp(mode, {'fullframe', 'full', 'single'}))
        mode = 'fullframe';
    elseif any(strcmp(mode, {'grid', 'tiling', 'tile'}))
        mode = 'grid';
    else
        mode = 'fullframe';
    end
end
