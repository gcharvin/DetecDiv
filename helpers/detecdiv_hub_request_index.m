function response = detecdiv_hub_request_index(remoteRootPath, hubSettings, varargin)
% detecdiv_hub_request_index  Ask detecdiv-hub to index one project root.
%
% Server-side indexing is worker-backed in the current webserver-labo
% deployment because the API VM does not have direct project storage access.

    if nargin < 2 || isempty(hubSettings)
        hubSettings = detecdiv_hub_settings_get();
    end

    ip = inputParser;
    ip.addParameter('StorageRootName', '', @(x)ischar(x) || isstring(x));
    ip.addParameter('HostScope', 'server', @(x)ischar(x) || isstring(x));
    ip.addParameter('RootType', 'project_root', @(x)ischar(x) || isstring(x));
    ip.addParameter('ClearExistingForRoot', false, @(x)islogical(x) || isnumeric(x));
    ip.addParameter('LaunchMode', 'worker', @(x)ischar(x) || isstring(x));
    ip.parse(varargin{:});
    opts = ip.Results;

    payload = struct( ...
        'source_kind', 'project_root', ...
        'source_path', char(string(remoteRootPath)), ...
        'storage_root_name', char(string(opts.StorageRootName)), ...
        'host_scope', char(string(opts.HostScope)), ...
        'root_type', char(string(opts.RootType)), ...
        'clear_existing_for_root', logical(opts.ClearExistingForRoot), ...
        'metadata_json', struct());

    launchMode = lower(strtrim(char(string(opts.LaunchMode))));
    if isempty(launchMode) || strcmp(launchMode, 'worker') || strcmp(launchMode, 'job')
        response = detecdiv_hub_write_json('/indexing/jobs', payload, hubSettings);
    elseif strcmp(launchMode, 'direct')
        response = detecdiv_hub_write_json('/indexing', payload, hubSettings);
    else
        error('detecdiv_hub_request_index:InvalidLaunchMode', ...
            'LaunchMode must be worker or direct.');
    end
end
