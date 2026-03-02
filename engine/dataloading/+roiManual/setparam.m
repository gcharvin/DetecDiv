function p = setparam(p)
% roiManual.setparam  Default parameters for manual ROI editing.

    if nargin < 1 || isempty(p) || ~isstruct(p)
        p = struct();
    end

    defaults = struct( ...
        'fovIndex', [], ...
        'keepExisting', false, ...
        'openFirstOnly', true);

    fn = fieldnames(defaults);
    for i = 1:numel(fn)
        k = fn{i};
        if ~isfield(p, k) || isempty(p.(k))
            p.(k) = defaults.(k);
        end
    end
end
