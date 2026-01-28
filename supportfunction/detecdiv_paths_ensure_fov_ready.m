function [obj, ok] = detecdiv_paths_ensure_fov_ready(obj, channel, debug)
% Ensure raw source exists. If not, ask user to pick a RAWDATA root and try to rebase.
% Silent by default. Console output only on real problems.

if nargin < 2 || isempty(channel), channel = 1; end
if nargin < 3, debug = false; end   % <-- SILENT by default

ok = true;
channel = max(1, min(channel, numel(obj.channel)));

% --- load prefs ---
try
    userprefs = detecdiv_prefs_load();
catch
    userprefs = [];
end

% --- determine missing path ---
isMT = isprop(obj,'isMultiTiff') && obj.isMultiTiff;
isND = isprop(obj,'isNDTiff') && obj.isNDTiff;

if isMT
    if channel <= numel(obj.tiffSource) && ~isempty(obj.tiffSource{channel})
        p0 = string(obj.tiffSource{channel});
    else
        p0 = string(obj.tiffSource{1});
    end

    if exist(p0,'file')
        return;
    end
elseif isND
    if isprop(obj,'ndtiffPath') && ~isempty(obj.ndtiffPath)
        p0 = string(obj.ndtiffPath);
    else
        p0 = "";
    end

    if strlength(p0) > 0 && isfolder(p0)
        return;
    end
else
    if ~iscell(obj.srcpath) || channel > numel(obj.srcpath) || isempty(obj.srcpath{channel})
        if debug
            fprintf('[paths] ERROR: srcpath missing for FOV %s ch=%d\n', obj.id, channel);
        end
        ok = false;
        return;
    end

    p0 = string(obj.srcpath{channel});
    if isfolder(p0)
        return;
    end
end

% ---- here: RAWDATA really missing ----
if debug
    fprintf('[paths] missing rawdata for FOV %s ch=%d\n', obj.id, channel);
    fprintf('[paths] expected: %s\n', p0);
end

% --- known roots ---
roots = strings(0,1);
if ~isempty(userprefs) && isfield(userprefs,'paths') && isfield(userprefs.paths,'rootCandidates')
    roots = string(userprefs.paths.rootCandidates(:));
end

% --- try known roots silently ---
for r = 1:numel(roots)
    root = roots(r);

    if isMT
        [p2, ok2] = detecdiv_paths_rebase_file(p0, root, debug);
    elseif isND
        [p2, ok2] = detecdiv_paths_rebase_ndtiff(p0, root, debug);
    else
        [p2, ok2] = detecdiv_paths_rebase_pospath(p0, root, debug);
    end

    if ok2
        % apply silently
        if isMT
            obj.tiffSource{channel} = char(p2);
        elseif isND
            obj.ndtiffPath = char(p2);
            if iscell(obj.srcpath) && ~isempty(obj.srcpath)
                obj.srcpath{channel} = char(p2);
            end
            try
                if channel <= numel(obj.srclist) && ~isempty(obj.srclist{channel})
                    L = obj.srclist{channel};
                    for k=1:numel(L), L(k).folder = char(p2); end
                    obj.srclist{channel} = L;
                end
            catch
            end
        else
            obj.srcpath{channel} = char(p2);
            try
                if channel <= numel(obj.srclist) && ~isempty(obj.srclist{channel})
                    L = obj.srclist{channel};
                    for k=1:numel(L), L(k).folder = char(p2); end
                    obj.srclist{channel} = L;
                end
            catch
            end
        end
        return;
    end
end

% --- ask user (only now) ---
msg = sprintf(['Raw data not found for FOV %s.\n\n' ...
               'Expected:\n%s\n\n' ...
               'Please select the RAWDATA folder.'], obj.id, p0);

uiwait(warndlg(msg, 'Missing rawdata', 'modal'));

root = uigetdir(pwd, 'Select RAWDATA folder');
if isequal(root,0)
    if debug
        fprintf('[paths] user cancelled RAWDATA selection for FOV %s\n', obj.id);
    end
    ok = false;
    return;
end
root = string(root);

