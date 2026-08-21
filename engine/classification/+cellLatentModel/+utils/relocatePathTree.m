function [value,audit] = relocatePathTree(value,sourceRoot,targetRoot)
%RELOCATEPATHTREE Rewrite paths after an atomic directory finalization.
%   VALUE = RELOCATEPATHTREE(VALUE,SOURCEROOT,TARGETROOT) recursively walks
%   structs, cells, character vectors and string arrays. Paths equal to or
%   below SOURCEROOT are rewritten below TARGETROOT.
%
%   Comparison is separator-independent. Windows drive and UNC paths are
%   also compared case-insensitively, even when this helper is exercised on
%   another platform. A path-prefix boundary is required, so relocating
%   "bundle.partial_x" cannot accidentally rewrite
%   "bundle.partial_xyz".
%
%   [VALUE,AUDIT] additionally reports how many values were inspected and
%   rewritten, and whether any source-root paths remain. AUDIT deliberately
%   omits the transient source path so it can be embedded in a finalized
%   immutable manifest without preserving a stale .partial_UUID reference.

sourceRoot = canonicalRoot(sourceRoot);
targetRoot = canonicalRoot(targetRoot);
if isempty(sourceRoot) || isempty(targetRoot)
    error('cellLatentModel:InvalidRelocationRoot', ...
        'Path relocation requires non-empty source and target roots.');
end
if pathsEqual(sourceRoot,targetRoot)
    error('cellLatentModel:InvalidRelocationRoot', ...
        'Path relocation source and target roots must be distinct.');
end

[value,stats] = relocateValue(value,sourceRoot,targetRoot);
audit = struct( ...
    'schema_version',1, ...
    'target_root',targetRoot, ...
    'checked_value_count',stats.checked, ...
    'relocated_path_count',stats.relocated, ...
    'source_paths_remaining',stats.remaining, ...
    'verified_no_transient_paths',stats.remaining == 0);
end

function [value,stats] = relocateValue(value,sourceRoot,targetRoot)
stats = emptyStats();
if isstruct(value)
    names = fieldnames(value);
    for row = 1:numel(value)
        for fieldIndex = 1:numel(names)
            name = names{fieldIndex};
            [value(row).(name),child] = relocateValue( ...
                value(row).(name),sourceRoot,targetRoot);
            stats = addStats(stats,child);
        end
    end
elseif iscell(value)
    for index = 1:numel(value)
        [value{index},child] = relocateValue( ...
            value{index},sourceRoot,targetRoot);
        stats = addStats(stats,child);
    end
elseif isstring(value)
    for index = 1:numel(value)
        if ismissing(value(index)), continue; end
        [text,child] = relocateText(char(value(index)), ...
            sourceRoot,targetRoot);
        value(index) = string(text);
        stats = addStats(stats,child);
    end
elseif ischar(value)
    % Manifests use character vectors for scalar paths. Leave legacy char
    % matrices alone rather than flattening them into an invalid path.
    if isrow(value) || isempty(value)
        [value,stats] = relocateText(value,sourceRoot,targetRoot);
    end
end
end

function [text,stats] = relocateText(text,sourceRoot,targetRoot)
stats = emptyStats();
stats.checked = 1;
canonical = canonicalPath(text);
[underSource,suffix] = pathSuffix(canonical,sourceRoot);
if underSource
    text = [targetRoot suffix];
    stats.relocated = 1;
end
canonicalAfter = canonicalPath(text);
stats.remaining = double(pathSuffix(canonicalAfter,sourceRoot));
end

function [match,suffix] = pathSuffix(pathValue,root)
suffix = '';
match = false;
if isempty(pathValue), return; end
if pathsEqual(pathValue,root)
    match = true;
    return;
end
prefix = [root '/'];
if isWindowsPath(root)
    hasPrefix = startsWith(pathValue,prefix,'IgnoreCase',true);
else
    hasPrefix = startsWith(pathValue,prefix);
end
if hasPrefix
    match = true;
    suffix = pathValue(numel(root)+1:end);
end
end

function value = canonicalRoot(value)
value = canonicalPath(value);
while numel(value) > 1 && value(end) == '/' && ~isDriveRoot(value)
    value(end) = [];
end
end

function value = canonicalPath(value)
value = char(string(value));
value = strrep(value,'\','/');
end

function tf = pathsEqual(left,right)
if isWindowsPath(left) || isWindowsPath(right)
    tf = strcmpi(left,right);
else
    tf = strcmp(left,right);
end
end

function tf = isWindowsPath(value)
tf = ~isempty(regexp(value,'^[A-Za-z]:/','once')) || ...
    startsWith(value,'//');
end

function tf = isDriveRoot(value)
tf = ~isempty(regexp(value,'^[A-Za-z]:/$','once'));
end

function stats = emptyStats()
stats = struct('checked',0,'relocated',0,'remaining',0);
end

function total = addStats(total,part)
total.checked = total.checked + part.checked;
total.relocated = total.relocated + part.relocated;
total.remaining = total.remaining + part.remaining;
end
