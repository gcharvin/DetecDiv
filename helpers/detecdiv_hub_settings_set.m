function detecdiv_hub_settings_set(hubSettings)
% detecdiv_hub_settings_set  Save detecdiv-hub client settings into userprefs.

    userprefs = detecdiv_prefs_load();
    defaults = detecdiv_hub_settings_get();
    userprefs.hub = localMergeStruct(hubSettings, defaults);
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
