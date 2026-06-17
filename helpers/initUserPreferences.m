function initUserPreferences

    if numel(userpath)==0
        userpath('reset')
    end

    pth = prefdir;

    if ispc
        fle = fullfile(pth,'Detecdiv','userprefs.mat');
        targetpth = prefdir;
    else
        tmpfile = getenv("HOME");
        fle = fullfile(tmpfile,'Detecdiv','userprefs.mat');
        targetpth = tmpfile;
    end

    if ~exist(fullfile(targetpth,'Detecdiv'), 'dir')
        mkdir(fullfile(targetpth,'Detecdiv'))
    end

    % ---------------------------
    % Load if existing
    % ---------------------------
    if exist(fle,'file')
        S = load(fle);
        if isfield(S,'userprefs')
            userprefs = S.userprefs;
        else
            userprefs = struct();
        end
    else
        userprefs = struct();
    end

    % ---------------------------
    % Legacy tips + default keys
    % ---------------------------
    tip = {'Keyboard shortcuts used to assign a class to an image; Please enter space-separated letters; Please restart the ROI viewer after modification', ...
           'Keyboard shortcuts used to correct GT vs prediction discrepancies; Please enter space-separated letters; Please restart the ROI viewer after modification', ...
           'Keyboard shortcuts used to set frames bounds: only frames within the bounds will be considered for training; Please enter space-separated letters; Please restart the ROI viewer after modification', ...
           'Keyboard shortcuts used to quickly jump between frames', ...
           'Keyboard shortcuts used to fill holes when painting', ...
           'Keyboard shortcuts used to change painting transparency', ...
           'Radius in pixels used with the left mouse button', ...
           'Radius in pixels used with the middle mouse button', ...
           'Radius in pixels used with the right mouse button', ...
           'Radius in pixels used by shift + left mouse button eraser'};

    defaults = struct( ...
        'roi_view_shortcut_keys',         'a z e r t y u i', ...
        'roi_view_corr_shortcut_keys',    'j k', ...
        'roi_view_bounds_shortcut_keys',  'w x', ...
        'roi_view_frames_jump_size',      'l m', ...
        'painting_fill_holes_shortcut',   'k', ...
        'painting_transparency_shortcut', 'g h', ...
        'painting_left_brush_radius',      7, ...
        'painting_middle_brush_radius',   13, ...
        'painting_right_brush_radius',     4, ...
        'painting_eraser_brush_radius',    7, ...
        'painting_large_brush_size',      49, ...
        'painting_small_brush_size',      49, ...
        'painting_huge_brush_size',      169, ...
        'tip',                            {tip} );

    % ---------------------------
    % NEW: path resolution prefs (retro-compatible)
    % ---------------------------
    % rootMap: alias -> absolute root path on this machine
    % rawPathHistory: list of absolute raw roots already used/seen
    % rawPathCache: containers.Map-like data stored as struct arrays (MATLAB save friendly)
    %   cache entries: {key, paths[]} where key can be projectId or datasetId
    %
    % scanRoots: where to search as last resort
    % maxScanDepth/maxCandidates: guardrails for scan
    %
    % NOTE: we store as regular structs/cells to be save/load robustly.

    [defaultRoots, defaultScanRoots] = localDefaultRawRoots();

    defaults.paths = struct( ...
        'rootMap',        defaultRoots, ...         % struct fields are aliases
        'scanRoots',      {defaultScanRoots}, ...   % cellstr
        'rawPathHistory', {{}}, ...                 % cellstr
        'rawPathCache',   struct('key',{},'paths',{}), ...
        'maxCandidates',  50, ...
        'maxScanDepth',   4, ...
        'enableAutoFix',  true );

    % ---------------------------
    % Merge defaults (non-destructive)
    % ---------------------------
    userprefs = localMergeStruct(userprefs, defaults);

    % Ensure Detecdiv folder exists + save
    save(fle,'userprefs');

end

% ----------------- helpers -----------------

function out = localMergeStruct(in, defaults)
    out = in;
    f = fieldnames(defaults);
    for i = 1:numel(f)
        k = f{i};
        if ~isfield(out, k) || isempty(out.(k))
            out.(k) = defaults.(k);
        else
            % recurse for nested structs
            if isstruct(out.(k)) && isstruct(defaults.(k))
                out.(k) = localMergeStruct(out.(k), defaults.(k));
            end
        end
    end
end

function [roots, scanRoots] = localDefaultRawRoots()
    roots = struct();   % alias -> absolute path
    scanRoots = {};

    if ispc
        % exemples: adapte à tes habitudes
        % roots.RAW = "Z:\SynologyDrive\Data";
        % roots.NAS = "\\NAS\SynologyDrive\Data";
        scanRoots = { ...
            "Z:\", ...
            "Y:\", ...
            "X:\", ...
            "\\NAS\", ...
            "\\SynologyDrive\", ...
            fullfile(getenv("USERPROFILE"),"SynologyDrive"), ...
            fullfile(getenv("USERPROFILE"),"Data")};
    else
        scanRoots = { ...
            "/mnt", ...
            "/media", ...
            "/Volumes", ...
            fullfile(getenv("HOME"),"SynologyDrive"), ...
            fullfile(getenv("HOME"),"Data")};
    end
end
