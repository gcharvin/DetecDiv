function response = detecdiv_hub_request_index(remoteRootPath, hubSettings, varargin)
% detecdiv_hub_request_index  Ask detecdiv-hub to index one project root.

    if nargin < 2 || isempty(hubSettings)
        hubSettings = detecdiv_hub_settings_get();
    end

    ip = inputParser;
    ip.addParameter('StorageRootName', '', @(x)ischar(x) || isstring(x));
    ip.addParameter('HostScope', 'server', @(x)ischar(x) || isstring(x));
    ip.addParameter('RootType', 'project_root', @(x)ischar(x) || isstring(x));
    ip.addParameter('ClearExistingForRoot', false, @(x)islogical(x) || isnumeric(x));
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

    response = detecdiv_hub_write_json('/indexing', payload, hubSettings);
end
