classdef processDataGUI < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        ProcessdataUIFigure           matlab.ui.Figure
        Label                         matlab.ui.control.Label
        SaveparametersButton          matlab.ui.control.Button
        TabGroup                      matlab.ui.container.TabGroup
        ROIsTab                       matlab.ui.container.Tab
        ProcessallframesoveridesframestableselectionCheckBox  matlab.ui.control.CheckBox
        ApplyselectedsettingstoallButton  matlab.ui.control.Button
        DeselectallButton             matlab.ui.control.Button
        SelectallButton               matlab.ui.control.Button
        UIROITable                    matlab.ui.control.Table
        ParametersTab                 matlab.ui.container.Tab
        UIParametersTable             matlab.ui.control.Table
        CloseButton                   matlab.ui.control.Button
        ProcessselecteddataButton     matlab.ui.control.Button
        SelectprocessorDropDown       matlab.ui.control.DropDown
        SelectprocessorDropDownLabel  matlab.ui.control.Label
    end


    properties (Access = private)
        Data % Description
         isRefreshing logical = false
    paramSpec = struct();        % metadata params (type, choices)
    paramTableData = table();    % table affich e dans UIParametersTable
    paramSelectedKey = '';
    paramEditorControls = gobjects(0);

    % cache param + channels
    paramChannelsSig = '';
    processParam = struct();
    end

    methods (Access = private)

   function procObj = getSelectedProcessor(app)
    procObj = [];
    list = app.SelectprocessorDropDown.Items;
    idx = find(matches(list, app.SelectprocessorDropDown.Value), 1);
    if isempty(idx), return; end
    if idx > numel(app.Data.varstr), return; end

    varName = app.Data.varstr{idx};
    if strcmp(varName, '__provided_process__') && isfield(app.Data,'providedProcessObj')
        procObj = app.Data.providedProcessObj;
    else
        procObj = evalin('base', varName);
    end

    % ---- normalize processFun to package if available ----
    if isprop(procObj,'processFun') && ~isempty(procObj.processFun)
        procObj.processFun = normalizeProcessFun(app, procObj.processFun);
    end
end

function f = normalizeProcessFun(app, f)
    if isempty(f), return; end
    if contains(f,'.'), return; end
    if ~isempty(which([f '.process']))
        f = [f '.process'];
    end
end

function updateProcessorLabel(app)
    if ~isprop(app,'Label') || isempty(app.Label) || ~isvalid(app.Label)
        return;
    end

    procObj = getSelectedProcessor(app);
    if isempty(procObj)
        app.Label.Text = 'Processor: (none)';
        return;
    end

    procName = '';
    if isprop(procObj,'processFun') && ~isempty(procObj.processFun)
        procName = char(string(procObj.processFun));
        if endsWith(procName, '.process')
            procName = extractBefore(procName, '.process');
        end
    end

    if isprop(procObj,'strid') && ~isempty(procObj.strid)
        app.Label.Text = sprintf('type: %s',procName);
    else
        app.Label.Text = sprintf('type : --');
    end
end


function loadProcessorParamsFromSelection(app)
    procObj = getSelectedProcessor(app);
    if isempty(procObj), return; end

    % --- old params (priority) ---
    oldParam = [];
    if isprop(procObj,'processArg') && ~isempty(procObj.processArg)
        oldParam = procObj.processArg;
    elseif isprop(procObj,'runProfiles') && isfield(procObj.runProfiles,'process') && ...
            isfield(procObj.runProfiles.process,'params') && ...
            ~isempty(procObj.runProfiles.process.params)
        oldParam = procObj.runProfiles.process.params;
    end

    % --- new defaults (based on channels) ---
    ctx = struct();
    ctx.channels = collectChannelsFromSelection(app);
    newParam = buildProcessorParam(app, procObj.processFun, ctx.channels);

    % --- merge ---
    if isempty(oldParam)
        app.processParam = newParam;
    else
        app.processParam = mergeParamStruct(app, oldParam, newParam);
    end

    % force rebuild
    app.paramChannelsSig = '';
end




        function [spec, t] = buildParamTable(app, param)
% buildParamTable  Build UIParametersTable data + spec from param struct.

    tp = param;
    if isfield(tp,'tip')
        tp = rmfield(tp,'tip');
    end

    keys = fieldnames(tp);
    n = numel(keys);

    Param = cell(n,1);
    Value = cell(n,1);

    spec = struct();

    for i = 1:n
        k = keys{i};
        v = tp.(k);

        Param{i} = k;

        [vStr, vType, choices] = inferParamValueType(app, k, v);
        Value{i} = vStr;

        spec.(k) = struct('type', vType, 'choices', {choices});
        spec.(k).raw = v;
    end

    t = table(Param, Value);
end

function param = paramStructFromTable(app)
    param = struct();
    d = app.UIParametersTable.Data;
    if isempty(d), return; end

    if istable(d)
        keys = d.Param;
        vals = d.Value;
    else
        keys = d(:,1);
        vals = d(:,2);
    end

    for i = 1:numel(keys)
        key = keys{i};
        val = vals{i};

        if isprop(app,'paramSpec') && isfield(app.paramSpec,key)
            t = app.paramSpec.(key).type;
            switch t
                case 'logical'
                    if islogical(val), v = val;
                    else, v = strcmpi(string(val),'true'); end
                case 'numeric'
                    if isnumeric(val), v = val;
                    else, v = str2num(char(string(val))); %#ok<ST2NM>
                    end
                otherwise
                    v = char(string(val));
            end
        else
            if isnumeric(val) || islogical(val)
                v = val;
            else
                v = char(string(val));
            end
        end
        param.(key) = v;
    end
