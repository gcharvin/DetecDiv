function userprefs = detecdiv_prefs_migrate(userprefs)

    if ~isstruct(userprefs)
        userprefs = struct();
    end

    % defaults.paths
    [defaultRoots, defaultScanRoots] = localDefaultRawRoots();
    defaults.paths = struct( ...
        'rootMap',        defaultRoots, ...
        'scanRoots',      {defaultScanRoots}, ...
        'rawPathHistory', {{}}, ...
        'rawPathCache',   struct('key',{},'paths',{}), ...
        'maxCandidates',  50, ...
        'maxScanDepth',   4, ...
        'enableAutoFix',  true );

    if ~isfield(userprefs,'paths') || ~isstruct(userprefs.paths)
        userprefs.paths = defaults.paths;
        return;
    end

    % merge non-destructif
    userprefs.paths = localMergeStruct(userprefs.paths, defaults.paths);
end

function out = localMergeStruct(in, defaults)
    out = in;
    f = fieldnames(defaults);
    for i = 1:numel(f)
        k = f{i};
        if ~isfield(out, k) || isempty(out.(k))
            out.(k) = defaults.(k);
        else
            if isstruct(out.(k)) && isstruct(defaults.(k))
                out.(k) = localMergeStruct(out.(k), defaults.(k));
            end
        end
    end
end

function [roots, scanRoots] = localDefaultRawRoots()
    roots = struct();
    scanRoots = {};

    if ispc
        scanRoots = { ...
            "Z:\", "Y:\", "X:\", ...
            "\\10.20.11.250\data", ...
            fullfile(getenv("USERPROFILE"),"SynologyDrive","Data"), ...
            fullfile(getenv("USERPROFILE"),"Data")};
    else
        scanRoots = {"/mnt","/media","/Volumes", ...
            fullfile(getenv("HOME"),"SynologyDrive"), ...
            fullfile(getenv("HOME"),"Data")};
    end
end
