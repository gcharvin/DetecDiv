function [p2, ok, how] = detecdiv_paths_rebase_pospath(oldPosPath, userPick, debug)
% Flexible rebase for legacy path: ...\DATASET\PosX
%
% userPick can be:
%   A) upstream root that contains DATASET somewhere
%   B) the DATASET folder itself
%   C) the PosX folder itself (or any PosY under same dataset)
%
% Returns:
%   p2  : resolved folder to the requested PosX
%   ok  : true/false
%   how : string describing the match strategy

if nargin < 3, debug = true; end

p2 = ""; ok = false; how = "";

oldPosPath = string(oldPosPath);
userPick   = string(userPick);

if debug
    fprintf('[paths] rebase_pospath FLEX:\n');
    fprintf('[paths]   oldPosPath=%s\n', oldPosPath);
    fprintf('[paths]   userPick  =%s\n', userPick);
end

if strlength(oldPosPath)==0
    if debug, fprintf('[paths]   FAIL: oldPosPath empty\n'); end
    return;
end
if strlength(userPick)==0 || ~isfolder(userPick)
    if debug, fprintf('[paths]   FAIL: userPick empty or not a folder\n'); end
    return;
end

% ----- parse legacy -----
[parent, posName] = fileparts(oldPosPath);   % ...\DATASET , PosX
[~, datasetName]  = fileparts(parent);       % DATASET

if debug
    fprintf('[paths]   parsed datasetName=%s posName=%s\n', datasetName, posName);
end

if strlength(datasetName)==0 || strlength(posName)==0
    if debug, fprintf('[paths]   FAIL: could not parse dataset/pos from oldPosPath\n'); end
    return;
end

% ----- analyze userPick leaf -----
[upParent, upLeaf] = fileparts(userPick);
isPosLeaf = ~isempty(regexp(char(upLeaf), '^pos\d+$', 'once', 'ignorecase'));

if debug
    fprintf('[paths]   userPick leaf=%s (isPos=%d)\n', upLeaf, isPosLeaf);
end

% =========================================================
% C) user picked a Pos folder itself
% =========================================================
if isPosLeaf
    % If user picked exactly the requested PosX -> done
    if strcmpi(upLeaf, posName) && isfolder(userPick)
        p2 = userPick; ok = true; how = "pickedPosExact";
        if debug, fprintf('[paths]   SUCCESS: userPick is exactly requested Pos folder\n'); end
        return;
    end

    % User picked another PosY -> assume dataset folder is its parent
    dsFolder = string(upParent);
    cand = string(fullfile(dsFolder, posName));
    if debug
        fprintf('[paths]   userPick is PosY, using its parent as dataset\n');
        fprintf('[paths]   candidate=%s\n', cand);
    end
    if isfolder(cand)
        p2 = cand; ok = true; how = "pickedPosSibling";
        if debug, fprintf('[paths]   SUCCESS: resolved using dataset parent of picked Pos\n'); end
        return;
    end

    if debug, fprintf('[paths]   FAIL: picked Pos folder, but cannot resolve requested Pos under its parent\n'); end
    % continue to other strategies (maybe userPick isn't really a dataset tree)
end

% =========================================================
% B) user picked the DATASET folder itself
% =========================================================
% If leaf equals datasetName, userPick is dataset folder
if strcmpi(upLeaf, datasetName)
    cand = string(fullfile(userPick, posName));
    if debug
        fprintf('[paths]   userPick looks like DATASET folder\n');
        fprintf('[paths]   candidate=%s\n', cand);
    end
    if isfolder(cand)
        p2 = cand; ok = true; how = "pickedDataset";
        if debug, fprintf('[paths]   SUCCESS: resolved using dataset folder\n'); end
        return;
    else
        if debug, fprintf('[paths]   FAIL: dataset folder picked, but Pos not found inside\n'); end
        return;
    end
end

