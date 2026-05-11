classdef pipelineRunGUI < matlab.apps.AppBase

    properties (Access = public)
        UIFigure                    matlab.ui.Figure
        ProjectDropDownLabel        matlab.ui.control.Label
        ProjectDropDown             matlab.ui.control.DropDown
        RunIdEditFieldLabel         matlab.ui.control.Label
        RunIdEditField              matlab.ui.control.EditField
        DescriptionEditFieldLabel   matlab.ui.control.Label
        DescriptionEditField        matlab.ui.control.EditField
        RunPolicyDropDownLabel      matlab.ui.control.Label
        RunPolicyDropDown           matlab.ui.control.DropDown
        ExistingPolicyDropDownLabel matlab.ui.control.Label
        ExistingPolicyDropDown      matlab.ui.control.DropDown
        CachePolicyDropDownLabel    matlab.ui.control.Label
        CachePolicyDropDown         matlab.ui.control.DropDown
        GpuPolicyDropDownLabel      matlab.ui.control.Label
        GpuPolicyDropDown           matlab.ui.control.DropDown
        ExecutionModeDropDownLabel  matlab.ui.control.Label
        ExecutionModeDropDown       matlab.ui.control.DropDown
        InputSourceDropDownLabel    matlab.ui.control.Label
        InputSourceDropDown         matlab.ui.control.DropDown
        FovSelectionEditFieldLabel  matlab.ui.control.Label
        FovSelectionEditField       matlab.ui.control.EditField
        PythonEnvModeDropDownLabel  matlab.ui.control.Label
        PythonEnvModeDropDown       matlab.ui.control.DropDown
        PythonEnvNameEditFieldLabel matlab.ui.control.Label
        PythonEnvNameEditField      matlab.ui.control.EditField
        NodeTableLabel              matlab.ui.control.Label
        NodeTable                   matlab.ui.control.Table
        ParamTableLabel             matlab.ui.control.Label
        ParamTable                  matlab.ui.control.Table
        OpenNodeGUIButton           matlab.ui.control.Button
        HubStatusLabel              matlab.ui.control.Label
        RefreshHubButton            matlab.ui.control.Button
        RunOnHubButton              matlab.ui.control.Button
        CreateRunButton             matlab.ui.control.Button
        CloseButton                 matlab.ui.control.Button
    end

    properties (Access = private)
        Data struct = struct( ...
            'pipelineSpec', struct('nodes',[],'edges',[]), ...
            'shallowObj', [], ...
            'runObj', [], ...
            'editMode', false, ...
            'dirty', false, ...
            'projectVars', {{}}, ...
            'selectedNode', [], ...
            'nodeTemplateParams', {{}}, ...
            'nodeParams', {{}}, ...
            'templateId', 'pipeline', ...
            'templatePath', '' )
        CurrentRunParamRows struct = struct( ...
            'section',{},'label',{},'key',{},'templateValue',{},'overrideValue',{}, ...
            'notes',{},'editable',{},'kind',{},'choiceItems',{},'allowMulti',{}, ...
            'storageKind',{},'templateRaw',{},'defaultRaw',{})
    end

    methods (Access = private)

        function startupFcn(app, varargin)
            pipeIn = [];
            shallowObj = [];
            runObj = [];

            for i = 1:numel(varargin)
                arg = varargin{i};
                if isa(arg, 'shallow')
                    shallowObj = arg;
                elseif isa(arg, 'pipelineRun')
                    runObj = arg;
                elseif isa(arg, 'pipeline') || (isstruct(arg) && isfield(arg,'nodes'))
                    pipeIn = arg;
                end
            end

            if isempty(pipeIn) && ~isempty(runObj)
                pipeIn = resolvePipelineSpecFromRun(app, runObj);
            end

            if isempty(pipeIn)
                uialert(app.UIFigure, 'A pipeline object/struct is required.', 'Error', 'Icon', 'error');
                delete(app);
                return;
            end

            [spec, templateId, templatePath] = normalizePipelineSpec(app, pipeIn);
            if isempty(templatePath)
                templatePath = inferTemplatePathFromProject(app, shallowObj, templateId);
            end
            app.Data.pipelineSpec = spec;
            app.Data.templateId = templateId;
            app.Data.templatePath = templatePath;
            app.Data.shallowObj = shallowObj;
            app.Data.runObj = runObj;
            app.Data.editMode = ~isempty(runObj);

            initProjectList(app);
            initNodeTable(app);

            if ~isempty(runObj)
                loadRunIntoUi(app, runObj);
                app.CreateRunButton.Text = 'Save run';
                app.RunIdEditField.Editable = 'off';
            elseif ~isempty(shallowObj)
                app.RunIdEditField.Value = suggestRunId(app, shallowObj, templateId);
                app.RunPolicyDropDown.Value = 'Resume previous progress';
                app.ExistingPolicyDropDown.Value = 'Use each module default';
                app.CachePolicyDropDown.Value = 'Automatic';
                app.GpuPolicyDropDown.Value = 'Use each module default';
                app.InputSourceDropDown.Value = 'Start from raw data (dataloader)';
                app.FovSelectionEditField.Value = '';
                app.PythonEnvModeDropDown.Value = 'Default detecdiv_python';
                app.PythonEnvNameEditField.Value = '';
                app.ExecutionModeDropDown.Value = 'Local MATLAB session';
            else
                app.RunIdEditField.Value = [templateId '_run'];
                app.RunPolicyDropDown.Value = 'Resume previous progress';
                app.ExistingPolicyDropDown.Value = 'Use each module default';
                app.CachePolicyDropDown.Value = 'Automatic';
                app.GpuPolicyDropDown.Value = 'Use each module default';
                app.InputSourceDropDown.Value = 'Start from raw data (dataloader)';
                app.FovSelectionEditField.Value = '';
                app.PythonEnvModeDropDown.Value = 'Default detecdiv_python';
                app.PythonEnvNameEditField.Value = '';
                app.ExecutionModeDropDown.Value = 'Local MATLAB session';
            end
            initTooltips(app);
            updateRunSourceSelectionUi(app);
            updatePythonEnvUi(app);
            updateHubStatusUi(app);
            app.Data.dirty = ~app.Data.editMode;
            updateWindowTitle(app);
        end

        function pipeIn = resolvePipelineSpecFromRun(app, runObj)
            pipeIn = [];
            try
                spec = runObj.ctx.pipelineSpec;
                if isstruct(spec) && isfield(spec,'nodes') && ~isempty(spec.nodes)
                    pipeIn = spec;
                    if ~isfield(pipeIn,'edges') || isempty(pipeIn.edges)
                        pipeIn.edges = struct([]);
                    end
                    if ~isfield(pipeIn,'name') || isempty(pipeIn.name)
                        pipeIn.name = char(string(runObj.templateId));
                    end
                    if ~isfield(pipeIn,'path') || isempty(pipeIn.path)
                        pipeIn.path = char(string(runObj.templatePath));
                    end
                    return;
                end
            catch
            end

            try
                refPath = '';
                if isprop(runObj,'pipelineRef') && isstruct(runObj.pipelineRef) && isfield(runObj.pipelineRef,'path') && ~isempty(runObj.pipelineRef.path)
                    refPath = char(string(runObj.pipelineRef.path));
                elseif isprop(runObj,'templatePath') && ~isempty(runObj.templatePath)
                    refPath = char(string(runObj.templatePath));
                end
                if ~isempty(refPath)
                    [pipeObj, ~] = pipelineLoad(refPath);
                    if ~isempty(pipeObj)
                        pipeIn = pipeObj;
                    end
                end
            catch
            end
        end

        function [spec, templateId, templatePath] = normalizePipelineSpec(app, pipeIn) %#ok<INUSD>
            spec = struct('nodes',[],'edges',[]);
            templateId = 'pipeline';
            templatePath = '';

            if isa(pipeIn, 'pipeline')
                spec.nodes = pipeIn.nodes;
                spec.edges = pipeIn.edges;
                templateId = pipeIn.strid;
                templatePath = pipeIn.path;
                return;
            end

            if isstruct(pipeIn)
                if isfield(pipeIn, 'nodes')
                    spec.nodes = pipeIn.nodes;
                end
                if isfield(pipeIn, 'edges')
                    spec.edges = pipeIn.edges;
                end
                if isfield(pipeIn, 'name') && ~isempty(pipeIn.name)
                    templateId = char(string(pipeIn.name));
                end
                if isfield(pipeIn, 'path') && ~isempty(pipeIn.path)
                    templatePath = char(string(pipeIn.path));
                end
            end
        end

        function templatePath = inferTemplatePathFromProject(app, shallowObj, templateId) %#ok<INUSD>
            templatePath = '';
            if isempty(shallowObj) || ~isa(shallowObj, 'shallow')
                return;
            end
            try
                if ~isprop(shallowObj,'runProfiles') || isempty(shallowObj.runProfiles) || ...
                        ~isfield(shallowObj.runProfiles,'pipeline') || isempty(shallowObj.runProfiles.pipeline)
                    return;
                end
                p = shallowObj.runProfiles.pipeline;
                if isfield(p,'defaultTemplatePath') && ~isempty(p.defaultTemplatePath)
                    candidate = char(string(p.defaultTemplatePath));
                    if exist(candidate, 'file') == 2
                        if nargin < 3 || isempty(templateId) || ...
                                ~isfield(p,'defaultTemplateId') || isempty(p.defaultTemplateId) || ...
                                strcmp(char(string(p.defaultTemplateId)), char(string(templateId)))
                            templatePath = fileparts(candidate);
                        end
                    end
                end
            catch
                templatePath = '';
            end
        end

        function initProjectList(app)
            if ~isempty(app.Data.shallowObj)
                app.ProjectDropDown.Items = {app.Data.shallowObj.io.file};
                app.ProjectDropDown.Value = app.Data.shallowObj.io.file;
                app.ProjectDropDown.Enable = 'off';
                app.Data.projectVars = {app.Data.shallowObj.io.file};
                return;
            end

            varlist = evalin('base','who');
            names = {};
            for i = 1:numel(varlist)
                if strcmp(varlist{i}, 'ans')
                    continue;
                end
                try
                    tmp = evalin('base', varlist{i});
                    if isa(tmp, 'shallow')
                        names{end+1} = varlist{i}; %#ok<AGROW>
                    end
                catch
                end
            end

            if isempty(names)
                app.ProjectDropDown.Items = {'<no project in workspace>'};
                app.ProjectDropDown.Value = '<no project in workspace>';
                app.ProjectDropDown.Enable = 'off';
                app.CreateRunButton.Enable = 'off';
                app.Data.projectVars = {};
            else
                app.ProjectDropDown.Items = names;
                app.ProjectDropDown.Value = names{1};
                app.ProjectDropDown.Enable = 'on';
                app.CreateRunButton.Enable = 'on';
                app.Data.projectVars = names;
            end
        end

        function initNodeTable(app)
            nodes = app.Data.pipelineSpec.nodes;
            n = numel(nodes);
            data = cell(n,6);
            app.Data.nodeTemplateParams = cell(n,1);
            app.Data.nodeParams = cell(n,1);

            for i = 1:n
                node = nodes(i);
                pkg = resolveNodePackageLocal(app, node);

                data{i,1} = true;
                data{i,2} = char(string(node.id));
                data{i,3} = describeNodeFamilyLocal(app, node);
                data{i,4} = describeNodeStageLocal(app, node);
                data{i,5} = pkg;
                data{i,6} = describeNodeBindingLocal(app, node);

                tpl = struct();
                if isfield(node,'params') && isstruct(node.params)
                    tpl = node.params;
                end
                app.Data.nodeTemplateParams{i} = tpl;
                app.Data.nodeParams{i} = struct();
            end

            app.NodeTable.Data = data;
            if n > 0
                app.NodeTable.Selection = [1 2];
                app.Data.selectedNode = 1;
                updateParamTable(app, 1);
            else
                app.Data.selectedNode = [];
                app.ParamTable.Data = {};
            end
        end

        function loadRunIntoUi(app, runObj)
            if isempty(runObj) || ~isa(runObj, 'pipelineRun')
                return;
            end

            try
                if ~isempty(runObj.runId)
                    app.RunIdEditField.Value = char(string(runObj.runId));
                end
            catch
            end
            try
                if ~isempty(runObj.description)
                    app.DescriptionEditField.Value = char(string(runObj.description));
                end
            catch
            end

            try
                if isstruct(runObj.ctx) && isfield(runObj.ctx,'run') && isstruct(runObj.ctx.run)
                    runCfg = runObj.ctx.run;
                    if isfield(runCfg,'runPolicy') && ~isempty(runCfg.runPolicy)
                        app.RunPolicyDropDown.Value = runPolicyToLabel(app, runCfg.runPolicy);
                    end
                    if isfield(runCfg,'gpuPolicy') && ~isempty(runCfg.gpuPolicy)
                        app.GpuPolicyDropDown.Value = gpuPolicyToLabel(app, runCfg.gpuPolicy);
                    end
                    if isfield(runCfg,'executionMode') && ~isempty(runCfg.executionMode)
                        app.ExecutionModeDropDown.Value = executionModeToLabel(app, runCfg.executionMode);
                    end
                    if isfield(runCfg,'inputSource') && ~isempty(runCfg.inputSource)
                        app.InputSourceDropDown.Value = inputSourceToLabel(app, runCfg.inputSource);
                    end
                    if isfield(runCfg,'selectedNodes') && ~isempty(runCfg.selectedNodes)
                        selectedIds = cellstr(runCfg.selectedNodes(:));
                        data = app.NodeTable.Data;
                        for ii = 1:size(data,1)
                            data{ii,1} = any(strcmp(selectedIds, char(string(data{ii,2}))));
                        end
                        app.NodeTable.Data = data;
                    end
                    if isfield(runCfg,'nodeParams') && isstruct(runCfg.nodeParams) && ~isempty(runCfg.nodeParams)
                        for ii = 1:numel(runCfg.nodeParams)
                            nodeId = char(string(runCfg.nodeParams(ii).id));
                            idx = find(strcmp({app.Data.pipelineSpec.nodes.id}, nodeId), 1);
                            if ~isempty(idx) && isstruct(runCfg.nodeParams(ii).params)
                                app.Data.nodeParams{idx} = runCfg.nodeParams(ii).params;
                            end
                        end
                    end
                end
            catch
            end
            try
                if strcmpi(app.ExecutionModeDropDown.Value, 'Local MATLAB session') && ~isempty(localRunHubJobId(app, runObj))
                    app.ExecutionModeDropDown.Value = 'Detecdiv hub';
                end
            catch
            end

            try
                if isstruct(runObj.ctx) && isfield(runObj.ctx,'io') && isstruct(runObj.ctx.io)
                    ioCfg = runObj.ctx.io;
                    if isfield(ioCfg,'existingPolicy') && ~isempty(ioCfg.existingPolicy)
                        existingLabel = existingPolicyToLabel(app, ioCfg.existingPolicy);
                        if any(strcmp(app.ExistingPolicyDropDown.Items, existingLabel))
                            app.ExistingPolicyDropDown.Value = existingLabel;
                        end
                    end
                    if isfield(ioCfg,'cachePolicy') && ~isempty(ioCfg.cachePolicy)
                        cacheLabel = cachePolicyToLabel(app, ioCfg.cachePolicy);
                        if any(strcmp(app.CachePolicyDropDown.Items, cacheLabel))
                            app.CachePolicyDropDown.Value = cacheLabel;
                        end
                    end
                end
            catch
            end

            try
                if isstruct(runObj.ctx) && isfield(runObj.ctx,'sel') && isstruct(runObj.ctx.sel) ...
                        && isfield(runObj.ctx.sel,'fovs') && ~isempty(runObj.ctx.sel.fovs)
                    app.FovSelectionEditField.Value = valueToDisplay(app, runObj.ctx.sel.fovs);
                end
            catch
            end

            try
                if isstruct(runObj.ctx) && isfield(runObj.ctx,'exec') && isstruct(runObj.ctx.exec)
                    execCfg = runObj.ctx.exec;
                    if isfield(execCfg,'python') && isstruct(execCfg.python)
                        py = execCfg.python;
                        mode = char(string(getfielddefault(app, py,'mode','default')));
                        if strcmpi(mode,'custom')
                            app.PythonEnvModeDropDown.Value = 'Custom conda env';
                            app.PythonEnvNameEditField.Value = char(string(getfielddefault(app, py,'envName','')));
                        else
                            app.PythonEnvModeDropDown.Value = 'Default detecdiv_python';
                            app.PythonEnvNameEditField.Value = '';
                        end
                    end
                end
            catch
            end

            updateRunSourceSelectionUi(app);
            updatePythonEnvUi(app);
            if ~isempty(app.Data.selectedNode)
                updateParamTable(app, app.Data.selectedNode);
            end
        end

        function dflt = getRunDefaults(app, node) %#ok<INUSD>
            t = lower(char(string(node.type)));
            switch t
                case 'dataloader'
                    dflt = struct('path','','positionIdx',[],'channelIdx',[],'frameRange',[],'label','');
                case {'roiidentify','roipattern'}
                    dflt = struct('fovIndex',[],'referenceFrame',[],'channel','','channelIndex',[],'threshold',[], ...
                        'activePatternIndex',[],'fallbackFullFrame',[],'keepExisting',[]);
                case 'roimanual'
                    dflt = struct('fovIndex',[],'keepExisting',[],'openFirstOnly',[]);
                case 'roigrid'
                    dflt = struct('fovIndex',[],'mode','','gridCount',[],'keepExisting',[]);
                case 'roitracked'
                    dflt = struct('fovIndex',[],'roiIndex',[],'channel','','margin',0, ...
                        'extract',true,'extractFrames',[],'extractChannels',[],'saveArgs',{{}});
                case 'roiextract'
                    dflt = struct('fovIndex',[],'channels',[],'frames',[],'correctDrift',[], ...
                        'driftChannel',[],'driftMethod','','driftRefMode','','driftSubpixel',[], ...
                        'driftMaxShift',[],'scale',[],'cropDrift',[],'extend',[],'forceChannelNames',[]);
                case {'processor','classifier'}
                    dflt = struct('roiList',[],'channels',[],'frames',[]);
                    if strcmp(t, 'classifier')
                        dflt.moduleVar = '';
                        dflt.modulePath = '';
                        dflt.moduleId = '';
                    end
                otherwise
                    dflt = struct();
            end
            dflt = addCommonRunDefaults(app, t, dflt);
        end

        function dflt = addCommonRunDefaults(app, nodeType, dflt)
            common = struct('runPolicy','','existingPolicy','');
            if any(strcmp(nodeType, {'roiextract','roitracked','processor','classifier'}))
                common.cachePolicy = '';
            end
            if any(strcmp(nodeType, {'processor','classifier'}))
                common.outputName = '';
            end
            dflt = mergeStructLocal(app, common, dflt);
        end

        function p = mergeDefaults(app, p, dflt) %#ok<INUSD>
            if ~isstruct(p)
                p = struct();
            end
            fn = fieldnames(dflt);
            for i = 1:numel(fn)
                k = fn{i};
                if ~isfield(p, k)
                    p.(k) = dflt.(k);
                end
            end
        end

        function updateParamTable(app, row)
            if isempty(row) || row < 1 || row > numel(app.Data.nodeParams)
                app.CurrentRunParamRows = struct( ...
                    'section',{},'label',{},'key',{},'templateValue',{},'overrideValue',{}, ...
                    'notes',{},'editable',{},'kind',{},'choiceItems',{},'allowMulti',{}, ...
                    'storageKind',{},'templateRaw',{},'defaultRaw',{});
                app.ParamTable.Data = {};
                return;
            end

            tpl = getTemplateParams(app, row);
            runP = app.Data.nodeParams{row};
            if ~isstruct(runP)
                runP = struct();
            end

            node = app.Data.pipelineSpec.nodes(row);
            rows = buildRunParamRows(app, row, node, tpl, runP);
            app.CurrentRunParamRows = rows;
            app.ParamTable.Data = runParamRowsToTableData(app, rows);
        end

        function out = valueToDisplay(app, v) %#ok<INUSD>
            if islogical(v)
                if v, out = 'true'; else, out = 'false'; end
            elseif isnumeric(v)
                if isscalar(v)
                    out = num2str(v);
                else
                    out = compactNumericDisplay(app, v);
                end
            elseif ischar(v)
                out = v;
            elseif isstring(v)
                out = char(v);
            elseif iscell(v) || isstruct(v)
                try
                    out = jsonencode(v);
                catch
                    out = char(string(v));
                end
            else
                out = char(string(v));
            end
        end

        function initTooltips(app)
            projectTip = { ...
                'Project that will own this pipeline run.', ...
                'If this window was opened from an existing project, the project is locked here.'};
            app.ProjectDropDown.Tooltip = projectTip;
            app.ProjectDropDownLabel.Tooltip = projectTip;

            runPolicyTip = { ...
                'Rerun mode controls what happens if this run already has progress or outputs.', ...
                'Resume previous progress: reuse prior work when the runner can do so safely.', ...
                'Restart from scratch: ignore prior progress and execute the selected nodes again.'};
            app.RunPolicyDropDown.Tooltip = runPolicyTip;
            app.RunPolicyDropDownLabel.Tooltip = runPolicyTip;

            existingTip = { ...
                'Existing outputs policy controls what to do when a node would write data that already exists.', ...
                'Use each module default: keep the node''s own behavior.', ...
                'Replace existing outputs: overwrite prior outputs.', ...
                'Append alongside existing outputs: keep prior data and add new outputs.', ...
                'Skip when outputs exist: do nothing for that step if outputs are already there.', ...
                'Stop when outputs exist: fail fast instead of modifying data.', ...
                'Upsert when supported: update in place if the node supports it, otherwise create.'};
            app.ExistingPolicyDropDown.Tooltip = existingTip;
            app.ExistingPolicyDropDownLabel.Tooltip = existingTip;

            cacheTip = { ...
                'ROI cache mode controls where extracted ROI image data is buffered during the run.', ...
                'Automatic: let the runner choose.', ...
                'Prefer memory cache: keep ROI content in RAM when possible.', ...
                'Prefer disk cache: favor on-disk buffering to reduce RAM pressure.'};
            app.CachePolicyDropDown.Tooltip = cacheTip;
            app.CachePolicyDropDownLabel.Tooltip = cacheTip;

            gpuTip = { ...
                'Global GPU policy for this run.', ...
                'Use each module default: keep each node''s own GPU behavior.', ...
                'Force GPU where supported: request GPU everywhere a compatible node supports it.', ...
                'Force CPU: disable GPU even for modules that default to GPU, useful for debug and thermal limits.'};
            app.GpuPolicyDropDown.Tooltip = gpuTip;
            app.GpuPolicyDropDownLabel.Tooltip = gpuTip;

            executionTip = { ...
                'Execution mode for this pipeline run.', ...
                'Local MATLAB session keeps execution in the current MATLAB process.', ...
                'Detecdiv hub submits the saved pipelineRun to detecdiv-hub for remote execution.'};
            app.ExecutionModeDropDown.Tooltip = executionTip;
            app.ExecutionModeDropDownLabel.Tooltip = executionTip;

            sourceTip = { ...
                'Start from defines where execution begins and which existing project data is reused.', ...
                'Start from raw data (dataloader): start from raw image loading.', ...
                'Reuse existing project FOVs: bypass the dataloader and use FOVs already in the project.', ...
                'Reuse existing ROIs: start from previously created ROIs.', ...
                'Reuse existing masks: start from ROI data that already contains mask-like channels.', ...
                'Reuse existing data series: start from ROI quantitative outputs already present.'};
            app.InputSourceDropDown.Tooltip = sourceTip;
            app.InputSourceDropDownLabel.Tooltip = sourceTip;

            pythonTip = { ...
                'Python environment prepared at the very beginning of the run for Python-backed nodes.', ...
                'Default detecdiv_python: use the standard Detecdiv conda env with no mid-run prompt.', ...
                'Custom conda env: resolve a specific existing conda env by name.'};
            app.PythonEnvModeDropDown.Tooltip = pythonTip;
            app.PythonEnvModeDropDownLabel.Tooltip = pythonTip;

            pythonNameTip = { ...
                'Name of the custom conda environment to use for this run.', ...
                'Example: cellpose_env', ...
                'Ignored when Python runtime is set to Default detecdiv_python.'};
            app.PythonEnvNameEditField.Tooltip = pythonNameTip;
            app.PythonEnvNameEditFieldLabel.Tooltip = pythonNameTip;

            app.RunOnHubButton.Tooltip = 'Submit the saved pipelineRun to detecdiv-hub.';
            app.RefreshHubButton.Tooltip = 'Refresh the current hub job status.';
        end

        function out = compactNumericDisplay(app, v) %#ok<INUSD>
            if ~isnumeric(v) || isempty(v)
                out = '';
                return;
            end

            if ~isvector(v)
                out = mat2str(v);
                return;
            end

            x = double(v(:)');
            if numel(x) <= 1
                out = num2str(x);
                return;
            end

            if all(isfinite(x))
                d = diff(x);
                if ~isempty(d) && all(abs(d - d(1)) < 1e-12)
                    step = d(1);
                    if abs(step - 1) < 1e-12
                        out = sprintf('%s:%s', num2str(x(1)), num2str(x(end)));
                        return;
                    end
                    out = sprintf('%s:%s:%s', num2str(x(1)), num2str(step), num2str(x(end)));
                    return;
                end

                if all(abs(x - round(x)) < 1e-12)
                    parts = {};
                    startVal = x(1);
                    prevVal = x(1);
                    for ii = 2:numel(x)
                        if abs(x(ii) - (prevVal + 1)) < 1e-12
                            prevVal = x(ii);
                            continue;
                        end
                        parts{end+1} = makeIntegerRunString(app, startVal, prevVal); %#ok<AGROW>
                        startVal = x(ii);
                        prevVal = x(ii);
                    end
                    parts{end+1} = makeIntegerRunString(app, startVal, prevVal); %#ok<AGROW>
                    if numel(parts) > 1
                        out = ['[' strjoin(parts, ' ') ']'];
                        return;
                    end
                end
            end

            out = mat2str(v);
        end

        function txt = makeIntegerRunString(app, a, b) %#ok<INUSD>
            if abs(a - b) < 1e-12
                txt = num2str(round(a));
            elseif abs(b - (a + 1)) < 1e-12
                txt = sprintf('%d %d', round(a), round(b));
            else
                txt = sprintf('%d:%d', round(a), round(b));
            end
        end

        function tf = isDefaultRunValue(app, row, key, v)
            tf = false;
            if isempty(app.Data.pipelineSpec.nodes) || row < 1 || row > numel(app.Data.pipelineSpec.nodes)
                return;
            end
            dflt = getRunDefaults(app, app.Data.pipelineSpec.nodes(row));
            if isstruct(dflt) && isfield(dflt, key)
                try
                    tf = isequaln(v, dflt.(key));
                catch
                    tf = false;
                end
            end
        end

        function v = getRunDefaultValue(app, row, key)
            v = [];
            if isempty(app.Data.pipelineSpec.nodes) || row < 1 || row > numel(app.Data.pipelineSpec.nodes)
                return;
            end
            dflt = getRunDefaults(app, app.Data.pipelineSpec.nodes(row));
            if isstruct(dflt) && isfield(dflt, key)
                v = dflt.(key);
            end
        end

        function p = getTemplateParams(app, row)
            p = struct();
            if row >= 1 && row <= numel(app.Data.nodeTemplateParams)
                tmp = app.Data.nodeTemplateParams{row};
                if isstruct(tmp)
                    p = tmp;
                end
            end
        end

        function p = getMergedNodeParams(app, row)
            p = getTemplateParams(app, row);
            if row >= 1 && row <= numel(app.Data.nodeParams)
                ov = app.Data.nodeParams{row};
                if isstruct(ov)
                    p = mergeStructLocal(app, p, ov);
                end
            end
        end

        function rows = buildRunParamRows(app, row, node, tpl, runP)
            rows = struct( ...
                'section',{},'label',{},'key',{},'templateValue',{},'overrideValue',{}, ...
                'notes',{},'editable',{},'kind',{},'choiceItems',{},'allowMulti',{}, ...
                'storageKind',{},'templateRaw',{},'defaultRaw',{});

            dflt = getRunDefaults(app, node);
            tipMap = buildParamTipMapLocal(app, tpl);
            keys = orderedRunParamKeys(app, tpl, runP, dflt);
            inheritedFrames = getInheritedFramesDisplay(app, row);
            rows = appendMissingConfigRunRows(app, node, tpl, runP, dflt, rows);

            for i = 1:numel(keys)
                key = keys{i};
                if ~shouldExposeRunParamKey(app, key, tpl, runP, dflt)
                    continue;
                end

                tplVal = [];
                if isfield(tpl, key)
                    tplVal = tpl.(key);
                end
                dfltVal = [];
                if isfield(dflt, key)
                    dfltVal = dflt.(key);
                end

                hasOverride = isfield(runP, key);
                if hasOverride
                    overrideVal = runP.(key);
                else
                    overrideVal = dfltVal;
                end

                notes = getfielddefault(app, tipMap, key, '');
                if strcmpi(key, 'frames') && ~isempty(inheritedFrames)
                    notes = appendRunNote(app, notes, ['Inherited when empty: ' inheritedFrames]);
                end

                rowMeta = buildRunParamRow(app, node, key, tplVal, overrideVal, notes, dfltVal, hasOverride);
                rows(end+1) = rowMeta; %#ok<AGROW>
            end
        end

        function rows = appendMissingConfigRunRows(app, node, tpl, runP, dflt, rows)
            if nargin < 6 || isempty(rows)
                rows = struct( ...
                    'section',{},'label',{},'key',{},'templateValue',{},'overrideValue',{}, ...
                    'notes',{},'editable',{},'kind',{},'choiceItems',{},'allowMulti',{}, ...
                    'storageKind',{},'templateRaw',{},'defaultRaw',{});
            end
            c = pipelineNodeContract(node, resolveNodePackageLocal(app, node));
            if isempty(c) || ~isstruct(c) || ~isfield(c, 'parameters') || ~isstruct(c.parameters)
                return;
            end

            configKeys = {};
            configKeys = [configKeys normalizeParamNameListLocal(app, getfielddefault(app, c.parameters, 'fixed', {}))]; %#ok<AGROW>
            configKeys = [configKeys normalizeParamNameListLocal(app, getfielddefault(app, c.parameters, 'design', {}))]; %#ok<AGROW>
            configKeys = [configKeys normalizeParamNameListLocal(app, getfielddefault(app, c.parameters, 'template', {}))]; %#ok<AGROW>
            configKeys = unique(configKeys(~cellfun(@isempty, configKeys)), 'stable');
            if isempty(configKeys)
                return;
            end

            existing = lower(strtrim(cellstr(string({rows.key}))));
            for i = 1:numel(configKeys)
                key = char(string(configKeys{i}));
                if any(strcmp(existing, lower(strtrim(key))))
                    continue;
                end

                if isfield(runP, key)
                    overrideVal = runP.(key);
                    hasOverride = true;
                elseif isfield(tpl, key)
                    overrideVal = tpl.(key);
                    hasOverride = false;
                elseif isfield(dflt, key)
                    overrideVal = dflt.(key);
                    hasOverride = false;
                else
                    overrideVal = [];
                    hasOverride = false;
                end
                rows(end+1) = buildRunParamRow(app, node, key, getfielddefault(app, tpl, key, []), overrideVal, configRunNote(app, node, key), getfielddefault(app, dflt, key, []), hasOverride); %#ok<AGROW>
                rows(end).section = 'Config';
            end
        end

        function data = runParamRowsToTableData(app, rows) %#ok<INUSD>
            if isempty(rows)
                data = {};
                return;
            end
            data = cell(numel(rows), 5);
            for i = 1:numel(rows)
                data{i,1} = rows(i).section;
                data{i,2} = rows(i).label;
                data{i,3} = rows(i).templateValue;
                data{i,4} = rows(i).overrideValue;
                data{i,5} = rows(i).notes;
            end
        end

        function rowMeta = buildRunParamRow(app, node, key, tplVal, overrideVal, notes, dfltVal, hasOverride)
            section = categorizeRunParamKey(app, node, key);
            label = friendlyRunParamLabel(app, key);
            if isChannelSlotBindingKeyLocal(app, node, key)
                label = strtrim(regexprep(char(string(key)), '^Channel', 'Slot '));
            end
            kind = 'text';
            choiceItems = {};
            allowMulti = false;
            storageKind = 'plain';

            refVal = overrideVal;
            if isempty(refVal)
                refVal = tplVal;
            end

            if isChannelSlotBindingKeyLocal(app, node, key)
                choiceItems = unique([{'none'}, getNodeSelectableChannelsLocal(app, rowFromNode(app, node))], 'stable');
                storageKind = 'plain';
                if isChoicePayloadLocal(app, tplVal)
                    templateText = extractChoiceDisplayLocal(app, tplVal);
                else
                    templateText = valueToDisplay(app, tplVal);
                end
                if isempty(strtrim(templateText))
                    templateText = '<pipeline default>';
                end
                if hasOverride
                    if isChoicePayloadLocal(app, overrideVal)
                        overrideText = extractChoiceDisplayLocal(app, overrideVal);
                    else
                        overrideText = valueToDisplay(app, overrideVal);
                    end
                else
                    overrideText = '<inherit>';
                end
                notes = appendRunNote(app, notes, 'Binding slot. Pick one dataset channel, or none to leave this slot unused.');
                if ~isempty(choiceItems)
                    kind = 'choice';
                end
            elseif isChoicePayloadLocal(app, refVal)
                choiceItems = getChoicePayloadItemsLocal(app, refVal);
                kind = 'choice';
                storageKind = 'choicePayload';
            elseif isChannelSelectorKeyLocal(app, node, key)
                choiceItems = getNodeSelectableChannelsLocal(app, rowFromNode(app, node));
                allowMulti = strcmpi(key, 'channels') && ~requiresSingleExplicitChannelLocal(app, node);
                if ~isempty(choiceItems)
                    kind = 'choice';
                end
            end

            if isChoicePayloadLocal(app, tplVal)
                templateText = extractChoiceDisplayLocal(app, tplVal);
            else
                templateText = valueToDisplay(app, tplVal);
            end
            if isempty(strtrim(templateText))
                templateText = '<pipeline default>';
            end

            if hasOverride
                if isChoicePayloadLocal(app, overrideVal)
                    overrideText = extractChoiceDisplayLocal(app, overrideVal);
                else
                    overrideText = valueToDisplay(app, overrideVal);
                end
            else
                overrideText = '<inherit>';
            end

            if strcmp(kind, 'choice')
                if hasOverride
                    overrideText = extractChoiceDisplayLocal(app, overrideVal);
                else
                    overrideText = '<inherit>';
                end
                if ~isempty(choiceItems)
                    notes = appendRunNote(app, notes, sprintf('Click the override cell to choose from %d option(s).', numel(choiceItems)));
                end
            end

            if islogical(refVal) && isscalar(refVal)
                notes = appendRunNote(app, notes, 'Type true/false to override this flag.');
            elseif isstruct(refVal) || (iscell(refVal) && ~isChoicePayloadLocal(app, refVal))
                notes = appendRunNote(app, notes, 'Structured value. For complex edits, use the node-specific GUI.');
            end

            rowMeta = struct( ...
                'section', section, ...
                'label', label, ...
                'key', char(string(key)), ...
                'templateValue', templateText, ...
                'overrideValue', overrideText, ...
                'notes', notes, ...
                'editable', true, ...
                'kind', kind, ...
                'choiceItems', {choiceItems}, ...
                'allowMulti', allowMulti, ...
                'storageKind', storageKind, ...
                'templateRaw', {tplVal}, ...
                'defaultRaw', {dfltVal});
        end

        function keys = orderedRunParamKeys(app, tpl, runP, dflt) %#ok<INUSD>
            keys = {};
            if isstruct(tpl)
                tplKeys = fieldnames(tpl);
                tplKeys(strcmp(tplKeys, 'tip')) = [];
                keys = [keys; tplKeys];
            end
            if isstruct(dflt)
                keys = [keys; fieldnames(dflt)];
            end
            if isstruct(runP)
                keys = [keys; fieldnames(runP)];
            end
            keys = unique(keys, 'stable');
        end

        function tf = shouldExposeRunParamKey(app, key, tpl, runP, dflt) %#ok<INUSD>
            lowerKey = lower(char(string(key)));
            if strcmp(lowerKey, 'tip')
                tf = false;
                return;
            end
            if any(strcmp(lowerKey, {'modulevar','modulepath','moduleid'}))
                hasValue = (isstruct(runP) && isfield(runP, key) && ~isempty(runP.(key))) || ...
                    (isstruct(tpl) && isfield(tpl, key) && ~isempty(tpl.(key)));
                tf = hasValue;
                return;
            end
            tf = true;
        end

        function out = getInheritedFramesDisplay(app, row)
            out = '';
            if row < 1 || row > numel(app.Data.pipelineSpec.nodes)
                return;
            end

            currentParams = getMergedNodeParams(app, row);
            if isstruct(currentParams) && isfield(currentParams, 'frames') ...
                    && ~isempty(currentParams.frames) && ~(isnumeric(currentParams.frames) && isequal(currentParams.frames, -1))
                return;
            end

            if isempty(app.NodeTable.Data)
                return;
            end

            selectedMask = false(size(app.NodeTable.Data, 1), 1);
            try
                selectedMask = logical(cell2mat(app.NodeTable.Data(:,1)));
            catch
            end

            if row > numel(selectedMask) || ~selectedMask(row)
                return;
            end

            for ii = row-1:-1:1
                if ii > numel(selectedMask) || ~selectedMask(ii)
                    continue;
                end
                params = getMergedNodeParams(app, ii);
                if ~isstruct(params) || ~isfield(params, 'frames') || isempty(params.frames)
                    continue;
                end
                framesVal = params.frames;
                if isnumeric(framesVal) && isequal(framesVal, -1)
                    continue;
                end
                sourceId = char(string(app.Data.pipelineSpec.nodes(ii).id));
                out = sprintf('%s (from %s)', valueToDisplay(app, framesVal), sourceId);
                return;
            end
        end

        function out = mergeStructLocal(app, base, patch) %#ok<INUSD>
            if nargin < 2 || ~isstruct(base) || isempty(base)
                base = struct();
            end
            out = base;
            if nargin < 3 || ~isstruct(patch) || isempty(patch)
                return;
            end
            fn = fieldnames(patch);
            for i = 1:numel(fn)
                out.(fn{i}) = patch.(fn{i});
            end
        end

        function out = extractRunOverrides(app, node, templateParams, mergedParams)
            out = struct();
            if ~isstruct(mergedParams)
                out = struct();
                return;
            end
            fn = fieldnames(mergedParams);
            for i = 1:numel(fn)
                k = fn{i};
                newVal = mergedParams.(k);
                tplVal = [];
                if isstruct(templateParams) && isfield(templateParams, k)
                    tplVal = templateParams.(k);
                end
                sameAsTemplate = false;
                sameAsDefault = false;
                try
                    sameAsTemplate = isequaln(newVal, tplVal);
                catch
                end
                dflt = getRunDefaults(app, node);
                if isstruct(dflt) && isfield(dflt, k)
                    try
                        sameAsDefault = isequaln(newVal, dflt.(k));
                    catch
                    end
                end
                if ~sameAsTemplate && ~sameAsDefault
                    out.(k) = newVal;
                end
            end
        end

        function out = pruneRunOverrides(app, row, p)
            out = struct();
            if ~isstruct(p)
                return;
            end
            fn = fieldnames(p);
            for i = 1:numel(fn)
                k = fn{i};
                if isDefaultRunValue(app, row, k, p.(k))
                    continue;
                end
                tpl = getTemplateParams(app, row);
                sameAsTemplate = false;
                if isstruct(tpl) && isfield(tpl, k)
                    try
                        sameAsTemplate = isequaln(p.(k), tpl.(k));
                    catch
                        sameAsTemplate = false;
                    end
                end
                if ~sameAsTemplate
                    out.(k) = p.(k);
                end
            end
        end

        function out = parseDisplayValue(app, raw, oldVal) %#ok<INUSD>
            if isstring(raw)
                raw = char(raw);
            end

            if islogical(oldVal)
                s = lower(strtrim(char(string(raw))));
                out = any(strcmp(s, {'1','true','yes','on'}));
                return;
            end

            if isnumeric(oldVal)
                s = strtrim(char(string(raw)));
                if isempty(s)
                    out = oldVal;
                    return;
                end
                if isscalar(oldVal)
                    z = str2double(s);
                    if isnan(z)
                        out = oldVal;
                    else
                        out = z;
                    end
                else
                    z = str2num(s); %#ok<ST2NM>
                    if isempty(z)
                        out = oldVal;
                    else
                        out = z;
                    end
                end
                return;
            end

            if isstruct(oldVal)
                try
                    out = jsondecode(char(string(raw)));
                catch
                    out = oldVal;
                end
                return;
            end

            if iscell(oldVal)
                s = char(string(raw));
                if isempty(strtrim(s))
                    out = {};
                else
                    out = {s};
                end
                return;
            end

            out = char(string(raw));
        end

        function tipMap = buildParamTipMapLocal(app, params) %#ok<INUSD>
            tipMap = struct();
            if ~isstruct(params) || ~isfield(params, 'tip') || isempty(params.tip)
                return;
            end
            keys = fieldnames(params);
            keys(strcmp(keys, 'tip')) = [];
            tips = params.tip;
            if ischar(tips) || isstring(tips)
                tips = cellstr(string(tips(:)));
            end
            if ~iscell(tips)
                return;
            end
            n = min(numel(keys), numel(tips));
            for i = 1:n
                try
                    tipMap.(keys{i}) = char(string(tips{i}));
                catch
                end
            end
        end

        function out = appendRunNote(app, base, extra) %#ok<INUSD>
            base = strtrim(char(string(base)));
            extra = strtrim(char(string(extra)));
            if isempty(base)
                out = extra;
            elseif isempty(extra)
                out = base;
            else
                out = [base ' ' extra];
            end
        end

        function tf = shouldClearRunOverride(app, row, key, newVal, meta)
            tf = false;
            if isDefaultRunValue(app, row, key, newVal)
                tf = true;
                return;
            end
            tpl = getTemplateParams(app, row);
            if isstruct(tpl) && isfield(tpl, key)
                try
                    tf = isequaln(newVal, tpl.(key));
                catch
                    tf = false;
                end
            elseif nargin >= 5 && isstruct(meta)
                try
                    tf = isequaln(newVal, meta.templateRaw);
                catch
                    tf = false;
                end
            end
        end

        function [newVal, applied] = chooseRunParamValueForRow(app, nodeRow, node, meta, runOverrides)
            newVal = [];
            applied = false;
            choices = meta.choiceItems;
            if isempty(choices) && isChannelSelectorKeyLocal(app, node, meta.key)
                choices = getNodeSelectableChannelsLocal(app, nodeRow);
            elseif isempty(choices) && isChannelSlotBindingKeyLocal(app, node, meta.key)
                choices = getNodeSelectableChannelsLocal(app, nodeRow);
            end
            if isempty(choices)
                return;
            end

            initialNames = {};
            if isfield(runOverrides, meta.key)
                currentVal = runOverrides.(meta.key);
            else
                currentVal = meta.templateRaw;
                if isempty(currentVal)
                    currentVal = meta.defaultRaw;
                end
            end

            if isChannelSlotBindingKeyLocal(app, node, meta.key)
                if isChoicePayloadLocal(app, currentVal)
                    initialNames = normalizeChannelChoiceListLocal(app, extractChoiceDisplayLocal(app, currentVal));
                else
                    initialNames = normalizeChannelChoiceListLocal(app, currentVal);
                end
            elseif strcmp(meta.storageKind, 'choicePayload')
                initialNames = normalizeChannelChoiceListLocal(app, extractChoiceDisplayLocal(app, currentVal));
            else
                initialNames = normalizeChannelChoiceListLocal(app, currentVal);
            end
            initialIdx = find(ismember(lower(choices), lower(initialNames)));
            if isempty(initialIdx) && ~isempty(choices)
                initialIdx = 1;
            end

            mode = 'single';
            if logical(meta.allowMulti)
                mode = 'multiple';
            end

            [sel, ok] = listdlg( ...
                'ListString', choices, ...
                'SelectionMode', mode, ...
                'InitialValue', initialIdx, ...
                'PromptString', ['Select ' lower(char(string(meta.label)))], ...
                'Name', char(string(meta.label)));
            if ~ok || isempty(sel)
                return;
            end

            picked = choices(sel);
            if isChannelSlotBindingKeyLocal(app, node, meta.key)
                newVal = picked{1};
            elseif strcmp(meta.storageKind, 'choicePayload')
                if meta.allowMulti
                    newVal = applyChoicePayloadSelectionLocal(app, currentVal, picked(:)');
                else
                    newVal = applyChoicePayloadSelectionLocal(app, currentVal, picked{1});
                end
            elseif meta.allowMulti
                newVal = picked(:)';
            else
                newVal = picked{1};
            end
            applied = true;
        end

        function section = categorizeRunParamKey(app, node, key) %#ok<INUSD>
            key = lower(char(string(key)));
            c = pipelineNodeContract(node, resolveNodePackageLocal(app, node));
            if isstruct(c) && isfield(c, 'parameters') && isstruct(c.parameters)
                if any(strcmp(key, normalizeParamNameListLocal(app, getfielddefault(app, c.parameters, 'fixed', {})))) || ...
                        any(strcmp(key, normalizeParamNameListLocal(app, getfielddefault(app, c.parameters, 'design', {})))) || ...
                        any(strcmp(key, normalizeParamNameListLocal(app, getfielddefault(app, c.parameters, 'template', {}))))
                    section = 'Config';
                    return;
                end
                if any(strcmp(key, normalizeParamNameListLocal(app, getfielddefault(app, c.parameters, 'data', {}))))
                    section = 'Data';
                    return;
                end
            end
            if any(strcmp(key, {'channel','channels','channelidx','channelindex','extractchannels'})) || startsWith(key, 'channel')
                section = 'Input';
            elseif contains(key, 'frame')
                section = 'Frames';
            elseif contains(key, 'output')
                section = 'Output';
            elseif any(strcmp(key, {'runpolicy','existingpolicy','cachepolicy','gpu','executionmode'}))
                section = 'Execution';
            elseif any(strcmp(key, {'path','positionidx','fovindex','roiindex'}))
                section = 'Scope';
            else
                section = 'Parameters';
            end
        end

        function label = friendlyRunParamLabel(app, key) %#ok<INUSD>
            key = char(string(key));
            switch lower(key)
                case 'channel'
                    label = 'Input channel';
                case 'channels'
                    label = 'Input channels';
                case 'extractchannels'
                    label = 'Extracted channels';
                case 'referenceframe'
                    label = 'Reference frame';
                case 'outputname'
                    label = 'Output name';
                case 'outputchannelname'
                    label = 'Output channel name';
                case 'cachepolicy'
                    label = 'ROI cache mode';
                case 'existingpolicy'
                    label = 'Existing outputs policy';
                case 'runpolicy'
                    label = 'Rerun mode';
                otherwise
                    label = strrep(regexprep(key, '([a-z])([A-Z])', '$1 $2'), '_', ' ');
            end
        end

        function notes = configRunNote(app, node, key) %#ok<INUSD>
            notes = '';
            nodeType = lower(char(string(getfielddefault(app, node, 'type', ''))));
            key = lower(char(string(key)));
            if strcmp(nodeType, 'roipattern') && strcmp(key, 'pattern')
                notes = 'Pattern must be chosen in the ROI editor before run submission.';
                return;
            end
            if strcmp(nodeType, 'roigrid') && strcmp(key, 'gridcount')
                notes = 'GridCount is a pipeline design choice, not a run override.';
                return;
            end
            if strcmp(nodeType, 'classifier') && strcmp(key, 'classes')
                notes = 'Class labels are defined by the classifier module.';
                return;
            end
            if strcmp(nodeType, 'classifier') && strcmp(key, 'trainingparam')
                notes = 'Training parameters belong to the classifier module GUI.';
                return;
            end
            notes = 'Pipeline configuration parameter.';
        end

        function pkg = resolveNodePackageLocal(app, node) %#ok<INUSD>
            pkg = '';
            if isfield(node, 'pkg') && ~isempty(node.pkg)
                pkg = char(string(node.pkg));
            elseif isfield(node, 'params') && isstruct(node.params) && isfield(node.params, 'pkg') && ~isempty(node.params.pkg)
                pkg = char(string(node.params.pkg));
            elseif isfield(node, 'func') && ~isempty(node.func)
                token = regexp(char(string(node.func)), '^([A-Za-z]\w*)\.(process|classify)$', 'tokens', 'once');
                if ~isempty(token)
                    pkg = token{1};
                end
            end
        end

        function txt = describeNodeFamilyLocal(app, node) %#ok<INUSD>
            nodeType = lower(char(string(node.type)));
            pkg = lower(resolveNodePackageLocal(app, node));
            switch nodeType
                case 'dataloader'
                    txt = 'Data source';
                case {'roiidentify','roipattern'}
                    txt = 'ROI detection';
                case 'roimanual'
                    txt = 'Manual ROI';
                case 'roigrid'
                    txt = 'Grid ROI';
                case 'roitracked'
                    txt = 'Tracked ROI';
                case 'roiextract'
                    txt = 'ROI extraction';
                case 'processor'
                    if isempty(pkg)
                        txt = 'Processor';
                    else
                        txt = ['Processor (' pkg ')'];
                    end
                case 'classifier'
                    if isempty(pkg)
                        txt = 'Classifier';
                    else
                        txt = ['Classifier (' pkg ')'];
                    end
                otherwise
                    txt = char(string(node.type));
            end
        end

        function txt = describeNodeStageLocal(app, node)
            c = pipelineNodeContract(node, resolveNodePackageLocal(app, node));
            if ~isstruct(c) || ~isfield(c, 'parameters') || ~isstruct(c.parameters)
                txt = 'Run';
                return;
            end

            configKeys = normalizeParamNameListLocal(app, getfielddefault(app, c.parameters, 'fixed', {}));
            configKeys = [configKeys normalizeParamNameListLocal(app, getfielddefault(app, c.parameters, 'design', {}))]; %#ok<AGROW>
            configKeys = [configKeys normalizeParamNameListLocal(app, getfielddefault(app, c.parameters, 'template', {}))]; %#ok<AGROW>
            configKeys = unique(configKeys(~cellfun(@isempty, configKeys)), 'stable');

            runKeys = normalizeParamNameListLocal(app, getfielddefault(app, c.parameters, 'run', {}));
            runKeys = [runKeys normalizeParamNameListLocal(app, getfielddefault(app, c.parameters, 'data', {}))]; %#ok<AGROW>
            runKeys = unique(runKeys(~cellfun(@isempty, runKeys)), 'stable');

            hasConfig = ~isempty(configKeys);
            hasRun = ~isempty(runKeys);
            if hasConfig && hasRun
                txt = 'Config + Run';
            elseif hasConfig
                txt = 'Config';
            elseif hasRun
                txt = 'Run';
            else
                txt = 'None';
            end
        end

        function txt = describeNodeBindingLocal(app, node)
            c = pipelineNodeContract(node, resolveNodePackageLocal(app, node));
            txt = char(string(getfielddefault(app, c, 'summary', '')));
            req = getfielddefault(app, c, 'requirements', struct());
            if isstruct(req) && isfield(req, 'roi') && isstruct(req.roi)
                n = double(getfielddefault(app, req.roi, 'channelsMin', 0));
                if n > 0
                    txt = sprintf('Needs ROI data with >=%d channel(s)', n);
                end
            end
            if strcmpi(char(string(node.type)), 'roiextract')
                txt = 'Produces ROI channels from upstream image data';
            elseif strcmpi(char(string(node.type)), 'dataloader')
                txt = 'Defines the raw channel inventory';
            end
        end

        function tf = isChoicePayloadLocal(app, value) %#ok<INUSD>
            tf = false;
            if ~iscell(value) || numel(value) < 3
                return;
            end
            try
                strs = cellfun(@(x) char(string(x)), value, 'UniformOutput', false);
            catch
                return;
            end
            if any(cellfun(@(x) isempty(strtrim(x)), strs))
                return;
            end
            selected = strs{end};
            choices = strs(1:end-1);
            tf = any(strcmpi(choices, selected)) || any(strcmpi(choices, 'none')) || any(strcmpi(choices, 'n/a'));
        end

        function items = getChoicePayloadItemsLocal(app, value) %#ok<INUSD>
            items = {};
            if ~isChoicePayloadLocal(app, value)
                return;
            end
            items = cellfun(@(x) char(string(x)), value(1:end-1), 'UniformOutput', false);
            items = unique(items, 'stable');
        end

        function out = applyChoicePayloadSelectionLocal(app, value, selected) %#ok<INUSD>
            items = getChoicePayloadItemsLocal(app, value);
            if iscell(selected)
                if isempty(selected)
                    picked = '';
                else
                    picked = char(string(selected{1}));
                end
            else
                picked = char(string(selected));
            end
            if isempty(items) && iscell(value)
                items = cellfun(@(x) char(string(x)), value, 'UniformOutput', false);
            end
            if ~isempty(picked) && ~any(strcmpi(items, picked))
                items{end+1} = picked; %#ok<AGROW>
            end
            if isempty(picked) && ~isempty(items)
                picked = items{1};
            end
            out = [items(:)' {picked}];
        end

        function txt = extractChoiceDisplayLocal(app, value) %#ok<INUSD>
            txt = '';
            if isChoicePayloadLocal(app, value)
                txt = char(string(value{end}));
            elseif iscell(value) && ~isempty(value)
                txt = char(string(value{1}));
            else
                txt = char(string(value));
            end
        end

        function tf = isChannelSelectorKeyLocal(app, node, key) %#ok<INUSD>
            tf = false;
            key = lower(char(string(key)));
            if any(strcmp(key, {'channel','channels','extractchannels'}))
                tf = true;
                return;
            end
            if strcmpi(char(string(node.type)), 'classifier') && any(strcmp(resolveNodePackageLocal(app, node), {'cellposesam','cnn_lstm'}))
                tf = strcmp(key, 'channel');
            end
        end

        function tf = isChannelSlotBindingKeyLocal(app, node, key)
            tf = false;
            if nargin < 3 || isempty(key)
                return;
            end
            key = char(string(key));
            if isempty(regexp(key, '^Channel\d+$', 'once'))
                return;
            end
            c = pipelineNodeContract(node, resolveNodePackageLocal(app, node));
            binding = getfielddefault(app, c, 'binding', struct());
            mode = lower(char(string(getfielddefault(app, binding, 'mode', ''))));
            tf = strcmp(mode, 'channelslots');
        end

        function tf = requiresSingleExplicitChannelLocal(app, node) %#ok<INUSD>
            tf = false;
            if ~strcmpi(char(string(node.type)), 'classifier')
                return;
            end
            pkg = lower(resolveNodePackageLocal(app, node));
            tf = any(strcmp(pkg, {'cellposesam','cnn_lstm'}));
        end

        function names = getNodeSelectableChannelsLocal(app, row)
            names = {};
            if row < 1 || row > numel(app.Data.pipelineSpec.nodes)
                return;
            end
            ctx = struct();
            if ~isempty(app.Data.shallowObj)
                ctx.shallow = app.Data.shallowObj;
                ctx.shallowObj = app.Data.shallowObj;
            end
            try
                if ~isempty(app.Data.shallowObj) && isprop(app.Data.shallowObj, 'fov') && ~isempty(app.Data.shallowObj.fov)
                    ctx.channels = app.Data.shallowObj.fov(1).channel;
                end
            catch
            end
            merged = getMergedNodeParams(app, row);
            if isstruct(merged) && isfield(merged, 'channels') && ~isempty(merged.channels)
                names = mergeChannelChoiceListsLocal(app, names, merged.channels);
            end
            if isstruct(ctx) && isfield(ctx, 'channels') && ~isempty(ctx.channels)
                names = mergeChannelChoiceListsLocal(app, names, ctx.channels);
            end
            for ii = 1:row-1
                params = getMergedNodeParams(app, ii);
                if isstruct(params)
                    probe = {'channel','channels','extractChannels','channelFilter','channelName'};
                    for jj = 1:numel(probe)
                        k = probe{jj};
                        if isfield(params, k) && ~isempty(params.(k))
                            names = mergeChannelChoiceListsLocal(app, names, params.(k));
                        end
                    end
                end
            end
        end

        function names = mergeChannelChoiceListsLocal(app, a, b) %#ok<INUSD>
            names = unique([normalizeChannelChoiceListLocal(app, a), normalizeChannelChoiceListLocal(app, b)], 'stable');
        end

        function names = normalizeChannelChoiceListLocal(app, v) %#ok<INUSD>
            names = {};
            if isempty(v)
                return;
            end
            if ischar(v) || (isstring(v) && isscalar(v))
                s = strtrim(char(string(v)));
                if isempty(s)
                    return;
                end
                if startsWith(s, '[') && endsWith(s, ']')
                    try
                        tmp = jsondecode(s);
                        names = normalizeChannelChoiceListLocal(app, tmp);
                        return;
                    catch
                    end
                end
                if contains(s, ',')
                    parts = strtrim(strsplit(s, ','));
                    names = parts(~cellfun(@isempty, parts));
                else
                    names = {s};
                end
                return;
            end
            if isstring(v)
                names = cellstr(v(:)');
                return;
            end
            if iscell(v)
                tmp = {};
                for ii = 1:numel(v)
                    tmp = [tmp normalizeChannelChoiceListLocal(app, v{ii})]; %#ok<AGROW>
                end
                names = unique(tmp, 'stable');
                return;
            end
            if isnumeric(v)
                vals = double(v(:)');
                vals = vals(isfinite(vals));
                for ii = 1:numel(vals)
                    names{end+1} = num2str(vals(ii)); %#ok<AGROW>
                end
            end
        end

        function list = normalizeParamNameListLocal(app, v) %#ok<INUSD>
            list = {};
            if isempty(v)
                return;
            end
            if ischar(v) || isstring(v)
                list = cellstr(string(v(:)));
                list = lower(strtrim(list));
                list = list(~cellfun(@isempty, list));
                return;
            end
            if iscell(v)
                tmp = cell(1, numel(v));
                for ii = 1:numel(v)
                    if isempty(v{ii})
                        tmp{ii} = '';
                    else
                        tmp{ii} = lower(strtrim(char(string(v{ii}))));
                    end
                end
                list = tmp(~cellfun(@isempty, tmp));
            end
        end

        function idx = rowFromNode(app, node) %#ok<INUSD>
            idx = find(strcmp({app.Data.pipelineSpec.nodes.id}, char(string(node.id))), 1, 'first');
        end

        function shallowObj = resolveSelectedProject(app)
            shallowObj = [];
            if ~isempty(app.Data.shallowObj) && isa(app.Data.shallowObj, 'shallow')
                shallowObj = app.Data.shallowObj;
                return;
            end

            if isempty(app.Data.projectVars)
                return;
            end

            varName = app.ProjectDropDown.Value;
            if ~any(strcmp(app.Data.projectVars, varName))
                return;
            end

            try
                tmp = evalin('base', varName);
                if isa(tmp, 'shallow')
                    shallowObj = tmp;
                end
            catch
            end
        end

        function shallowObj = resolveProjectForRun(app, runObj)
            shallowObj = resolveSelectedProject(app);
            if ~isempty(shallowObj)
                return;
            end

            try
                vars = evalin('base', 'who');
            catch
                vars = {};
            end
            for iVar = 1:numel(vars)
                try
                    candidate = evalin('base', vars{iVar});
                    if ~isa(candidate, 'shallow')
                        continue;
                    end
                    idx = findRunIndexInProject(app, candidate, runObj);
                    if ~isempty(idx)
                        shallowObj = candidate;
                        app.Data.shallowObj = shallowObj;
                        return;
                    end
                catch
                end
            end
        end

        function runId = suggestRunId(app, shallowObj, templateId) %#ok<INUSD>
            n = 1;
            runId = [templateId '_run_' num2str(n)];
            if ~isfield(shallowObj.processing,'pipelineRun') || isempty(shallowObj.processing.pipelineRun)
                return;
            end
            names = arrayfun(@(p) p.runId, shallowObj.processing.pipelineRun, 'UniformOutput', false);
            while any(strcmp(names, runId))
                n = n + 1;
                runId = [templateId '_run_' num2str(n)];
            end
        end

        function openSelectedNodeGUI(app)
            if isempty(app.Data.selectedNode)
                return;
            end
            row = app.Data.selectedNode;
            if row > numel(app.Data.pipelineSpec.nodes)
                return;
            end
            node = app.Data.pipelineSpec.nodes(row);
            templateParams = getTemplateParams(app, row);
            params = getMergedNodeParams(app, row);
            shallowObj = resolveSelectedProject(app);

            try
                if any(strcmpi(char(string(node.type)), {'dataloader','roigrid','roiextract'}))
                    if isempty(shallowObj)
                        uialert(app.UIFigure, 'Workflow needs a project context.', 'Info');
                        return;
                    end
                    focusTarget = lower(char(string(node.type)));
                    workflow(shallowObj, focusTarget);
                    return;
                end

                if strcmpi(node.type,'dataloader')
                    dlg = dataLoaderGUI(params);
                    try
                        uiwait(dlg.UIFigure);
                    catch
                    end
                    cancelled = true;
                    try
                        cancelled = dlg.Cancelled;
                    catch
                    end
                    if ~cancelled
                        app.Data.nodeParams{row} = extractRunOverrides(app, node, templateParams, dlg.Result);
                        updateParamTable(app, row);
                    end
                    try
                        delete(dlg);
                    catch
                    end
                    return;
                end

                if strcmpi(node.type,'roiidentify') || strcmpi(node.type,'roiPattern')
                    if isempty(shallowObj)
                        uialert(app.UIFigure, 'ROI pattern run overrides need a project context.', 'Info');
                        return;
                    end
                    dlg = roiIdentifyGUI(shallowObj, params);
                    try
                        uiwait(dlg.UIFigure);
                    catch
                    end
                    cancelled = true;
                    try
                        cancelled = dlg.Cancelled;
                    catch
                    end
                    if ~cancelled
                        app.Data.nodeParams{row} = extractRunOverrides(app, node, templateParams, dlg.Result);
                        updateParamTable(app, row);
                    end
                    try
                        delete(dlg);
                    catch
                    end
                    return;
                end

                if strcmpi(node.type,'roiManual')
                    fovCount = 0;
                    if ~isempty(shallowObj)
                        try
                            fovCount = numel(shallowObj.fov);
                        catch
                            fovCount = 0;
                        end
                    end
                    dlg = roiManualGUI(params, fovCount);
                    try
                        uiwait(dlg.UIFigure);
                    catch
                    end
                    cancelled = true;
                    try
                        cancelled = dlg.Cancelled;
                    catch
                    end
                    if ~cancelled
                        app.Data.nodeParams{row} = extractRunOverrides(app, node, templateParams, dlg.Result);
                        updateParamTable(app, row);
                    end
                    try
                        delete(dlg);
                    catch
                    end
                    return;
                end

                if strcmpi(node.type,'roiGrid')
                    fovCount = 0;
                    if ~isempty(shallowObj)
                        try
                            fovCount = numel(shallowObj.fov);
                        catch
                            fovCount = 0;
                        end
                    end
                    dlg = roiGridGUI(params, fovCount);
                    try
                        uiwait(dlg.UIFigure);
                    catch
                    end
                    cancelled = true;
                    try
                        cancelled = dlg.Cancelled;
                    catch
                    end
                    if ~cancelled
                        app.Data.nodeParams{row} = extractRunOverrides(app, node, templateParams, dlg.Result);
                        updateParamTable(app, row);
                    end
                    try
                        delete(dlg);
                    catch
                    end
                    return;
                end

                if strcmpi(node.type,'roiextract')
                    dlg = roiExtractGUI(params);
                    try
                        uiwait(dlg.UIFigure);
                    catch
                    end
                    cancelled = true;
                    try
                        cancelled = dlg.Cancelled;
                    catch
                    end
                    if ~cancelled
                        app.Data.nodeParams{row} = extractRunOverrides(app, node, templateParams, dlg.Result);
                        updateParamTable(app, row);
                    end
                    try
                        delete(dlg);
                    catch
                    end
                    return;
                end

                if strcmpi(node.type,'roitracked')
                    if isempty(shallowObj)
                        uialert(app.UIFigure, 'Tracked ROI run overrides need a project context.', 'Info');
                        return;
                    end
                    ctxTracked = struct('shallow', shallowObj, 'roiTracked', params, 'params', params);
                    ctxTracked = roiTracked.ui(ctxTracked);
                    cancelled = false;
                    if isfield(ctxTracked,'cancelled') && ~isempty(ctxTracked.cancelled)
                        cancelled = logical(ctxTracked.cancelled);
                    end
                    if ~cancelled && isfield(ctxTracked,'roiTracked') && isstruct(ctxTracked.roiTracked)
                        app.Data.nodeParams{row} = extractRunOverrides(app, node, templateParams, ctxTracked.roiTracked);
                        updateParamTable(app, row);
                    end
                    return;
                end

                if strcmpi(node.type,'processor')
                    if isempty(shallowObj)
                        processDataGUI;
                        return;
                    end
                    tmpProc = process(tempdir, 'pipeline_run', 1);
                    if isfield(node,'pkg') && ~isempty(node.pkg)
                        tmpProc.processFun = [char(string(node.pkg)) '.process'];
                    elseif isfield(node,'func') && ~isempty(node.func)
                        tmpProc.processFun = char(string(node.func));
                    end
                    if isstruct(params)
                        tmpProc.processArg = params;
                    end
                    processDataGUI(shallowObj, tmpProc);
                    return;
                end

                if strcmpi(node.type,'classifier')
                    tmpClassi = classi(tempdir, 'pipeline_run', 1);
                    if isfield(node,'pkg') && ~isempty(node.pkg)
                        tmpClassi.classifierPkg = char(string(node.pkg));
                    end
                    if isfield(node,'func') && ~isempty(node.func)
                        tmpClassi.classifyFun = char(string(node.func));
                    end
                    classifierGUI(tmpClassi);
                    return;
                end

                if isfield(node,'gui') && ~isempty(node.gui)
                    guiFn = char(string(node.gui));
                    if ~isempty(shallowObj)
                        feval(guiFn, shallowObj);
                    else
                        feval(guiFn);
                    end
                else
                    uialert(app.UIFigure, 'No GUI for selected node.', 'Info');
                end
            catch ME
                uialert(app.UIFigure, ME.message, 'GUI error', 'Icon', 'warning');
            end
        end
    end

    methods (Access = private)

        function NodeTableSelectionChanged(app, event)
            sel = app.NodeTable.Selection;
            if isempty(sel)
                return;
            end
            row = sel(1,1);
            app.Data.selectedNode = row;
            updateParamTable(app, row);
            updateHubStatusUi(app);
        end

        function NodeTableCellEdit(app, event)
            idx = event.Indices;
            if isempty(idx)
                return;
            end
            row = idx(1);
            col = idx(2);
            if col ~= 1
                return;
            end
            data = app.NodeTable.Data;
            data{row,1} = logical(event.NewData);
            app.NodeTable.Data = data;
            updateHubStatusUi(app);
            markDirty(app, true);
        end

        function ParamTableCellEdit(app, event)
            idx = event.Indices;
            if isempty(idx)
                return;
            end
            row = idx(1);
            col = idx(2);
            if col ~= 4
                return;
            end
            if isempty(app.Data.selectedNode)
                return;
            end

            nodeRow = app.Data.selectedNode;
            p = app.Data.nodeParams{nodeRow};
            if ~isstruct(p)
                p = struct();
            end

            if isempty(app.CurrentRunParamRows) || row > numel(app.CurrentRunParamRows)
                return;
            end

            meta = app.CurrentRunParamRows(row);
            key = meta.key;
            rawStr = strtrim(char(string(event.NewData)));
            if isempty(rawStr) || strcmpi(rawStr, '<inherit>')
                if isfield(p, key)
                    p = rmfield(p, key);
                end
            else
                typeRef = meta.templateRaw;
                if isempty(typeRef)
                    typeRef = meta.defaultRaw;
                end
                if strcmp(meta.storageKind, 'choicePayload')
                    newVal = applyChoicePayloadSelectionLocal(app, typeRef, event.NewData);
                else
                    newVal = parseDisplayValue(app, event.NewData, typeRef);
                end
                if shouldClearRunOverride(app, nodeRow, key, newVal, meta)
                    if isfield(p, key)
                        p = rmfield(p, key);
                    end
                else
                    p.(key) = newVal;
                end
            end
            app.Data.nodeParams{nodeRow} = p;

            updateParamTable(app, nodeRow);
            markDirty(app, true);
        end

        function ParamTableSelectionChanged(app, event)
            sel = app.ParamTable.Selection;
            if isempty(sel) || size(sel,1) ~= 1 || sel(1,2) ~= 4 || isempty(app.Data.selectedNode)
                return;
            end

            row = sel(1,1);
            if isempty(app.CurrentRunParamRows) || row > numel(app.CurrentRunParamRows)
                return;
            end

            meta = app.CurrentRunParamRows(row);
            if ~strcmp(meta.kind, 'choice')
                return;
            end

            nodeRow = app.Data.selectedNode;
            node = app.Data.pipelineSpec.nodes(nodeRow);
            p = app.Data.nodeParams{nodeRow};
            if ~isstruct(p)
                p = struct();
            end

            [newVal, applied] = chooseRunParamValueForRow(app, nodeRow, node, meta, p);
            if ~applied
                return;
            end

            if shouldClearRunOverride(app, nodeRow, meta.key, newVal, meta)
                if isfield(p, meta.key)
                    p = rmfield(p, meta.key);
                end
            else
                p.(meta.key) = newVal;
            end
            app.Data.nodeParams{nodeRow} = p;
            updateParamTable(app, nodeRow);
            markDirty(app, true);
        end

        function commitVisibleParamTable(app)
            % Edits are committed immediately by the parameter table callbacks.
        end

        function OpenNodeGUIButtonPushed(app, event)
            openSelectedNodeGUI(app);
        end

        function InputSourceDropDownValueChanged(app, event)
            updateRunSourceSelectionUi(app);
            markDirty(app, true);
        end

        function DescriptionEditFieldValueChanged(app, event) %#ok<INUSD>
            markDirty(app, true);
        end

        function RunIdEditFieldValueChanged(app, event) %#ok<INUSD>
            markDirty(app, true);
        end

        function RunPolicyDropDownValueChanged(app, event) %#ok<INUSD>
            markDirty(app, true);
        end

        function ExistingPolicyDropDownValueChanged(app, event) %#ok<INUSD>
            markDirty(app, true);
        end

        function CachePolicyDropDownValueChanged(app, event) %#ok<INUSD>
            markDirty(app, true);
        end

        function GpuPolicyDropDownValueChanged(app, event) %#ok<INUSD>
            markDirty(app, true);
        end

        function ExecutionModeDropDownValueChanged(app, event) %#ok<INUSD>
            markDirty(app, true);
            updateHubStatusUi(app);
        end

        function FovSelectionEditFieldValueChanged(app, event) %#ok<INUSD>
            markDirty(app, true);
        end

        function PythonEnvModeDropDownValueChanged(app, event) %#ok<INUSD>
            updatePythonEnvUi(app);
            markDirty(app, true);
        end

        function PythonEnvNameEditFieldValueChanged(app, event) %#ok<INUSD>
            markDirty(app, true);
        end

        function updatePythonEnvUi(app)
            mode = char(string(app.PythonEnvModeDropDown.Value));
            isCustom = strcmpi(mode, 'Custom conda env');
            if isCustom
                app.PythonEnvNameEditField.Enable = 'on';
                app.PythonEnvNameEditFieldLabel.Enable = 'on';
                app.PythonEnvNameEditField.Placeholder = 'existing conda env name';
            else
                app.PythonEnvNameEditField.Enable = 'off';
                app.PythonEnvNameEditFieldLabel.Enable = 'off';
                app.PythonEnvNameEditField.Placeholder = 'Not used with Default detecdiv_python';
            end
        end

        function pyCfg = buildPythonRunConfig(app)
            modeLabel = char(string(app.PythonEnvModeDropDown.Value));
            pyCfg = struct('mode', 'default', 'envName', '', 'preflight', true);
            if strcmpi(modeLabel, 'Custom conda env')
                envName = strtrim(char(string(app.PythonEnvNameEditField.Value)));
                if isempty(envName)
                    error('Enter a conda environment name or choose Default detecdiv_python.');
                end
                pyCfg.mode = 'custom';
                pyCfg.envName = envName;
            end
        end

        function label = gpuPolicyToLabel(app, policy) %#ok<INUSD>
            key = lower(strtrim(char(string(policy))));
            switch key
                case 'force_gpu'
                    label = 'Force GPU where supported';
                case 'force_cpu'
                    label = 'Force CPU';
                otherwise
                    label = 'Use each module default';
            end
        end

        function markDirty(app, tf)
            if nargin < 2 || isempty(tf)
                tf = true;
            end
            app.Data.dirty = logical(tf);
            updateWindowTitle(app);
            updateHubStatusUi(app);
        end

        function updateHubStatusUi(app)
            hasRun = app.Data.editMode && isa(app.Data.runObj, 'pipelineRun') && ~isempty(app.Data.runObj);
            isHubMode = false;
            try
                isHubMode = strcmpi(char(string(app.ExecutionModeDropDown.Value)), 'Detecdiv hub');
            catch
            end
            if hasRun && isHubMode
                app.RunOnHubButton.Enable = 'on';
            else
                app.RunOnHubButton.Enable = 'off';
            end
            if hasRun
                app.RefreshHubButton.Enable = 'on';
            else
                app.RefreshHubButton.Enable = 'off';
            end

            label = 'Hub: no job';
            try
                jobId = localRunHubJobId(app, app.Data.runObj);
                if ~isempty(jobId)
                    status = localRunHubStatus(app, app.Data.runObj);
                    if isempty(status)
                        status = 'unknown';
                    end
                    label = sprintf('Hub: %s (%s)', status, jobId);
                elseif hasRun && isHubMode
                    label = 'Hub: ready';
                elseif hasRun
                    label = 'Hub: local mode';
                end
                if app.Data.dirty && hasRun
                    label = [label ' - unsaved'];
                end
            catch
            end
            runSummary = buildRunSummaryText(app);
            if isempty(runSummary)
                app.HubStatusLabel.Text = label;
            else
                app.HubStatusLabel.Text = [runSummary ' | ' label];
            end
        end

        function txt = buildRunSummaryText(app)
            txt = '';
            try
                if isempty(app.NodeTable) || isempty(app.NodeTable.Data)
                    return;
                end
                data = app.NodeTable.Data;
                if size(data,2) < 1 || isempty(data)
                    return;
                end

                selected = false(size(data,1), 1);
                try
                    selected = cell2mat(data(:,1));
                catch
                end
                selectedCount = nnz(selected);
                totalCount = numel(selected);

                src = 'raw data';
                try
                    src = lower(char(string(app.InputSourceDropDown.Value)));
                catch
                end
                switch src
                    case 'start from raw data (dataloader)'
                        src = 'raw data';
                    case 'reuse existing project fovs'
                        src = 'existing project FOVs';
                    case 'reuse existing rois'
                        src = 'existing ROIs';
                    case 'reuse existing masks'
                        src = 'existing masks';
                    case 'reuse existing data series'
                        src = 'existing data series';
                end

                modeTxt = 'local';
                try
                    modeTxt = lower(char(string(app.ExecutionModeDropDown.Value)));
                    if strcmp(modeTxt, 'detecdiv hub')
                        modeTxt = 'hub';
                    end
                catch
                end

                stateTxt = 'ready';
                if selectedCount == 0
                    stateTxt = 'no nodes selected';
                elseif app.Data.dirty
                    stateTxt = 'unsaved';
                elseif isempty(app.Data.runObj) && ~app.Data.editMode
                    stateTxt = 'new';
                end

                txt = sprintf('Run: %d/%d nodes, %s, %s, %s', selectedCount, totalCount, src, modeTxt, stateTxt);
            catch
                txt = '';
            end
        end

        function RunOnHubButtonPushed(app, event) %#ok<INUSD>
            if app.Data.dirty
                choice = uiconfirm(app.UIFigure, ...
                    'Save this pipeline run before submitting it to the hub?', ...
                    'Save before hub submit', ...
                    'Options', {'Save and submit','Cancel'}, ...
                    'DefaultOption', 1, ...
                    'CancelOption', 2, ...
                    'Icon', 'warning');
                if ~strcmp(choice, 'Save and submit')
                    return;
                end
                CreateRunButtonPushed(app, []);
                if app.Data.dirty
                    return;
                end
            end

            runObj = app.Data.runObj;
            shallowObj = resolveProjectForRun(app, runObj);
            if isempty(shallowObj) || isempty(runObj) || ~isa(runObj, 'pipelineRun')
                uialert(app.UIFigure, 'Save the run before submitting it to the hub.', 'Run on hub', 'Icon', 'warning');
                return;
            end

            choice = uiconfirm(app.UIFigure, ...
                {'Submit this existing pipeline run to the hub?', ...
                 'The local project should be reloaded after the server job completes.'}, ...
                'Run on hub', ...
                'Options', {'Submit','Cancel'}, ...
                'DefaultOption', 1, ...
                'CancelOption', 2, ...
                'Icon', 'warning');
            if ~strcmp(choice, 'Submit')
                return;
            end

            d = uiprogressdlg(app.UIFigure, 'Title', 'Please Wait...', ...
                'Message', ['Submitting hub job for ' char(string(runObj.runId)) '...'], ...
                'Indeterminate', 'on');
            try
                try
                    detecdiv_hub_release_project_open(shallowObj);
                catch
                end
                job = detecdiv_hub_submit_pipeline_run(runObj, shallowObj);
                app.Data.runObj = runObj;
                app.Data.editMode = true;
                app.RunIdEditField.Editable = 'off';
                localStoreRunInProject(app, shallowObj, runObj);
                try
                    if isprop(shallowObj, 'runProfiles')
                        if ~isfield(shallowObj.runProfiles, 'hub') || ~isstruct(shallowObj.runProfiles.hub)
                            shallowObj.runProfiles.hub = struct();
                        end
                        shallowObj.runProfiles.hub.read_only = true;
                        shallowObj.runProfiles.hub.reason = 'Hub pipeline job submitted; reload project before further local editing.';
                    end
                    assignin('base', shallowObj.io.file, shallowObj);
                catch
                end
                markDirty(app, false);
                close(d);
                uialert(app.UIFigure, ...
                    sprintf('Hub job submitted: %s\nStatus: %s\nReload the project after completion before local editing.', ...
                    char(string(job.id)), char(string(job.status))), ...
                    'Hub job submitted', 'Icon', 'success');
            catch ME
                close(d);
                uialert(app.UIFigure, localErrorReport(app, ME), 'Hub submit failed', 'Icon', 'error');
            end
            updateHubStatusUi(app);
        end

        function RefreshHubButtonPushed(app, event) %#ok<INUSD>
            runObj = app.Data.runObj;
            jobId = localRunHubJobId(app, runObj);
            if isempty(jobId)
                uialert(app.UIFigure, 'This run has no hub job id yet.', 'Hub status', 'Icon', 'warning');
                return;
            end

            shallowObj = resolveSelectedProject(app);
            try
                job = detecdiv_hub_get_pipeline_run(jobId);
                if ~isstruct(runObj.ctx)
                    runObj.ctx = struct();
                end
                if ~isfield(runObj.ctx, 'hub') || ~isstruct(runObj.ctx.hub)
                    runObj.ctx.hub = struct();
                end
                runObj.ctx.hub.job_id = char(string(job.id));
                runObj.ctx.hub.status = char(string(job.status));
                runObj.ctx.hub.refreshed_at = char(datetime('now'));
                runObj.status = ['hub_' char(string(job.status))];
                app.Data.runObj = runObj;
                if ~isempty(shallowObj)
                    localStoreRunInProject(app, shallowObj, runObj);
                end
                try
                    pipelineRunSave(runObj);
                catch
                end
                updateHubStatusUi(app);

                msg = sprintf('Hub job: %s\nStatus: %s', char(string(job.id)), char(string(job.status)));
                if any(strcmp(char(string(job.status)), {'done','failed','cancelled'}))
                    msg = sprintf('%s\n\nProject changed on hub/server. Reload before local editing.', msg);
                end
                uialert(app.UIFigure, msg, 'Hub status', 'Icon', 'info');
            catch ME
                uialert(app.UIFigure, localErrorReport(app, ME), 'Hub status failed', 'Icon', 'error');
            end
        end

        function msg = localErrorReport(app, ME) %#ok<INUSD>
            msg = ME.message;
            try
                if ~isempty(ME.identifier)
                    msg = sprintf('%s\n\nIdentifier: %s', msg, ME.identifier);
                end
                if ~isempty(ME.stack)
                    lines = cell(1, min(numel(ME.stack), 6));
                    for iStack = 1:numel(lines)
                        lines{iStack} = sprintf('%s:%d', ME.stack(iStack).name, ME.stack(iStack).line);
                    end
                    msg = sprintf('%s\n\nStack:\n%s', msg, strjoin(lines, newline));
                end
            catch
            end
        end

        function jobId = localRunHubJobId(app, runObj) %#ok<INUSD>
            jobId = '';
            try
                if isa(runObj, 'pipelineRun') && isstruct(runObj.ctx) && isfield(runObj.ctx, 'hub') && isstruct(runObj.ctx.hub)
                    if isfield(runObj.ctx.hub, 'job_id') && ~isempty(runObj.ctx.hub.job_id)
                        jobId = char(string(runObj.ctx.hub.job_id));
                    elseif isfield(runObj.ctx.hub, 'hub_job_id') && ~isempty(runObj.ctx.hub.hub_job_id)
                        jobId = char(string(runObj.ctx.hub.hub_job_id));
                    end
                end
            catch
            end
        end

        function status = localRunHubStatus(app, runObj) %#ok<INUSD>
            status = '';
            try
                if isa(runObj, 'pipelineRun') && isstruct(runObj.ctx) && isfield(runObj.ctx, 'hub') && ...
                        isstruct(runObj.ctx.hub) && isfield(runObj.ctx.hub, 'status') && ~isempty(runObj.ctx.hub.status)
                    status = char(string(runObj.ctx.hub.status));
                end
            catch
            end
        end

        function localStoreRunInProject(app, shallowObj, runObj)
            runIdx = findRunIndexInProject(app, shallowObj, runObj);
            if ~isempty(runIdx)
                shallowObj.processing.pipelineRun(runIdx) = runObj;
            end
        end

        function updateWindowTitle(app)
            baseName = 'Pipeline Run Builder';
            if app.Data.editMode && isa(app.Data.runObj, 'pipelineRun') && ~isempty(app.Data.runObj)
                try
                    baseName = sprintf('Pipeline Run Builder - %s', char(string(app.Data.runObj.runId)));
                catch
                end
            elseif strlength(string(app.RunIdEditField.Value)) > 0
                baseName = sprintf('Pipeline Run Builder - %s', char(string(app.RunIdEditField.Value)));
            end

            if app.Data.dirty
                app.UIFigure.Name = ['* ' baseName];
            else
                app.UIFigure.Name = baseName;
            end
        end

        function policy = normalizeGpuPolicyLabel(app, value) %#ok<INUSD>
            policy = lower(strtrim(char(string(value))));
            switch policy
                case {'', 'use each module default', 'module default', 'default'}
                    policy = 'module_default';
                case {'force gpu where supported', 'force gpu', 'gpu'}
                    policy = 'force_gpu';
                case {'force cpu', 'cpu'}
                    policy = 'force_cpu';
                otherwise
                    policy = 'module_default';
            end
        end

        function mode = normalizeExecutionModeLabel(app, value) %#ok<INUSD>
            mode = lower(strtrim(char(string(value))));
            switch mode
                case {'detecdiv hub', 'hub', 'remote', 'run on hub'}
                    mode = 'hub';
                otherwise
                    mode = 'local';
            end
        end

        function label = executionModeToLabel(app, mode) %#ok<INUSD>
            key = lower(strtrim(char(string(mode))));
            switch key
                case {'hub', 'remote', 'run on hub'}
                    label = 'Detecdiv hub';
                otherwise
                    label = 'Local MATLAB session';
            end
        end

        function label = runPolicyToLabel(app, value) %#ok<INUSD>
            key = lower(strtrim(char(string(value))));
            switch key
                case 'restart'
                    label = 'Restart from scratch';
                otherwise
                    label = 'Resume previous progress';
            end
        end

        function key = normalizeRunPolicyLabel(app, value) %#ok<INUSD>
            label = lower(strtrim(char(string(value))));
            switch label
                case {'restart from scratch', 'restart'}
                    key = 'restart';
                otherwise
                    key = 'resume';
            end
        end

        function label = existingPolicyToLabel(app, value) %#ok<INUSD>
            key = lower(strtrim(char(string(value))));
            switch key
                case 'replace'
                    label = 'Replace existing outputs';
                case 'append'
                    label = 'Append alongside existing outputs';
                case 'skip'
                    label = 'Skip when outputs exist';
                case 'error'
                    label = 'Stop when outputs exist';
                case 'upsert'
                    label = 'Upsert when supported';
                otherwise
                    label = 'Use each module default';
            end
        end

        function key = normalizeExistingPolicyLabel(app, value) %#ok<INUSD>
            label = lower(strtrim(char(string(value))));
            switch label
                case 'replace existing outputs'
                    key = 'replace';
                case 'append alongside existing outputs'
                    key = 'append';
                case 'skip when outputs exist'
                    key = 'skip';
                case 'stop when outputs exist'
                    key = 'error';
                case 'upsert when supported'
                    key = 'upsert';
                otherwise
                    key = 'module_default';
            end
        end

        function label = cachePolicyToLabel(app, value) %#ok<INUSD>
            key = lower(strtrim(char(string(value))));
            switch key
                case 'memory'
                    label = 'Prefer memory cache';
                case 'disk'
                    label = 'Prefer disk cache';
                otherwise
                    label = 'Automatic';
            end
        end

        function key = normalizeCachePolicyLabel(app, value) %#ok<INUSD>
            label = lower(strtrim(char(string(value))));
            switch label
                case 'prefer memory cache'
                    key = 'memory';
                case 'prefer disk cache'
                    key = 'disk';
                otherwise
                    key = 'auto';
            end
        end

        function label = inputSourceToLabel(app, value) %#ok<INUSD>
            key = lower(strtrim(char(string(value))));
            switch key
                case 'existing project fovs'
                    label = 'Reuse existing project FOVs';
                case 'existing rois'
                    label = 'Reuse existing ROIs';
                case 'existing masks'
                    label = 'Reuse existing masks';
                case 'existing dataseries'
                    label = 'Reuse existing data series';
                otherwise
                    label = 'Start from raw data (dataloader)';
            end
        end

        function key = normalizeInputSourceLabel(app, value) %#ok<INUSD>
            label = lower(strtrim(char(string(value))));
            switch label
                case 'reuse existing project fovs'
                    key = 'Existing project FOVs';
                case 'reuse existing rois'
                    key = 'Existing ROIs';
                case 'reuse existing masks'
                    key = 'Existing masks';
                case 'reuse existing data series'
                    key = 'Existing dataSeries';
                otherwise
                    key = 'Pipeline start (dataloader)';
            end
        end

        function CreateRunButtonPushed(app, event)
            commitVisibleParamTable(app);
            shallowObj = resolveSelectedProject(app);
            if isempty(shallowObj)
                uialert(app.UIFigure, 'No project selected/available.', 'Error', 'Icon', 'error');
                return;
            end

            if isempty(app.NodeTable.Data)
                uialert(app.UIFigure, 'Pipeline has no nodes.', 'Error', 'Icon', 'error');
                return;
            end

            selectedMask = cell2mat(app.NodeTable.Data(:,1));
            if ~any(selectedMask)
                uialert(app.UIFigure, 'Select at least one node for this run.', 'Warning', 'Icon', 'warning');
                return;
            end

            runId = strtrim(app.RunIdEditField.Value);
            if isempty(runId)
                runId = suggestRunId(app, shallowObj, app.Data.templateId);
            end
            descr = strtrim(app.DescriptionEditField.Value);
            templatePath = app.Data.templatePath;
            if isempty(templatePath)
                templatePath = inferTemplatePathFromProject(app, shallowObj, app.Data.templateId);
                if ~isempty(templatePath)
                    app.Data.templatePath = templatePath;
                end
            end

            nodes = app.Data.pipelineSpec.nodes;
            selectedMask = cell2mat(app.NodeTable.Data(:,1));
            inputSource = char(string(app.InputSourceDropDown.Value));
            selectedFovs = parseIndexSelection(app, app.FovSelectionEditField.Value);
            if ~strcmpi(inputSource, 'Start from raw data (dataloader)')
                hasSelectedLoader = false;
                for ii = 1:numel(nodes)
                    if selectedMask(ii) && strcmpi(char(string(nodes(ii).type)), 'dataloader')
                        hasSelectedLoader = true;
                        break;
                    end
                end
                if hasSelectedLoader
                    uialert(app.UIFigure, ...
                        'Disable the dataloader node when starting from existing project FOVs.', ...
                        'Incompatible run source', 'Icon', 'warning');
                    return;
                end
            end
            [sourceOk, sourceMsg] = validateRunSourceAvailability(app, shallowObj, inputSource, selectedFovs);
            if ~sourceOk
                uialert(app.UIFigure, sourceMsg, 'Run source unavailable', 'Icon', 'warning');
                return;
            end
            ctx = struct();
            ctx.allowGUI = true;
            ctx.shallow = shallowObj;
            ctx.shallowObj = shallowObj;
            ctx.run = struct();
            ctx.run.runId = runId;
            ctx.run.runPolicy = normalizeRunPolicyLabel(app, app.RunPolicyDropDown.Value);
            ctx.run.resume = strcmpi(ctx.run.runPolicy, 'resume');
            ctx.run.gpuPolicy = normalizeGpuPolicyLabel(app, app.GpuPolicyDropDown.Value);
            ctx.run.executionMode = normalizeExecutionModeLabel(app, app.ExecutionModeDropDown.Value);
            ctx.run.inputSource = normalizeInputSourceLabel(app, inputSource);
            ctx.run.selectedNodes = {};
            ctx.run.nodeParams = struct('id',{},'params',{});
            ctx.executionMode = ctx.run.executionMode;
            ctx.io = struct();
            existingPolicy = normalizeExistingPolicyLabel(app, app.ExistingPolicyDropDown.Value);
            if ~strcmpi(existingPolicy, 'module_default')
                ctx.io.existingPolicy = existingPolicy;
            end
            ctx.io.cachePolicy = normalizeCachePolicyLabel(app, app.CachePolicyDropDown.Value);
            ctx.store = struct('cacheMode', ctx.io.cachePolicy);
            ctx.sel = struct();
            ctx.sel.fovs = selectedFovs;
            ctx.exec = struct();
            ctx.exec.gpuPolicy = ctx.run.gpuPolicy;
            ctx.exec.python = buildPythonRunConfig(app);
            ctx.pipelineSpec = app.Data.pipelineSpec;
            ctx.pipelineRef = struct('id', app.Data.templateId, 'path', templatePath, 'version', '');

            for i = 1:numel(nodes)
                if ~selectedMask(i)
                    continue;
                end
                nodeId = char(string(nodes(i).id));
                ctx.run.selectedNodes{end+1} = nodeId; %#ok<AGROW>
                ctx.run.nodeParams(end+1).id = nodeId; %#ok<AGROW>
                ctx.run.nodeParams(end).params = pruneRunOverrides(app, i, app.Data.nodeParams{i});
            end

            try
                if app.Data.editMode && isa(app.Data.runObj, 'pipelineRun') && ~isempty(app.Data.runObj)
                    runObj = app.Data.runObj;
                    runObj.description = descr;
                    runObj.ctx = ctx;
                    runObj.templateId = app.Data.templateId;
                    runObj.templatePath = templatePath;
                    if isfield(ctx,'pipelineRef') && isstruct(ctx.pipelineRef)
                        runObj.pipelineRef = ctx.pipelineRef;
                    end
                    runObj.projectPath = fullfile(shallowObj.io.path, shallowObj.io.file);
                    runObj.projectName = shallowObj.io.file;
                    if isprop(runObj,'targetRef') && isstruct(runObj.targetRef)
                        runObj.targetRef.projectPath = runObj.projectPath;
                        runObj.targetRef.projectName = runObj.projectName;
                    end
                    if isempty(runObj.status)
                        runObj.status = 'new';
                    end

                    runIdx = findRunIndexInProject(app, shallowObj, runObj);
                    if isempty(runIdx)
                        error('Could not find this pipeline run in the selected project.');
                    end
                    shallowObj.processing.pipelineRun(runIdx) = runObj;

                    try
                        assignin('base', shallowObj.io.file, shallowObj);
                    catch
                    end
                    try
                        pipelineRunSave(runObj);
                    catch
                    end
                    try
                        shallowSave(shallowObj, 'shallowObj');
                    catch
                    end
                    app.Data.runObj = runObj;
                    markDirty(app, false);
                    updateHubStatusUi(app);

                    msgbox({ ...
                        ['Pipeline run updated: ' runObj.runId], ...
                        'Changes were saved.'}, ...
                        'Success', 'help');
                else
                    runObj = pipelineRunNew(shallowObj, app.Data.templateId, templatePath, ...
                        'runId', runId, 'description', descr, 'ctx', ctx, 'status', 'new');
                    try
                        assignin('base', shallowObj.io.file, shallowObj);
                    catch
                    end
                    try
                        pipelineRunSave(runObj);
                    catch
                    end
                    try
                        shallowSave(shallowObj, 'shallowObj');
                    catch
                    end
                    msgbox({ ...
                        ['Pipeline run created: ' runObj.runId], ...
                        'Run settings were saved.'}, ...
                        'Success', 'help');
                    app.Data.runObj = runObj;
                    app.Data.editMode = true;
                    app.CreateRunButton.Text = 'Save run';
                    app.RunIdEditField.Editable = 'off';
                    markDirty(app, false);
                    updateHubStatusUi(app);
                end
            catch ME
                uialert(app.UIFigure, ME.message, 'Create run failed', 'Icon', 'error');
            end
        end

        function runIdx = findRunIndexInProject(app, shallowObj, runObj) %#ok<INUSD>
            runIdx = [];
            if isempty(shallowObj) || ~isa(shallowObj, 'shallow')
                return;
            end
            if ~isfield(shallowObj.processing,'pipelineRun') || isempty(shallowObj.processing.pipelineRun)
                return;
            end

            try
                for ii = 1:numel(shallowObj.processing.pipelineRun)
                    cand = shallowObj.processing.pipelineRun(ii);
                    if cand == runObj
                        runIdx = ii;
                        return;
                    end
                end
            catch
            end

            try
                names = arrayfun(@(r) char(string(r.runId)), shallowObj.processing.pipelineRun, 'UniformOutput', false);
                runIdx = find(strcmp(names, char(string(runObj.runId))), 1);
            catch
                runIdx = [];
            end
        end

        function CloseButtonPushed(app, event)
            requestClose(app);
        end

        function UIFigureCloseRequest(app, event)
            requestClose(app);
        end

        function requestClose(app)
            if app.Data.dirty
                choice = uiconfirm(app.UIFigure, ...
                    'This pipeline run has unsaved changes. Close without saving?', ...
                    'Unsaved changes', ...
                    'Options', {'Close','Cancel'}, ...
                    'DefaultOption', 2, ...
                    'CancelOption', 2, ...
                    'Icon', 'warning');
                if ~strcmp(choice, 'Close')
                    return;
                end
            end
            delete(app);
        end

        function updateRunSourceSelectionUi(app)
            src = char(string(app.InputSourceDropDown.Value));
            switch lower(src)
                case 'start from raw data (dataloader)'
                    app.FovSelectionEditFieldLabel.Text = 'Selection';
                    app.FovSelectionEditField.Placeholder = 'Not used when starting from raw data';
                    app.FovSelectionEditField.Enable = 'off';
                    selTip = { ...
                        'Not used for this run source.', ...
                        'When starting from the dataloader, the pipeline decides the FOV set itself.'};
                case 'reuse existing project fovs'
                    app.FovSelectionEditFieldLabel.Text = 'Project FOVs';
                    app.FovSelectionEditField.Placeholder = 'empty = all | ex: 1 3 5 or 1:7';
                    app.FovSelectionEditField.Enable = 'on';
                    selTip = { ...
                        'Subset of project FOVs to use as input.', ...
                        'Leave empty to use all FOVs.', ...
                        'Examples: 1:7 or 1 3 5'};
                case 'reuse existing rois'
                    app.FovSelectionEditFieldLabel.Text = 'ROI source';
                    app.FovSelectionEditField.Placeholder = 'FOVs whose existing ROI sets seed the run';
                    app.FovSelectionEditField.Enable = 'on';
                    selTip = { ...
                        'Subset of project FOVs whose existing ROIs will seed the run.', ...
                        'Leave empty to use all project FOVs that already contain ROIs.'};
                case 'reuse existing masks'
                    app.FovSelectionEditFieldLabel.Text = 'Mask source';
                    app.FovSelectionEditField.Placeholder = 'FOVs whose existing masks seed the run';
                    app.FovSelectionEditField.Enable = 'on';
                    selTip = { ...
                        'Subset of project FOVs whose existing masks will seed the run.', ...
                        'Leave empty to use all compatible project FOVs.'};
                case 'reuse existing data series'
                    app.FovSelectionEditFieldLabel.Text = 'DataSeries source';
                    app.FovSelectionEditField.Placeholder = 'FOVs whose existing dataseries seed the run';
                    app.FovSelectionEditField.Enable = 'on';
                    selTip = { ...
                        'Subset of project FOVs whose existing dataseries will seed the run.', ...
                        'Leave empty to use all compatible project FOVs.'};
                otherwise
                    app.FovSelectionEditFieldLabel.Text = 'Selection';
                    app.FovSelectionEditField.Placeholder = 'empty = all | ex: 1 3 5 or 1:7';
                    app.FovSelectionEditField.Enable = 'on';
                    selTip = { ...
                        'Optional FOV selection for the chosen run source.', ...
                        'Leave empty to use all compatible FOVs.'};
            end
            app.FovSelectionEditField.Tooltip = selTip;
            app.FovSelectionEditFieldLabel.Tooltip = selTip;
        end

        function vals = parseIndexSelection(app, raw) %#ok<INUSD>
            vals = [];
            raw = char(string(raw));
            raw = strtrim(raw);
            if isempty(raw)
                return;
            end
            raw = regexprep(raw, '[;,]+', ' ');
            if contains(raw, ':')
                try
                    vals = eval(['[' raw ']']); %#ok<EVLDIR>
                catch
                    vals = [];
                end
            else
                parts = regexp(raw, '\s+', 'split');
                nums = str2double(parts);
                nums = nums(~isnan(nums));
                vals = nums;
            end
            vals = unique(round(double(vals(:)')), 'stable');
            vals = vals(isfinite(vals) & vals >= 1);
        end

        function [ok, msg] = validateRunSourceAvailability(app, shallowObj, inputSource, selectedFovs)
            ok = true;
            msg = '';
            if isempty(shallowObj) || ~isa(shallowObj, 'shallow')
                ok = false;
                msg = 'No valid project selected.';
                return;
            end
            if strcmpi(inputSource, 'Start from raw data (dataloader)')
                return;
            end

            fovs = selectProjectFovs(app, shallowObj, selectedFovs);
            if isempty(fovs)
                ok = false;
                msg = 'No project FOV matches the current run selection.';
                return;
            end

            rois = collectProjectRois(app, fovs);
            switch lower(char(string(inputSource)))
                case 'reuse existing project fovs'
                    return;
                case 'reuse existing rois'
                    ok = ~isempty(rois);
                    if ~ok
                        msg = 'No ROI found in the selected project FOVs.';
                    end
                case 'reuse existing masks'
                    ok = ~isempty(collectProjectMasks(app, rois));
                    if ~ok
                        msg = 'No mask-like ROI channels found in the selected project FOVs.';
                    end
                case 'reuse existing data series'
                    ok = ~isempty(collectProjectDataSeries(app, rois));
                    if ~ok
                        msg = 'No dataseries found in the selected project FOVs.';
                    end
                otherwise
                    ok = true;
            end
        end

        function fovs = selectProjectFovs(app, shallowObj, selectedFovs) %#ok<INUSD>
            fovs = [];
            try
                allFovs = shallowObj.fov;
            catch
                return;
            end
            if isempty(selectedFovs)
                fovs = allFovs;
                return;
            end
            idx = selectedFovs(selectedFovs >= 1 & selectedFovs <= numel(allFovs));
            if isempty(idx)
                return;
            end
            fovs = allFovs(idx);
        end

        function rois = collectProjectRois(app, fovs) %#ok<INUSD>
            rois = [];
            for i = 1:numel(fovs)
                try
                    r = fovs(i).roi;
                    if ~isempty(r)
                        rois = [rois r(:)']; %#ok<AGROW>
                    end
                catch
                end
            end
        end

        function masks = collectProjectMasks(app, rois) %#ok<INUSD>
            masks = {};
            if isempty(rois)
                return;
            end
            try
                r0 = rois(1);
                names = {};
                if isfield(r0.display,'channel') && ~isempty(r0.display.channel)
                    names = r0.display.channel;
                end
                keep = false(1, numel(names));
                for i = 1:numel(names)
                    nm = lower(char(string(names{i})));
                    keep(i) = contains(nm, 'mask') || contains(nm, 'result') || contains(nm, 'track');
                end
                masks = names(keep);
            catch
                masks = {};
            end
        end

        function ds = collectProjectDataSeries(app, rois) %#ok<INUSD>
            ds = {};
            for i = 1:numel(rois)
                try
                    r = rois(i);
                    if isempty(r.data)
                        r.load('data');
                    end
                    for k = 1:numel(r.data)
                        if isprop(r.data(k), 'groupid') && ~isempty(r.data(k).groupid)
                            ds{end+1} = char(string(r.data(k).groupid)); %#ok<AGROW>
                        end
                    end
                catch
                end
            end
            if ~isempty(ds)
                ds = unique(ds, 'stable');
            end
        end

        function val = getfielddefault(varargin)
            if nargin == 4
                s = varargin{2};
                f = varargin{3};
                default = varargin{4};
            elseif nargin == 3
                s = varargin{1};
                f = varargin{2};
                default = varargin{3};
            else
                val = [];
                return;
            end

            if isstruct(s) && isfield(s, f)
                val = s.(f);
            else
                val = default;
            end
        end
    end

    methods (Access = private)

        function createComponents(app)
            app.UIFigure = uifigure('Visible','off');
            app.UIFigure.Position = [100 100 900 710];
            app.UIFigure.Name = 'Pipeline Run Builder';
            app.UIFigure.CloseRequestFcn = createCallbackFcn(app, @UIFigureCloseRequest, true);

            app.ProjectDropDownLabel = uilabel(app.UIFigure);
            app.ProjectDropDownLabel.HorizontalAlignment = 'right';
            app.ProjectDropDownLabel.Position = [18 626 52 22];
            app.ProjectDropDownLabel.Text = 'Project';

            app.ProjectDropDown = uidropdown(app.UIFigure);
            app.ProjectDropDown.Position = [84 626 190 22];
            app.ProjectDropDown.Items = {'<no project in workspace>'};
            app.ProjectDropDown.Value = '<no project in workspace>';

            app.RunIdEditFieldLabel = uilabel(app.UIFigure);
            app.RunIdEditFieldLabel.HorizontalAlignment = 'right';
            app.RunIdEditFieldLabel.Position = [289 626 43 22];
            app.RunIdEditFieldLabel.Text = 'Run ID';

            app.RunIdEditField = uieditfield(app.UIFigure, 'text');
            app.RunIdEditField.Position = [346 626 170 22];
            app.RunIdEditField.Value = 'pipeline_run_1';
            app.RunIdEditField.ValueChangedFcn = createCallbackFcn(app, @RunIdEditFieldValueChanged, true);

            app.DescriptionEditFieldLabel = uilabel(app.UIFigure);
            app.DescriptionEditFieldLabel.HorizontalAlignment = 'right';
            app.DescriptionEditFieldLabel.Position = [530 626 67 22];
            app.DescriptionEditFieldLabel.Text = 'Description';

            app.DescriptionEditField = uieditfield(app.UIFigure, 'text');
            app.DescriptionEditField.Position = [611 626 210 22];
            app.DescriptionEditField.ValueChangedFcn = createCallbackFcn(app, @DescriptionEditFieldValueChanged, true);

            app.RunPolicyDropDownLabel = uilabel(app.UIFigure);
            app.RunPolicyDropDownLabel.HorizontalAlignment = 'right';
            app.RunPolicyDropDownLabel.Position = [8 590 74 22];
            app.RunPolicyDropDownLabel.Text = 'Rerun mode';

            app.RunPolicyDropDown = uidropdown(app.UIFigure);
            app.RunPolicyDropDown.Items = {'Resume previous progress', 'Restart from scratch'};
            app.RunPolicyDropDown.Position = [96 590 120 22];
            app.RunPolicyDropDown.Value = 'Resume previous progress';
            app.RunPolicyDropDown.ValueChangedFcn = createCallbackFcn(app, @RunPolicyDropDownValueChanged, true);

            app.ExistingPolicyDropDownLabel = uilabel(app.UIFigure);
            app.ExistingPolicyDropDownLabel.HorizontalAlignment = 'right';
            app.ExistingPolicyDropDownLabel.Position = [216 590 98 22];
            app.ExistingPolicyDropDownLabel.Text = 'Existing outputs';

            app.ExistingPolicyDropDown = uidropdown(app.UIFigure);
            app.ExistingPolicyDropDown.Items = {'Use each module default', 'Replace existing outputs', 'Append alongside existing outputs', 'Skip when outputs exist', 'Stop when outputs exist', 'Upsert when supported'};
            app.ExistingPolicyDropDown.Position = [328 590 135 22];
            app.ExistingPolicyDropDown.Value = 'Use each module default';
            app.ExistingPolicyDropDown.ValueChangedFcn = createCallbackFcn(app, @ExistingPolicyDropDownValueChanged, true);

            app.CachePolicyDropDownLabel = uilabel(app.UIFigure);
            app.CachePolicyDropDownLabel.HorizontalAlignment = 'right';
            app.CachePolicyDropDownLabel.Position = [472 590 82 22];
            app.CachePolicyDropDownLabel.Text = 'ROI cache mode';

            app.CachePolicyDropDown = uidropdown(app.UIFigure);
            app.CachePolicyDropDown.Items = {'Automatic', 'Prefer memory cache', 'Prefer disk cache'};
            app.CachePolicyDropDown.Position = [568 590 120 22];
            app.CachePolicyDropDown.Value = 'Automatic';
            app.CachePolicyDropDown.ValueChangedFcn = createCallbackFcn(app, @CachePolicyDropDownValueChanged, true);

            app.GpuPolicyDropDownLabel = uilabel(app.UIFigure);
            app.GpuPolicyDropDownLabel.HorizontalAlignment = 'right';
            app.GpuPolicyDropDownLabel.Position = [700 590 62 22];
            app.GpuPolicyDropDownLabel.Text = 'GPU';

            app.GpuPolicyDropDown = uidropdown(app.UIFigure);
            app.GpuPolicyDropDown.Items = {'Use each module default', 'Force GPU where supported', 'Force CPU'};
            app.GpuPolicyDropDown.Position = [774 590 106 22];
            app.GpuPolicyDropDown.Value = 'Use each module default';
            app.GpuPolicyDropDown.ValueChangedFcn = createCallbackFcn(app, @GpuPolicyDropDownValueChanged, true);

            app.ExecutionModeDropDownLabel = uilabel(app.UIFigure);
            app.ExecutionModeDropDownLabel.HorizontalAlignment = 'right';
            app.ExecutionModeDropDownLabel.Position = [694 554 68 22];
            app.ExecutionModeDropDownLabel.Text = 'Execution';

            app.ExecutionModeDropDown = uidropdown(app.UIFigure);
            app.ExecutionModeDropDown.Items = {'Local MATLAB session', 'Detecdiv hub'};
            app.ExecutionModeDropDown.Position = [774 554 106 22];
            app.ExecutionModeDropDown.Value = 'Local MATLAB session';
            app.ExecutionModeDropDown.ValueChangedFcn = createCallbackFcn(app, @ExecutionModeDropDownValueChanged, true);

            app.InputSourceDropDownLabel = uilabel(app.UIFigure);
            app.InputSourceDropDownLabel.HorizontalAlignment = 'right';
            app.InputSourceDropDownLabel.Position = [28 554 57 22];
            app.InputSourceDropDownLabel.Text = 'Start from';

            app.InputSourceDropDown = uidropdown(app.UIFigure);
            app.InputSourceDropDown.Items = { ...
                'Start from raw data (dataloader)', ...
                'Reuse existing project FOVs', ...
                'Reuse existing ROIs', ...
                'Reuse existing masks', ...
                'Reuse existing data series'};
            app.InputSourceDropDown.Position = [96 554 180 22];
            app.InputSourceDropDown.Value = 'Start from raw data (dataloader)';
            app.InputSourceDropDown.ValueChangedFcn = createCallbackFcn(app, @InputSourceDropDownValueChanged, true);

            app.FovSelectionEditFieldLabel = uilabel(app.UIFigure);
            app.FovSelectionEditFieldLabel.HorizontalAlignment = 'right';
            app.FovSelectionEditFieldLabel.Position = [289 554 98 22];
            app.FovSelectionEditFieldLabel.Text = 'Project FOVs';

            app.FovSelectionEditField = uieditfield(app.UIFigure, 'text');
            app.FovSelectionEditField.Position = [401 554 287 22];
            app.FovSelectionEditField.Placeholder = 'empty = all | ex: 1 3 5 or 1:7';
            app.FovSelectionEditField.ValueChangedFcn = createCallbackFcn(app, @FovSelectionEditFieldValueChanged, true);

            app.PythonEnvModeDropDownLabel = uilabel(app.UIFigure);
            app.PythonEnvModeDropDownLabel.HorizontalAlignment = 'right';
            app.PythonEnvModeDropDownLabel.Position = [8 518 77 22];
            app.PythonEnvModeDropDownLabel.Text = 'Python runtime';

            app.PythonEnvModeDropDown = uidropdown(app.UIFigure);
            app.PythonEnvModeDropDown.Items = {'Default detecdiv_python', 'Custom conda env'};
            app.PythonEnvModeDropDown.Position = [96 518 180 22];
            app.PythonEnvModeDropDown.Value = 'Default detecdiv_python';
            app.PythonEnvModeDropDown.ValueChangedFcn = createCallbackFcn(app, @PythonEnvModeDropDownValueChanged, true);

            app.PythonEnvNameEditFieldLabel = uilabel(app.UIFigure);
            app.PythonEnvNameEditFieldLabel.HorizontalAlignment = 'right';
            app.PythonEnvNameEditFieldLabel.Position = [289 518 98 22];
            app.PythonEnvNameEditFieldLabel.Text = 'Custom env';

            app.PythonEnvNameEditField = uieditfield(app.UIFigure, 'text');
            app.PythonEnvNameEditField.Position = [401 518 287 22];
            app.PythonEnvNameEditField.Placeholder = 'existing conda env name';
            app.PythonEnvNameEditField.ValueChangedFcn = createCallbackFcn(app, @PythonEnvNameEditFieldValueChanged, true);

            app.NodeTableLabel = uilabel(app.UIFigure);
            app.NodeTableLabel.Position = [20 488 99 22];
            app.NodeTableLabel.Text = 'Pipeline nodes';

            app.NodeTable = uitable(app.UIFigure);
            app.NodeTable.ColumnName = {'Select'; 'Node'; 'Family'; 'Stage'; 'Package'; 'Binding'};
            app.NodeTable.RowName = {};
            app.NodeTable.ColumnEditable = [true false false false false false];
            app.NodeTable.ColumnWidth = {56 144 152 96 118 'auto'};
            app.NodeTable.CellEditCallback = createCallbackFcn(app, @NodeTableCellEdit, true);
            app.NodeTable.SelectionChangedFcn = createCallbackFcn(app, @NodeTableSelectionChanged, true);
            app.NodeTable.Position = [20 274 860 205];

            app.ParamTableLabel = uilabel(app.UIFigure);
            app.ParamTableLabel.Position = [20 242 220 22];
            app.ParamTableLabel.Text = 'Template values and run overrides';

            app.ParamTable = uitable(app.UIFigure);
            app.ParamTable.ColumnName = {'Section'; 'Parameter'; 'Template'; 'Run override'; 'Notes'};
            app.ParamTable.RowName = {};
            app.ParamTable.ColumnEditable = [false false false true false];
            app.ParamTable.ColumnWidth = {88 156 196 178 'auto'};
            app.ParamTable.CellEditCallback = createCallbackFcn(app, @ParamTableCellEdit, true);
            app.ParamTable.SelectionChangedFcn = createCallbackFcn(app, @ParamTableSelectionChanged, true);
            app.ParamTable.Position = [20 64 860 170];

            app.OpenNodeGUIButton = uibutton(app.UIFigure, 'push');
            app.OpenNodeGUIButton.Position = [20 20 160 28];
            app.OpenNodeGUIButton.Text = 'Open selected node GUI';
            app.OpenNodeGUIButton.ButtonPushedFcn = createCallbackFcn(app, @OpenNodeGUIButtonPushed, true);

            app.HubStatusLabel = uilabel(app.UIFigure);
            app.HubStatusLabel.Position = [196 20 210 28];
            app.HubStatusLabel.Text = 'Hub: no job';

            app.RefreshHubButton = uibutton(app.UIFigure, 'push');
            app.RefreshHubButton.Position = [420 20 88 28];
            app.RefreshHubButton.Text = 'Refresh hub';
            app.RefreshHubButton.ButtonPushedFcn = createCallbackFcn(app, @RefreshHubButtonPushed, true);

            app.RunOnHubButton = uibutton(app.UIFigure, 'push');
            app.RunOnHubButton.Position = [520 20 88 28];
            app.RunOnHubButton.Text = 'Run on hub';
            app.RunOnHubButton.ButtonPushedFcn = createCallbackFcn(app, @RunOnHubButtonPushed, true);

            app.CreateRunButton = uibutton(app.UIFigure, 'push');
            app.CreateRunButton.Position = [620 20 120 28];
            app.CreateRunButton.Text = 'Create run';
            app.CreateRunButton.ButtonPushedFcn = createCallbackFcn(app, @CreateRunButtonPushed, true);

            app.CloseButton = uibutton(app.UIFigure, 'push');
            app.CloseButton.Position = [760 20 120 28];
            app.CloseButton.Text = 'Close';
            app.CloseButton.ButtonPushedFcn = createCallbackFcn(app, @CloseButtonPushed, true);

            app.UIFigure.Visible = 'on';
        end
    end

    methods (Access = public)

        function app = pipelineRunGUI(varargin)
            createComponents(app)
            registerApp(app, app.UIFigure)
            runStartupFcn(app, @(app)startupFcn(app, varargin{:}))

            if nargout == 0
                clear app
            end
        end

        function delete(app)
            delete(app.UIFigure)
        end
    end
end