end



function [vStr, vType, choices] = inferParamValueType(app, key, v) %#ok<INUSD>
% inferParamValueType  Return display string + type + dropdown choices.

    choices = {};

    % Special case: runtime params
    if strcmpi(key,'ExecutionEnvironment')
        vType = 'enum';
        choices = {'CPU','GPU'};
        if iscell(v)
            vStr = v{end};
        else
            vStr = char(string(v));
        end
        return;
    end

    if strcmpi(key,'Parallel')
        vType = 'logical';
        vStr = logicalToString(app, logical(v));
        return;
    end

    % dropdown style : cell array of strings, last = selected
    if iscell(v) && ~isempty(v) && all(cellfun(@ischar, v))
        vType = 'enum';
        choices = v;
        vStr = v{end};
        return;
    end

    if islogical(v) && isscalar(v)
        vType = 'logical';
        vStr = logicalToString(app,v);
        return;
    end

    if isnumeric(v)
        vType = 'numeric';
        vStr = numericToString(app,v);
        return;
    end

    if ischar(v) || isstring(v)
        vType = 'string';
        vStr = char(string(v));
        return;
    end

    if iscell(v)
        vType = 'cell';
        vStr = sprintf('{%d cell}', numel(v));
        return;
    end

    vType = class(v);
    vStr = '[unsupported]';
end

function s = numericToString(app, v) %#ok<INUSD>
% numericToString  No brackets, space-separated for vectors.
    if isempty(v)
        s = '';
        return;
    end
    if isscalar(v)
        s = num2str(v);
        return;
    end
    v = v(:).';
    s = strtrim(sprintf('%g ', v));
end

function s = logicalToString(app, v) %#ok<INUSD>
% logicalToString  true/false without brackets.
    if v
        s = 'true';
    else
        s = 'false';
    end
end

function lockProcessorDropdown(app, procObj)
    % Lock dropdown to a specific processor (if provided)
    if isempty(procObj)
        app.SelectprocessorDropDown.Enable = 'on';
        return;
    end

    idx = [];

    % 1) Try exact object match via varstr
    for k = 1:numel(app.Data.varstr)
        try
            obj = evalin('base', app.Data.varstr{k});
            if isequal(obj, procObj)
                idx = k; break;
            end
        catch
        end
    end

    % 2) Fallback: match by strid in dropdown labels
    if isempty(idx) && isprop(procObj,'strid') && ~isempty(procObj.strid)
        items = app.SelectprocessorDropDown.Items;
        if isstring(items), items = cellstr(items); end
        pix = find(contains(items, procObj.strid), 1);
        if ~isempty(pix), idx = pix; end
    end

    if ~isempty(idx)
        items = app.SelectprocessorDropDown.Items;
        if isstring(items), items = cellstr(items); end
        app.SelectprocessorDropDown.Value = items{idx};
        app.SelectprocessorDropDown.Enable = 'off';
    end
end

function applyRuntimeOptions(app, sel)
    if isfield(sel,'processAllFrames')
        app.ProcessallframesoveridesframestableselectionCheckBox.Value = logical(sel.processAllFrames);
    end
    if isfield(sel,'parallel')
        % store in params table if you keep Parallel there
        app.processParam.Parallel = logical(sel.parallel);
    end
    if isfield(sel,'executionEnvironment')
        app.processParam.ExecutionEnvironment = sel.executionEnvironment;
    end
    refreshParamTable(app);
end




function restoreSelectionFromRunProfile(app, procObj)
    if isempty(procObj) || ~isprop(procObj,'runProfiles') || isempty(procObj.runProfiles)
        return;
    end
    if ~isfield(procObj.runProfiles,'selection') || isempty(procObj.runProfiles.selection)
        return;
    end

    sel = procObj.runProfiles.selection;
    data = app.UIROITable.Data;
    if isempty(data)
        return;
    end

    % Reset selection
    data(:,1) = {false};

    % 1) If stored row indices are valid, use them directly
    if isfield(sel,'selectedRows') && ~isempty(sel.selectedRows)
        rows = sel.selectedRows;
        rows = rows(rows>=1 & rows<=size(data,1));
        if ~isempty(rows)
            data(rows,1) = {true};
            % Restore ROI array + frames for those rows
            if isfield(sel,'roiArray'), data(rows,5) = sel.roiArray(1:numel(rows)); end
            if isfield(sel,'frames'),   data(rows,6) = sel.frames(1:numel(rows));   end
            app.UIROITable.Data = data;
            applyRuntimeOptions(app, sel);
            return;
        end
    end

    % 2) Fallback: match by Project + Name + SourceType
    if isfield(sel,'project') && isfield(sel,'name') && isfield(sel,'sourceType')
        for i = 1:size(data,1)
            for k = 1:numel(sel.project)
                if strcmp(string(data{i,2}), string(sel.project{k})) && ...
                   strcmp(string(data{i,4}), string(sel.name{k})) && ...
                   strcmp(string(data{i,3}), string(sel.sourceType{k}))
                    data{i,1} = true;
                    if isfield(sel,'roiArray'), data{i,5} = sel.roiArray{k}; end
                    if isfield(sel,'frames'),   data{i,6} = sel.frames{k};   end
                end
            end
        end
    end

    app.UIROITable.Data = data;
    applyRuntimeOptions(app, sel);
end