% Also accept case: userPick\datasetName exists -> dataset is directly under pick
candDS = string(fullfile(userPick, datasetName));
if isfolder(candDS)
    cand = string(fullfile(candDS, posName));
    if debug
        fprintf('[paths]   userPick contains DATASET directly\n');
        fprintf('[paths]   dataset=%s\n', candDS);
        fprintf('[paths]   candidate=%s\n', cand);
    end
    if isfolder(cand)
        p2 = cand; ok = true; how = "pickedUpstreamDirect";
        if debug, fprintf('[paths]   SUCCESS: resolved using direct dataset under userPick\n'); end
        return;
    else
        if debug, fprintf('[paths]   FAIL: dataset found under userPick but Pos missing\n'); end
        % continue to scan strategy (dataset might be deeper)
    end
end

% Common synced-drive case: the selected root (for example
% Z:\Gilles\Data) shares a named ancestor with the saved absolute path
% (...\SynologyDrive\Data\coudreuse\...). Reuse the remaining suffix
% deterministically before falling back to a recursive scan.
cand = localCandidateFromMatchingAncestor(oldPosPath, userPick);
if strlength(cand) > 0 && isfolder(cand)
    p2 = cand; ok = true; how = "matchedAncestorSuffix";
    if debug, fprintf('[paths]   SUCCESS: resolved using matching ancestor suffix: %s\n', cand); end
    return;
end

% =========================================================
% A) user picked upstream root -> search datasetName under it (limited depth)
% =========================================================
maxDepth = 6;
if debug
    fprintf('[paths]   scanning for dataset "%s" under userPick (maxDepth=%d)\n', datasetName, maxDepth);
end

dsFolder = localFindFolder(userPick, datasetName, maxDepth, debug);
if strlength(dsFolder)==0
    if debug, fprintf('[paths]   FAIL: dataset folder not found by scan\n'); end
    return;
end

cand = string(fullfile(dsFolder, posName));
if debug
    fprintf('[paths]   scan found dataset=%s\n', dsFolder);
    fprintf('[paths]   candidate=%s\n', cand);
end

if isfolder(cand)
    p2 = cand; ok = true; how = "scannedUpstream";
    if debug, fprintf('[paths]   SUCCESS: resolved by scanning upstream\n'); end
else
    if debug, fprintf('[paths]   FAIL: dataset found but requested Pos not present\n'); end
end

end

function cand = localCandidateFromMatchingAncestor(oldPath, newRoot)
cand = "";
oldNorm = replace(string(oldPath), "\", "/");
rootNorm = replace(string(newRoot), "\", "/");
oldParts = split(oldNorm, "/");
rootParts = split(rootNorm, "/");
oldParts = oldParts(oldParts ~= "");
rootParts = rootParts(rootParts ~= "");
if isempty(oldParts) || isempty(rootParts)
    return;
end

anchor = rootParts(end);
idx = find(strcmpi(oldParts, anchor), 1, 'last');
if isempty(idx) || idx >= numel(oldParts)
    return;
end

tail = oldParts(idx+1:end);
cand = string(newRoot);
for i = 1:numel(tail)
    cand = string(fullfile(cand, tail(i)));
end
end

function out = localFindFolder(root, targetName, maxDepth, debug)
out = "";
if maxDepth <= 0
    if debug, fprintf('[paths]   findFolder depth limit at %s\n', string(root)); end
    return;
end

try
    d = dir(root);
catch ME
    if debug, fprintf('[paths]   dir() failed at %s : %s\n', string(root), ME.message); end
    return;
end

d = d([d.isdir]);
names = string({d.name});
names = names(~ismember(names,[".",".."]));

% direct match
for i=1:numel(names)
    if strcmpi(names(i), targetName)
        out = string(fullfile(root, names(i)));
        if debug, fprintf('[paths]   MATCH dataset folder: %s\n', out); end
        return;
    end
end

% recurse
for i=1:numel(names)
    out = localFindFolder(fullfile(root, names(i)), targetName, maxDepth-1, debug);
    if strlength(out)>0, return; end
end
end
