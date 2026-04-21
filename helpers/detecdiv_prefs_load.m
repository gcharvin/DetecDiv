function userprefs = detecdiv_prefs_load()

    if ispc
        fle = fullfile(prefdir,'Detecdiv','userprefs.mat');
    else
        fle = fullfile(getenv("HOME"),'Detecdiv','userprefs.mat');
    end

    userprefs = struct();

    try
        if exist(fle,'file')
            S = load(fle);
            if isstruct(S) && isfield(S,'userprefs') && isstruct(S.userprefs)
                userprefs = S.userprefs;
            end
        else
            initUserPreferences;
            S = load(fle);
            if isstruct(S) && isfield(S,'userprefs') && isstruct(S.userprefs)
                userprefs = S.userprefs;
            end
        end
    catch
        % Fall back to defaults if the file is absent, invalid or corrupted.
        userprefs = struct();
    end

    % Complete missing fields from current defaults.
    userprefs = detecdiv_prefs_migrate(userprefs);
    userprefs = localMergeLegacyShortcutDefaults(userprefs);

    % Save silently if defaults were added.
    try
        detecdiv_prefs_save(userprefs);
    catch
    end
end

function userprefs = localMergeLegacyShortcutDefaults(userprefs)
tip = {'Keyboard shortcuts used to assign a class to an image; Please enter space-separated letters; Please restart the ROI viewer after modification', ...
       'Keyboard shortcuts used to correct GT vs prediction discrepancies; Please enter space-separated letters; Please restart the ROI viewer after modification', ...
       'Keyboard shortcuts used to set frames bounds: only frames within the bounds will be considered for training; Please enter space-separated letters; Please restart the ROI viewer after modification', ...
       'Keyboard shortcuts used to quickly jump between frames', ...
       'Keyboard shortcuts used to fill holes when painting', ...
       'Keyboard shortcuts used to change painting transparency', ...
       'Size in pixels of the brush size used when using the left mouse button;  Please restart the ROI viewer after modification', ...
       'Size in pixels of the brush size used when using the right mouse button;  Please restart the ROI viewer after modification', ...
       'Size in pixels of the brush size used when using the mouse wheel button;  Please restart the ROI viewer after modification'};

defaults = struct( ...
    'roi_view_shortcut_keys',         'a z e r t y u i', ...
    'roi_view_corr_shortcut_keys',    'j k', ...
    'roi_view_bounds_shortcut_keys',  'w x', ...
    'roi_view_frames_jump_size',      'l m', ...
    'painting_fill_holes_shortcut',   'k', ...
    'painting_transparency_shortcut', 'g h', ...
    'painting_large_brush_size',       9, ...
    'painting_small_brush_size',       1, ...
    'painting_huge_brush_size',       49, ...
    'tip',                            {tip});

fn = fieldnames(defaults);
for i = 1:numel(fn)
    k = fn{i};
    if ~isfield(userprefs, k) || isempty(userprefs.(k))
        userprefs.(k) = defaults.(k);
    end
end
end