function showParamEditor(app, key)
% showParamEditor  Create dynamic editor on the right side of the table.

    % delete existing editors
    if ~isempty(app.paramEditorControls)
        delete(app.paramEditorControls(ishandle(app.paramEditorControls)));
    end
    app.paramEditorControls = gobjects(0);

    if ~isfield(app.paramSpec, key)
        return;
    end

    spec = app.paramSpec.(key);
    type = spec.type;
    choices = {};
    if isfield(spec,'choices'), choices = spec.choices; end

    % Layout area (adjust if needed)
    baseX = 480; baseY = 260; w = 260; h = 200;

    lbl = uilabel(app.ParametersTab, ...
        'Text', key, 'Position',[baseX baseY+h-20 w 20], ...
        'FontWeight','bold');
    app.paramEditorControls(end+1) = lbl;

    row = find(strcmp(app.UIParametersTable.Data.Param, key), 1);
    curValStr = '';
    if ~isempty(row)
        curValStr = app.UIParametersTable.Data.Value{row};
    end

    % ---- special case: RGB_ ----
    if startsWith(key,'RGB_')
        % text field
        ef = uieditfield(app.ParametersTab, 'text', ...
            'Position',[baseX baseY+120 w-70 22], ...
            'Value', curValStr, ...
            'ValueChangedFcn', @(src,evt)applyParamEdit(app, key, src.Value));
        app.paramEditorControls(end+1) = ef;

        % color preview
        preview = uipanel(app.ParametersTab, ...
            'Position',[baseX+w-60 baseY+120 20 20], ...
            'BorderType','line');
        app.paramEditorControls(end+1) = preview;

        % parse current value into rgb
        rgb = parseRGB(app, curValStr);
        if ~isempty(rgb)
            preview.BackgroundColor = rgb;
        end

        % pick button
        btn = uibutton(app.ParametersTab, ...
            'Text','Pick', ...
            'Position',[baseX+w-35 baseY+120 45 22], ...
            'ButtonPushedFcn', @(src,evt)pickRGB());
        app.paramEditorControls(end+1) = btn;

        return;
    end

    % ---- normal controls ----
    switch type
        case 'enum'
            if isempty(choices)
                choices = {curValStr};
            end
            dd = uidropdown(app.ParametersTab, ...
                'Items', choices, ...
                'Position',[baseX baseY+120 w 22], ...
                'Value', curValStr, ...
                'ValueChangedFcn', @(src,evt)applyParamEdit(app, key, src.Value));
            app.paramEditorControls(end+1) = dd;

        case 'logical'
            cb = uicheckbox(app.ParametersTab, ...
                'Position',[baseX baseY+120 w 22], ...
                'Value', strcmpi(curValStr,'true'), ...
                'ValueChangedFcn', @(src,evt)applyParamEdit(app, key, logical(src.Value)));
            app.paramEditorControls(end+1) = cb;

        case 'numeric'
            ef = uieditfield(app.ParametersTab, 'text', ...
                'Position',[baseX baseY+120 w 22], ...
                'Value', curValStr, ...
                'ValueChangedFcn', @(src,evt)applyParamEdit(app, key, src.Value));
            app.paramEditorControls(end+1) = ef;

        otherwise
            ta = uitextarea(app.ParametersTab, ...
                'Position',[baseX baseY+60 w 60], ...
                'Value', curValStr, ...
                'ValueChangedFcn', @(src,evt)applyParamEdit(app, key, strjoin(src.Value, ' ')));
            app.paramEditorControls(end+1) = ta;
    end


    % ---- local helper for pick ----
    function pickRGB()
        c = uisetcolor;
        if numel(c) == 3
            s = sprintf('%g %g %g', c);
            applyParamEdit(app, key, s);
            if isvalid(preview)
                preview.BackgroundColor = c;
            end
        end
    end
end


function rgb = parseRGB(app, s) %#ok<INUSD>
% parseRGB  Accept "1 0 0" or "[1 0 0]"
    rgb = [];
    if isempty(s), return; end
    try
        v = str2num(char(string(s))); %#ok<ST2NM>
      
        if isnumeric(v) && numel(v) == 3
            v = v(:).';
            rgb = v;
        end
    catch
        rgb = [];
    end
end



function out = updateDropdownValue(app, dropCell, selected) %#ok<INUSD>
% updateDropdownValue  Update last entry of dropdown cell array.
    if ~iscell(dropCell)
        out = dropCell;
        return;
    end
    out = dropCell;
    out{end} = char(string(selected));
end

function rows = getActiveRows(app)
% Prefer explicit selection; fallback to checked rows.
    rows = [];
    try
        sel = app.UIROITable.Selection;
        if ~isempty(sel)
            rows = unique(sel(:,1));
        end
    catch
    end

    if isempty(rows) && ~isempty(app.UIROITable.Data)
        rows = find(cellfun(@(x) x==1, app.UIROITable.Data(:,1)));
    end
end

