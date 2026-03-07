function detecdiv_catalog_settings_set(catalogSettings)
% detecdiv_catalog_settings_set  Save catalog GUI settings into userprefs.

    userprefs = detecdiv_prefs_load();
    defaults = detecdiv_catalog_settings_get();
    userprefs.catalog = localMergeStruct(catalogSettings, defaults);
    detecdiv_prefs_save(userprefs);
end

function out = localMergeStruct(in, defaults)
    out = defaults;
    fields = fieldnames(defaults);
    for i = 1:numel(fields)
        key = fields{i};
        if isfield(in, key) && ~isempty(in.(key))
            out.(key) = in.(key);
        end
    end
end
