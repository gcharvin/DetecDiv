function target = classifierDefaultExecutionTarget(classifierPath, hub)
%classifierDefaultExecutionTarget  Pick a runnable default for training.
%
% Hub is appropriate only when the classifier path is already server-visible
% or can be translated through the configured client/server path mappings.
% Local-only Windows paths must stay on Local MATLAB.

if nargin < 1
    classifierPath = '';
end
if nargin < 2 || isempty(hub)
    try
        hub = detecdiv_hub_settings_get();
    catch
        hub = struct();
    end
end

classifierPath = strtrim(char(string(classifierPath)));
target = 'local';
if isempty(classifierPath)
    return;
end

serverComparable = strrep(classifierPath, '\', '/');
if startsWith(serverComparable, '/')
    target = 'hub';
    return;
end

try
    ctx = struct('hub', hub);
    [mappedPath, mapped] = detecdiv_paths_map_module_path( ...
        classifierPath, ctx, 'server');
    mappedPath = strrep(char(string(mappedPath)), '\', '/');
    if mapped && startsWith(mappedPath, '/')
        target = 'hub';
    end
catch
    % A missing/invalid mapping is a local execution decision, not a launch
    % error. The normal pipeline preflight will still validate explicit Hub
    % selections.
end
end
