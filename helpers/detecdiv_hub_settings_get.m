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
    hub = localSanitizePathMappings(hub);
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

function hub = localSanitizePathMappings(hub)
    if ~isfield(hub, 'pathMappings') || ~isstruct(hub.pathMappings)
        hub.pathMappings = struct('remoteRoot', {}, 'localRoot', {});
        return;
    end
    keep = false(1, numel(hub.pathMappings));
    for i = 1:numel(hub.pathMappings)
        try
            remoteRoot = regexprep(strrep(char(string(hub.pathMappings(i).remoteRoot)), '\', '/'), '[\/]+$', '');
            localRoot = regexprep(strrep(char(string(hub.pathMappings(i).localRoot)), '/', filesep), '[\\\/]+$', '');
            keep(i) = ~isempty(localRoot) && startsWith(remoteRoot, '/');
        catch
            keep(i) = false;
        end
    end
    hub.pathMappings = hub.pathMappings(keep);
    if isfield(hub, 'defaultRemoteProjectRoot') && ~isempty(hub.defaultRemoteProjectRoot)
        remoteRoot = regexprep(strrep(char(string(hub.defaultRemoteProjectRoot)), '\', '/'), '[\/]+$', '');
        if ~startsWith(remoteRoot, '/')
            hub.defaultRemoteProjectRoot = '';
        end
    end
end
