function hub = detecdiv_hub_settings_get()
% detecdiv_hub_settings_get  Load DetecDiv hub client settings.

    hub = localDefaults();
    prefsFile = fullfile(prefdir, 'detecdiv_hub_settings.mat');
    if isfile(prefsFile)
        try
            S = load(prefsFile, 'hub');
            if isfield(S, 'hub') && isstruct(S.hub)
                hub = localMergeStruct(hub, S.hub);
            end
        catch
        end
    end

    hub.baseUrl = localEnvOrValue('DETECDIV_HUB_BASE_URL', hub.baseUrl);
    hub.userKey = localEnvOrValue('DETECDIV_HUB_USER_KEY', hub.userKey);
    hub.sessionToken = localEnvOrValue('DETECDIV_HUB_SESSION_TOKEN', hub.sessionToken);
end

function hub = localDefaults()
    hub = struct();
    hub.baseUrl = 'http://127.0.0.1:8000';
    hub.userKey = 'localdev';
    hub.sessionToken = '';
    hub.timeout = 20;
    hub.defaultRemoteProjectRoot = '';
    hub.defaultLocalProjectRoot = '';
    hub.pathMappings = struct('remoteRoot', {}, 'localRoot', {});
end

function out = localMergeStruct(out, in)
    fn = fieldnames(in);
    for i = 1:numel(fn)
        out.(fn{i}) = in.(fn{i});
    end
end

function value = localEnvOrValue(name, value)
    envValue = getenv(name);
    if ~isempty(envValue)
        value = envValue;
    end
end
