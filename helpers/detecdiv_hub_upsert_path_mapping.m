function hubSettings = detecdiv_hub_upsert_path_mapping(hubSettings, remotePrefix, localPrefix)
% detecdiv_hub_upsert_path_mapping  Add or update one remote/local root mapping.

    if nargin < 1 || isempty(hubSettings)
        hubSettings = detecdiv_hub_settings_get();
    end

    remotePrefix = strtrim(char(string(remotePrefix)));
    localPrefix = strtrim(char(string(localPrefix)));
    if isempty(remotePrefix) || isempty(localPrefix)
        return;
    end

    if ~isfield(hubSettings, 'pathPrefixMap') || ~isstruct(hubSettings.pathPrefixMap)
        hubSettings.pathPrefixMap = struct();
    end

    key = matlab.lang.makeValidName(remotePrefix);
    hubSettings.pathPrefixMap.(key) = struct( ...
        'remotePrefix', remotePrefix, ...
        'localPrefix', localPrefix);
end