function channels = collectChannelsFromSelection(app)
% Collect channels from selected ROIs without loading heavy data.
    channels = {};
    rows = getActiveRows(app);
    if isempty(rows)
        return;
    end

    for r = rows(:)'
        if r > numel(app.Data.storedobj), continue; end
        obj = app.Data.storedobj(r).data;
        if isempty(obj) || ~isprop(obj,'roi'), continue; end

        roiStr = app.UIROITable.Data{r,5};
        roiIdx = str2num(roiStr); %#ok<ST2NM>
        if isempty(roiIdx)
            roiIdx = 1:numel(obj.roi);
        end
        roiIdx = roiIdx(roiIdx>=1 & roiIdx<=numel(obj.roi));

        for k = roiIdx(:)'
            if k > numel(obj.roi), continue; end
            try
                dispStruct = obj.roi(k).display;
                if isfield(dispStruct,'channel')
                    ch = dispStruct.channel;
                    if ischar(ch), ch = {ch}; end
                    channels = [channels, ch(:)']; %#ok<AGROW>
                end
            catch
            end
        end
    end

    channels = unique(channels, 'stable');
end

function param = buildProcessorParam(app, processFun, channels)
% Build param struct using setparam if possible.
    param = struct();

    ctx = struct();
    ctx.channels = channels;
    ctx.useProvidedChannels = true;

    setparamFun = '';
    if ~isempty(processFun) && ~contains(processFun,'.')
        if ~isempty(which([processFun '.setparam']))
            setparamFun = [processFun '.setparam'];
        else
            setparamFun = processFun;
        end
    elseif contains(processFun,'.process')
        setparamFun = strrep(processFun,'.process','.setparam');
    end


    if ~isempty(setparamFun)
        try
            param = feval(setparamFun, ctx);
        catch
            try
                param = feval(setparamFun);
            catch
                param = struct();
            end
        end
    end

    % inject runtime params into table
    if ~isfield(param,'Parallel'), param.Parallel = false; end
    if ~isfield(param,'ExecutionEnvironment'), param.ExecutionEnvironment = 'CPU'; end
end

function merged = mergeParamStruct(app, oldParam, newParam)
% Keep previous values when possible; preserve enum choices.
    merged = newParam;
    if isempty(oldParam), return; end

    fn = fieldnames(merged);
    for i = 1:numel(fn)
        k = fn{i};
        if ~isfield(oldParam,k), continue; end

        newVal = merged.(k);
        oldVal = oldParam.(k);

        % enum case (new is cell choices)
        if iscell(newVal) && all(cellfun(@ischar,newVal))
            if iscell(oldVal) && ~isempty(oldVal)
                sel = oldVal{end};
            else
                sel = char(string(oldVal));
            end
            if any(strcmp(newVal, sel))
                newVal{end} = sel;
                merged.(k) = newVal;
            end
        else
            merged.(k) = oldVal;
        end
    end
end



% function procObj = getSelectedProcessor(app)
%     procObj = [];
%     list = app.SelectprocessorDropDown.Items;
%     idx = find(matches(list, app.SelectprocessorDropDown.Value), 1);
%     if isempty(idx), return; end
%     if idx > numel(app.Data.varstr), return; end
%     varName = app.Data.varstr{idx};
%     procObj = evalin('base', varName);
% end

function refreshParamTable(app)
    if app.isRefreshing, return; end
    app.isRefreshing = true;

    procObj = getSelectedProcessor(app);
    if isempty(procObj)
        app.isRefreshing = false;
        return;
    end

    channels = collectChannelsFromSelection(app);
    sig = strjoin(channels, '|');

    % Initial fill only if empty
    if isempty(app.processParam)
        app.processParam = buildProcessorParam(app, procObj.processFun, channels);
        app.paramChannelsSig = sig;
    else
        % only rebuild when channels changed
        if ~strcmp(app.paramChannelsSig, sig)
            newParam = buildProcessorParam(app, procObj.processFun, channels);
           app.processParam = mergeParamStruct(app, app.processParam, newParam);

            app.paramChannelsSig = sig;
        end
    end

    [app.paramSpec, app.paramTableData] = buildParamTable(app, app.processParam);
    app.UIParametersTable.Data = app.paramTableData;
    app.UIParametersTable.ColumnName = {'Parameters','Value'};
    app.UIParametersTable.ColumnEditable = [false true];

    if height(app.paramTableData) > 0
        app.paramSelectedKey = app.paramTableData.Param{1};
        app.UIParametersTable.Selection = [1 1];
        showParamEditor(app, app.paramSelectedKey);
    end

    app.isRefreshing = false;
end


function setRefreshingFalse(app)
    app.isRefreshing = false;
end



function applyParamEdit(app, key, newVal)
% applyParamEdit  Update param struct + table row.

    if ~isfield(app.processParam, key), return; end
    spec = app.paramSpec.(key);

    switch spec.type
        case 'enum'
            if iscell(app.processParam.(key))
                app.processParam.(key) = updateDropdownValue(app, app.processParam.(key), newVal);
                newValStr = char(string(newVal));
            else
                app.processParam.(key) = char(string(newVal));
                newValStr = char(string(newVal));
            end

        case 'logical'
            app.processParam.(key) = logical(newVal);
            newValStr = logicalToString(app, app.processParam.(key));

        case 'numeric'
            try
                v = str2num(char(string(newVal))); %#ok<ST2NM>
                if isempty(v), v = app.processParam.(key); end
            catch
                v = app.processParam.(key);
            end
            app.processParam.(key) = v;
            newValStr = numericToString(app,v);

        otherwise
            app.processParam.(key) = newVal;
            newValStr = char(string(newVal));
    end

    row = find(strcmp(app.UIParametersTable.Data.Param, key), 1);
    if ~isempty(row)
        app.UIParametersTable.Data.Value{row} = newValStr;
    end
end


        function updateTable(app)

            shallowObj=app.Data.shallowObj;

            app.Data.storedobj=[];
            %app.Data.storedobj.data=[];

            procSel = getSelectedProcessor(app);
            if isempty(procSel)
                return;
            end

            projectlist= app.Data.tobeclassified_varstr;
            projectnames=app.Data.tobeclassified_projectstr;

            classif = procSel; %#ok<NASGU>

            % classiid=find(matches(app.SelectclassfiermodelDropDown.Items,str));

            %  shallowObj=app.Data.shallowObj;

            t=app.UIROITable;
            t.ColumnName={'Select','Project','ROIs from Position or Classifier','Name','Select ROIs array','Select frames'};
            t.ColumnEditable=[true false false false true true];

            %             str2={};
            %
            %             for i=1:numel(projectlist)
            %
            %               shallowObj=evalin('base',projectlist{i});
            %
            %              if numel(shallowObj.fov(i).roi(1).id)
            %                  tmp= shallowObj.fov(i).roi(1).display.channel;
            %                  str2=unique([tmp,str2],'stable');
            %              end
            %             end

            t.ColumnFormat={[] [] [] [] [] [] []};

            Data={};

            cc=1;
            for i=1:numel(projectlist)
                strcha='';

                if numel(projectlist{i})==0
                    continue
                end

                obj= evalin('base',projectlist{i});

                if isa(obj,'process')

                    if numel(app.Data.specificobj)
                        if app.Data.specificobj~= obj % subselect specific classi
                            continue
                        end
                    end

                else % check that fov belongs to the right project
                    if numel(projectnames{i})
                    projn=evalin('base',projectnames{i});
                    if app.Data.specificobj~=projn
                        continue
                    end
                    end 
                end

                app.Data.storedobj(cc).data=obj;

                %                 if numel(obj.roi(1).id)
                %                     cha=obj.roi(1).display.channel;
                %                   % txt= shallowObj.processing.classification(1).channelName;
                %
                %                   if ischar(classif.channelName)
                %                      classif.channelName={classif.channelName};
                %                   end
                %
                %                   for j=1:numel(classif.channelName)
                %
                %                   query= classif.channelName{j};
                %
                %                    if numel(find(matches(cha,query)))
                %
                %                        strcha=[strcha classif.channelName{j} ','];
                %                    else
                %                        aa=obj.roi(1).display.channel;
                %                        if ischar(aa)
                %                           strcha=[aa ','];
                %                        else
                %                           strcha=[obj.roi(1).display.channel{1},','];
                %
                %                        end
                %
                %                    end
                %                   end
                %                 end
                % strcha

                %strcha=strcha(1:end-1);

                fra=[];

                if isfield(obj,'frames')
                    if numel(obj.frames)>1
                        pix=find(matches(obj.channel,strcha));
                        if numel(pix)
                            fra=obj.frames(pix);
                        else
                            fra=obj.frames(1);
                        end
                    end
                end

                if isempty(fra)
    fra = 1; % fallback safe
    if numel(obj.roi) > 0
        r1 = obj.roi(1);

        % avoid load if ID/path missing
        if ~isempty(r1.id) && isprop(r1,'path') && ~isempty(r1.path)
            h5 = fullfile(r1.path, ['im_' r1.id '.h5']);
            mat = fullfile(r1.path, ['im_' r1.id '.mat']);
            if exist(h5,'file') || exist(mat,'file')
                try
                    r1.load;
                    if ~isempty(r1.image)
                        fra = size(r1.image,4);
                    end
                catch
                    fra = 1;
                end
            end
        end
    end
end

                roilist=['1:' num2str(numel(obj.roi))];

                %                if isa(obj,'classi')
                %                    id=obj.strid;
                %                    typ='Classifier';
                %
                %                    if app.Data.validation==1 % this is a classfier to validate, hence take only the validation ROIs
                %
                %                          roilist=num2str(setxor(1:numel(obj.roi),obj.trainingset));
                %                    end
                %                end
                if isa(obj,'fov')
                    id=obj.id;
                    typ='FOV';
                end
                if isa(obj,'classi')
                    id=obj.strid;
                    typ='Classifier';
                end


                Data(cc,:)={true projectnames{i} typ id roilist ['1:' num2str(fra)]};
                cc=cc+1;
            end

            t.Data=Data;


            %             % HERE update function for display
            %
            %             str= app.SelectprocessorDropDown.Value;
            %             shallowObj=app.Data.shallowObj;
            %             t=app.UIROITable;
            %             t.ColumnName={'Select','Position or Classifier ROIs','Name','Select ROIs array','Select frames'};
            %             t.ColumnEditable=[true false false true true];
            %
            %             t.ColumnFormat={[] [] [] [] []};
            %
            %             Data={};
            %
            %             for i=1:numel(shallowObj.fov)
            %
            %                 if numel(shallowObj.fov(i).frames)>1
            %                     % pix=find(matches(shallowObj.fov(i).channel,strcha));
            %                     fra=shallowObj.fov(i).frames(1);
            %                 else
            %                     fra=shallowObj.fov(i).frames;
            %                 end
            %
            %                 Data(i,:)={true num2str(i) shallowObj.fov(i).id ['1:' num2str(numel(shallowObj.fov(i).roi))] ['1:' num2str(fra)]};
            %             end
            %
            %             t.Data=Data;
        end

    end


    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app, shallowObj, processObj)

     if nargin < 2, shallowObj = []; end
    if nargin < 3, processObj = []; end

    app.Data.shallowObj = shallowObj;
    app.Data.specificobj = [];

    if isa(processObj,'process')
        app.Data.specificobj = processObj;
        app.Data.processObj  = processObj;   % garder le handle
    end

    app.Data.st = gatherVariablesFromWorkspace;

    s = app.Data.st;

    % --- init vars (manquaient, d'o  l'erreur) ---
    cc = 1;
    cd = 1;
    store = [];
    displaystr = {};
    varstr = {};
    tobeclassified_varstr = {};
    tobeclassified_projectstr = {};

    app.Data.specificobj = [];

    % ---- Projects ----
    for i=1:numel(s.Project)

        proj = s.Project{i};

        if shallowObj==evalin('base',proj)
            app.Data.specificobj = shallowObj;
        end

        % FOVs
        for k=1:numel(s.Projectpos{i})
            tmp = evalin('base',[proj '.fov(' num2str(k) ')']);
            if numel(tmp.roi)>0 && numel(tmp.roi(1).id)>0
                tobeclassified_varstr{cd} = [proj '.fov(' num2str(k) ')'];
                tobeclassified_projectstr{cd} = proj;
                if isempty(store), store=numel(tmp.roi); end
                cd = cd + 1;
            end
        end

        % Classifiers
        for k=1:numel(s.Projectclassi{i})
            tmp = evalin('base',[proj '.processing.classification(' num2str(k) ')']);
            tobeclassified_varstr{cd} = [proj '.processing.classification(' num2str(k) ')'];
            tobeclassified_projectstr{cd} = proj;
            if isempty(store), store=numel(tmp.roi); end
            cd = cd + 1;
        end

        % Processors
        for k=1:numel(s.Projectprocessor{i})
            tmp = evalin('base',[proj '.processing.processor(' num2str(k) ')']);

            if shallowObj==tmp
                app.Data.specificobj = shallowObj;
            else
                if isa(shallowObj,'process')
                    continue
                end
            end

            varstr{cc} = [proj '.processing.processor(' num2str(k) ')'];
            displaystr{cc} = [proj '  //  ' s.Projectprocessor{i}{k}];
            cc = cc + 1;
        end
    end

    % ---- standalone classifier vars ----
    for i=1:numel(s.Classifier)
        clas = s.Classifier{i};
        tmp = evalin('base',clas);

        varstr{cc} = clas;
        tobeclassified_varstr{cd} = clas;
        tobeclassified_projectstr{cd} = '';
        if isempty(store), store=numel(tmp.roi); end
        cd = cd + 1;
        cc = cc + 1;
    end

    % ---- ensure provided processor is selectable even if not attached to a project ----
    if isa(processObj,'process')
        hit = false;
        for ii = 1:numel(varstr)
            if strcmp(varstr{ii}, '__provided_process__')
                hit = true;
                break;
            end
            if contains(displaystr{ii}, processObj.strid)
                hit = true;
                break;
            end
        end
        if ~hit
            varstr{end+1} = '__provided_process__';
            displaystr{end+1} = ['Pipeline // ' char(string(processObj.strid))];
            app.Data.providedProcessObj = processObj;
        end
    end

    % ---- assign dropdown ----
