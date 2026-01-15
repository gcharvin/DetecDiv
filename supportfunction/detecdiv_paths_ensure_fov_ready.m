function [obj, ok] = detecdiv_paths_ensure_fov_ready(obj, channel, debug)
% Ensure raw source exists. If not, ask user to pick a RAWDATA root and try to rebase.
% debug: true -> prints in console

if nargin < 2 || isempty(channel), channel = 1; end
if nargin < 3, debug = true; end

ok = true;
channel = max(1, min(channel, numel(obj.channel)));

if debug
    fprintf('[paths] ensure_fov_ready: fov=%s channel=%d\n', string(obj.id), channel);
end

% --- load prefs (if you have these functions globally) ---
try
    userprefs = detecdiv_prefs_load();
catch
    userprefs = [];
end

% --- determine what is missing ---
isMT = isprop(obj,'isMultiTiff') && obj.isMultiTiff;

if isMT
    % multi-tiff uses tiffSource{ch}
    if channel <= numel(obj.tiffSource) && ~isempty(obj.tiffSource{channel})
        p0 = string(obj.tiffSource{channel});
    else
        p0 = string(obj.tiffSource{1});
    end

    if debug
        fprintf('[paths] mode=multiTiff expected file: %s\n', p0);
    end

    if exist(p0,'file')
        if debug, fprintf('[paths] OK: multiTiff file exists\n'); end
        return;
    end
else
    if ~iscell(obj.srcpath) || channel > numel(obj.srcpath) || isempty(obj.srcpath{channel})
        if debug, fprintf('[paths] ERROR: srcpath missing/empty for channel %d\n', channel); end
        ok = false;
        return;
    end

    p0 = string(obj.srcpath{channel});

    if debug
        fprintf('[paths] mode=classic expected folder: %s\n', p0);
    end

    if isfolder(p0)
        if debug, fprintf('[paths] OK: folder exists\n'); end
        return;
    end
end

% --- get known roots ---
roots = strings(0,1);
if ~isempty(userprefs) && isfield(userprefs,'paths') && isfield(userprefs.paths,'rootCandidates')
    roots = string(userprefs.paths.rootCandidates(:));
end

if debug
    fprintf('[paths] missing rawdata -> trying %d known roots\n', numel(roots));
    if numel(roots)
        for i=1:numel(roots)
            fprintf('[paths]   root[%d]=%s\n', i, roots(i));
        end
    end
end

% --- try known roots ---
for r=1:numel(roots)
    root = roots(r);
    if debug, fprintf('[paths] try known root: %s\n', root); end

    if isMT
        [p2, ok2] = detecdiv_paths_rebase_file(p0, root, debug);
        if ok2
            if debug, fprintf('[paths] SUCCESS: rebase_file -> %s\n', p2); end
            obj.tiffSource{channel} = char(p2);
            ok = true;
            return;
        end
    else
        [p2, ok2, how] = detecdiv_paths_rebase_pospath(p0, root, debug);
        if ok2
    if debug, fprintf('[paths] SUCCESS: rebase_pospath -> %s (how=%s)\n', p2, how); end
            obj.srcpath{channel} = char(p2);

            % keep srclist folder consistent (optional)
            try
                if channel <= numel(obj.srclist) && ~isempty(obj.srclist{channel})
                    L = obj.srclist{channel};
                    for k=1:numel(L), L(k).folder = char(p2); end
                    obj.srclist{channel} = L;
                    if debug, fprintf('[paths] updated srclist{%d} folders -> %s\n', channel, p2); end
                end
            catch ME
                if debug, fprintf('[paths] WARNING: srclist update failed: %s\n', ME.message); end
            end

            ok = true;
            return;
        end
    end
end

% --- ask user ---
msg = sprintf('Raw data not found for FOV %s.\n\nExpected:\n%s\n\nSelect RAWDATA root folder.', obj.id, p0);
uiwait(warndlg(msg, 'Missing rawdata', 'modal'));

root = uigetdir(pwd, 'Select RAWDATA root folder');
if isequal(root,0)
    if debug, fprintf('[paths] user cancelled root selection\n'); end
    ok = false;
    return;
end
root = string(root);
if debug, fprintf('[paths] user selected root: %s\n', root); end

% try user root
if isMT
    [p2, ok2] = detecdiv_paths_rebase_file(p0, root, debug);
else
    [p2, ok2, how] = detecdiv_paths_rebase_pospath(p0, root, debug);
if debug
    fprintf('[paths] userPick resolved? ok=%d how=%s p2=%s\n', ok2, how, p2);
end

end

if ~ok2
    if debug, fprintf('[paths] FAIL: selected root did not resolve path\n'); end
    uiwait(warndlg('Selected root did not match this dataset (could not rebase path).','Rawdata relink failed','modal'));
    ok = false;
    return;
end

% Decide what to store as a good future candidate
rootToStore = root;
try
    if exist('how','var') && strlength(string(how))>0
        switch string(how)
            case {"pickedPosExact","pickedPosSibling"}
                % store dataset folder (parent of PosX)
                rootToStore = string(fileparts(root));
            case "pickedDataset"
                rootToStore = root; % dataset folder is good
            otherwise
                rootToStore = root; % upstream root
        end
    end
catch
end

if debug
    fprintf('[paths] storing rootCandidate=%s (from userPick=%s how=%s)\n', rootToStore, root, string(how));
end


% apply
if isMT
    obj.tiffSource{channel} = char(p2);
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

% remember root (best-effort)
try
    if isempty(userprefs), userprefs = struct(); end
    if ~isfield(userprefs,'paths') || ~isstruct(userprefs.paths), userprefs.paths = struct(); end
    if ~isfield(userprefs.paths,'rootCandidates') || isempty(userprefs.paths.rootCandidates)
        userprefs.paths.rootCandidates = {};
    end
    roots2 = string(userprefs.paths.rootCandidates(:));
    roots2 = unique([rootToStore; roots2],'stable');
    if numel(roots2) > 30, roots2 = roots2(1:30); end
    userprefs.paths.rootCandidates = cellstr(roots2);
    detecdiv_prefs_save(userprefs);
    if debug, fprintf('[paths] stored rootCandidates (n=%d)\n', numel(roots2)); end
catch ME
    if debug, fprintf('[paths] WARNING: could not save prefs: %s\n', ME.message); end
end

ok = true;

end
