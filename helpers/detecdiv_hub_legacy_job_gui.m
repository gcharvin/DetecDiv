function fig = detecdiv_hub_legacy_job_gui(shallowObj)
% Compact three-tab Hub UI for project-bound legacy MATLAB jobs.
hub = detecdiv_hub_settings_get(); jobId = latestProjectJobId(shallowObj);
fig = uifigure('Name','DetecDiv Hub custom job','Position',[220 180 720 510]);
tabs = uitabgroup(fig,'Position',[10 10 700 490]);
connectionTab = uitab(tabs,'Title','Hub connection'); runTab = uitab(tabs,'Title','Run'); monitorTab = uitab(tabs,'Title','Monitor');

cg = uigridlayout(connectionTab,[7 2]); cg.RowHeight = repmat({30},1,7); cg.ColumnWidth = {130,'1x'};
addField(cg,'Hub URL',hub.baseUrl,'baseUrl'); addField(cg,'User key',hub.userKey,'userKey');
uialabel(cg,'Text','Password'); password = uieditfield(cg,'password');
connect = uibutton(cg,'Text','Connect','ButtonPushedFcn',@connectHub); connect.Layout.Row = 4; connect.Layout.Column = 2;
uialabel(cg,'Text','Session'); session = uilabel(cg,'Text',shortToken(hub)); session.Layout.Row = 5; session.Layout.Column = 2;
uialabel(cg,'Text','Remote root'); remoteRoot = uieditfield(cg,'text','Value',hub.defaultRemoteProjectRoot); remoteRoot.Layout.Row = 6; remoteRoot.Layout.Column = 2;
uialabel(cg,'Text','Local root'); localRoot = uieditfield(cg,'text','Value',hub.defaultLocalProjectRoot); localRoot.Layout.Row = 7; localRoot.Layout.Column = 2;

rg = uigridlayout(runTab,[6 2]); rg.RowHeight = {28,28,28,90,28,'1x'}; rg.ColumnWidth = {130,'1x'};
uialabel(rg,'Text','Loaded project'); uilabel(rg,'Text',projectName(shallowObj));
uialabel(rg,'Text','Script path'); scriptPath = uieditfield(rg,'text','Value','X:\Alexander\code\gillestest\hub_legacy_smoke_test.m');
uialabel(rg,'Text','Arguments JSON'); args = uitextarea(rg,'Value',{'[]'});
submit = uibutton(rg,'Text','Run job on Hub','ButtonPushedFcn',@submitJob); submit.Layout.Row = 5; submit.Layout.Column = 2;
runStatus = uilabel(rg,'Text','Save the project, then submit it to Hub.'); runStatus.Layout.Row = 6; runStatus.Layout.Column = [1 2];

mg = uigridlayout(monitorTab,[3 1]); mg.RowHeight = {28,28,'1x'};
monitorStatus = uilabel(mg,'Text',initialMonitorText(jobId)); uibutton(mg,'Text','Refresh now','ButtonPushedFcn',@refreshJob);
console = uitextarea(mg,'Editable','off','Value',{'Monitor ready.'});
timerObj = timer('ExecutionMode','fixedSpacing','Period',5,'TimerFcn',@(~,~)refreshJob()); start(timerObj);
fig.CloseRequestFcn = @closeGui;

    function addField(grid,label,value,fieldName)
        uialabel(grid,'Text',label); control = uieditfield(grid,'text','Value',char(string(value))); control.Tag = fieldName;
    end
    function connectHub(~,~)
        try
            hub.baseUrl = findobj(connectionTab,'Tag','baseUrl').Value; hub.userKey = findobj(connectionTab,'Tag','userKey').Value;
            hub.defaultRemoteProjectRoot = remoteRoot.Value; hub.defaultLocalProjectRoot = localRoot.Value;
            [~,hub] = detecdiv_hub_login(hub.userKey,password.Value,hub); detecdiv_hub_settings_set(hub); session.Text = shortToken(hub); password.Value = '';
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