app.SelectprocessorDropDown.Items = displaystr';
    app.Data.varstr = varstr;
    app.Data.tobeclassified_varstr = tobeclassified_varstr;
    app.Data.tobeclassified_projectstr = tobeclassified_projectstr;
    app.Data.displaystr = displaystr;

    % --- pr selection du processor si fourni
    if isa(processObj,'process')
        idx = find(contains(displaystr, processObj.strid), 1);
        if ~isempty(idx)
            app.SelectprocessorDropDown.Value = displaystr{idx};
        end
    end

      % --- NEW: lock dropdown if procObj passed ---
    lockProcessorDropdown(app, processObj);


updateTable(app);
loadProcessorParamsFromSelection(app);
refreshParamTable(app);

procObj = getSelectedProcessor(app);
restoreSelectionFromRunProfile(app, procObj);

updateProcessorLabel(app);



        end

        % Button pushed function: CloseButton
        function CloseButtonPushed(app, event)
            delete(app)
        end

        % Close request function: ProcessdataUIFigure
        function ProcessdataUIFigureCloseRequest(app, event)
            delete(app)

        end

        % Value changed function: SelectprocessorDropDown
        function SelectprocessorDropDownValueChanged(app, event)
      updateProcessorLabel(app);
            updateTable(app);
loadProcessorParamsFromSelection(app);
refreshParamTable(app);

