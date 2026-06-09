function preview = detecdiv_hub_preview_project_deletion(projectId, hubSettings, varargin)
% detecdiv_hub_preview_project_deletion  Preview deletion of one hub project.

    if nargin < 1 || strlength(string(projectId)) == 0
        error('detecdiv_hub_preview_project_deletion:MissingProjectId', ...
            'A project id is required.');
    end
    if nargin < 2 || isempty(hubSettings)
        hubSettings = detecdiv_hub_settings_get();
    end

    ip = inputParser;
    ip.addParameter('DeleteProjectFiles', false, @(x)islogical(x) || isnumeric(x));
    ip.addParameter('DeleteLinkedRawData', false, @(x)islogical(x) || isnumeric(x));
    ip.parse(varargin{:});
    opts = ip.Results;

    endpoint = ['/projects/' char(string(projectId)) '/deletion-preview'];
    payload = struct( ...
        'delete_project_files', logical(opts.DeleteProjectFiles), ...
        'delete_linked_raw_data', logical(opts.DeleteLinkedRawData), ...
        'confirm', false);
    preview = detecdiv_hub_write_json(endpoint, payload, hubSettings);
end
