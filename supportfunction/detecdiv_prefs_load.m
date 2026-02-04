function userprefs = detecdiv_prefs_load()

    if ispc
        fle = fullfile(prefdir,'Detecdiv','userprefs.mat');
    else
        fle = fullfile(getenv("HOME"),'Detecdiv','userprefs.mat');
    end

    if exist(fle,'file')
        S = load(fle);
        userprefs = S.userprefs;
    else
        initUserPreferences;
        S = load(fle);
        userprefs = S.userprefs;
    end

    % --- MIGRATION: compléter champs manquants ---
    userprefs = detecdiv_prefs_migrate(userprefs);

    % Sauvegarde silencieuse si on a ajouté des champs
    try
        detecdiv_prefs_save(userprefs);
    catch
    end
end
