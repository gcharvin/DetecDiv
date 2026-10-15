function workDir = createShortWorkDir(roots)
%CREATESHORTWORKDIR Create a writable, unique directory for Python exchange.
% Prefer MATLAB's native temporary directory, which the Hub scopes to the
% job attempt. On Windows that directory can itself be too long; the normal
% local user temporary directory provides a second candidate. No project,
% node or ROI names are appended to the unique temporary directory name.
if nargin < 1
    roots = {tempdir};
    if ispc && ~isempty(getenv('LOCALAPPDATA'))
        roots{end+1} = fullfile(getenv('LOCALAPPDATA'), 'Temp');
    end
elseif ischar(roots) || isstring(roots)
    roots = cellstr(roots);
end

leafName = 'classify_cellposesam_config.json';
maxPathLength = 240;
details = {};
for rootIdx = 1:numel(roots)
    root = char(string(roots{rootIdx}));
    if isempty(strtrim(root))
        continue;
    end
    % A local scratch directory avoids both long UNC paths and dependence
    % on a network logon in the separate Python process.
    if ispc && isempty(regexp(root, '^[A-Za-z]:[\\/]', 'once'))
        details{end+1} = [root ' (not a local absolute path)']; %#ok<AGROW>
        continue;
    end
    if numel(root) + 1 + numel(leafName) > maxPathLength
        details{end+1} = [root ' (path exceeds 240 characters)']; %#ok<AGROW>
        continue;
    end
    try
        candidate = tempname(root);
    catch ME
        details{end+1} = [root ' (' ME.message ')']; %#ok<AGROW>
        continue;
    end
    if numel(fullfile(candidate, leafName)) > maxPathLength
        details{end+1} = [root ' (path exceeds 240 characters)']; %#ok<AGROW>
        continue;
    end
    if exist(candidate, 'file') || exist(candidate, 'dir')
        continue;
    end
    [ok, msg] = mkdir(candidate);
    if ~ok
        details{end+1} = [root ' (' msg ')']; %#ok<AGROW>
        continue;
    end
    probePath = fullfile(candidate, leafName);
    [fid, msg] = fopen(probePath, 'w');
    if fid < 0
        try, rmdir(candidate); catch, end
        details{end+1} = [root ' (' msg ')']; %#ok<AGROW>
        continue;
    end
    fclose(fid);
    delete(probePath);
    workDir = candidate;
    return;
end
error('cellposesam:NoShortWorkDir', ...
    'No writable local temporary directory fits the Windows path limit. Checked: %s', ...
    strjoin(details, '; '));
end
