function detecdiv_require_toolbox(toolboxName, requiredFunction)
% detecdiv_require_toolbox  Fail early with a clear message for missing toolboxes.

    if nargin < 2
        requiredFunction = '';
    end

    installed = ver;
    installedNames = {installed.Name};
    if any(strcmpi(toolboxName, installedNames))
        return;
    end

    if strlength(string(requiredFunction)) > 0 && exist(char(string(requiredFunction)), 'file') == 2
        return;
    end

    error('detecdiv:MissingToolbox', ...
        ['DetecDiv requires %s for this feature. Install %s from MATLAB Add-On Explorer ' ...
        'or disable the feature that uses it.'], toolboxName, toolboxName);
end
