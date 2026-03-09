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
        InputSourceDropDownLabel    matlab.ui.control.Label
        InputSourceDropDown         matlab.ui.control.DropDown
        FovSelectionEditFieldLabel  matlab.ui.control.Label
        FovSelectionEditField       matlab.ui.control.EditField
        NodeTableLabel              matlab.ui.control.Label
        NodeTable                   matlab.ui.control.Table
        ParamTableLabel             matlab.ui.control.Label
        ParamTable                  matlab.ui.control.Table
        OpenNodeGUIButton           matlab.ui.control.Button
        CreateRunButton             matlab.ui.control.Button
        CloseButton                 matlab.ui.control.Button
    end

    properties (Access = private)
        Data struct = struct( ...
            'pipelineSpec', struct('nodes',[],'edges',[]), ...
            'shallowObj', [], ...
            'projectVars', {{}}, ...
            'selectedNode', [], ...
            'nodeTemplateParams', {{}}, ...
            'nodeParams', {{}}, ...
            'templateId', 'pipeline', ...
            'templatePath', '' )
    end

    methods (Access = private)

        function startupFcn(app, varargin)
            pipeIn = [];
            shallowObj = [];

            for i = 1:numel(varargin)
                arg = varargin{i};
                if isa(arg, 'shallow')
                    shallowObj = arg;
                elseif isa(arg, 'pipeline') || (isstruct(arg) && isfield(arg,'nodes'))
                    pipeIn = arg;
                end
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

            initProjectList(app);
            initNodeTable(app);

            if ~isempty(shallowObj)
                app.RunIdEditField.Value = suggestRunId(app, shallowObj, templateId);
            else
                app.RunIdEditField.Value = [templateId '_run'];
            end

            app.RunPolicyDropDown.Value = 'resume';
            app.ExistingPolicyDropDown.Value = '<module default>';
            app.CachePolicyDropDown.Value = 'auto';
            app.InputSourceDropDown.Value = 'Pipeline start (dataloader)';
            app.FovSelectionEditField.Value = '';
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
            data = cell(n,4);
            app.Data.nodeTemplateParams = cell(n,1);
            app.Data.nodeParams = cell(n,1);

            for i = 1:n
                node = nodes(i);
                pkg = '';
                if isfield(node,'pkg') && ~isempty(node.pkg)
                    pkg = char(string(node.pkg));
                end

                data{i,1} = true;
                data{i,2} = char(string(node.id));
                data{i,3} = char(string(node.type));
                data{i,4} = pkg;

                tpl = struct();
                if isfield(node,'params') && isstruct(node.params)
                    tpl = node.params;
                end
                app.Data.nodeTemplateParams{i} = tpl;
                app.Data.nodeParams{i} = getRunDefaults(app, node);
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
                app.ParamTable.Data = {};
                return;
            end

            tpl = getTemplateParams(app, row);
            runP = app.Data.nodeParams{row};
            if ~isstruct(runP)
                runP = struct();
            end

            fnTpl = fieldnames(tpl);
            fnRun = fieldnames(runP);
            data = cell(numel(fnTpl) + numel(fnRun), 3);
            c = 1;
            for i = 1:numel(fnTpl)
                data{c,1} = 'Template';
                data{c,2} = fnTpl{i};
                data{c,3} = valueToDisplay(app, tpl.(fnTpl{i}));
                c = c + 1;
            end
            for i = 1:numel(fnRun)
                data{c,1} = 'Run';
                data{c,2} = fnRun{i};
                data{c,3} = runOverrideDisplayValue(app, row, fnRun{i}, runP.(fnRun{i}));
                c = c + 1;
            end
            app.ParamTable.Data = data;
        end

        function out = valueToDisplay(app, v) %#ok<INUSD>
            if islogical(v)
                if v, out = 'true'; else, out = 'false'; end
            elseif isnumeric(v)
                if isscalar(v)
                    out = num2str(v);
                else
                    out = mat2str(v);
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

        function out = runOverrideDisplayValue(app, row, key, v)
            if isDefaultRunValue(app, row, key, v)
                out = '<inherit>';
                return;
            end
            out = valueToDisplay(app, v);
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
            out = getRunDefaults(app, node);
            if ~isstruct(out)
                out = struct();
                return;
            end
            fn = fieldnames(out);
            for i = 1:numel(fn)
                k = fn{i};
                if ~isfield(mergedParams, k)
                    continue;
                end
                newVal = mergedParams.(k);
                tplVal = [];
                if isstruct(templateParams) && isfield(templateParams, k)
                    tplVal = templateParams.(k);
                end
                try
                    sameAsTemplate = isequaln(newVal, tplVal);
                catch
                    sameAsTemplate = false;
                end
                if ~sameAsTemplate
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
                if ~isDefaultRunValue(app, row, k, p.(k))
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

        function shallowObj = resolveSelectedProject(app)
            shallowObj = [];
            if ~isempty(app.Data.shallowObj)
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
        end

        function ParamTableCellEdit(app, event)
            idx = event.Indices;
            if isempty(idx)
                return;
            end
            row = idx(1);
            col = idx(2);
            if col ~= 2
                return;
            end
            if isempty(app.Data.selectedNode)
                return;
            end

            nodeRow = app.Data.selectedNode;
            p = app.Data.nodeParams{nodeRow};
            if ~isstruct(p)
                return;
            end

            data = app.ParamTable.Data;
            if row > size(data,1)
                return;
            end

            scope = char(string(data{row,1}));
            if ~strcmpi(scope, 'Run')
                return;
            end

            key = char(string(data{row,2}));
            oldVal = p.(key);
            rawStr = strtrim(char(string(event.NewData)));
            if isempty(rawStr) || strcmpi(rawStr, '<inherit>')
                p.(key) = getRunDefaultValue(app, nodeRow, key);
            else
                typeRef = oldVal;
                if isempty(typeRef)
                    tpl = getTemplateParams(app, nodeRow);
                    if isstruct(tpl) && isfield(tpl, key)
                        typeRef = tpl.(key);
                    end
                end
                p.(key) = parseDisplayValue(app, event.NewData, typeRef);
            end
            app.Data.nodeParams{nodeRow} = p;

            updateParamTable(app, nodeRow);
        end

        function OpenNodeGUIButtonPushed(app, event)
            openSelectedNodeGUI(app);
        end

        function CreateRunButtonPushed(app, event)
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
            if ~strcmpi(inputSource, 'Pipeline start (dataloader)')
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
            ctx.run.runPolicy = char(string(app.RunPolicyDropDown.Value));
            ctx.run.resume = strcmpi(ctx.run.runPolicy, 'resume');
            ctx.run.inputSource = inputSource;
            ctx.run.selectedNodes = {};
            ctx.run.nodeParams = struct('id',{},'params',{});
            ctx.io = struct();
            existingPolicy = char(string(app.ExistingPolicyDropDown.Value));
            if ~strcmpi(existingPolicy, '<module default>')
                ctx.io.existingPolicy = existingPolicy;
            end
            ctx.io.cachePolicy = char(string(app.CachePolicyDropDown.Value));
            ctx.store = struct('cacheMode', ctx.io.cachePolicy);
            ctx.sel = struct();
            ctx.sel.fovs = selectedFovs;
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
                runObj = pipelineRunNew(shallowObj, app.Data.templateId, templatePath, ...
                    'runId', runId, 'description', descr, 'ctx', ctx, 'status', 'new');
                uialert(app.UIFigure, ...
                    ['Pipeline run created in memory: ' runObj.runId newline ...
                     'It will be saved when you launch it.'], ...
                    'Success', 'Icon', 'success');
                app.RunIdEditField.Value = suggestRunId(app, shallowObj, app.Data.templateId);
            catch ME
                uialert(app.UIFigure, ME.message, 'Create run failed', 'Icon', 'error');
            end
        end

        function CloseButtonPushed(app, event)
            delete(app);
        end

        function UIFigureCloseRequest(app, event)
            delete(app);
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
            if strcmpi(inputSource, 'Pipeline start (dataloader)')
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
                case 'existing project fovs'
                    return;
                case 'existing rois'
                    ok = ~isempty(rois);
                    if ~ok
                        msg = 'No ROI found in the selected project FOVs.';
                    end
                case 'existing masks'
                    ok = ~isempty(collectProjectMasks(app, rois));
                    if ~ok
                        msg = 'No mask-like ROI channels found in the selected project FOVs.';
                    end
                case 'existing dataseries'
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

            app.DescriptionEditFieldLabel = uilabel(app.UIFigure);
            app.DescriptionEditFieldLabel.HorizontalAlignment = 'right';
            app.DescriptionEditFieldLabel.Position = [530 626 67 22];
            app.DescriptionEditFieldLabel.Text = 'Description';

            app.DescriptionEditField = uieditfield(app.UIFigure, 'text');
            app.DescriptionEditField.Position = [611 626 210 22];

            app.RunPolicyDropDownLabel = uilabel(app.UIFigure);
            app.RunPolicyDropDownLabel.HorizontalAlignment = 'right';
            app.RunPolicyDropDownLabel.Position = [14 590 68 22];
            app.RunPolicyDropDownLabel.Text = 'Run policy';

            app.RunPolicyDropDown = uidropdown(app.UIFigure);
            app.RunPolicyDropDown.Items = {'resume', 'restart'};
            app.RunPolicyDropDown.Position = [96 590 120 22];
            app.RunPolicyDropDown.Value = 'resume';

            app.ExistingPolicyDropDownLabel = uilabel(app.UIFigure);
            app.ExistingPolicyDropDownLabel.HorizontalAlignment = 'right';
            app.ExistingPolicyDropDownLabel.Position = [232 590 82 22];
            app.ExistingPolicyDropDownLabel.Text = 'Existing data';

            app.ExistingPolicyDropDown = uidropdown(app.UIFigure);
            app.ExistingPolicyDropDown.Items = {'<module default>', 'replace', 'append', 'skip', 'error'};
            app.ExistingPolicyDropDown.Position = [328 590 135 22];
            app.ExistingPolicyDropDown.Value = '<module default>';

            app.CachePolicyDropDownLabel = uilabel(app.UIFigure);
            app.CachePolicyDropDownLabel.HorizontalAlignment = 'right';
            app.CachePolicyDropDownLabel.Position = [479 590 75 22];
            app.CachePolicyDropDownLabel.Text = 'ROI cache';

            app.CachePolicyDropDown = uidropdown(app.UIFigure);
            app.CachePolicyDropDown.Items = {'auto', 'memory', 'disk'};
            app.CachePolicyDropDown.Position = [568 590 120 22];
            app.CachePolicyDropDown.Value = 'auto';

            app.InputSourceDropDownLabel = uilabel(app.UIFigure);
            app.InputSourceDropDownLabel.HorizontalAlignment = 'right';
            app.InputSourceDropDownLabel.Position = [13 554 72 22];
            app.InputSourceDropDownLabel.Text = 'Run source';

            app.InputSourceDropDown = uidropdown(app.UIFigure);
            app.InputSourceDropDown.Items = { ...
                'Pipeline start (dataloader)', ...
                'Existing project FOVs', ...
                'Existing ROIs', ...
                'Existing masks', ...
                'Existing dataSeries'};
            app.InputSourceDropDown.Position = [96 554 180 22];
            app.InputSourceDropDown.Value = 'Pipeline start (dataloader)';

            app.FovSelectionEditFieldLabel = uilabel(app.UIFigure);
            app.FovSelectionEditFieldLabel.HorizontalAlignment = 'right';
            app.FovSelectionEditFieldLabel.Position = [301 554 86 22];
            app.FovSelectionEditFieldLabel.Text = 'Project FOVs';

            app.FovSelectionEditField = uieditfield(app.UIFigure, 'text');
            app.FovSelectionEditField.Position = [401 554 287 22];
            app.FovSelectionEditField.Placeholder = 'empty = all | ex: 1 3 5 or 1:7';

            app.NodeTableLabel = uilabel(app.UIFigure);
            app.NodeTableLabel.Position = [20 518 99 22];
            app.NodeTableLabel.Text = 'Pipeline nodes';

            app.NodeTable = uitable(app.UIFigure);
            app.NodeTable.ColumnName = {'Select'; 'Node'; 'Type'; 'Package'};
            app.NodeTable.RowName = {};
            app.NodeTable.ColumnEditable = [true false false false];
            app.NodeTable.CellEditCallback = createCallbackFcn(app, @NodeTableCellEdit, true);
            app.NodeTable.SelectionChangedFcn = createCallbackFcn(app, @NodeTableSelectionChanged, true);
            app.NodeTable.Position = [20 304 860 205];

            app.ParamTableLabel = uilabel(app.UIFigure);
            app.ParamTableLabel.Position = [20 272 220 22];
            app.ParamTableLabel.Text = 'Template params and run overrides';

            app.ParamTable = uitable(app.UIFigure);
            app.ParamTable.ColumnName = {'Scope'; 'Parameter'; 'Value'};
            app.ParamTable.RowName = {};
            app.ParamTable.ColumnEditable = [false false true];
            app.ParamTable.CellEditCallback = createCallbackFcn(app, @ParamTableCellEdit, true);
            app.ParamTable.Position = [20 64 860 200];

            app.OpenNodeGUIButton = uibutton(app.UIFigure, 'push');
            app.OpenNodeGUIButton.Position = [20 20 160 28];
            app.OpenNodeGUIButton.Text = 'Open selected node GUI';
            app.OpenNodeGUIButton.ButtonPushedFcn = createCallbackFcn(app, @OpenNodeGUIButtonPushed, true);

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
