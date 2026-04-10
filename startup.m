function startup
%STARTUP Normalize MATLAB path for the current DetecDiv checkout.
%
% DetecDiv exists with at least two layouts across branches:
% - legacy root layout (GUI/, supportfunction/, classification/, ...)
% - newer structure/ layout (structure/GUI, structure/classes, ...)
%
% After a git branch switch, MATLAB can keep stale paths and cached class
% definitions from the previous layout. This startup resets repo paths and
% class caches so function resolution matches the current checkout.

rootDir = fileparts(mfilename('fullpath'));
layout = detectLayout_(rootDir);

removeRepoPaths_(rootDir);
resetMatlabCaches_();
addRepoPaths_(rootDir, layout);
rehash;
rehash toolboxcache;

end

function removeRepoPaths_(rootDir)
pathEntries = strsplit(path, pathsep);
toRemove = {};

for i = 1:numel(pathEntries)
    entry = pathEntries{i};
    if isempty(entry)
        continue
    end

    underRoot = startsWith(string(entry), string(rootDir), 'IgnoreCase', true);
    if ~underRoot
        continue
    end

    toRemove{end+1} = entry; %#ok<AGROW>
end

if ~isempty(toRemove)
    rmpath(toRemove{:});
end
end

function addRepoPaths_(rootDir, layout)
switch layout
    case "root"
        baseDirs = {
            fullfile(rootDir, 'GUI')
            fullfile(rootDir, 'supportfunction')
            fullfile(rootDir, 'classification')
            fullfile(rootDir, 'processor')
            fullfile(rootDir, 'helpers')
            fullfile(rootDir, 'engine')
            fullfile(rootDir, 'AddOns')
            };
    case "structure"
        baseDirs = {
            fullfile(rootDir, 'structure')
            fullfile(rootDir, 'helpers')
            fullfile(rootDir, 'engine')
            fullfile(rootDir, 'AddOns')
            };
    otherwise
        baseDirs = {
            fullfile(rootDir, 'GUI')
            fullfile(rootDir, 'supportfunction')
            fullfile(rootDir, 'classification')
            fullfile(rootDir, 'processor')
            fullfile(rootDir, 'helpers')
            fullfile(rootDir, 'engine')
            fullfile(rootDir, 'AddOns')
            };
end

addpath(rootDir);

for i = 1:numel(baseDirs)
    thisDir = baseDirs{i};
    if ~isfolder(thisDir)
        continue
    end

    gp = genpath(thisDir);
    gpEntries = strsplit(gp, pathsep);
    gpEntries = gpEntries(~cellfun(@isempty, gpEntries));
    keep = true(size(gpEntries));

    for j = 1:numel(gpEntries)
        entry = gpEntries{j};
        if contains(entry, [filesep '.git']) || ...
           contains(entry, [filesep 'backups']) || ...
           contains(entry, [filesep 'Tutorial']) || ...
           contains(entry, [filesep 'deprecated']) || ...
           contains(entry, [filesep '__pycache__']) || ...
           contains(entry, [filesep 'runs'])
            keep(j) = false;
        end
    end

    gpEntries = gpEntries(keep);
    if ~isempty(gpEntries)
        addpath(gpEntries{:});
    end
end
end

function layout = detectLayout_(rootDir)
layout = "root";

rootMarkers = {
    'GUI/detecdiv.mlapp'
    '@classi/addROI.m'
    };

structureMarkers = {
    'structure/GUI/detecdiv.mlapp'
    'structure/classes/@classi/addROI.m'
    };

nRoot = 0;
for i = 1:numel(rootMarkers)
    if isTrackedPath_(rootDir, rootMarkers{i})
        nRoot = nRoot + 1;
    end
end

nStructure = 0;
for i = 1:numel(structureMarkers)
    if isTrackedPath_(rootDir, structureMarkers{i})
        nStructure = nStructure + 1;
    end
end

if nStructure > nRoot
    layout = "structure";
    return
end

if nRoot > nStructure
    layout = "root";
    return
end

% Fallback when git is unavailable or ambiguous.
if isfile(fullfile(rootDir, 'structure', 'GUI', 'detecdiv.mlapp')) && ...
        ~isfile(fullfile(rootDir, 'GUI', 'detecdiv.mlapp'))
    layout = "structure";
else
    layout = "root";
end
end

function tf = isTrackedPath_(rootDir, relPath)
tf = false;

gitDir = fullfile(rootDir, '.git');
if ~exist(gitDir, 'dir')
    return
end

cmd = sprintf('git -C "%s" ls-files --error-unmatch -- "%s"', rootDir, relPath);
[status, ~] = system(cmd);
tf = (status == 0);
end

function resetMatlabCaches_()
% Clear stale class/function definitions after a branch switch.
clear classes
clear functions
end