procObj = getSelectedProcessor(app);
restoreSelectionFromRunProfile(app, procObj);
        end

        % Button pushed function: ProcessselecteddataButton
        function ProcessselecteddataButtonPushed(app, event)
    classif = getSelectedProcessor(app);
    if isempty(classif)
        uialert(app.ProcessdataUIFigure,'No processor selected.','Error','Icon','error');
        return;
    end

    data=app.UIROITable.Data;
    selpos=find(cellfun(@(x) x==1,data(:,1)));

    frames={};
    roiobj=[];
    cc=1;

    for i=1:numel(selpos)
        obj=app.Data.storedobj(selpos(i)).data;
        tmp=str2num(data{selpos(i),5}); %#ok<ST2NM>

        if sum(ismember(tmp,1:numel(obj.roi)))==numel(tmp)
            roiobj=[roiobj obj.roi(tmp)];

            for j=1:numel(tmp)
                if app.ProcessallframesoveridesframestableselectionCheckBox.Value==1
                    frames{cc}=-1;
                else
                    frames{cc}=str2num(data{selpos(i),6}); %#ok<ST2NM>
                end
                cc=cc+1;
            end
        end
    end

    d = uiprogressdlg(app.ProcessdataUIFigure,'Title','Please Wait...', ...
        'Message','Starting data processing...');
    d.Value=0.01;

    % ---- extract runtime params from table ----
    procParam = app.processParam;
    runParallel = false;
    runEnv = 'CPU';

    if isfield(procParam,'Parallel')
        runParallel = logical(procParam.Parallel);
        procParam = rmfield(procParam,'Parallel');
    end
    if isfield(procParam,'ExecutionEnvironment')
        if iscell(procParam.ExecutionEnvironment)
            runEnv = procParam.ExecutionEnvironment{end};
        else
            runEnv = char(string(procParam.ExecutionEnvironment));
        end
        procParam = rmfield(procParam,'ExecutionEnvironment');
    end

    % ---- store processor params ----
    classif.processArg = procParam;

    % ---- ctx (pipeline compatible) ----
    ctx = struct();
    ctx.frames = frames;             % cell array, same as processData
    ctx.outputName = classif.strid;  % standard
    ctx.params = procParam;          % FULL param snapshot (pipeline/log)

    % optional: push channel selection if you have it
    % ctx.channels = collectChannelsFromSelection(app);

    arg = {'Progress',d,'Frames',frames,'Ctx',ctx};

    if runParallel
        arg=[arg {'Parallel'}];
    end
    if strcmpi(runEnv,'GPU')
        arg=[arg {'GPU'}];
    end

    tic
    processData(classif, roiobj, arg{:});
    toc
        end

        % Button pushed function: SelectallButton
        function SelectallButtonPushed(app, event)
            data=app.UIROITable.Data;
    data(:,1)={true};
    app.UIROITable.Data=data;
    refreshParamTable(app);
        end

        % Button pushed function: DeselectallButton
        function DeselectallButtonPushed(app, event)
             data=app.UIROITable.Data;
    data(:,1)={false};
    app.UIROITable.Data=data;
    refreshParamTable(app);
        end

        % Button pushed function: ApplyselectedsettingstoallButton
        function ApplyselectedsettingstoallButtonPushed(app, event)
          data=app.UIROITable.Data;

    selectedfovs=find(cellfun(@(x) x==1,data(:,1)));
    if numel(selectedfovs)==0
        uialert(app.ProcessdataUIFigure,'No position was selected','Error');
    end

    for i=1:size(data,1)
        if i~=selectedfovs(1)
            data(i,4:end)=data(selectedfovs(1),4:end);
        end
    end

    app.UIROITable.Data=data;
    refreshParamTable(app);
        end

        % Cell selection callback: UIParametersTable
        function UIParametersTableCellSelection(app, event)
          % UIParametersTableCellSelection  Select a param row -> show editor.
    if isempty(event.Indices), return; end
    row = event.Indices(1);
    key = app.UIParametersTable.Data.Param{row};
    app.paramSelectedKey = key;
    showParamEditor(app, key);
        end

        % Cell edit callback: UIParametersTable
        function UIParametersTableCellEdit(app, event)
      % UIParametersTableCellEdit  Edit directly in table -> update param.
    row = event.Indices(1);
    key = app.UIParametersTable.Data.Param{row};
    newValStr = event.NewData;
    applyParamEdit(app, key, newValStr);
            
        end

        % Selection changed function: UIROITable
        function UIROITableSelectionChanged(app, event)
            % Update params based on current ROI selection
    refreshParamTable(app);
        end

        % Cell edit callback: UIROITable
        function UIROITableCellEdit(app, event)
           
           col = event.Indices(2);
    if col == 1 || col == 5
        refreshParamTable(app);
    end
        end

        % Button pushed function: SaveparametersButton
        function SaveparametersButtonPushed(app, event)
     
              procObj = getSelectedProcessor(app);
    if isempty(procObj)
        uialert(app.ProcessdataUIFigure, ...
            'No processor selected.', 'Error', 'Icon','error');
        return;
    end

    % --- get current param struct ---
    param = [];
    if isprop(app,'processParam') && ~isempty(app.processParam)
        param = app.processParam;
    elseif isfield(app.Data,'processParam') && ~isempty(app.Data.processParam)
        param = app.Data.processParam;
    else
        % fallback: rebuild from table
        param = paramStructFromTable(app);
    end

    if isempty(param)
        uialert(app.ProcessdataUIFigure, ...
            'No parameters to save.', 'Warning', 'Icon','warning');
        return;
    end

    % update processor object (handle -> persists)
    procObj.processArg = param;