% --- try user selection ---
if isMT
    [p2, ok2] = detecdiv_paths_rebase_file(p0, root, debug);
    how = "";
elseif isND
    [p2, ok2] = detecdiv_paths_rebase_ndtiff(p0, root, debug);
    how = "";
else
    [p2, ok2, how] = detecdiv_paths_rebase_pospath(p0, root, debug);
end

if ~ok2
    if debug
        fprintf('[paths] FAIL: user root did not match dataset\n');
    end
    uiwait(warndlg( ...
        'Selected folder does not match this dataset.', ...
        'Rawdata relink failed', 'modal'));
    ok = false;
    return;
end

% --- apply ---
if isMT
    obj.tiffSource{channel} = char(p2);
elseif isND
    obj.ndtiffPath = char(p2);
    if iscell(obj.srcpath) && ~isempty(obj.srcpath)
        obj.srcpath{channel} = char(p2);
    end
    try
        if channel <= numel(obj.srclist) && ~isempty(obj.srclist{channel})
            L = obj.srclist{channel};
            for k=1:numel(L), L(k).folder = char(p2); end
            obj.srclist{channel} = L;
        end
    catch
    end
else
    obj.srcpath{channel} = char(p2);
    try
        if channel <= numel(obj.srclist) && ~isempty(obj.srclist{channel})
            L = obj.srclist{channel};
            for k=1:numel(L), L(k).folder = char(p2); end
            obj.srclist{channel} = L;
        end
    catch
    end
end

% --- decide what to store ---
rootToStore = root;
try
    switch string(how)
        case {"pickedPosExact","pickedPosSibling"}
            rootToStore = string(fileparts(root)); % dataset folder
        case "pickedDataset"
            rootToStore = root;
    end
catch
end

% --- remember root (best-effort, silent) ---
try
    if isempty(userprefs), userprefs = struct(); end
    if ~isfield(userprefs,'paths'), userprefs.paths = struct(); end
    if ~isfield(userprefs.paths,'rootCandidates')
        userprefs.paths.rootCandidates = {};
    end
    roots2 = string(userprefs.paths.rootCandidates(:));
    roots2 = unique([rootToStore; roots2],'stable');
    if numel(roots2) > 30, roots2 = roots2(1:30); end
    userprefs.paths.rootCandidates = cellstr(roots2);
    detecdiv_prefs_save(userprefs);
catch
end

ok = true;
end

function [p2, ok] = detecdiv_paths_rebase_ndtiff(oldPath, root, debug)
% Rebase NDTiff dataset path by matching dataset folder name and NDTiff.index
if nargin < 3, debug = true; end
ok = false;
p2 = "";

oldPath = string(oldPath);
root = string(root);

if strlength(oldPath)==0 || strlength(root)==0 || ~isfolder(root)
    return;
end

[~, datasetName] = fileparts(oldPath);
if strlength(datasetName)==0
    return;
end

% direct candidate
cand = fullfile(root, datasetName);
if isfolder(cand) && exist(fullfile(cand,'NDTiff.index'),'file')==2
    p2 = string(cand);
    ok = true;
    return;
end

% scan limited depth
maxDepth = 6;
found = localFindNDTiff(root, datasetName, maxDepth, debug);
if strlength(found) > 0
    p2 = found;
    ok = true;
end
end

function out = localFindNDTiff(root, targetName, maxDepth, debug)
out = "";
if maxDepth <= 0
    return;
end

try
    d = dir(root);
catch ME
    if debug, fprintf('[paths] dir() failed at %s : %s\n', string(root), ME.message); end
    return;
end

d = d([d.isdir]);
names = string({d.name});
names = names(~ismember(names,[".",".."]));

for i = 1:numel(names)
    if strcmpi(names(i), targetName)
        cand = string(fullfile(root, names(i)));
        if exist(fullfile(cand,'NDTiff.index'),'file')==2
            out = cand;
            return;
        end
    end
end

for i = 1:numel(names)
    out = localFindNDTiff(fullfile(root, names(i)), targetName, maxDepth-1, debug);
    if strlength(out)>0, return; end
end
end
