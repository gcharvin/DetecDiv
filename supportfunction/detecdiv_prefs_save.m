function detecdiv_prefs_save(userprefs)
    if ispc
        fle = fullfile(prefdir,'Detecdiv','userprefs.mat');
    else
        fle = fullfile(getenv("HOME"),'Detecdiv','userprefs.mat');
    end
    save(fle,'userprefs');
end