% ---- save selection snapshot (run profile) ----
data = app.UIROITable.Data;
sel  = find(cellfun(@(x) x==1, data(:,1)));

selection = struct();
selection.timestamp = datetime('now');
selection.processAllFrames = app.ProcessallframesoveridesframestableselectionCheckBox.Value;

if ~isempty(sel)
    selection.project    = data(sel,2);
    selection.sourceType = data(sel,3);
    selection.name       = data(sel,4);
    selection.roiArray   = data(sel,5);
    selection.frames     = data(sel,6);
    selection.selectedRows = sel;
else
    selection.project = {};
    selection.sourceType = {};
    selection.name = {};
    selection.roiArray = {};
    selection.frames = {};
    selection.selectedRows = [];
end

if ~isprop(procObj,'runProfiles') || isempty(procObj.runProfiles)
    procObj.runProfiles = struct('process', struct(), 'selection', struct());
end
procObj.runProfiles.process   = struct('params', param);
procObj.runProfiles.selection = selection;



    % save to disk
    try
        processSave(procObj);
        uialert(app.ProcessdataUIFigure, ...
            'Processor parameters saved.', 'Success', 'Icon','success');
    catch ME
        uialert(app.ProcessdataUIFigure, ...
            ['Save failed: ' ME.message], 'Error', 'Icon','error');
    end

        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create ProcessdataUIFigure and hide until all components are created
            app.ProcessdataUIFigure = uifigure('Visible', 'off');
            app.ProcessdataUIFigure.Position = [100 100 797 680];
            app.ProcessdataUIFigure.Name = 'Process data';
            app.ProcessdataUIFigure.CloseRequestFcn = createCallbackFcn(app, @ProcessdataUIFigureCloseRequest, true);

            % Create SelectprocessorDropDownLabel
            app.SelectprocessorDropDownLabel = uilabel(app.ProcessdataUIFigure);
            app.SelectprocessorDropDownLabel.HorizontalAlignment = 'right';
            app.SelectprocessorDropDownLabel.Position = [23 640 102 22];
            app.SelectprocessorDropDownLabel.Text = 'Select processor: ';

            % Create SelectprocessorDropDown
            app.SelectprocessorDropDown = uidropdown(app.ProcessdataUIFigure);
            app.SelectprocessorDropDown.ValueChangedFcn = createCallbackFcn(app, @SelectprocessorDropDownValueChanged, true);
            app.SelectprocessorDropDown.Position = [201 640 249 22];

            % Create ProcessselecteddataButton
            app.ProcessselecteddataButton = uibutton(app.ProcessdataUIFigure, 'push');
            app.ProcessselecteddataButton.ButtonPushedFcn = createCallbackFcn(app, @ProcessselecteddataButtonPushed, true);
            app.ProcessselecteddataButton.Position = [23 25 269 34];
            app.ProcessselecteddataButton.Text = 'Process selected data';

            % Create CloseButton
            app.CloseButton = uibutton(app.ProcessdataUIFigure, 'push');
            app.CloseButton.ButtonPushedFcn = createCallbackFcn(app, @CloseButtonPushed, true);
            app.CloseButton.Position = [516 25 269 34];
            app.CloseButton.Text = 'Close';

            % Create TabGroup
            app.TabGroup = uitabgroup(app.ProcessdataUIFigure);
            app.TabGroup.Position = [19 73 767 550];

            % Create ROIsTab
            app.ROIsTab = uitab(app.TabGroup);
            app.ROIsTab.Title = 'ROIs';

            % Create UIROITable
            app.UIROITable = uitable(app.ROIsTab);
            app.UIROITable.ColumnName = {'Column 1'; 'Column 2'; 'Column 3'; 'Column 4'};
            app.UIROITable.RowName = {};
            app.UIROITable.CellEditCallback = createCallbackFcn(app, @UIROITableCellEdit, true);
            app.UIROITable.SelectionChangedFcn = createCallbackFcn(app, @UIROITableSelectionChanged, true);
            app.UIROITable.Position = [15 17 737 461];

            % Create SelectallButton
            app.SelectallButton = uibutton(app.ROIsTab, 'push');
            app.SelectallButton.ButtonPushedFcn = createCallbackFcn(app, @SelectallButtonPushed, true);
            app.SelectallButton.Position = [12 495 100 22];
            app.SelectallButton.Text = 'Select all';

            % Create DeselectallButton
            app.DeselectallButton = uibutton(app.ROIsTab, 'push');
            app.DeselectallButton.ButtonPushedFcn = createCallbackFcn(app, @DeselectallButtonPushed, true);
            app.DeselectallButton.Position = [124 495 100 22];
            app.DeselectallButton.Text = 'Deselect all';

            % Create ApplyselectedsettingstoallButton
            app.ApplyselectedsettingstoallButton = uibutton(app.ROIsTab, 'push');
            app.ApplyselectedsettingstoallButton.ButtonPushedFcn = createCallbackFcn(app, @ApplyselectedsettingstoallButtonPushed, true);
            app.ApplyselectedsettingstoallButton.Position = [235 495 167 22];
            app.ApplyselectedsettingstoallButton.Text = 'Apply selected settings to all';

            % Create ProcessallframesoveridesframestableselectionCheckBox
            app.ProcessallframesoveridesframestableselectionCheckBox = uicheckbox(app.ROIsTab);
            app.ProcessallframesoveridesframestableselectionCheckBox.Text = 'Process all frames (overides frames table selection)';
            app.ProcessallframesoveridesframestableselectionCheckBox.Position = [423 494 302 22];

            % Create ParametersTab
            app.ParametersTab = uitab(app.TabGroup);
            app.ParametersTab.Title = 'Parameters';

            % Create UIParametersTable
            app.UIParametersTable = uitable(app.ParametersTab);
            app.UIParametersTable.ColumnName = {'Parameters'; 'Value'};
            app.UIParametersTable.RowName = {};
            app.UIParametersTable.ColumnEditable = [false true];
            app.UIParametersTable.CellEditCallback = createCallbackFcn(app, @UIParametersTableCellEdit, true);
            app.UIParametersTable.CellSelectionCallback = createCallbackFcn(app, @UIParametersTableCellSelection, true);
            app.UIParametersTable.Position = [12 17 448 500];

            % Create SaveparametersButton
            app.SaveparametersButton = uibutton(app.ProcessdataUIFigure, 'push');
            app.SaveparametersButton.ButtonPushedFcn = createCallbackFcn(app, @SaveparametersButtonPushed, true);
            app.SaveparametersButton.Position = [321 25 167 34];
            app.SaveparametersButton.Text = 'Save parameters';

            % Create Label
            app.Label = uilabel(app.ProcessdataUIFigure);
            app.Label.FontWeight = 'bold';
            app.Label.Position = [479 640 284 22];

            % Show the figure after all components are created
            app.ProcessdataUIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = processDataGUI(varargin)

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.ProcessdataUIFigure)

            % Execute the startup function
            runStartupFcn(app, @(app)startupFcn(app, varargin{:}))

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.ProcessdataUIFigure)
        end
    end
end