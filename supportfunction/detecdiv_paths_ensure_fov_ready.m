function [obj, ok] = detecdiv_paths_ensure_fov_ready(obj, channel, debug, interactive, rootHint)
% Ensure raw source exists. If not, ask user to pick a RAWDATA root and try to rebase.
% Silent by default. Console output only on real problems.

if nargin < 2 || isempty(channel), channel = 1; end
if nargin < 3, debug = false; end   % <-- SILENT by default
if nargin < 4, interactive = true; end
if nargin < 5, rootHint = ""; end

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
isOZ = isprop(obj,'isOMEZarr') && obj.isOMEZarr;

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
roots = localCollectKnownRoots(userprefs);
rootHint = string(rootHint);
if strlength(rootHint) > 0
    roots = unique([rootHint; roots], 'stable');
end

% --- try known roots silently ---
for r = 1:numel(roots)
    root = roots(r);

    if isMT
        [p2, ok2] = detecdiv_paths_rebase_file(p0, root, debug, 0);
    elseif isND
        [p2, ok2] = detecdiv_paths_rebase_ndtiff(p0, root, debug);
    elseif isOZ
        [p2, ok2] = detecdiv_paths_rebase_datasetpath(p0, root, debug, 4);
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

% Non-interactive mode must be fast and non-blocking for display/render calls.
if ~interactive
    ok = false;
    return;
end

% --- ask user (only now) ---
if ~usejava('desktop')
    if debug
        fprintf('[paths] no desktop UI for folder picker; aborting interactive relink\n');
    end
    warning(['No desktop UI available for RAWDATA picker. ' ...
        'Provide a root path explicitly or run relink from desktop MATLAB.']);
    ok = false;
    return;
end

if debug
    fprintf('[paths] Prompting user for RAWDATA folder...\n');
end
startDir = pwd;
if strlength(rootHint) > 0 && isfolder(rootHint)
    startDir = char(rootHint);
elseif ~isempty(roots) && isfolder(roots(1))
    startDir = char(roots(1));
end

[root, pickedOk] = detecdiv_paths_prompt_root(string(startDir), p0, obj.id);
if ~pickedOk
    if debug
        fprintf('[paths] user cancelled RAWDATA selection for FOV %s\n', obj.id);
    end
    ok = false;
    return;
end
root = string(root);

% --- try user selection ---
if isMT
    [p2, ok2] = detecdiv_paths_rebase_file(p0, root, debug, 0);
    how = "";
elseif isND
    [p2, ok2] = detecdiv_paths_rebase_ndtiff(p0, root, debug);
    how = "";
elseif isOZ
    [p2, ok2, how] = detecdiv_paths_rebase_datasetpath(p0, root, debug, 6);
else
    [p2, ok2, how] = detecdiv_paths_rebase_pospath(p0, root, debug);
end

if ~ok2
    if debug
        fprintf('[paths] FAIL: user root did not match dataset (fast mode)\n');
    end
    warning('Selected folder does not match this dataset.');
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

function roots = localCollectKnownRoots(userprefs)
roots = strings(0,1);
if isempty(userprefs) || ~isstruct(userprefs) || ~isfield(userprefs,'paths') || ~isstruct(userprefs.paths)
    return;
end

p = userprefs.paths;

if isfield(p,'scanRoots') && ~isempty(p.scanRoots)
    roots = [roots; string(p.scanRoots(:))];
end

if isfield(p,'rootCandidates') && ~isempty(p.rootCandidates)
    roots = [roots; string(p.rootCandidates(:))];
end

if isfield(p,'rootMap') && isstruct(p.rootMap) && ~isempty(fieldnames(p.rootMap))
    fn = fieldnames(p.rootMap);
    for i = 1:numel(fn)
        v = p.rootMap.(fn{i});
        if ischar(v) || isstring(v)
            roots = [roots; string(v)];
        end
    end
end

if isfield(p,'rawPathHistory') && ~isempty(p.rawPathHistory)
    roots = [roots; string(p.rawPathHistory(:))];
end

roots = strip(roots);
roots = roots(strlength(roots) > 0);
roots = unique(roots, 'stable');
roots = roots(arrayfun(@localIsLikelyReachableRoot, roots));
if numel(roots) > 24
    roots = roots(1:24);
end
end

function tf = localIsLikelyReachableRoot(p)
tf = false;
p = string(p);
if strlength(p) == 0
    return;
end

% Avoid potentially blocking UNC probes in fast auto mode.
if startsWith(p, "\\")
    return;
end

if ispc
    token = regexp(char(p), '^[A-Za-z]:', 'match', 'once');
    if ~isempty(token)
        drive = upper(token(1));
        if localDriveIsSlowOrUnavailable(drive)
            return;
        end
        try
            r = java.io.File.listRoots();
            avail = strings(numel(r),1);
            for i = 1:numel(r)
                rr = char(r(i).getPath());
                if numel(rr) >= 1
                    avail(i) = upper(string(rr(1)));
                end
            end
            if ~any(avail == string(drive))
                return;
            end
        catch
            % If Java listing fails, keep probing the path.
        end
    end
end

tf = true;
end

function tf = localDriveIsSlowOrUnavailable(driveLetter)
tf = false;
try
    drives = System.IO.DriveInfo.GetDrives();
    for i = 1:drives.Length
        d = drives(i);
        nm = char(d.Name);
        if isempty(nm) || upper(nm(1)) ~= driveLetter
            continue;
        end
        try
            if ~d.IsReady
                tf = true;
                return;
            end
        catch
        end
        return;
    end
catch
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
