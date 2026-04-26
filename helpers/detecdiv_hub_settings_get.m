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

    hub = localNormalizeDeploymentDefaults(hub);
    hub.baseUrl = localEnvOrValue('DETECDIV_HUB_BASE_URL', hub.baseUrl);
    hub.userKey = localEnvOrValue('DETECDIV_HUB_USER_KEY', hub.userKey);
    hub.sessionToken = localEnvOrValue('DETECDIV_HUB_SESSION_TOKEN', hub.sessionToken);
end

function hub = localDefaults()
    hub = struct();
    hub.baseUrl = 'http://detecdiv-hub.detecdiv.internal';
    hub.fallbackBaseUrls = {'http://127.0.0.1:8000'};
    hub.userKey = 'localdev';
    hub.sessionToken = '';
    hub.timeout = 20;
    hub.defaultRemoteProjectRoot = '';
    hub.defaultLocalProjectRoot = '';
    hub.pathMappings = struct('remoteRoot', {}, 'localRoot', {});
end

function hub = localNormalizeDeploymentDefaults(hub)
    currentDefault = 'http://detecdiv-hub.detecdiv.internal';
    oldTunnelDefault = 'http://127.0.0.1:8000';

    if ~isfield(hub, 'baseUrl') || isempty(hub.baseUrl)
        hub.baseUrl = currentDefault;
    end
    if ~isfield(hub, 'fallbackBaseUrls') || isempty(hub.fallbackBaseUrls)
        hub.fallbackBaseUrls = {oldTunnelDefault};
    end

    if isempty(getenv('DETECDIV_HUB_BASE_URL')) && strcmp(localTrimUrl(hub.baseUrl), localTrimUrl(oldTunnelDefault))
        hub.baseUrl = currentDefault;
    end
end

function out = localTrimUrl(value)
    out = regexprep(char(string(value)), '/+$', '');
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
