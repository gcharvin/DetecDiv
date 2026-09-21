function fig = detecdiv_hub_legacy_job_gui(shallowObj)
% Compact three-tab Hub UI for project-bound legacy MATLAB jobs.
hub = detecdiv_hub_settings_get(); jobId = latestProjectJobId(shallowObj);
fig = uifigure('Name','DetecDiv Hub custom job','Position',[220 180 720 510]);
tabs = uitabgroup(fig,'Position',[10 10 700 490]);
connectionTab = uitab(tabs,'Title','Hub connection'); runTab = uitab(tabs,'Title','Run'); monitorTab = uitab(tabs,'Title','Monitor');

% Use explicit positions rather than GridLayout parents: this also works in
% older MATLAB App Designer releases used by legacy DetecDiv installations.
addField(connectionTab,'Hub URL',hub.baseUrl,'baseUrl',405);
addField(connectionTab,'User key',hub.userKey,'userKey',365);
% uihtml is available since R2019b and provides a real masked password
% input on R2024a. The HTML component only returns its current value in
% memory; it is cleared immediately after a successful login.
addLabel(connectionTab,'Password',325);
password = uihtml(connectionTab, 'HTMLSource', fullfile(fileparts(mfilename('fullpath')), ...
    'detecdiv_hub_password_input.html'), 'Position',[135 325 385 24]);
uibutton(connectionTab,'Text','Connect','Position',[535 325 110 24],'ButtonPushedFcn',@connectHub);
addLabel(connectionTab,'Session',285); session = uilabel(connectionTab,'Text',shortToken(hub),'Position',[135 285 510 24]);
addLabel(connectionTab,'Remote root',245); remoteRoot = uieditfield(connectionTab,'text','Value',hub.defaultRemoteProjectRoot,'Position',[135 245 510 24]);
addLabel(connectionTab,'Local root',205); localRoot = uieditfield(connectionTab,'text','Value',hub.defaultLocalProjectRoot,'Position',[135 205 510 24]);

addLabel(runTab,'Loaded project',405); uilabel(runTab,'Text',projectName(shallowObj),'Position',[135 405 510 24]);
addLabel(runTab,'Script path',365); scriptPath = uieditfield(runTab,'text','Value','X:\Alexander\code\gillestest\hub_legacy_smoke_test.m','Position',[135 365 510 24]);
addLabel(runTab,'Arguments JSON',325); args = uitextarea(runTab,'Value',{'[]'},'Position',[135 205 510 144]);
uibutton(runTab,'Text','Run job on Hub','Position',[425 165 220 28],'ButtonPushedFcn',@submitJob);
runStatus = uilabel(runTab,'Text','Save the project, then submit it to Hub.','Position',[20 125 625 24]);

monitorStatus = uilabel(monitorTab,'Text',initialMonitorText(jobId),'Position',[20 405 460 24]);
uibutton(monitorTab,'Text','Refresh now','Position',[520 405 125 24],'ButtonPushedFcn',@refreshJob);
console = uitextarea(monitorTab,'Editable','off','Value',{'Monitor ready.'},'Position',[20 25 625 365]);
timerObj = timer('ExecutionMode','fixedSpacing','Period',5,'TimerFcn',@(~,~)refreshJob()); start(timerObj);
fig.CloseRequestFcn = @closeGui;

    function addField(parent,label,value,fieldName,y)
        addLabel(parent,label,y);
        control = uieditfield(parent,'text','Value',char(string(value)), ...
            'Position',[135 y 510 24]);
        control.Tag = fieldName;
    end
    function addLabel(parent,label,y)
        uilabel(parent,'Text',label,'HorizontalAlignment','right', ...
            'Position',[20 y 105 24]);
    end
    function connectHub(~,~)
        try
            hub.baseUrl = findobj(connectionTab,'Tag','baseUrl').Value; hub.userKey = findobj(connectionTab,'Tag','userKey').Value;
            hub.defaultRemoteProjectRoot = remoteRoot.Value; hub.defaultLocalProjectRoot = localRoot.Value;
            [~,hub] = detecdiv_hub_login(hub.userKey,char(string(password.Data)),hub);
            detecdiv_hub_settings_set(hub); session.Text = shortToken(hub); password.Data = struct('clear',true);
        catch ME
            uialert(fig,ME.message,'Hub connection failed');
        end
    end
    function submitJob(~,~)
        try
            shallowSave(shallowObj); [~,ref] = detecdiv_hub_ensure_project(shallowObj,'Hub',hub);
            [serverPath,mapped] = detecdiv_paths_map_module_path(scriptPath.Value,struct('hub',hub),'server');
            if ~mapped || ~startsWith(string(serverPath),'/data/'), error('Script must be under a server-visible /data root.'); end
            values = jsondecode(strjoin(args.Value,newline)); if ~iscell(values), error('Arguments must be a JSON array.'); end
            [~,name] = fileparts(char(serverPath)); payload = struct('project_id',ref.project_id,'requested_mode','server', ...
                'routine_path',char(serverPath),'function_name',name,'arguments',{values});
            job = detecdiv_hub_request('POST','/legacy-matlab-runs',payload,hub); jobId = char(string(job.id));
            recordProjectJob(shallowObj, jobId, char(serverPath), strjoin(args.Value,newline));
            runStatus.Text = ['Queued: ' jobId]; tabs.SelectedTab = monitorTab; refreshJob();
        catch ME
            uialert(fig,ME.message,'Job submission failed');
        end
    end
    function refreshJob(~,~)
        if isempty(jobId), return; end
        try
            job = detecdiv_hub_request_json(['/jobs/' jobId],hub); monitorStatus.Text = ['Job ' jobId ': ' char(string(job.status))];
            if isfield(job,'result_json'), console.Value = {jsonencode(job.result_json)}; end
            if isfield(job,'error_text') && ~isempty(job.error_text), console.Value = {char(string(job.error_text))}; end
        catch ME
            monitorStatus.Text = ['Monitor unavailable: ' ME.message];
        end
    end
    function closeGui(~,~), stop(timerObj); delete(timerObj); delete(fig); end
end

function recordProjectJob(project, jobId, routinePath, argumentsJson)
record = struct('job_id',jobId,'routine_path',routinePath, ...
    'arguments_json',argumentsJson,'submitted_at',char(datetime('now','Format',"yyyy-MM-dd'T'HH:mm:ss")));
if ~isfield(project.processing,'hubLegacyJobs') || isempty(project.processing.hubLegacyJobs)
    project.processing.hubLegacyJobs = record;
else
    project.processing.hubLegacyJobs(end+1) = record;
end
shallowSave(project,'shallowObj');
end

function jobId = latestProjectJobId(project)
jobId = '';
try
    records = project.processing.hubLegacyJobs;
    if ~isempty(records) && isfield(records,'job_id')
        jobId = char(string(records(end).job_id));
    end
catch
end
end

function text = initialMonitorText(jobId)
if isempty(jobId)
    text = 'No submitted job.';
else
    text = ['Latest project job: ' jobId];
end
end

function text = shortToken(hub)
text = 'Not connected';
if isfield(hub,'sessionToken') && ~isempty(hub.sessionToken), text = 'Connected'; end
end

function text = projectName(project)
text = 'Loaded DetecDiv project';
try
    text = project.io.file;
catch
end
end
