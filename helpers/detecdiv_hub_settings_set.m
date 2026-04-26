function detecdiv_hub_settings_set(hub)
% detecdiv_hub_settings_set  Persist DetecDiv hub client settings.

    if nargin < 1 || ~isstruct(hub)
        error('detecdiv_hub_settings_set:InvalidSettings', 'hub settings must be a struct.');
    end

    prefsFile = fullfile(prefdir, 'detecdiv_hub_settings.mat');
    save(prefsFile, 'hub');
end
