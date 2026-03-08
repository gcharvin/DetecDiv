function hubSettings = detecdiv_hub_settings_get()
% detecdiv_hub_settings_get  Load detecdiv-hub client settings from userprefs.

    userprefs = detecdiv_prefs_load();
    defaults = localDefaultSettings();

    if ~isfield(userprefs, 'hub') || ~isstruct(userprefs.hub)
        hubSettings = defaults;
        return;
    end

    hubSettings = localMergeStruct(userprefs.hub, defaults);
end

function settings = localDefaultSettings()
    settings = struct( ...
        'sourceMode', 'local', ...
        'baseUrl', 'http://127.0.0.1:8000', ...
        'timeoutSeconds', 15, ...
        'defaultRemoteProjectRoot', '', ...
        'defaultLocalProjectRoot', '', ...
        'storageRootMap', struct(), ...
        'pathPrefixMap', struct(), ...
        'lastProjectId', '');
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
