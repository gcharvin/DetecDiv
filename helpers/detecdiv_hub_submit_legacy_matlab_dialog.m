function job = detecdiv_hub_submit_legacy_matlab_dialog(shallowObj, hub)
% Prompt for a published legacy MATLAB routine and queue it on DetecDiv Hub.
if nargin < 2 || isempty(hub), hub = detecdiv_hub_settings_get(); end
if ~isa(shallowObj, 'shallow')
    error('detecdiv_hub_submit_legacy_matlab_dialog:ProjectRequired', ...
        'Select a loaded DetecDiv project before submitting a Hub job.');
end
answer = inputdlg({'Routine path (published code)', 'Arguments JSON array'}, ...
    'Run job on Hub', [1 90; 4 90], ...
    {'X:\Alexander\code\gillestest\hub_legacy_smoke_test.m', '[]'});
if isempty(answer), error('detecdiv_hub_submit_legacy_matlab_dialog:Cancelled', 'Submission cancelled.'); end
arguments = jsondecode(answer{2});
if ~iscell(arguments), error('detecdiv_hub_submit_legacy_matlab_dialog:Arguments', 'Arguments must be a JSON array.'); end
[serverPath, mapped] = detecdiv_paths_map_module_path(answer{1}, struct('hub', hub), 'server');
if ~mapped || ~startsWith(string(serverPath), "/data/")
    error('detecdiv_hub_submit_legacy_matlab_dialog:Path', 'The routine must resolve to a server-visible /data path.');
end
% Save first: the worker always reloads the canonical shared project file.
shallowSave(shallowObj);
[shallowObj, ref] = detecdiv_hub_ensure_project(shallowObj, 'Hub', hub);
[~, functionName] = fileparts(char(serverPath));
payload = struct('project_id', ref.project_id, 'requested_mode', 'server', ...
    'routine_path', char(serverPath), 'function_name', functionName, ...
    'arguments', {arguments});
job = detecdiv_hub_request('POST', '/legacy-matlab-runs', payload, hub);
end
