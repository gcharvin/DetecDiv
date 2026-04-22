function [keys, specialkeys, userprefs] = detecdiv_prefs_get_shortcuts()
% Return ROI and score shortcut preferences with safe defaults.

userprefs = detecdiv_prefs_load();

keys = localSplitShortcutText(localGetText(userprefs, 'roi_view_shortcut_keys', 'a z e r t y u i'));

specialkeys = cell(1,5);
specialkeys{1} = localSplitShortcutText(localGetText(userprefs, 'roi_view_corr_shortcut_keys', 'j k'));
specialkeys{2} = localSplitShortcutText(localGetText(userprefs, 'roi_view_bounds_shortcut_keys', 'w x'));
specialkeys{3} = localSplitShortcutText(localGetText(userprefs, 'roi_view_frames_jump_size', 'l m'));
specialkeys{4} = localSplitShortcutText(localGetText(userprefs, 'painting_fill_holes_shortcut', 'k'));
specialkeys{5} = localSplitShortcutText(localGetText(userprefs, 'painting_transparency_shortcut', 'g h'));
end

function txt = localGetText(S, fieldName, defaultVal)
txt = defaultVal;
try
    if isstruct(S) && isfield(S, fieldName) && ~isempty(S.(fieldName))
        txt = char(string(S.(fieldName)));
    end
catch
end
end

function out = localSplitShortcutText(txt)
tmp = textscan(char(string(txt)), '%s');
out = tmp{1};
out = out';
end
