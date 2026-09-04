classdef classifierGUI < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        ClassifierUIFigure              matlab.ui.Figure
        FileMenu                        matlab.ui.container.Menu
        SaveclassifierMenu              matlab.ui.container.Menu
        RestorepreviousclassifierMenu   matlab.ui.container.Menu
        ClassifierMenu                  matlab.ui.container.Menu
        FormattrainingsetMenu           matlab.ui.container.Menu
        TrainClassifierMenu             matlab.ui.container.Menu
        ValidateclassifierusingtestsetMenu  matlab.ui.container.Menu
        DisplaystatisticsMenu           matlab.ui.container.Menu
        LoadclassifierMenu              matlab.ui.container.Menu
        CheckstatusMenu                 matlab.ui.container.Menu
        SaveclassifierButton            matlab.ui.control.Button
        ClassifierisloadedinworksapcememoryLabel  matlab.ui.control.Label
        ParametersaresavedLabel         matlab.ui.control.Label
        StatusLoad                      matlab.ui.control.Lamp
        StatusSaved                     matlab.ui.control.Lamp
        TabGroup                        matlab.ui.container.TabGroup
        ClassifierPropertiesTab         matlab.ui.container.Tab
        Label_5                         matlab.ui.control.Label
        Label_4                         matlab.ui.control.Label
        Label_3                         matlab.ui.control.Label
        OutputandstatisticsPanel        matlab.ui.container.Panel
        AnnotatedROIswithvalidationdataEditField  matlab.ui.control.EditField
        AnnotatedROIswithvalidationdataEditFieldLabel  matlab.ui.control.Label
        NumberofannotatedROIsEditField  matlab.ui.control.EditField
        NumberofannotatedROIsEditFieldLabel  matlab.ui.control.Label
        displayROIsusedforvalidationButton  matlab.ui.control.Button
        ValidateclassifierButton        matlab.ui.control.Button
        DisplayclassifierstatisticsButton  matlab.ui.control.Button
        TrainingvalidationsetPanel      matlab.ui.container.Panel
        DisplayaugmentedimagesButton    matlab.ui.control.Button
        TrainClassifierButton           matlab.ui.control.Button
        AvailableformattedtrainingsetLabel  matlab.ui.control.Label
        SettrainingparametersButton     matlab.ui.control.Button
        DisplaysampleimagesButton       matlab.ui.control.Button
        formatLabel                     matlab.ui.control.Label
        NumberROIS_2                    matlab.ui.control.EditField
        NumberofROIsusedfortrainingvalidationLabel_2  matlab.ui.control.Label
        ManageROIsformattrainingsetButton  matlab.ui.control.Button
        NumberROIS                      matlab.ui.control.EditField
        NumberofROIsusedfortrainingvalidationLabel  matlab.ui.control.Label
        ClassifierquickinfoPanel        matlab.ui.container.Panel
        UsercommentsEditField           matlab.ui.control.EditField
        UsercommentsEditFieldLabel      matlab.ui.control.Label
        SetclassfierparametersButton    matlab.ui.control.Button
        OpenfolderButton                matlab.ui.control.Button
        BackupButton                    matlab.ui.control.Button
        RestoreButton                   matlab.ui.control.Button
        backupversionsEditField         matlab.ui.control.EditField
        backupversionsEditFieldLabel    matlab.ui.control.Label
        ClassesEditField                matlab.ui.control.EditField
        ClassesEditFieldLabel           matlab.ui.control.Label
        TypeEditField                   matlab.ui.control.EditField
        TypeEditFieldLabel              matlab.ui.control.Label
        PathEditField                   matlab.ui.control.EditField
        PathEditFieldLabel              matlab.ui.control.Label
        SetclassifierparametersTab      matlab.ui.container.Tab
        UsercommentsEditField_2         matlab.ui.control.EditField
        UsercommentsEditField_2Label    matlab.ui.control.Label
        DeSelectButton                  matlab.ui.control.Button
        SelectButton                    matlab.ui.control.Button
        ChannelListBoxSel               matlab.ui.control.ListBox
        SelectedchannelsasclassificationinputLabel  matlab.ui.control.Label
        ChannelListBox                  matlab.ui.control.ListBox
        AvailablechannelstakenfromtrainingdatasetROIsLabel  matlab.ui.control.Label
        PostprocessingparametersPanel   matlab.ui.container.Panel
        SizepixelEditField              matlab.ui.control.NumericEditField
        SizepixelEditFieldLabel         matlab.ui.control.Label
        FilteroutsmallobjectsCheckBox   matlab.ui.control.CheckBox
        ThresholdingButtonGroup         matlab.ui.container.ButtonGroup
        ValueEditField                  matlab.ui.control.EditField
        ValueEditFieldLabel             matlab.ui.control.Label
        MaximumprobabilityButton        matlab.ui.control.RadioButton
        AdaptivethresholdOtsumethodButton  matlab.ui.control.RadioButton
        FixedthresholdButton            matlab.ui.control.RadioButton
        WatershedCheckBox               matlab.ui.control.CheckBox
        PostprocessingDropDown          matlab.ui.control.DropDown
        PostprocessingDropDownLabel     matlab.ui.control.Label
        ClassiDetailsLabel              matlab.ui.control.Label
        PostprocessingcustomfunctionhandleEditField  matlab.ui.control.EditField
        PostprocessingcustomfunctionhandleEditFieldLabel  matlab.ui.control.Label
        SpaceseparatedclassnamesEditField  matlab.ui.control.EditField
        SpaceseparatedclassnamesLabel   matlab.ui.control.Label
        TypeDropDown                    matlab.ui.control.DropDown
        TypeLabel                       matlab.ui.control.Label
        SettrainingparametersTab        matlab.ui.container.Tab
        UITableParam                    matlab.ui.control.Table
        SettrainingandvalidationsetROIsTab  matlab.ui.container.Tab
        AnnotationFilterDropDown        matlab.ui.control.DropDown
        AnnotationFilterDropDownLabel   matlab.ui.control.Label
        RefreshAnnotationStatusButton   matlab.ui.control.Button
        StartBlankGTButton              matlab.ui.control.Button
        GenerateDraftButton             matlab.ui.control.Button
        BoundsnoticeLabel               matlab.ui.control.Label
        SetboundsselectionrulesButton   matlab.ui.control.Button
        FormattrainingsetfortrainingButton  matlab.ui.control.Button
        ShuffleROIsfractionEditField    matlab.ui.control.EditField
        ShuffleROIsfractionEditFieldLabel  matlab.ui.control.Label
        SelectROIsEditField             matlab.ui.control.EditField
        SelectROIsEditFieldLabel        matlab.ui.control.Label
        removeselectedROIButton         matlab.ui.control.Button
        DeselectallButton               matlab.ui.control.Button
        SelectallButton                 matlab.ui.control.Button
        AnnotateselectedROIButton       matlab.ui.control.Button
        ImportROIsButton                matlab.ui.control.Button
        UITableData                     matlab.ui.control.Table
    end


    properties (Access = private)
        callingApp % Description
    isRefreshing logical = false
    paramSpec = struct();        % metadata sur les params (type, choices, tip)
     paramTableData = table();    % table affichée dans UITableParam
paramSelectedKey = '';
paramEditorControls = gobjects(0);
trainingScopeTextArea = gobjects(0);
    end

    properties (Access = public)
        Data % Description % must be public to shar info with other apps
    end

    methods (Access = private)


      
function [spec, t] = buildParamTable(app, trainingParam, classiObj)
% buildParamTable  Build UITable data + spec from trainingParam.

    if nargin < 3, classiObj = []; end

    tp = trainingParam;
    rawKeys = fieldnames(tp);
    rawTips = {};
    if isfield(tp,'tip') && iscell(tp.tip)
        rawTips = tp.tip;
        while numel(rawTips)==1 && iscell(rawTips{1}), rawTips=rawTips{1}; end
    end
    if isfield(tp,'tip')
        tp = rmfield(tp,'tip');
    end

    spec = struct();
    bindingSpec = struct([]);
    bindingCatalog = struct();
    parameterDisplaySpec = struct([]);
    parameterDisplayPolicy = struct('showUnspecified',true);
    try
        bindingSpec = classifierBinding.trainingSpec(classiObj);
        if ~isempty(bindingSpec)
            bindingCatalog = classifierBinding.catalog(classiObj);
        end
    catch ME
        warning('classifierGUI:TrainingBindings', ...
            'Could not build typed training bindings: %s', ME.message);
        bindingSpec = struct([]);
    end
    try
        [parameterDisplaySpec,parameterDisplayPolicy] = ...
            classifierBinding.trainingParameterSpec(classiObj);
    catch ME
        warning('classifierGUI:TrainingParameterSpec', ...
            'Could not build training-parameter labels: %s',ME.message);
    end

    keys = fieldnames(tp);
    if ~parameterDisplayPolicy.showUnspecified
        visibleKeys = {parameterDisplaySpec.param};
        if ~isempty(bindingSpec)
            visibleKeys = [visibleKeys {bindingSpec.param}]; %#ok<AGROW>
        end
        visibleKeys = unique(visibleKeys,'stable');
        visibleKeys = visibleKeys(ismember(visibleKeys,keys));
        keys = reshape(visibleKeys,[],1);
    end
    if ~isempty(bindingSpec)
        virtualKeys = {bindingSpec.param};
        keys = [keys; virtualKeys(~ismember(virtualKeys, keys)).'];
    end
    n = numel(keys);

    Param = cell(n,1);
    Label = cell(n,1);
    Value = cell(n,1);
    Type  = cell(n,1);
    Group = cell(n,1);

    for i = 1:n
        k = keys{i};
        bindingIndex = [];
        if ~isempty(bindingSpec)
            bindingIndex = find(strcmp({bindingSpec.param}, k), 1);
        end
        if ~isempty(bindingIndex)
            v = classifierBinding.value(classiObj, bindingSpec(bindingIndex));
        elseif isfield(tp, k)
            v = tp.(k);
        else
            v = [];
        end

        Param{i} = k;
        Label{i} = humanizeParameterName(app,k);
        displayIndex = [];
        if ~isempty(parameterDisplaySpec)
            displayIndex = find(strcmp({parameterDisplaySpec.param},k),1);
        end
        fallbackTip = '';
        rawIndex = find(strcmp(rawKeys,k),1);
        if ~isempty(rawIndex) && rawIndex <= numel(rawTips)
            try fallbackTip = char(string(rawTips{rawIndex})); catch, end
        end

        % group by prefix
        if startsWith(k,'CNN_')
            Group{i} = 'CNN';
        elseif startsWith(k,'LSTM_')
            Group{i} = 'LSTM';
        elseif startsWith(k,'Format_')
            Group{i} = 'Format';
        else
            Group{i} = 'General';
        end

        [vStr, vType, choices] = inferParamValueType(app, v);
        choiceLabels = choices;
        if ~isempty(bindingIndex)
            binding = bindingSpec(bindingIndex);
            vStr = bindingValueToString(app, v);
            if ~binding.editable
                vType = 'binding_fixed';
                choices = {};
                choiceLabels = {};
            else
                resolved = classifierBinding.choices(binding, bindingCatalog, v);
                choices = resolved.values;
                choiceLabels = resolved.labels;
                if strcmpi(binding.cardinality, 'many')
                    vType = 'binding_multi';
                else
                    vType = 'binding';
                end
            end
            Group{i} = binding.group;
            Label{i} = char(string(binding.label));
            if isempty(vStr)
                if any(strcmp(choices, '<none>'))
                    vStr = '<none>';
                elseif any(strcmp(choices, '<unconfigured>'))
                    vStr = '<unconfigured>';
                elseif any(strcmp(choices, '<auto>'))
                    vStr = '<auto>';
                end
            end
        end
        if ~isempty(displayIndex)
            meta = parameterDisplaySpec(displayIndex);
            if ~isempty(meta.label), Label{i} = meta.label; end
            if ~isempty(meta.group), Group{i} = meta.group; end
            if ~isempty(meta.choiceLabels) && ...
                    numel(meta.choiceLabels)==numel(choices)
                choiceLabels = meta.choiceLabels;
            end
        end
        Value{i} = vStr;
        Type{i}  = vType;

        spec.(k) = struct('type', vType, 'choices', {choices});
        spec.(k).choiceLabels = choiceLabels;
        spec.(k).raw = v; % keep raw
        spec.(k).label = Label{i};
        spec.(k).tip = fallbackTip;
        if ~isempty(displayIndex) && ~isempty(parameterDisplaySpec(displayIndex).tip)
            spec.(k).tip = parameterDisplaySpec(displayIndex).tip;
        end
        if ~isempty(bindingIndex)
            spec.(k).binding = bindingSpec(bindingIndex);
        end
    end

    t = table(Label, Value, Group, Type, Param);
    groupOrder = { ...
        'Training scope', ...
        'Shared > Dataset', ...
        'Shared > Validation', ...
        'Tracking head > Input', ...
        'Tracking head > Ground truth', ...
        'Tracking head > GT quality', ...
        'Tracking head > Candidates', ...
        'Tracking head > Initialization', ...
        'Tracking head > Loss weights', ...
        'Tracking head > Optimization', ...
        'Mother/NULL head > Input', ...
        'Mother/NULL head > Ground truth', ...
        'Mother/NULL head > Architecture', ...
        'Mother/NULL head > Temporal context', ...
        'Mother/NULL head > Optimization', ...
        'Shared > Runtime', ...
        'Output bundle', ...
        'Data bindings', 'Format', 'General', 'CNN', 'LSTM'};
    groupRank = (numel(groupOrder)+1) * ones(height(t),1);
    for groupIndex = 1:numel(groupOrder)
        groupRank(strcmp(t.Group,groupOrder{groupIndex})) = groupIndex;
    end
    [~,order] = sortrows([groupRank (1:height(t)).'],[1 2]);
    t = t(order, :);
end

function label = humanizeParameterName(app,key) %#ok<INUSD>
% Human-readable fallback; the exact internal key stays in the hidden column.
    label = strrep(char(string(key)),'_',' ');
    label = regexprep(label,'([a-z0-9])([A-Z])','$1 $2');
    label = strtrim(label);
    if ~isempty(label), label(1)=upper(label(1)); end
end


function [vStr, vType, choices] = inferParamValueType(app, v) %#ok<INUSD>
% inferParamValueType  Return display string + type + dropdown choices.

    choices = {};

    % Several historical defaults used {{choices}}. Normalize them at the
    % renderer boundary as well as in classifierBinding.normalizeClassifier
    % so a read-only/struct-backed classifier never displays "{1 cell}".
    while iscell(v) && numel(v) == 1 && iscell(v{1})
        v = v{1};
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

function textValue = bindingValueToString(app, value) %#ok<INUSD>
    values = bindingValueList(app, value);
    textValue = strjoin(values, '; ');
end

function values = bindingValueList(app, raw) %#ok<INUSD>
    if isempty(raw)
        values = {};
    elseif ischar(raw)
        values = {raw};
    elseif isstring(raw)
        values = cellstr(raw(:).');
    elseif iscell(raw)
        values = {};
        for i = 1:numel(raw)
            values = [values bindingValueList(app, raw{i})]; %#ok<AGROW>
        end
    else
        values = {char(string(raw))};
    end
    values = values(~cellfun(@(x)isempty(strtrim(x)), values));
    values = unique(values, 'stable');
end

function msg = localGuiErrorMessage(app, ME) %#ok<INUSD>
% localGuiErrorMessage  Compact error text suitable for uialert.
    parts = {};
    if ~isempty(ME.identifier)
        parts{end+1} = ['Identifier: ' ME.identifier]; %#ok<AGROW>
    end
    if ~isempty(ME.message)
        parts{end+1} = ME.message; %#ok<AGROW>
    end

    causeList = ME.cause;
    for k = 1:min(numel(causeList), 2)
        if ~isempty(causeList{k}.message)
            parts{end+1} = ['Cause: ' causeList{k}.message]; %#ok<AGROW>
        end
    end

    if isempty(parts)
        msg = 'Training failed, but MATLAB did not provide an error message.';
    else
        msg = strjoin(parts, sprintf('\n\n'));
    end

    maxLen = 1800;
    if strlength(string(msg)) > maxLen
        msg = char(extractBefore(string(msg), maxLen));
        msg = [msg newline newline '...'];
    end
end

function tf = isSam31Classifier(app, classiObj) %#ok<INUSD>
    tf = false;
    try
        if isprop(classiObj, 'classifierPkg') && strcmpi(char(string(classiObj.classifierPkg)), 'sam31')
            tf = true;
            return;
        end
    catch
    end
    try
        if isprop(classiObj, 'trainingFun') && startsWith(char(string(classiObj.trainingFun)), 'sam31.', 'IgnoreCase', true)
            tf = true;
            return;
        end
    catch
    end
    try
        if isprop(classiObj, 'classifyFun') && startsWith(char(string(classiObj.classifyFun)), 'sam31.', 'IgnoreCase', true)
            tf = true;
        end
    catch
    end
end

function tf = hasTypedTrainingBindings(app, classiObj) %#ok<INUSD>
    tf = false;
    try
        tf = ~isempty(classifierBinding.trainingSpec(classiObj));
    catch
    end
end

function tf = usesLegacyTransferLearning(app, classiObj) %#ok<INUSD>
    pkg = '';
    try, pkg = lower(strtrim(char(string(classiObj.classifierPkg)))); catch, end
    % Only these MATLAB network packages use classi.version as an ImageNet
    % transfer-learning selector. Other packages own their artifact/model
    % initialization and must not receive a synthetic ImageNet parameter.
    tf = isempty(pkg) || any(strcmp(pkg, { ...
        'cnn','cnn_lstm','deeplab_pixel_classification'}));
end

function setLegacyChannelSelectorVisible(app, visible)
    state = localOnOff(app, visible);
    components = { ...
        app.ChannelListBox, ...
        app.ChannelListBoxSel, ...
        app.SelectButton, ...
        app.DeSelectButton, ...
        app.AvailablechannelstakenfromtrainingdatasetROIsLabel, ...
        app.SelectedchannelsasclassificationinputLabel};
    for i = 1:numel(components)
        try, components{i}.Visible = state; catch, end
    end
end

function refreshTypedTrainingBindingChoices(app)
    classiObj = app.Data.classiObj;
    if ~hasTypedTrainingBindings(app, classiObj)
        return;
    end
    selectedKey = app.paramSelectedKey;
    [app.paramSpec, app.paramTableData] = buildParamTable( ...
        app, classiObj.trainingParam, classiObj);
    app.UITableParam.Data = app.paramTableData;
    row = find(strcmp(app.paramTableData.Param, selectedKey), 1);
    if isempty(row) && height(app.paramTableData) > 0
        row = 1;
        selectedKey = app.paramTableData.Param{1};
    end
    if ~isempty(row)
        app.paramSelectedKey = selectedKey;
        app.UITableParam.Selection = [row 1];
        showParamEditor(app, selectedKey);
    end
end




function UITableParamCellSelection(app, event)
% UITableParamCellSelection  Select a param row -> show editor.

    if isempty(event.Indices), return; end
    row = event.Indices(1);
    key = app.UITableParam.Data.Param{row};
    app.paramSelectedKey = key;
    showParamEditor(app, key);
end


function UITableParamCellEdit(app, event)
% UITableParamCellEdit  Edit directly in table -> update trainingParam.

    row = event.Indices(1);
    key = app.UITableParam.Data.Param{row};
    newValStr = event.NewData;

    if isfield(app.paramSpec, key) && ...
            startsWith(app.paramSpec.(key).type, 'binding')
        if strcmp(app.paramSpec.(key).type, 'binding_fixed')
            app.UITableParam.Data.Value{row} = event.PreviousData;
            showParamEditor(app, key);
            return;
        end
        allowed = app.paramSpec.(key).choices;
        candidate = char(string(newValStr));
        if strcmp(app.paramSpec.(key).type, 'binding_multi') || ...
                ~any(strcmp(allowed, candidate))
            app.UITableParam.Data.Value{row} = event.PreviousData;
            showParamEditor(app, key);
            uialert(app.ClassifierUIFigure, ...
                'Select typed data bindings from the dropdown editor.', ...
                'Invalid data binding');
            return;
        end
    end

    applyParamEdit(app, key, newValStr);
end

function showParamEditor(app, key)
% showParamEditor  Create dynamic editor on the right side of the table.

    % delete existing editors
    if ~isempty(app.paramEditorControls)
        delete(app.paramEditorControls(ishandle(app.paramEditorControls)));
    end
    app.paramEditorControls = gobjects(0);
    app.trainingScopeTextArea = gobjects(0);

    if ~isfield(app.paramSpec, key)
        return;
    end

    spec = app.paramSpec.(key);
    type = spec.type;
    choices = {};
    if isfield(spec,'choices'), choices = spec.choices; end

    % Layout area (adjust as needed)
    baseX = 710; baseY = 260; w = 370; h = 250;

    labelText = key;
    if isfield(spec,'label') && ~isempty(spec.label), labelText=spec.label; end
    lbl = uilabel(app.SettrainingparametersTab, ...
        'Text', labelText, 'Position',[baseX baseY+h-20 w 20], ...
        'FontWeight','bold');
    if isfield(spec,'tip') && ~isempty(spec.tip)
        lbl.Tooltip = char(string(spec.tip));
    end
    if isfield(spec, 'binding')
        bindingLabel = char(string(spec.binding.label));
        if ~isempty(bindingLabel), lbl.Text = bindingLabel; end
        lbl.Tooltip = char(string(spec.binding.tip));
    end
    app.paramEditorControls(end+1) = lbl;

    scopeBox = uitextarea(app.SettrainingparametersTab, ...
        'Position',[baseX 55 w 170], ...
        'Editable','off', ...
        'WordWrap','on', ...
        'Value',trainingScopeLines(app,app.Data.classiObj));
    scopeBox.Tooltip = ['Explicit ownership contract: data quality, trainable ' ...
        'sub-module, frozen neighbours, split, and prediction output.'];
    app.paramEditorControls(end+1) = scopeBox;
    app.trainingScopeTextArea = scopeBox;
    refreshTrainingScopePanel(app);

    % current value (string from table)
    row = find(strcmp(app.UITableParam.Data.Param, key), 1);
    curValStr = '';
    if ~isempty(row)
        curValStr = app.UITableParam.Data.Value{row};
    end

    switch type
        case 'binding'
            choiceValues = choices;
            choiceLabels = choiceValues;
            if isfield(spec, 'choiceLabels') && ...
                    numel(spec.choiceLabels) == numel(choiceValues)
                choiceLabels = spec.choiceLabels;
            end
            currentValue = curValStr;
            if isempty(currentValue)
                if any(strcmp(choiceValues, '<none>'))
                    currentValue = '<none>';
                elseif any(strcmp(choiceValues, '<unconfigured>'))
                    currentValue = '<unconfigured>';
                elseif any(strcmp(choiceValues, '<auto>'))
                    currentValue = '<auto>';
                end
            end
            if ~any(strcmp(choiceValues, currentValue))
                choiceValues{end+1} = currentValue;
                choiceLabels{end+1} = currentValue;
            end
            dd = uidropdown(app.SettrainingparametersTab, ...
                'Items', choiceLabels, ...
                'ItemsData', choiceValues, ...
                'Position',[baseX baseY+160 w 22], ...
                'Value', currentValue, ...
                'ValueChangedFcn', @(src,evt)applyParamEdit(app, key, src.Value));
            if isfield(spec, 'binding')
                dd.Tooltip = char(string(spec.binding.tip));
            end
            app.paramEditorControls(end+1) = dd;

        case 'binding_multi'
            choiceValues = choices;
            choiceLabels = choiceValues;
            if isfield(spec, 'choiceLabels') && ...
                    numel(spec.choiceLabels) == numel(choiceValues)
                choiceLabels = spec.choiceLabels;
            end
            selectedValues = bindingValueList(app, spec.raw);
            selectedValues = selectedValues(ismember(selectedValues, choiceValues));
            if isempty(selectedValues)
                if any(strcmp(choiceValues, '<unconfigured>'))
                    selectedValues = {'<unconfigured>'};
                elseif any(strcmp(choiceValues, '<none>'))
                    selectedValues = {'<none>'};
                elseif any(strcmp(choiceValues, '<auto>'))
                    selectedValues = {'<auto>'};
                end
            end
            lb = uilistbox(app.SettrainingparametersTab, ...
                'Items', choiceLabels, ...
                'ItemsData', choiceValues, ...
                'Multiselect', 'on', ...
                'Position',[baseX baseY+70 w 112], ...
                'Value', selectedValues, ...
                'ValueChangedFcn', @(src,evt)applyParamEdit(app, key, src.Value));
            if isfield(spec, 'binding')
                lb.Tooltip = char(string(spec.binding.tip));
            end
            app.paramEditorControls(end+1) = lb;

        case 'binding_fixed'
            ef = uieditfield(app.SettrainingparametersTab, 'text', ...
                'Position',[baseX baseY+160 w 22], ...
                'Value', curValStr, 'Editable', 'off');
            if isfield(spec, 'binding')
                ef.Tooltip = char(string(spec.binding.tip));
            end
            app.paramEditorControls(end+1) = ef;

        case 'enum'
            if isempty(choices)
                choices = {curValStr};
            end
            choiceValues = choices;
            choiceLabels = choiceValues;
            if isfield(spec, 'choiceLabels') && ...
                    numel(spec.choiceLabels) == numel(choiceValues)
                choiceLabels = spec.choiceLabels;
            end
            [choiceValues, keep] = unique(choiceValues, 'stable');
            choiceLabels = choiceLabels(keep);
            if ~any(strcmp(choiceValues, curValStr))
                choiceValues{end+1} = curValStr;
                choiceLabels{end+1} = curValStr;
            end
            dd = uidropdown(app.SettrainingparametersTab, ...
                'Items', choiceLabels, ...
                'ItemsData', choiceValues, ...
                'Position',[baseX baseY+160 w 22], ...
                'Value', curValStr, ...
                'ValueChangedFcn', @(src,evt)applyParamEdit(app, key, src.Value));
            app.paramEditorControls(end+1) = dd;

        case 'logical'
            cb = uicheckbox(app.SettrainingparametersTab, ...
                'Position',[baseX baseY+160 w 22], ...
                'Value', strcmpi(curValStr,'true'), ...
                'ValueChangedFcn', @(src,evt)applyParamEdit(app, key, logical(src.Value)));
            app.paramEditorControls(end+1) = cb;

        case 'numeric'
            ef = uieditfield(app.SettrainingparametersTab, 'text', ...
                'Position',[baseX baseY+160 w 22], ...
                'Value', curValStr, ...
                'ValueChangedFcn', @(src,evt)applyParamEdit(app, key, src.Value));
            app.paramEditorControls(end+1) = ef;

        otherwise
            ta = uitextarea(app.SettrainingparametersTab, ...
                'Position',[baseX baseY+90 w 80], ...
                'Value', curValStr, ...
                'ValueChangedFcn', @(src,evt)applyParamEdit(app, key, strjoin(src.Value, ' ')));
            app.paramEditorControls(end+1) = ta;
    end
end

function out = updateDropdownValue(app, dropCell, selected) %#ok<INUSD>
% updateDropdownValue  Update last entry of dropdown cell array.

    while iscell(dropCell) && numel(dropCell) == 1 && iscell(dropCell{1})
        dropCell = dropCell{1};
    end
    if ~iscell(dropCell)
        out = dropCell;
        return;
    end
    out = dropCell;
    out{end} = char(string(selected));
end

function applyParamEdit(app, key, newVal)
% applyParamEdit  Update trainingParam + table row.

    c = app.Data.classiObj;
    if ~isfield(app.paramSpec, key), return; end
    spec = app.paramSpec.(key);
    if ~isfield(c.trainingParam, key) && ~isfield(spec, 'binding')
        return;
    end

    switch spec.type
        case {'binding','binding_multi'}
            classifierBinding.applyValue(c, spec.binding, newVal);
            stored = classifierBinding.value(c, spec.binding);
            newValStr = bindingValueToString(app, stored);
            if isempty(newValStr)
                values = bindingValueList(app, newVal);
                if any(strcmp(values, '<auto>'))
                    newValStr = '<auto>';
                elseif any(strcmp(values, '<none>'))
                    newValStr = '<none>';
                else
                    newValStr = '<unconfigured>';
                end
            end

        case 'binding_fixed'
            return;

        case 'enum'
            c.trainingParam.(key) = updateDropdownValue(app, c.trainingParam.(key), newVal);
            newValStr = char(string(newVal));

        case 'logical'
            c.trainingParam.(key) = logical(newVal);
            newValStr = logicalToString(app, c.trainingParam.(key));

        case 'numeric'
            try
                v = str2num(char(string(newVal))); %#ok<ST2NM>
                if isempty(v), v = c.trainingParam.(key); end
            catch
                v = c.trainingParam.(key);
            end
            c.trainingParam.(key) = v;
            newValStr = numericToString(app,v);

        otherwise
            c.trainingParam.(key) = newVal;
            newValStr = char(string(newVal));
    end

    % update table
    row = find(strcmp(app.UITableParam.Data.Param, key), 1);
    if ~isempty(row)
        app.UITableParam.Data.Value{row} = newValStr;
    end

    app.Data.classiObj = c;
    refreshTrainingScopePanel(app);
    checkStatus(app,false);
end


function classlist = loadClasslist(app)
% loadClasslist  Build classlist from engine/classification/+* packages.
% Fallback to classlist.mat if needed.

    classlist = {};

    % Try from shallowNew.m -> repo root
    sh = which('shallowNew.m');
    if ~isempty(sh)
        ioDir   = fileparts(sh);                 % .../structure/io
        rootDir = fileparts(fileparts(ioDir));   % repo root
        classRoot = fullfile(rootDir,'engine','classification');
    else
        classRoot = '';
    end

    % Fallback: where classlist.mat is found
    if isempty(classRoot) || ~isfolder(classRoot)
        cl = which('classlist.mat');
        if ~isempty(cl)
            classRoot = fileparts(cl);
        end
    end

    if isempty(classRoot) || ~isfolder(classRoot)
        return;
    end

    % Primary: package scan
    classlist = buildPackageClasslist(app, classRoot);

    % Fallback: legacy classlist.mat
    if isempty(classlist)
        clFile = fullfile(classRoot,'classlist.mat');
        if isfile(clFile)
            S = load(clFile,'classlist');
            if isfield(S,'classlist') && ~isempty(S.classlist)
                classlist = S.classlist;
                if istable(classlist)
                    classlist = table2cell(classlist);
                end
            end
        end
    end
end


function classlist = buildPackageClasslist(app, rootPath) %#ok<INUSD>
    if ~exist(rootPath, 'dir')
        classlist = {};
        return;
    end

    pkgDirs = dir(fullfile(rootPath, '+*'));
    pkgDirs = pkgDirs(arrayfun(@(d) ...
        isfile(fullfile(d.folder, d.name, 'train.m')) && ...
        isfile(fullfile(d.folder, d.name, 'classify.m')), pkgDirs));
    if isempty(pkgDirs)
        classlist = {};
        return;
    end

    % sort for stable UI
    [~, idx] = sort({pkgDirs.name});
    pkgDirs = pkgDirs(idx);

    n = numel(pkgDirs);
    classlist = cell(n,6);
    for k = 1:n
        pkgName = erase(pkgDirs(k).name, '+');  % e.g. "cnn_lstm"
        classlist{k,1} = k;                         % id
        classlist{k,2} = pkgName;                   % short name (dropdown)
        classlist{k,3} = [pkgName ' classifier'];   % long descr
        classlist{k,4} = inferPkgCategory(app,pkgName); % category
        classlist{k,5} = {[pkgName '.train']};      % training fun
        classlist{k,6} = {[pkgName '.classify']};   % classify fun
    end
end

function cat = inferPkgCategory(app,pkgName)
    cat = '';
    try
        specFun = [pkgName '.executionSpec'];
        if ~isempty(which(specFun))
            spec = feval(specFun);
            if isstruct(spec) && isfield(spec, 'category') && ~isempty(spec.category)
                cat = char(string(spec.category));
                return;
            end
        end
    catch
    end

    switch lower(pkgName)
        case 'cnn_lstm'
            cat = 'LSTM';
        case 'cellposesam'
            cat = 'Pixel';
        otherwise
            cat = 'Image';
    end
end


   
function classlist = appendPackageClassifiers(app, classlist, rootPath)
    % Append classifiers defined as MATLAB packages +pkgname (with train/classify)

    if ~exist(rootPath, 'dir')
        return;
    end

    pkgDirs = dir(fullfile(rootPath, '+*'));
    pkgDirs = pkgDirs(arrayfun(@(d) ...
        isfile(fullfile(d.folder, d.name, 'train.m')) && ...
        isfile(fullfile(d.folder, d.name, 'classify.m')), pkgDirs));
    if isempty(pkgDirs)
        return;
    end

    % ---- Extract existing train/classify columns (table OR cell) ----
    if istable(classlist)
        existingTrainCol    = classlist{:,5};
        existingClassifyCol = classlist{:,6};
    else
        existingTrainCol    = classlist(:,5);
        existingClassifyCol = classlist(:,6);
    end

    existingTrain    = normalizeFunCol(existingTrainCol);
    existingClassify = normalizeFunCol(existingClassifyCol);

    for k = 1:numel(pkgDirs)
        pkgName = erase(pkgDirs(k).name, '+');  % e.g. "cnn_lstm"
        trainFun = [pkgName '.train'];
        classifyFun = [pkgName '.classify'];

        if any(strcmp(existingTrain, trainFun)) || any(strcmp(existingClassify, classifyFun))
            continue;
        end

        % Create a minimal entry (refine labels later)
        newId = size(classlist,1) + 1;
        descr = pkgName;
        longdescr = [pkgName ' classifier'];
        category = inferPkgCategory(app,pkgName);

        if istable(classlist)
            newRow = {newId, descr, longdescr, category, {trainFun}, {classifyFun}};
            classlist = [classlist; cell2table(newRow, 'VariableNames', classlist.Properties.VariableNames)];
        else
            classlist(end+1,:) = { ...
                newId, ...
                descr, ...
                longdescr, ...
                category, ...
                {trainFun}, ...
                {classifyFun} ...
            };
        end

        existingTrain{end+1} = trainFun;
        existingClassify{end+1} = classifyFun;
    end

    function out = normalizeFunCol(col)
        % Accept table/array/cell and return cellstr of function names
        if istable(col)
            col = col{:,:};
        end

        % If it’s a string/cell/char array, wrap to cell
        if ischar(col) || isstring(col)
            col = cellstr(col);
        end

        out = col;
        if ~iscell(out)
            out = num2cell(out);
        end

        for i = 1:numel(out)
            v = out{i};
            if iscell(v)
                if isempty(v)
                    out{i} = '';
                else
                    out{i} = v{1};
                end
            elseif isa(v, 'function_handle')
                out{i} = func2str(v);
            elseif isstring(v)
                if isscalar(v)
                    out{i} = char(v);
                else
                    out{i} = char(v(1));
                end
            elseif isempty(v)
                out{i} = '';
            else
                % assume char or scalar; leave as-is
            end
        end
    end
end

function lines = trainingScopeLines(app,classiObj) %#ok<INUSD>
% Render package-owned training/data provenance.
scope=classifierBinding.trainingScopeSpec(classiObj);
lines={['TRAINING SCOPE - ' scope.displayName]};
if ~isempty(scope.objective),lines{end+1}=['Objective: ' scope.objective];end %#ok<AGROW>
if ~isempty(scope.trainedComponents)
    lines{end+1}=['CHANGES: ' strjoin(scope.trainedComponents,', ')]; %#ok<AGROW>
end
if ~isempty(scope.frozenComponents)
    lines{end+1}=['FROZEN: ' strjoin(scope.frozenComponents,', ')]; %#ok<AGROW>
end
bindings=classifierBinding.trainingSpec(classiObj);
if ~isempty(bindings),lines{end+1}='DATA USED:';end %#ok<AGROW>
for i=1:numel(bindings)
    value='';
    try value=scopeValueText(app,classifierBinding.value(classiObj,bindings(i)));catch,end
    if isempty(value),value='<not configured>';end
    label=regexprep(char(string(bindings(i).label)),'^\[[^\]]+\]\s*','');
    quality=upper(char(string(bindings(i).quality)));
    lines{end+1}=sprintf('[%s] %s = %s',quality,label,value); %#ok<AGROW>
end
if ~isempty(scope.datasetUnit),lines{end+1}=['Dataset: ' scope.datasetUnit];end %#ok<AGROW>
output=resolvedScopeOutput(app,classiObj,scope);
if ~isempty(output)
    lines{end+1}=sprintf('[%s] %s = %s', ...
        upper(scope.outputQuality),scope.outputSemantic,output); %#ok<AGROW>
end
if ~isempty(scope.canonicalOutput)&&~strcmp(output,scope.canonicalOutput)
    lines{end+1}=['Canonical new output: ' scope.canonicalOutput]; %#ok<AGROW>
end
if ~isempty(scope.splitPolicy),lines{end+1}=['Split: ' scope.splitPolicy];end %#ok<AGROW>
for i=1:numel(scope.notes),lines{end+1}=['Note: ' scope.notes{i}];end %#ok<AGROW>
end

function output = resolvedScopeOutput(app,classiObj,scope) %#ok<INUSD>
output=''; value='';
if isempty(scope.outputParameter),return;end
try
    fun=[scope.module '.executionSpec']; spec=feval(fun,classiObj);
    value=scopeValueText(app,spec.defaults.(scope.outputParameter));
catch
end
if isempty(value),value=scope.canonicalOutput;end
output=scope.outputTemplate;
if isempty(output),output=value;return;end
output=strrep(output,['<' scope.outputParameter '>'],value);
output=strrep(output,'<outputName>',value);
output=strrep(output,'<outputFamilyName>',value);
end

function value = scopeValueText(app,value) %#ok<INUSD>
while iscell(value)
    if isempty(value),value='';return;end
    if numel(value)>1
        value=strjoin(cellfun(@(item)scopeValueText(app,item),value, ...
            'UniformOutput',false),', ');
        return;
    end
    value=value{1};
end
if islogical(value)&&isscalar(value),value=mat2str(value);
elseif isnumeric(value),value=mat2str(value);
else,value=char(string(value));end
end

function updateTrainingScopeLabels(app,classiObj)
scope=classifierBinding.trainingScopeSpec(classiObj);
if isempty(scope.displayName),return;end
app.SettrainingparametersTab.Title=['Training - ' scope.displayName];
app.FormattrainingsetMenu.Text=['Format data for ' scope.module '...'];
app.TrainClassifierMenu.Text=['Train only ' scope.module '...'];
end

function refreshTrainingScopePanel(app)
% Keep the ownership summary synchronized with live parameter edits.
classiObj=app.Data.classiObj;
if ~isempty(app.trainingScopeTextArea) && ...
        isvalid(app.trainingScopeTextArea)
    app.trainingScopeTextArea.Value=trainingScopeLines(app,classiObj);
end
updateTrainingScopeLabels(app,classiObj);
end


function label = classifierDropdownLabel(app, classiObj)
% Reuse the package entry already present in classlist instead of adding
% the classifier's human-readable title as a second dropdown entry.
    label = '';
    try
        if iscell(classiObj.description) && ~isempty(classiObj.description)
            label = classiObj.description{1};
            while iscell(label) && numel(label) == 1
                label = label{1};
            end
            label = char(string(label));
        end
    catch
        label = '';
    end

    pkg = '';
    try
        pkg = lower(strtrim(char(string(classiObj.classifierPkg))));
    catch
    end
    if isempty(pkg)
        try
            fun = char(string(classiObj.trainingFun));
            dot = strfind(fun,'.');
            if ~isempty(dot), pkg = lower(strtrim(fun(1:dot(1)-1))); end
        catch
        end
    end
    if isempty(pkg), return; end

    try
        for i = 1:size(app.Data.classlist,1)
            candidate = app.Data.classlist{i,2};
            while iscell(candidate) && numel(candidate) == 1
                candidate = candidate{1};
            end
            candidate = char(string(candidate));
            if strcmpi(strtrim(candidate),pkg)
                label = candidate;
                return;
            end
        end
    catch
    end
end


 function refreshAll(app, varargin)
% refreshAll(app) : refresh UI from app.Data.classiObj
% refreshAll(app,'RebuildTrainingParam',true)

    p = inputParser;
    addParameter(p,'RebuildTrainingParam',true,@islogical);
    parse(p,varargin{:});
    rebuildTP = p.Results.RebuildTrainingParam;

    app.isRefreshing = true;
    c = app.Data.classiObj;

    % 1) Type dropdown
    if ~isempty(c.description) && ~isempty(c.description{1})
        descr = classifierDropdownLabel(app,c);
        if ~any(matches(app.TypeDropDown.Items, descr))
            app.TypeDropDown.Items = [app.TypeDropDown.Items, {descr}];
        end
        app.TypeDropDown.Value = descr;
    end

    % 2) Classes + colormap
    if isempty(c.colormap) && ~isempty(c.classes)
        c.colormap = shallowColormap(numel(c.classes));
    end
    if ~isempty(c.classes)
        c.classes = cellfun(@(s) strtrim(s), c.classes, 'UniformOutput', false);
    end
    for i=1:numel(c.roi)
        c.roi(i).classes = c.classes;
    end
    app.Data.classiObj = c;

    % 3) Rebuild trainingParam GUI (table-based)
    if rebuildTP
        if isempty(c.trainingParam)
            c.trainClassifier('setparam');
        end
        try, classifierBinding.normalizeClassifier(c); catch, end
        if ~isfield(c.trainingParam,'tip')
            c.trainingParam.tip = {};
        end

        % Build table-based editor
        [app.paramSpec, app.paramTableData] = buildParamTable(app, c.trainingParam, c);
        app.UITableParam.Data = app.paramTableData;
        app.UITableParam.ColumnName = { ...
            'Parameter','Value','Model component / category','',''};
        app.UITableParam.ColumnEditable = [false true false false false];
        try app.UITableParam.ColumnWidth = {'auto','auto','auto',1,1}; catch, end
        app.UITableParam.CellSelectionCallback = createCallbackFcn(app, @UITableParamCellSelection, true);
        app.UITableParam.CellEditCallback = createCallbackFcn(app, @UITableParamCellEdit, true);

        % Auto-select first row
        if height(app.paramTableData) > 0
            app.paramSelectedKey = app.paramTableData.Param{1};
            app.UITableParam.Selection = [1 1];
            showParamEditor(app, app.paramSelectedKey);
        end

        app.Data.classiObj = c;
    end

    % 4) Refresh panels
    displayClassi(app);
    displayProperties(app);
    displayData(app);

    % 5) Restore => considered unsaved
    checkStatus(app,false);

    app.isRefreshing = false;
end




        function  displayClassi(app) % displays the data from classi as they are

               classiObj = app.Data.classiObj;

    % guard: classlist must be loaded
    if ~isfield(app.Data,'classlist') || isempty(app.Data.classlist) || size(app.Data.classlist,2) < 6
        app.TypeDropDown.Items = {};
        app.ClassiDetailsLabel.Text = 'No classifier package found in engine/classification';
        return;
    end


            if numel(classiObj.description)==0 % new classi
                pix=1;
                classlist=app.Data.classlist;

                app.Data.classiObj.description={classlist{pix,2} ' - ' classlist{pix,3}};
                app.Data.classiObj.category = classiNormalizeCategory(classlist{pix,4});
                app.Data.classiObj.classifyFun=classlist{pix,6}{1};
                app.Data.classiObj.trainingFun=classlist{pix,5}{1};
            end

            % Package metadata may have evolved after a classifier was
            % saved. Repair it before dereferencing the legacy description
            % triplet used by this GUI.
            try
                pkg = lower(strtrim(char(string(classiObj.classifierPkg))));
                trainFun = lower(strtrim(char(string(classiObj.trainingFun))));
                classifyFun = lower(strtrim(char(string(classiObj.classifyFun))));
                if isempty(pkg)
                    if contains(trainFun,'.'), pkg = extractBefore(trainFun,'.');
                    elseif contains(classifyFun,'.'), pkg = extractBefore(classifyFun,'.');
                    end
                end
                metadataFun = [pkg '.ensureClassMetadata'];
                if ~isempty(pkg) && ~isempty(which(metadataFun))
                    feval(metadataFun,classiObj);
                end
            catch
            end

            % All legacy classifiers are expected to expose
            % {type, user comment, package details}. Keep the GUI usable
            % even when loading an older or partially initialized object.
            description = classiObj.description;
            if ~iscell(description)
                description = {char(string(description))};
            end
            if numel(description) < 2
                description{2} = '';
            end
            if numel(description) < 3
                details = '';
                try
                    pix = classiObj.typeid;
                    if isnumeric(pix) && isscalar(pix) && pix >= 1 && ...
                            pix <= size(app.Data.classlist,1)
                        details = app.Data.classlist{pix,3};
                        while iscell(details) && numel(details) == 1
                            details = details{1};
                        end
                    end
                catch
                end
                description{3} = details;
            end
            classiObj.description = description;

            dropdownLabel = classifierDropdownLabel(app,app.Data.classiObj);
            if numel(find(matches(app.TypeDropDown.Items,dropdownLabel)))
                app.TypeDropDown.Value=dropdownLabel;
            else
                app.TypeDropDown.Items=[app.TypeDropDown.Items {dropdownLabel}];
                app.TypeDropDown.Value=dropdownLabel;
            end

            % classi description
            % if numel(classiObj.description)
            app.ClassiDetailsLabel.Text=classiObj.description{3};
            % end


            app.PostprocessingparametersPanel.Enable='off';
            app.PostprocessingDropDown.Enable='off';
            app.PostprocessingcustomfunctionhandleEditField.Enable='off';


            % channels

            typedTrainingBindings = hasTypedTrainingBindings(app, classiObj);
            setLegacyChannelSelectorVisible(app, ~typedTrainingBindings);

            if ~typedTrainingBindings

            app.ChannelListBoxSel.Items={};
            app.ChannelListBoxSel.Enable='off';

            cha={};

            
            [catCell, ~] = classiNormalizeCategory(classiObj.category);
            switch catCell{1}

                case 'Timeseries' % timeseries

                    if numel(classiObj.roi(1).results)
                    fi=fieldnames(classiObj.roi(1).results);
                    cc=1;
                     for i=1:numel(fi)
                         tmp=classiObj.roi(1).results.(fi{i});       
                         fi2=fieldnames(tmp); 

                         for j=1:numel(fi2)
                             
                             cha{cc}=['train.' fi{i} '.' fi2{j}];
                             
                             cc=cc+1;
                         end
                     end
                    end
                                   
                    
                  if numel(cha)
                        app.ChannelListBox.Items=cha;
                        app.ChannelListBox.Enable='on';
                    else
                        app.ChannelListBox.Items={};
                        app.ChannelListBox.Enable='off';
                  end
                  
                  if numel(classiObj.channelName)~=0 % in case previou system is used
                        channelName=classiObj.channelName;
                        app.ChannelListBoxSel.Items=channelName;
                        app.ChannelListBoxSel.Enable='on';
      
                  end
                  
                  
                  
                     
                otherwise % image classification 
                    
                    for i=1:numel(classiObj.roi)
                        if numel(classiObj.roi(i).id)
                            tmp=classiObj.roi(i).display.channel(:);
                            if size(tmp,1)>1
                                tmp=tmp';
                            end

                            cha=unique([cha tmp],'stable');

                        end
                    end

                    if numel(cha)
                        app.ChannelListBox.Items=cha;
                        app.ChannelListBox.Enable='on';
                    else
                        app.ChannelListBox.Items={};
                        app.ChannelListBox.Enable='off';
                    end

                    if numel(classiObj.channelName)==0 % in case previou system is used
                        if numel(cha) & numel(classiObj.channel)
                            if numel(cha)>= classiObj.channel(1) && classiObj.channel(1)>0
                                channelName=cha(classiObj.channel(1));
                                classiObj.channelName=channelName;
                                app.ChannelListBoxSel.Items=channelName;
                                app.ChannelListBoxSel.Enable='on';
                            end
                        else
                            channelName='';
                        end
                    else
                        channelName=classiObj.channelName;

                        if ischar(channelName) % fix previous classification format
                            channelName={channelName};
                            classiObj.channelName=channelName;
                        end

                        app.ChannelListBoxSel.Items=channelName;
                        app.ChannelListBoxSel.Enable='on';
                    end
            end

            else
                app.ChannelListBox.Items = {};
                app.ChannelListBoxSel.Items = {};
                app.ChannelListBox.Enable = 'off';
                app.ChannelListBoxSel.Enable = 'off';
            end

            % classes
            %   aaa=classiObj.description{1}
            if strcmp(classiObj.description{1},'Image Regression') || strcmp(classiObj.description{1},'LSTM Regression') % image regression : no classes needed
                classiObj.classes={};
                %   app.SpaceseparatedclassnamesEditField
                app.SpaceseparatedclassnamesEditField.Enable='off';

            else
                app.SpaceseparatedclassnamesEditField.Enable='on';
            end

            if numel(classiObj.classes)
                str='';
                for i=1:numel(classiObj.classes)
                    str=[str classiObj.classes{i} ' '];
                end
                app.SpaceseparatedclassnamesEditField.Value=str;
            else
                app.SpaceseparatedclassnamesEditField.Value='';
            end

            % postprocessing functions
            outputstr='';
            % outut functions



            [catCell, ~] = classiNormalizeCategory(classiObj.category);
            if strcmp(catCell{1},'Pixel')
                %   aa=classiObj.outputFun
                %   class(aa)
                app.PostprocessingDropDown.Enable='on';
                if usesExecutionSpecOutputType(app, classiObj)
                    app.PostprocessingDropDownLabel.Text = 'Output resource';
                    app.PostprocessingDropDown.Items = getExecutionSpecOutputChoices(app, classiObj);
                    outputstr = normalizeExecutionSpecOutputType(app, classiObj.outputType);
                    if isempty(outputstr)
                        outputstr = getExecutionSpecDefaultOutputType(app, classiObj);
                        classiObj.outputType = outputstr;
                    end
                else
                    app.PostprocessingDropDownLabel.Text = 'Post-processing';
                    app.PostprocessingDropDown.Items = {'plain output / probabilities for each class', 'plain output / semantic segmentation', 'postprocessing', 'custom function (see below)'};
                    if numel(classiObj.outputType)
                        outputstr=classiObj.outputType;
                    else
                        outputstr='proba';
                    end
                    %  outputstr

                    switch outputstr
                        case 'proba'
                            outputstr='plain output / probabilities for each class';
                        case 'segmentation'
                            outputstr='plain output / semantic segmentation';
                        case 'postprocessing'
                            if ischar(classiObj.outputFun)
                                if strcmp(classiObj.outputFun,'post')
                                    outputstr='postprocessing';
                                else
                                    outputstr='custom function (see below)';
                                end
                            end
                    end
                end

                app.PostprocessingDropDown.Value=outputstr;


                if strcmp(outputstr,'custom function (see below)')
                    app.PostprocessingcustomfunctionhandleEditField.Enable='on';

                    if  numel(classiObj.outputFun)
                        if ischar(classiObj.outputFun)
                            app.PostprocessingcustomfunctionhandleEditField.Value=classiObj.outputFun;
                        end
                    end
                else
                    app.PostprocessingcustomfunctionhandleEditField.Enable='off';
                    app.PostprocessingcustomfunctionhandleEditField.Value='';
                end

                outputArg=classiObj.outputArg;
                app.WatershedCheckBox.Value=false;
                app.FilteroutsmallobjectsCheckBox.Value=false;
                app.SizepixelEditField.Value=10;
                app.FixedthresholdButton.Value=false;
                app.ValueEditField.Value=num2str(0.9);
                app.AdaptivethresholdOtsumethodButton.Value=false;
                app.MaximumprobabilityButton.Value=false;

                if  strcmp(outputstr,'postprocessing')

                    app.PostprocessingcustomfunctionhandleEditField.Value='post';
                    app.PostprocessingparametersPanel.Enable='on';
                    app.PostprocessingcustomfunctionhandleEditField.Value='post';

                    % display postprocessing parameters


                    for j=1:numel(outputArg)

                        if strcmp(outputArg{j},'watershed')
                            app.WatershedCheckBox.Value=true;
                        end

                        if strcmp(outputArg{j},'sizethreshold')
                            app.FilteroutsmallobjectsCheckBox.Value=true;
                            app.SizepixelEditField.Value=str2double(outputArg{j+1});
                        end
                        if strcmp(outputArg{j},'threshold')
                            app.FixedthresholdButton.Value=true;

                            app.ValueEditField.Value=num2str(outputArg{j+1});
                        end
                        if strcmp(outputArg{j},'adaptivethreshold')
                            app.AdaptivethresholdOtsumethodButton.Value=true;

                        end
                        if strcmp(outputArg{j},'maxproba')
                            app.MaximumprobabilityButton.Value=true;
                        end
                    end


                end
            else
                app.PostprocessingDropDown.Enable='off';
            end

            app.UsercommentsEditField_2.Value=classiObj.description{2};



 
        end



        function [boundsType, globalBounds] = localBoundsConfig(app,classiObj)
    boundsType = "Auto";
    globalBounds = [];

    if isprop(classiObj,'bounds') && isstruct(classiObj.bounds)
        if isfield(classiObj.bounds,'Type') && ~isempty(classiObj.bounds.Type)
            boundsType = string(classiObj.bounds.Type);
        end
        if isfield(classiObj.bounds,'Values')
            globalBounds = normalizeBounds(app,classiObj.bounds.Values);
        end
    end
end

function txt = localBoundsText(app,roiObj, pixdata, classiObj, boundsType, globalBounds) %#ok<INUSD>
    % The table is the canonical user-facing view.  The backend also reads
    % legacy per-dataseries bounds, but an absent value is always shown as
    % the explicit and editable default "all".
    try
        b = trainingBounds.resolve(classiObj, roiObj);
        txt = trainingBounds.text(b);
    catch
        txt = 'all';
    end
end

function txt = localBoundsNotice(app,boundsType, globalBounds) %#ok<INUSD>
    switch lower(string(boundsType))
        case "auto"
            if isempty(globalBounds)
                txt = 'Formatting: all frames (default)';
            else
                txt = sprintf('Formatting: frames %d:%d (legacy global bound)', ...
                    globalBounds(1), globalBounds(2));
            end
        case "manual"
            txt = 'Formatting: persistent per-ROI bounds shown above; all = all frames';
        case "rules"
            txt = 'Bounds: Rules';
        otherwise
            txt = sprintf('Bounds: %s', string(boundsType));
    end
end

function b = readBoundsField(app,ud, fieldName) %#ok<INUSD>
    b = [];
    if isstruct(ud) && isfield(ud, fieldName)
        b = ud.(fieldName);
    elseif isa(ud,'containers.Map') && isKey(ud, fieldName)
        b = ud(fieldName);
    end
end

function b = normalizeBounds(app,raw) %#ok<INUSD>
    b = [];

    if isempty(raw), return; end
    if iscell(raw), raw = raw{1}; end

    if ischar(raw) || isstring(raw)
        nums = regexp(char(string(raw)), '[-+]?\d*\.?\d+(?:[eE][-+]?\d+)?', 'match');
        if numel(nums) < 2, return; end
        raw = [str2double(nums{1}) str2double(nums{2})];
    end

    if ~isnumeric(raw), return; end
    raw = double(raw(:)');
    if numel(raw) < 2 || any(~isfinite(raw(1:2))), return; end

    b = round(raw(1:2));
    if b(1) == 0
        b = [];
        return;
    end
    if b(2) ~= 0 && b(2) < b(1)
        b = b([2 1]);
    end
end

function displayData(app, annotationScanMode) % displays rois in the table

    if nargin < 2 || isempty(annotationScanMode)
        annotationScanMode = 'fast';
    end

    rois         = app.Data.classiObj.roi;
    trainingrois = app.Data.classiObj.trainingset;
    classiObj    = app.Data.classiObj;

    [boundsType, globalBounds] = localBoundsConfig(app,classiObj);
    frameBoundsEditable = ~(strcmpi(boundsType,'Auto') && ...
        ~isempty(globalBounds));

    t    = app.UITableData;
    Data = {};
    annotationRows = struct([]);
    try
        annotationRows = annotationSummaryRows(app, classiObj, [], ...
            'Fast', ~strcmpi(char(string(annotationScanMode)), 'full'));
    catch ME
        warning('classifierGUI:AnnotationSummary', ...
            'Could not summarize annotations: %s', ME.message);
    end

    if numel(rois) == 1
        if numel(rois.id) == 0
            t.Data = {};
            app.Data.annotationVisibleRoiIndices = [];
            app.BoundsnoticeLabel.Text = localBoundsNotice(app,boundsType, globalBounds);
            updateAnnotationActionState(app);
            return;
        end
    end

    [catCell, ~] = classiNormalizeCategory(app.Data.classiObj.category);
    category = catCell{1};

    for i = 1:numel(rois)

        istrainee   = false;
        istest      = true;
        isannotated = false;
        isvalidated = false;
        pixdata     = [];
        [annotationStatus, annotationCoverage, annotationValidation] = ...
            annotationTableValues(app, annotationRows, i);
        managedAnnotated = ~strcmpi(annotationStatus, 'missing');

        if any(trainingrois == i)
            istrainee = true;
            istest    = false;
        end

        if strcmp(category,'Pixel')

            t.ColumnName     = {'Select for training','Select for test',...
                                ' ROI index','ROI Id','Frame bounds', ...
                                'Annotation status','Coverage'};
            t.ColumnWidth    = {135, 135, 80, 'auto', 120, 120, 190};
            t.ColumnEditable = [true true false false frameBoundsEditable ...
                false false];

            if numel(rois(i).data)
                listdata = {rois(i).data.groupid};
                pixdata  = find(matches(listdata, classiObj.strid));
            end

            boundsTxt = localBoundsText(app,rois(i), pixdata, classiObj, boundsType, globalBounds);
            Data(i,:) = {istrainee, istest, i, rois(i).id, boundsTxt, ...
                annotationStatus, annotationCoverage};

        else

            if numel(rois(i).data) == 0
                rois(i).load('data');
            end

            if numel(rois(i).data) == 0
                listdata = {};
                pixdata  = [];
            else
                listdata = {rois(i).data.groupid};
                pixdata  = find(matches(listdata, classiObj.strid));
            end

            if ismember(category, {'Image','LSTM'})

                t.ColumnName = {'Select for training','Select for testing',...
                                ' ROI index','ROI Id','is annotated',...
                                'Frame bounds','Annotation status','Coverage'};
                t.ColumnWidth    = {130, 130, 80, 'auto', 85, 105, 120, 190};
                t.ColumnEditable = [true true false false false ...
                    frameBoundsEditable false false];

                labelsTraining = [];
                labelsPred     = [];

                if ~isempty(pixdata)
                    dd = rois(i).data(pixdata(1));

                    try
                        labelsTraining = dd.getData('labels_training');
                    catch
                        labelsTraining = [];
                    end

                    try
                        labelsPred = dd.getData('labels');
                    catch
                        labelsPred = [];
                    end
                end

                if ~isempty(labelsTraining)
                    labStr = string(labelsTraining);
                    labStr = labStr(:);
                    labStr = labStr(~ismissing(labStr));
                    if ~isempty(labStr)
                        isannotated = any(labStr ~= "uncategorized");
                    end
                end

                if ~isempty(labelsPred)
                    labStr = string(labelsPred);
                    labStr = labStr(:);
                    labStr = labStr(~ismissing(labStr));
                    if ~isempty(labStr)
                        isvalidated = any(labStr ~= "uncategorized");
                    end
                end

                displayAnnotationStatus = annotationStatus;
                if strcmpi(displayAnnotationStatus, 'Missing')
                    if isvalidated
                        displayAnnotationStatus = 'Ready';
                    elseif isannotated
                        displayAnnotationStatus = 'Draft';
                    end
                end
                boundsTxt = localBoundsText(app, rois(i), pixdata, classiObj, boundsType, globalBounds);
                Data(i,:) = {istrainee, istest, i, rois(i).id, ...
                             isannotated || managedAnnotated, ...
                             boundsTxt, displayAnnotationStatus, annotationCoverage};

            else

                t.ColumnName = {'Select for training','Select for testing',...
                                ' ROI index','ROI Id','is annotated',...
                                'Frame bounds','Annotation status','Coverage'};
                t.ColumnWidth    = {130, 130, 80, 'auto', 85, 105, 120, 190};
                t.ColumnEditable = [true true false false false ...
                    frameBoundsEditable false false];

                if ~isempty(pixdata)
                    dd = rois(i).data(pixdata(1));
                    try
                        ddts = dd.getData('id_training');
                        if sum(ddts) > 0
                            isannotated = true;
                        end
                    catch
                    end
                end

                if ~isempty(pixdata)
                    dd      = rois(i).data(pixdata(1));
                    probtmp = 0;
                    for kclass = 1:numel(classiObj.classes)
                        fieldName = ['prob_ ' classiObj.classes{kclass}];
                        try
                            ddts    = dd.getData(fieldName);
                            probtmp = probtmp + sum(ddts(:));
                        catch
                        end
                    end
                    if probtmp > 0
                        isvalidated = true;
                    end
                end

                displayAnnotationStatus = annotationStatus;
                if strcmpi(displayAnnotationStatus, 'Missing')
                    if isvalidated
                        displayAnnotationStatus = 'Ready';
                    elseif isannotated
                        displayAnnotationStatus = 'Draft';
                    end
                end
                boundsTxt = localBoundsText(app, rois(i), pixdata, classiObj, boundsType, globalBounds);
                Data(i,:) = {istrainee, istest, i, rois(i).id, ...
                             isannotated || managedAnnotated, ...
                             boundsTxt, displayAnnotationStatus, annotationCoverage};
            end
        end
    end

    filterValue = 'All';
    try, filterValue = char(string(app.AnnotationFilterDropDown.Value)); catch, end
    if ~isempty(Data) && ~strcmpi(filterValue, 'All')
        statusColumn = find(strcmpi(string(t.ColumnName), ...
            'Annotation status'), 1);
        keep = strcmpi(string(Data(:, statusColumn)), string(filterValue));
        Data = Data(keep, :);
    end
    t.Data = Data;
    if isempty(Data)
        app.Data.annotationVisibleRoiIndices = [];
    else
        app.Data.annotationVisibleRoiIndices = cell2mat(Data(:, 3)).';
    end
    app.BoundsnoticeLabel.Text = localBoundsNotice(app,boundsType, globalBounds);
    updateAnnotationActionState(app);
end

function rows = annotationSummaryRows(app, classiObj, roiIndices, varargin) %#ok<INUSD>
    % Call the package backend directly. MATLAB caches the method table of
    % already-loaded classi objects, so recently added @classi convenience
    % methods may be unavailable until a full `clear classes`.
    if nargin < 3, roiIndices = []; end
    ensureAnnotationBackendAvailable(app);
    rows = annotationManager.summarizeClassifier(classiObj, roiIndices, varargin{:});
end

function session = annotationSessionForClassifier(app, classiObj, roiIndex) %#ok<INUSD>
    ensureAnnotationBackendAvailable(app);
    session = annotationManager.createSession(classiObj, roiIndex);
end

function attachAnnotationSessionListener(app, session)
    try
        if isfield(app.Data, 'annotationSessionListener') && ...
                ~isempty(app.Data.annotationSessionListener)
            delete(app.Data.annotationSessionListener);
        end
        if isfield(app.Data, 'annotationBoundsListener') && ...
                ~isempty(app.Data.annotationBoundsListener)
            delete(app.Data.annotationBoundsListener);
        end
    catch
    end
    app.Data.annotationSessionListener = addlistener(session, ...
        'StateChanged', @(~,~)refreshAnnotationTableRow(app, session));
    app.Data.annotationBoundsListener = addlistener(session, ...
        'BoundsChanged', @(~,~)annotationBoundsChanged(app, session));
end

function annotationBoundsChanged(app, session)
    try checkStatus(app, false); catch, end
    try
        if isempty(app) || ~isvalid(app) || isempty(app.UITableData.Data)
            return;
        end
        data = app.UITableData.Data;
        roiIndices = cellfun(@double, data(:,3));
        tableRow = find(roiIndices == double(session.RoiIndex), 1);
        if isempty(tableRow), return; end
        names = string(app.UITableData.ColumnName);
        data = setAnnotationTableColumn(app,data,names,tableRow, ...
            'Frame bounds',trainingBounds.text(session.frameBounds()));
        app.UITableData.Data = data;
        [boundsType,globalBounds] = localBoundsConfig(app,app.Data.classiObj);
        app.BoundsnoticeLabel.Text = localBoundsNotice( ...
            app,boundsType,globalBounds);
        drawnow limitrate nocallbacks;
    catch ME
        warning('classifierGUI:BoundsRowRefresh', ...
            'Could not refresh ROI frame bounds: %s',ME.message);
    end
end

function refreshAnnotationTableRow(app, session)
    try
        if isempty(app) || ~isvalid(app) || isempty(app.UITableData.Data)
            return;
        end
        filterValue = 'All';
        try, filterValue = char(string(app.AnnotationFilterDropDown.Value)); catch, end
        if ~strcmpi(filterValue, 'All')
            displayData(app);
            return;
        end

        data = app.UITableData.Data;
        roiIndices = cellfun(@double, data(:,3));
        tableRow = find(roiIndices == double(session.RoiIndex), 1);
        if isempty(tableRow), return; end
        rows = annotationSummaryRows(app, app.Data.classiObj, ...
            session.RoiIndex, 'Fast', true);
        [statusText, coverageText, validationText] = ...
            annotationTableValues(app, rows, session.RoiIndex);
        names = string(app.UITableData.ColumnName);
        data = setAnnotationTableColumn(app, data, names, tableRow, ...
            'Annotation status', statusText);
        data = setAnnotationTableColumn(app, data, names, tableRow, ...
            'Coverage', coverageText);
        data = setAnnotationTableColumn(app, data, names, tableRow, ...
            'is annotated', ~strcmpi(statusText, 'Missing'));
        data = setAnnotationTableColumn(app, data, names, tableRow, ...
            'Frame bounds', trainingBounds.text(session.frameBounds()));
        app.UITableData.Data = data;
        drawnow limitrate nocallbacks;
    catch ME
        warning('classifierGUI:AnnotationRowRefresh', ...
            'Could not refresh ROI annotation row: %s', ME.message);
    end

end

function data = setAnnotationTableColumn(app, data, names, row, name, value) %#ok<INUSD>
    column = find(strcmpi(strtrim(names), name), 1);
    if ~isempty(column), data{row, column} = value; end
end

function ensureAnnotationBackendAvailable(app) %#ok<INUSD>
    if ~isempty(which('annotationManager.summarizeClassifier'))
        return;
    end

    guiPath = which('classifierGUI');
    if isempty(guiPath)
        error('classifierGUI:AnnotationBackendPath', ...
            'Cannot locate classifierGUI on the MATLAB path.');
    end
    repoRoot = fileparts(fileparts(fileparts(guiPath)));
    engineRoot = fullfile(repoRoot, 'engine');
    if ~isfolder(engineRoot)
        error('classifierGUI:AnnotationBackendPath', ...
            'Cannot locate the DetecDiv engine folder: %s', engineRoot);
    end
    addpath(genpath(engineRoot));
    rehash;
    if isempty(which('annotationManager.summarizeClassifier'))
        error('classifierGUI:AnnotationBackendPath', ...
            'DetecDiv annotation backend is unavailable under %s.', engineRoot);
    end
end

function finishAnnotationEditorLaunch(app, progressDialog, previousButtonState)
    try
        if ~isempty(progressDialog) && isvalid(progressDialog)
            delete(progressDialog);
        end
    catch
    end
    try
        if ~isempty(app) && isvalid(app) && ...
                isvalid(app.AnnotateselectedROIButton)
            app.AnnotateselectedROIButton.Enable = previousButtonState;
        end
    catch
    end
end

function [statusText, coverageText, validationText] = ...
        annotationTableValues(app, rows, roiIndex) %#ok<INUSD>
    status = 'missing';
    reviewed = 0;
    total = 0;
    components = struct([]);
    persistedValidation = 'not_run';
    if ~isempty(rows)
        match = find([rows.roiIndex] == roiIndex, 1);
        if ~isempty(match)
            status = char(string(rows(match).status));
            reviewed = double(rows(match).reviewed);
            total = double(rows(match).total);
            if isfield(rows, 'coverageComponents')
                components = rows(match).coverageComponents;
            end
            if isfield(rows, 'validationStatus')
                persistedValidation = char(string( ...
                    rows(match).validationStatus));
            end
        end
    end
    if isempty(status), status = 'missing'; end
    coverageText = compactCoverageText(app, components, reviewed, total);
    validationText = activeAnnotationValidationText( ...
        app, roiIndex, status, persistedValidation);
    statusText = annotationReadyStatus(app, status, validationText);
end

function text = annotationReadyStatus(app, storedStatus, validationText) %#ok<INUSD>
    storedStatus = lower(char(string(storedStatus)));
    validationText = lower(char(string(validationText)));
    if strcmp(storedStatus, 'missing')
        text = 'Missing';
    elseif strcmp(validationText, 'invalid')
        text = 'Invalid';
    elseif strcmp(validationText, 'valid') || ...
            strcmp(storedStatus, 'approved')
        text = 'Ready';
    else
        text = 'Draft';
    end
end

function text = activeAnnotationValidationText( ...
        app, roiIndex, status, persistedValidation)
    if strcmpi(status, 'approved')
        text = 'Valid';
        return;
    end
    switch lower(char(string(persistedValidation)))
        case 'valid'
            text = 'Valid';
        case 'invalid'
            text = 'Invalid';
        otherwise
            text = 'Not run';
    end
    try
        if ~isfield(app.Data, 'annotationSession') || ...
                isempty(app.Data.annotationSession) || ...
                ~isvalid(app.Data.annotationSession) || ...
                double(app.Data.annotationSession.RoiIndex) ~= double(roiIndex)
            return;
        end
        switch char(string(app.Data.annotationSession.LastValidationStatus))
            case 'valid'
                text = 'Valid';
            case 'invalid'
                text = 'Invalid';
        end
    catch
    end
end

function text = compactCoverageText(app, components, reviewed, total) %#ok<INUSD>
    if isempty(components)
        text = sprintf('%d/%d', reviewed, total);
        return;
    end
    parts = strings(0,1);
    for i = 1:numel(components)
        switch char(string(components(i).id))
            case {'tracked_mask','instances','semantic_mask','mask'}
                prefix = 'S';
            case {'tracking','tracklets'}
                prefix = 'T';
            case {'parentage','lineage'}
                prefix = 'P';
            otherwise
                prefix = upper(extractBefore(string(components(i).id) + "_", 2));
        end
        parts(end+1,1) = sprintf('%s%d/%d', prefix, ...
            components(i).reviewed, components(i).total); %#ok<AGROW>
    end
    text = char(strjoin(parts, ' '));
end

function indices = selectedAnnotationRoiIndices(app)
    indices = [];
    try
        selection = app.UITableData.Selection;
        if ~isempty(selection) && ~isempty(app.UITableData.Data)
            rows = unique(selection(:,1), 'stable');
            rows = rows(rows >= 1 & rows <= size(app.UITableData.Data,1));
            for i = 1:numel(rows)
                value = app.UITableData.Data{rows(i),3};
                indices(end+1) = double(value); %#ok<AGROW>
            end
        end
    catch
        indices = [];
    end
    if isempty(indices)
        try, indices = double(app.Data.selected); catch, end
    end
    nRoi = numel(app.Data.classiObj.roi);
    indices = unique(round(indices(:).'), 'stable');
    indices = indices(isfinite(indices) & indices >= 1 & indices <= nRoi);
end

function updateAnnotationActionState(app)
    hasRois = false;
    try
        rois = app.Data.classiObj.roi;
        hasRois = ~isempty(rois) && ~(numel(rois) == 1 && isempty(rois(1).id));
    catch
    end
    app.RefreshAnnotationStatusButton.Enable = localOnOff(app, hasRois);
    app.GenerateDraftButton.Enable = 'off';
    app.StartBlankGTButton.Enable = 'off';
    app.StartBlankGTButton.Visible = 'off';
    app.AnnotateselectedROIButton.Enable = 'off';
    if ~hasRois, return; end

    indices = selectedAnnotationRoiIndices(app);
    if isempty(indices), return; end
    app.AnnotateselectedROIButton.Enable = localOnOff(app, numel(indices) == 1);
    app.GenerateDraftButton.Enable = 'on';
end

function value = localOnOff(app, condition) %#ok<INUSD>
    if condition, value = 'on'; else, value = 'off'; end
end

function setClassifierTrainingSelection(app, trainIndices)
    classiObj = app.Data.classiObj;
    nRoi = numel(classiObj.roi);
    trainIndices = unique(round(double(trainIndices(:).')), 'stable');
    trainIndices = trainIndices(isfinite(trainIndices) & ...
        trainIndices >= 1 & trainIndices <= nRoi);
    testIndices = setdiff(1:nRoi, trainIndices, 'stable');
    classiObj.trainingset = trainIndices;
    try
        if ~isprop(classiObj, 'dataset') || ~isstruct(classiObj.dataset)
            classiObj.dataset = struct('classes', {{}}, 'channels', {{}}, ...
                'split', struct('train', [], 'val', [], 'test', []));
        end
        if ~isfield(classiObj.dataset, 'split') || ...
                ~isstruct(classiObj.dataset.split)
            classiObj.dataset.split = struct('train', [], 'val', [], 'test', []);
        end
        classiObj.dataset.split.train = trainIndices;
        classiObj.dataset.split.val = [];
        classiObj.dataset.split.test = testIndices;
    catch
    end
    app.Data.classiObj = classiObj;
end

function dataset = remapClassifierDatasetAfterRoiRemoval( ...
        app, dataset, legacyTraining, keep, oldRoiCount) %#ok<INUSD>
    if ~isstruct(dataset) || ~isscalar(dataset)
        dataset = struct('classes', {{}}, 'channels', {{}}, ...
            'split', struct('train', [], 'val', [], 'test', []));
    end
    if ~isfield(dataset, 'split') || ~isstruct(dataset.split) || ...
            ~isscalar(dataset.split)
        dataset.split = struct('train', legacyTraining, ...
            'val', [], 'test', []);
    end
    splitNames = {'train','val','test'};
    for i = 1:numel(splitNames)
        name = splitNames{i};
        if isfield(dataset.split, name)
            oldIndices = dataset.split.(name);
        else
            oldIndices = [];
        end
        if strcmp(name, 'train') && isempty(oldIndices) && ...
                ~isempty(legacyTraining)
            oldIndices = legacyTraining;
        end
        oldIndices = unique(round(double(oldIndices(:).')), 'stable');
        oldIndices = oldIndices(isfinite(oldIndices) & ...
            oldIndices >= 1 & oldIndices <= oldRoiCount);
        dataset.split.(name) = find(ismember(keep, oldIndices));
    end
end

function clearAnnotationSessionAfterRoiRemoval(app, classiObj)
    session = [];
    try
        if isfield(app.Data, 'annotationSession')
            session = app.Data.annotationSession;
        end
    catch
    end
    try
        figures = findall(0, 'Type', 'figure');
        scoreFigure = findobj(figures, 'Name', 'ScoreApp');
        for i = 1:numel(scoreFigure)
            if ~isprop(scoreFigure(i), 'RunningAppInstance'), continue; end
            scoreApp = scoreFigure(i).RunningAppInstance;
            scoreSession = scoreApp.AnnotationSession;
            sameSession = ~isempty(session) && isequal(scoreSession, session);
            sameClassifier = false;
            if ~isempty(scoreSession) && isvalid(scoreSession)
                sameClassifier = isequal(scoreSession.Classifier, classiObj);
            end
            if sameSession || sameClassifier
                scoreApp.setAnnotationSession([]);
            end
        end
    catch
    end
    try
        if isfield(app.Data, 'annotationSessionListener') && ...
                ~isempty(app.Data.annotationSessionListener)
            delete(app.Data.annotationSessionListener);
        end
    catch
    end
    try
        if isfield(app.Data, 'annotationBoundsListener') && ...
                ~isempty(app.Data.annotationBoundsListener)
            delete(app.Data.annotationBoundsListener);
        end
    catch
    end
    app.Data.annotationSessionListener = [];
    app.Data.annotationBoundsListener = [];
    app.Data.annotationSession = [];
end

function proceed = confirmTrainingRoisReady(app, roiIndices)
    proceed = true;
    try
        rows = annotationSummaryRows(app, app.Data.classiObj, roiIndices);
    catch
        return;
    end
    if isempty(rows), return; end
    storedStatuses = string({rows.status});
    validationStatuses = string({rows.validationStatus});
    ready = strcmpi(storedStatuses, 'approved') | ...
        strcmpi(validationStatuses, 'valid');
    notReady = rows(~ready);
    if isempty(notReady), return; end

    maxRows = min(numel(notReady), 15);
    details = strings(maxRows,1);
    for i = 1:maxRows
        details(i) = sprintf('%s: %s', notReady(i).roiId, ...
            annotationReadyStatus(app, notReady(i).status, ...
                notReady(i).validationStatus));
    end
    if numel(notReady) > maxRows
        details(end+1) = sprintf('... and %d more ROI(s)', ...
            numel(notReady) - maxRows); %#ok<AGROW>
    end
    message = sprintf(['The following training ROI(s) are not ready:\n\n%s\n\n' ...
        'Continue formatting anyway?'], strjoin(details, newline));
    choice = uiconfirm(app.ClassifierUIFigure, message, ...
        'Ground truth not ready', 'Options', {'Cancel','Continue'}, ...
        'DefaultOption', 1, 'CancelOption', 1, 'Icon', 'warning');
    proceed = strcmp(choice, 'Continue');
end



        function  checkStatus(app,saving)
            % checks whether classi parameters are saved and classifier is
            % in memory

            classiObj=app.Data.classiObj;

            [~, check]=classiObj.loadClassifier('check');

            if check
                app.StatusLoad.Color=[0 1 0];

            end
            %   end

            % checks whether paramas have changed
            if nargin==2

                if saving==false
                    app.StatusSaved.Color=[1 0 0];
                else
                    app.StatusSaved.Color=[0 1 0];
                end
            end
        end
        
        function displayProperties(app)

            % display classi generic parameters

            classiObj=app.Data.classiObj;
            app.PathEditField.Value=classiObj.getPath;
            
            st1=classiObj.description{1};

            if iscell(st1)
                st1=st1{1};
            end

              st3=classiObj.description{3};

            if iscell(st3)
                st3=st3{1};
            end

            app.TypeEditField.Value= [st1 ' // ' st3];

            str='';
                 for i=1:numel(classiObj.classes)
                    str=[str classiObj.classes{i} ' '];
                 end
              
                app.ClassesEditField.Value=str;

            % display user comments 
            app.UsercommentsEditField.Value=classiObj.description{2};


         [t,in] =classiObj.version;
        app.backupversionsEditField.Value=num2str(size(t,1));

        % display classi ROIs and training set info 
        if numel(classiObj.roi(1).id)
        app.NumberROIS.Value=num2str(numel(classiObj.roi));
        n=numel(classiObj.roi);
        else
        app.NumberROIS.Value='0';
        n=0;
        end

        if n>0

        app.NumberROIS_2.Value= num2str( double(length(classiObj.trainingset))./double(n));
        else
        app.NumberROIS_2.Value='0';
        end

       pth=classiObj.getPath;
       
       % collect the number of images (quiet for empty/unsaved modules)
       k = {};
       canInspect = false;
       try
           if ~isempty(classiObj.path) && isfolder(classiObj.path)
               if isprop(classiObj,'roi') && ~isempty(classiObj.roi)
                   if ~(numel(classiObj.roi)==1 && isempty(classiObj.roi(1).id))
                       canInspect = true;
                   end
               end
           end
       catch
           canInspect = false;
       end

       if canInspect
           try
               [k, ~] = classiObj.displayFormattedTrainingSet;
           catch
               k = {};
           end
       end

     if numel(k)==0
         app.formatLabel.Text='This classfier has no formatted data';
     else
         tmpstr='';
         cc=0;
         for i=1:size(k,1)
                tmpstr=[tmpstr 'Folder: "' k{i,1} '" : ' num2str(k{i,2}) ' images'  newline];
                cc=cc+k{i,2};
         end
      tmpstr=[tmpstr 'Total number of images: ' num2str(cc)];

         app.formatLabel.Text=tmpstr;
     end


     % Annotation lifecycle statistics shared by every classifier category.
     try
         rows = annotationSummaryRows(app, classiObj);
         statuses = string({rows.status});
         validationStatuses = string({rows.validationStatus});
         app.NumberofannotatedROIsEditField.Value = ...
             num2str(nnz(~strcmpi(statuses, 'missing')));
         app.AnnotatedROIswithvalidationdataEditField.Value = ...
             num2str(nnz(strcmpi(statuses, 'approved') | ...
                 strcmpi(validationStatuses, 'valid')));
         app.AnnotatedROIswithvalidationdataEditFieldLabel.Text = ...
             'Ready annotation ROIs:';
     catch
         app.NumberofannotatedROIsEditField.Value = 'Not available';
         app.AnnotatedROIswithvalidationdataEditField.Value = 'Not available';
     end
        end

        function tf = isCellposeSAMClassifier(app, classiObj) %#ok<INUSD>
            tf = false;
            try
                if isprop(classiObj, 'classifierPkg') && ...
                        strcmpi(char(string(classiObj.classifierPkg)), 'cellposesam')
                    tf = true;
                    return;
                end
            catch
            end
            try
                if isprop(classiObj, 'classifyFun') && ...
                        any(strcmpi(char(string(classiObj.classifyFun)), {'classifyCPSAMFun','cellposesam.classify'}))
                    tf = true;
                    return;
                end
            catch
            end
            try
                if isprop(classiObj, 'description') && ~isempty(classiObj.description)
                    desc = lower(string(classiObj.description));
                    tf = any(contains(desc, 'cellpose'));
                end
            catch
                tf = false;
            end
        end

        function tf = usesExecutionSpecOutputType(app, classiObj) %#ok<INUSD>
            pkg = resolveClassifierPackageForOutput(app, classiObj);
            tf = any(strcmp(pkg, {'cellposesam','deeplab_pixel_classification'}));
        end

        function pkg = resolveClassifierPackageForOutput(app, classiObj) %#ok<INUSD>
            pkg = '';
            try
                if isprop(classiObj, 'classifierPkg') && ~isempty(classiObj.classifierPkg)
                    pkg = lower(strtrim(char(string(classiObj.classifierPkg))));
                    return;
                end
            catch
            end
            try
                if isprop(classiObj, 'classifyFun') && ~isempty(classiObj.classifyFun)
                    f = char(string(classiObj.classifyFun));
                    dot = strfind(f, '.');
                    if ~isempty(dot)
                        pkg = lower(strtrim(f(1:dot(1)-1)));
                        return;
                    elseif strcmpi(f, 'classifyCPSAMFun')
                        pkg = 'cellposesam';
                        return;
                    end
                end
            catch
            end
            try
                if isprop(classiObj, 'description') && ~isempty(classiObj.description)
                    desc = lower(string(classiObj.description));
                    if any(contains(desc, 'cellpose'))
                        pkg = 'cellposesam';
                    elseif any(contains(desc, 'deeplab'))
                        pkg = 'deeplab_pixel_classification';
                    end
                end
            catch
                pkg = '';
            end
        end

        function choices = getExecutionSpecOutputChoices(app, classiObj)
            choices = {'segmentation','probability','both'};
            pkg = resolveClassifierPackageForOutput(app, classiObj);
            try
                spec = feval([pkg '.executionSpec'], classiObj);
                if isfield(spec, 'choices') && isfield(spec.choices, 'outputType') && ~isempty(spec.choices.outputType)
                    choices = spec.choices.outputType;
                end
            catch
            end
        end

        function outputType = getExecutionSpecDefaultOutputType(app, classiObj)
            outputType = 'segmentation';
            pkg = resolveClassifierPackageForOutput(app, classiObj);
            try
                spec = feval([pkg '.executionSpec'], classiObj);
                if isfield(spec, 'defaults') && isfield(spec.defaults, 'outputType') && ~isempty(spec.defaults.outputType)
                    outputType = normalizeExecutionSpecOutputType(app, spec.defaults.outputType);
                end
            catch
            end
            if isempty(outputType)
                outputType = 'segmentation';
            end
        end

        function outputType = normalizeExecutionSpecOutputType(app, value) %#ok<INUSD>
            outputType = lower(strtrim(char(string(value))));
            outputType = strrep(outputType, '-', '_');
            outputType = strrep(outputType, ' ', '_');
            switch outputType
                case {'proba','probabilities','probability_map'}
                    outputType = 'probability';
                case {'seg','mask','masks','semantic','semantic_segmentation','postprocessing'}
                    outputType = 'segmentation';
                case {'segmentation','probability','both'}
                    % already normalized
                otherwise
                    if isempty(outputType)
                        outputType = '';
                    else
                        outputType = 'segmentation';
                    end
            end
        end
    end


    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app, classiObj)
  
% startupFcn  Initialize GUI with classiObj + classlist.

    if nargin==1
        classiObj = classi;
        classiObj.path = '';
        classiObj.strid = 'No input classi was provided';
    end

    app.ClassifierUIFigure.Name = [classiObj.strid];
    app.Data.classiObj = classiObj;
    app.SetboundsselectionrulesButton.Text = 'Set training frames...';
    app.SetboundsselectionrulesButton.Tooltip = [ ...
        'Apply all frames or one shared range to several ROIs, or switch ' ...
        'to per-ROI editing. These bounds are used directly by formatting.'];

    % Load classlist (and auto-append packages)
% Load classlist (and auto-append packages)
% Load classlist from engine/classification
app.Data.classlist = loadClasslist(app);

if isempty(app.Data.classlist)
    uialert(app.ClassifierUIFigure, ...
        'No classifier packages found in engine/classification (+pkg folders).', ...
        'Initialization error');
    app.TypeDropDown.Items = {};
    return;
end

items = app.Data.classlist(:,2); % short names
if iscell(items)
    app.TypeDropDown.Items = items(:)';   % row cellstr
else
    app.TypeDropDown.Items = cellstr(string(items(:))');
end



    app.Data.selected = [];

    if nargin>1
        displayClassi(app);
    end

    % Ensure trainingParam exists
    if numel(classiObj.trainingParam)==0
        classiObj.trainClassifier('setparam');
    end

    try, classifierBinding.normalizeClassifier(classiObj); catch, end

    if isSam31Classifier(app, classiObj)
        try
            sam31.ensureClassMetadata(classiObj);
        catch
        end
    end
    if usesLegacyTransferLearning(app, classiObj)
        % Ensure transfer_learning list for legacy MATLAB/CNN classifiers.
        if ~isfield(classiObj.trainingParam,'transfer_learning')
            [t,~] = classiObj.version;
            if numel(t{1,1})==0
                str={};
            else
                str=t(:,4);
            end
            str=['ImageNet', str', 'ImageNet'];
            classiObj.trainingParam.transfer_learning=str;
            classiObj.trainingParam.tip{end+1}='Select version of the classifier to be used';
            checkStatus(app,false);
        else
            [t,~]=classiObj.version;
            if numel(t{1,1})==0
                str={};
            else
                str=t(:,4);
            end
            str=['ImageNet', str', classiObj.trainingParam.transfer_learning{end}];
            classiObj.trainingParam.transfer_learning=str;
            checkStatus(app,true);
        end
    end

    % Build table-based editor
    [app.paramSpec, app.paramTableData] = buildParamTable(app, classiObj.trainingParam, classiObj);
    app.UITableParam.Data = app.paramTableData;
    app.UITableParam.ColumnName = { ...
        'Parameter','Value','Model component / category','',''};
    app.UITableParam.ColumnEditable = [false true false false false];
    try app.UITableParam.ColumnWidth = {'auto','auto','auto',1,1}; catch, end
    app.UITableParam.CellSelectionCallback = createCallbackFcn(app, @UITableParamCellSelection, true);
    app.UITableParam.CellEditCallback = createCallbackFcn(app, @UITableParamCellEdit, true);

    if height(app.paramTableData) > 0
        app.paramSelectedKey = app.paramTableData.Param{1};
        app.UITableParam.Selection = [1 1];
        showParamEditor(app, app.paramSelectedKey);
    end

    displayProperties(app);





        end

        % Close request function: ClassifierUIFigure
        function ClassifierUIFigureCloseRequest(app, event)
             % ---- 1) Vérifier si les paramètres/classifier sont sauvegardés ----
    % Remplace ceci par ton vrai flag de sauvegarde

    isSaved = isequal(app.StatusSaved.Color,[0 1 0]);
    % Ou : isSaved = strcmp(app.ParametersSavedLamp.Color,'green');



     if ~isSaved
        % ---- 2) Show confirmation dialog in English ----
        selection = uiconfirm(app.ClassifierUIFigure, ...
            ['The classifier has not been saved.', newline, ...
             'Are you sure you want to close the window?'], ...
             'Unsaved Changes', ...
             'Options', {'Close without saving','Cancel'}, ...
             'DefaultOption', 2, 'Icon','warning');

        % ---- 3) Cancel if the user does not confirm ----
        if strcmp(selection, 'Cancel')
            return
        end
    end

            
            
            delete(app)
        end

        % Callback function
        function SaveclassifierparametersButtonPushed(app, event)
            disp('Saving classifiers')

            d = uiprogressdlg(app.ClassifierUIFigure,'Title','Please Wait...',...
                'Message','Saving current classifier and trainingset...');
            d.Value=0.33;


            if numel(app.UITableData.Data)
                selectedfortraining=cellfun(@(x) x==1,app.UITableData.Data(:,1));
                app.Data.classiObj.trainingParam.rois=find(selectedfortraining');
            else
                app.Data.classiObj.trainingParam.rois =1:numel(app.Data.classiObj.roi);
            end

            classiSave(app.Data.classiObj);

            d.Value=0.67;
            d.Message='Saving training parameters...';


            d.Value=1;
            close(d)

        end

        % Button down function: SettrainingparametersTab
        function SettrainingparametersTabButtonDown(app, event)
            refreshTypedTrainingBindingChoices(app);
    % 
    % 
    %         % --- 1) Récupérer le classifier ---
    % if ~isfield(app.Data, 'classiObj') || isempty(app.Data.classiObj)
    %     % adapte le nom de la figure si nécessaire (UIFigure / ClassifierUIFigure)
    %     uialert(app.UIFigure, ...
    %         'No classifier object found in app.Data.classiObj.', ...
    %         'Error', 'Icon', 'error');
    %     return;
    % end
    % 
    % classif = app.Data.classiObj;  % handle class, modifiée par effet de bord
    % 
    % % --- 2) Vérifier si les paramètres de training sont déjà définis ---
    % hasParam = ~isempty(classif.trainingParam)
    % 
    % if ~hasParam
    %     % --- 3) Initialiser via la fonction de training en mode "init" ---
    %     if isempty(classif.trainingFun)
    %         uialert(app.UIFigure, ...
    %             'No training function defined for this classifier (trainingFun is empty).', ...
    %             'Error', 'Icon', 'error');
    %         return;
    %     end
    % 
    %     try
    %         funHandle = str2func(classif.trainingFun);
    % 
    %         % Convention : trainXXXFun(classif, <quelquechose>) avec nargin==2
    %         % déclenche le mode "setparam". La valeur du 2e argument n'a pas d'importance.
    %         funHandle(classif, 'init');
    % 
    %         % classif est un handle → app.Data.classiObj est déjà à jour,
    %         % mais on peut réassigner pour être explicite :
    %         app.Data.classiObj = classif;
    % 
    %     catch ME
    %         uialert(app.UIFigure, ...
    %             sprintf('Failed to initialize training parameters using %s:\n\n%s', ...
    %                     classif.trainingFun, ME.message), ...
    %             'Error', 'Icon', 'error');
    %         return;
    %     end
    % end
    % 
    % % --- 4) Ici tu peux rafraîchir l’affichage des champs de trainingParam ---
    % % Par ex. si tu as une méthode dédiée :
    % % updateTrainingParamUI(app);


        end

        % Value changed function: TypeDropDown
        function TypeDropDownValueChanged(app, event)

    if app.isRefreshing, return; end

    value = app.TypeDropDown.Value;
    pix = find(matches(app.TypeDropDown.Items, value), 1);

    classlist = app.Data.classlist;
if pix > size(classlist,1)
    % Legacy entry (not from package list) -> keep current settings
    uialert(app.ClassifierUIFigure, ...
        'Legacy classifier entry: no package mapping. Keeping current settings.', ...
        'Info');
    return;
end


    test = uiconfirm(app.ClassifierUIFigure, ...
        'Training parameters will be erased if you change the type of classifier ! Proceed?', ...
        'Warning','Icon','Warning');

    if strcmp(test,'Cancel')
        return;
    end

    app.Data.classiObj.typeid = pix;

    classlist = app.Data.classlist;

    app.Data.classiObj.description = {classlist{pix,2} ' - ' classlist{pix,3}};
    app.Data.classiObj.category = classiNormalizeCategory(classlist{pix,4});
    app.Data.classiObj.classifyFun = classlist{pix,6}{1};
    app.Data.classiObj.trainingFun = classlist{pix,5}{1};

    % Set classifierPkg from package-based functions when applicable
    try
        pkg = '';
        if ischar(app.Data.classiObj.trainingFun) && contains(app.Data.classiObj.trainingFun,'.')
            pkg = extractBefore(app.Data.classiObj.trainingFun,'.');
        elseif ischar(app.Data.classiObj.classifyFun) && contains(app.Data.classiObj.classifyFun,'.')
            pkg = extractBefore(app.Data.classiObj.classifyFun,'.');
        end
        app.Data.classiObj.classifierPkg = char(pkg);
    catch
    end

    app.Data.classiObj.trainingParam = [];

    % reset parameters
    app.Data.classiObj.trainClassifier('setparam');
    classiObj = app.Data.classiObj;

    try, classifierBinding.normalizeClassifier(classiObj); catch, end

    % set parameter menu:
    if isSam31Classifier(app, classiObj)
        try
            sam31.ensureClassMetadata(classiObj);
        catch
        end
    end
    if usesLegacyTransferLearning(app, classiObj)
        if ~isfield(classiObj.trainingParam,'transfer_learning')
            [t,~]=classiObj.version;
            if numel(t{1,1})==0, str={}; else, str=t(:,4); end
            str=['ImageNet', str', 'ImageNet'];
            classiObj.trainingParam.transfer_learning=str;
            classiObj.trainingParam.tip{end+1}='Select version of the classifier to be used';
            checkStatus(app,false);
        else
            [t,~]=classiObj.version;
            if numel(t{1,1})==0, str={}; else, str=t(:,4); end
            str=['ImageNet', str', classiObj.trainingParam.transfer_learning{end}];
            classiObj.trainingParam.transfer_learning=str;
            checkStatus(app,true);
        end
    end

    % Rebuild table-based editor
    [app.paramSpec, app.paramTableData] = buildParamTable(app, classiObj.trainingParam, classiObj);
    app.UITableParam.Data = app.paramTableData;
    app.UITableParam.ColumnName = { ...
        'Parameter','Value','Model component / category','',''};
    app.UITableParam.ColumnEditable = [false true false false false];
    try app.UITableParam.ColumnWidth = {'auto','auto','auto',1,1}; catch, end
    app.UITableParam.CellSelectionCallback = createCallbackFcn(app, @UITableParamCellSelection, true);
    app.UITableParam.CellEditCallback = createCallbackFcn(app, @UITableParamCellEdit, true);

    if height(app.paramTableData) > 0
        app.paramSelectedKey = app.paramTableData.Param{1};
        app.UITableParam.Selection = [1 1];
        showParamEditor(app, app.paramSelectedKey);
    end

    displayClassi(app);
    displayProperties(app);
   
        end

        % Callback function
        function ChannelnameusedasinputEditFieldValueChanged(app, event)
            value = app.ChannelnameusedasinputEditField.Value;
            app.Data.classiObj.channel=str2num(value);
            checkStatus(app,false)
        end

        % Value changed function: SpaceseparatedclassnamesEditField
        function SpaceseparatedclassnamesEditFieldValueChanged(app, event)

    if app.isRefreshing, return; end

    % ---- Parse new classes from edit field ----
    value = string(app.SpaceseparatedclassnamesEditField.Value);
    newClasses = strtrim(split(value));
    newClasses(newClasses=="") = [];
    newClasses = cellstr(newClasses(:));

    % ---- Old classes (normalize to column cellstr) ----
    oldClasses = app.Data.classiObj.classes;
    if isstring(oldClasses), oldClasses = cellstr(oldClasses); end
    oldClasses = oldClasses(:);

    % ---- No change -> nothing to do ----
    if isequal(oldClasses, newClasses)
        return;
    end

    % ---- Ask mapping (only once) if we had old classes ----
    mapping = [];  % leave empty if no old classes
    if ~isempty(oldClasses)
        [oldToNew, cancelled] = classMappingDialog(app.ClassifierUIFigure, oldClasses, newClasses);
        if cancelled
            % revert edit field to keep state consistent
            app.isRefreshing = true;
            app.SpaceseparatedclassnamesEditField.Value = strjoin(oldClasses, " ");
            app.isRefreshing = false;
            return;
        end
        mapping = oldToNew; % containers.Map old -> new (or "" for delete)
    end

    % ---- Apply via class method (this also updates ROI classes + LSTM training ds) ----
    try
        app.Data.classiObj.setClasses(newClasses, ...
            'mapping', mapping, ...
            'storeMapping', ~isempty(mapping), ...
            'updateROIData', true);  % you can set false if you want to delay ROI ds migration
    catch ME
        % If something fails, revert edit field and rethrow (or alert)
        app.isRefreshing = true;
        app.SpaceseparatedclassnamesEditField.Value = strjoin(oldClasses, " ");
        app.isRefreshing = false;
        rethrow(ME);
    end

    % ---- Refresh UI once ----
    displayProperties(app);
    checkStatus(app,false);

        end

        % Callback function
        function PostprocessingfunctionhandleEditFieldValueChanged(app, event)
            value =PostprocessingfunctionhandleEditFieldValueChanged.Value;
            app.Data.classiObj.outputFun=str2func(value);
            checkStatus(app,false)
        end

        % Value changed function: PostprocessingDropDown
        function PostprocessingDropDownValueChanged(app, event)
            if app.isRefreshing, return; end

            value = app.PostprocessingDropDown.Value;
            if usesExecutionSpecOutputType(app, app.Data.classiObj)
                app.Data.classiObj.outputType = normalizeExecutionSpecOutputType(app, value);
                app.Data.classiObj.outputFun='';
                app.Data.classiObj.outputArg={};
                app.PostprocessingcustomfunctionhandleEditField.Enable='off';
                app.PostprocessingcustomfunctionhandleEditField.Value='';
                checkStatus(app,false)
                displayClassi(app);
                return;
            end

            pix=find(contains(app.PostprocessingDropDown.Items,value));

            switch pix
                case 1
                    app.Data.classiObj.outputType='proba';
                    app.Data.classiObj.outputFun='';
                    app.Data.classiObj.outputArg={};
                case 2
                    app.Data.classiObj.outputType='segmentation';
                    app.Data.classiObj.outputFun='';
                    app.Data.classiObj.outputArg={};
                case 3
                    app.Data.classiObj.outputType='postprocessing';
                    app.Data.classiObj.outputFun='post';
                    app.Data.classiObj.outputArg={'threshold','0.9'};
                case 4
                    app.Data.classiObj.outputType='postprocessing';
                    app.Data.classiObj.outputFun='';
                    app.Data.classiObj.outputArg={};
                    app.PostprocessingcustomfunctionhandleEditField.Value='';
            end

            checkStatus(app,false)
            displayClassi(app);
        end

        % Value changed function: 
        % PostprocessingcustomfunctionhandleEditField
        function PostprocessingcustomfunctionhandleEditFieldValueChanged2(app, event)
            value = app.PostprocessingcustomfunctionhandleEditField.Value;
            app.Data.classiObj.outputFun=value;
            checkStatus(app,false)
        end

        % Button down function: SettrainingandvalidationsetROIsTab
        function SettrainingandvalidationsetROIsTabButtonDown(app, event)
            displayData(app);
        end

        % Cell edit callback: UITableData
        function UITableDataCellEdit(app, event)
            indices = event.Indices;
            row = indices(1);
            col = indices(2);

            columnNames = strtrim(string(app.UITableData.ColumnName));
            if col <= numel(columnNames) && strcmpi(columnNames(col), 'Frame bounds')
                roiIndex = double(app.UITableData.Data{row,3});
                try
                    roiObj = app.Data.classiObj.roi(roiIndex);
                    frameCount = annotationManager.frameCount(roiObj);
                    if frameCount < 1
                        try frameCount = size(roiObj.image,4); catch, frameCount = []; end
                    end
                    trainingBounds.setRoi(app.Data.classiObj, roiIndex, ...
                        event.NewData, 'FrameCount', frameCount);
                    checkStatus(app,false);
                    data = app.UITableData.Data;
                    data{row,col} = trainingBounds.text( ...
                        trainingBounds.resolve(app.Data.classiObj, roiIndex));
                    app.UITableData.Data = data;
                    [boundsType, globalBounds] = localBoundsConfig( ...
                        app,app.Data.classiObj);
                    app.BoundsnoticeLabel.Text = localBoundsNotice( ...
                        app,boundsType,globalBounds);
                catch ME
                    try
                        data = app.UITableData.Data;
                        data{row,col} = event.PreviousData;
                        app.UITableData.Data = data;
                    catch
                    end
                    uialert(app.ClassifierUIFigure, ME.message, ...
                        'Invalid training frame bounds');
                end
                return;
            end

            if col ~= 1 && col ~= 2, return; end

            roiIndex = double(app.UITableData.Data{row,3});
            trainIdx = double(app.Data.classiObj.trainingset(:).');
            selectForTraining = (col == 1 && logical(event.NewData)) || ...
                (col == 2 && ~logical(event.NewData));
            if selectForTraining
                trainIdx = union(trainIdx, roiIndex, 'stable');
            else
                trainIdx = setdiff(trainIdx, roiIndex, 'stable');
            end
            setClassifierTrainingSelection(app, trainIdx);
            checkStatus(app,false);
            displayData(app);
         


        end

        % Button pushed function: AnnotateselectedROIButton
        function AnnotateselectedROIButtonPushed(app, event)
            sel = selectedAnnotationRoiIndices(app);
            if numel(sel) ~= 1
                uialert(app.ClassifierUIFigure,'First select an ROI!','Error')
                return;
            end
            disp(['Launching ROI #' num2str(sel) '.... Please wait...']);
            previousButtonState = app.AnnotateselectedROIButton.Enable;
            app.AnnotateselectedROIButton.Enable = 'off';
            progressDialog = uiprogressdlg(app.ClassifierUIFigure, ...
                'Title', 'Opening annotation editor', ...
                'Message', sprintf([ ...
                    'Opening ROI #%d in Score...\n' ...
                    'The first launch can take 20-30 seconds; later ROIs reuse the open editor.'], ...
                    sel), ...
                'Indeterminate', 'on', ...
                'Cancelable', 'off');
            progressCleanup = onCleanup(@()finishAnnotationEditorLaunch( ...
                app, progressDialog, previousButtonState));
            drawnow;

            try
                app.Data.annotationSession = annotationSessionForClassifier( ...
                    app, app.Data.classiObj, sel);
                attachAnnotationSessionListener( ...
                    app, app.Data.annotationSession);
                app.Data.classiObj.userTraining('Roi', sel, ...
                    'AnnotationSession', app.Data.annotationSession);
            catch ME
                clear progressCleanup
                uialert(app.ClassifierUIFigure, sprintf( ...
                    'Could not open ROI #%d in Score.\n\n%s', sel, ME.message), ...
                    'Annotation editor error');
                return;
            end

            clear progressCleanup
            checkStatus(app,false)
            displayData(app);
        end

        % Cell selection callback: UITableData
        function UITableDataCellSelection(app, event)
            indices = event.Indices;
            if numel(indices)
                row = indices(1);
                if row <= size(app.UITableData.Data,1)
                    app.Data.selected = double(app.UITableData.Data{row,3});
                end
            end
            updateAnnotationActionState(app);
        end

        % Button pushed function: ImportROIsButton
        function ImportROIsButtonPushed(app, event)

            roiImporterGUI(app)
            uiwait(app.ClassifierUIFigure);

            displayData(app);
            displayClassi(app); % uodates the channel in particular in the classi tab
            refreshTypedTrainingBindingChoices(app);
        end

        % Button pushed function: SelectallButton
        function SelectallButtonPushed(app, event)
            visible = app.Data.annotationVisibleRoiIndices;
            trainIdx = union(double(app.Data.classiObj.trainingset(:).'), ...
                double(visible(:).'), 'stable');
            setClassifierTrainingSelection(app, trainIdx);
            checkStatus(app,false)
            displayData(app);
        end

        % Button pushed function: DeselectallButton
        function DeselectallButtonPushed(app, event)
            visible = app.Data.annotationVisibleRoiIndices;
            trainIdx = setdiff(double(app.Data.classiObj.trainingset(:).'), ...
                double(visible(:).'), 'stable');
            setClassifierTrainingSelection(app, trainIdx);
            checkStatus(app,false)
            displayData(app);
        end

        % Button pushed function: removeselectedROIButton
        function removeselectedROIButtonPushed(app, event)


    % Récupérer toutes les lignes sélectionnées dans le UITable
    indices = app.UITableData.Selection;   % [n x 2] (row, col)
    if isempty(indices)
        return
    end
    selectedRows = unique(indices(:,1));
    selectedRows = selectedRows(selectedRows >= 1 & ...
        selectedRows <= size(app.UITableData.Data,1));
    sel = zeros(1, numel(selectedRows));
    for i = 1:numel(selectedRows)
        sel(i) = double(app.UITableData.Data{selectedRows(i),3});
    end

    classiObj = app.Data.classiObj;
    nRoi = numel(classiObj.roi);
    oldRois = classiObj.roi;
    oldTraining = double(classiObj.trainingset(:).');
    oldDataset = classiObj.dataset;
    oldChannelName = classiObj.channelName;
    oldScore = classiObj.score;

    % Nettoyage des indices hors bornes
    sel = unique(round(sel(:).'), 'stable');
    sel = sel(isfinite(sel) & sel >= 1 & sel <= nRoi);
    if isempty(sel)
        return
    end

    % ROIs à conserver = toutes sauf celles sélectionnées
    keep = setdiff(1:nRoi, sel, 'stable');
    newDataset = remapClassifierDatasetAfterRoiRemoval( ...
        app, oldDataset, oldTraining, keep, nRoi);
    newTraining = newDataset.split.train;
    if isempty(keep)
        newRois = roi;
    else
        newRois = oldRois(keep);
    end

    % Commit the ROI array and its split together. If a future split update
    % fails, restore the complete pre-click state rather than leaving an
    % in-memory classifier with fewer ROIs and stale indices.
    try
        classiObj.roi = newRois;
        classiObj.trainingset = newTraining;
        classiObj.dataset = newDataset;
        classiObj.score = [];
        if isempty(keep)
            classiObj.channelName = {};
        end
    catch ME
        classiObj.roi = oldRois;
        classiObj.trainingset = oldTraining;
        classiObj.dataset = oldDataset;
        classiObj.channelName = oldChannelName;
        classiObj.score = oldScore;
        app.Data.classiObj = classiObj;
        rethrow(ME);
    end

    clearAnnotationSessionAfterRoiRemoval(app, classiObj);
    app.UITableData.Selection = [];
    app.Data.selected = [];
    if isempty(keep) || (numel(classiObj.roi) == 1 && ...
            isempty(classiObj.roi(1).id))
        classiObj.channelName = {};
        displayClassi(app);
    end

    % Mise à jour de l’état et de l’affichage
    checkStatus(app,false);
    displayData(app);
    refreshTypedTrainingBindingChoices(app);

        end

        % Menu selected function: DisplaystatisticsMenu
        function DisplaystatisticsMenuSelected(app, event)
            classiObj=app.Data.classiObj;
            aa=app.UITableData.Data;

            if numel(aa)==0
                uialert(app.ClassifierUIFigure,'First select the testset in the dataset tab or make sure you have ROIs!','Error');
                return;
            end


            % gather the test set.

            selectedfortest=find(cellfun(@(x) x==0,app.UITableData.Data(:,1)));
            try
                if strcmpi(char(string(classiObj.classifierPkg)), 'sam31') || ...
                        strcmpi(char(string(classiObj.classifyFun)), 'sam31.classify')
                    sam31.displayValidationRuns(classiObj, selectedfortest');
                    return;
                end
            catch ME
                uialert(app.ClassifierUIFigure, ...
                    sprintf('Could not open SAM31 validation browser:\n%s', ME.message), ...
                    'SAM31 validation runs', 'Icon', 'error');
                return;
            end
            classiObj.stats('Confusion','Classes','Rois',selectedfortest','Force');
        end

        % Menu selected function: ValidateclassifierusingtestsetMenu
        function ValidateclassifierusingtestsetMenuSelected(app, event)

            classiObj=app.Data.classiObj;

            testRois = [];
            try
                if ~isempty(app.UITableData.Data)
                    testRois = find(cellfun(@(x) isequal(x, 1) || isequal(x, true), app.UITableData.Data(:,2)));
                end
            catch
                testRois = [];
            end

            try
                classifierOpenValidationPipeline(classiObj, ...
                    'Rois', testRois, ...
                    'OutputPolicy', 'replace', ...
                    'Execution', 'Auto');
            catch ME
                uialert(app.ClassifierUIFigure, ME.message, ...
                    'Validation pipeline failed', 'Icon', 'error');
            end
            return;
%             
% 
% %             if ~exist(fullfile(classiObj.path,'trainingParam.mat'))
% %                 uialert(app.ClassifierUIFigure,'Error','Training parameters were not saved !')
% %                 return;
% %             end
% 
%             d = uiprogressdlg(app.ClassifierUIFigure,'Title','Please Wait...',...
%                 'Message','Checking number of frames');
%             d.Value=0.1;
% 
%             if numel(classiObj.roi(1).image)==0
%                 classiObj.roi(1).load;
%             end
% 
%             nframes=size(classiObj.roi(1).image,4);
% 
%             prompt = {'Process only ROIs/Frames in which groundtruth is available (yes -> 1; no -> 0):','Frames to be processed: (write -1 if variable frame numbers)','Use additional CNN only classification (yes -> 1; no -> 0) - for LSTM classification'};
%             dlgtitle = 'Input classifier validation parameters';
% 
%             dims = [1 100];
% 
%             definput = {'1',['1:' num2str(nframes)],'0'};%, num2str(inte)};
%             answer = inputdlg(prompt,dlgtitle,dims,definput);
% 
%             if numel(answer)==0
%                 return;
%             end
% 
%             % here bug suspected
%             if numel(app.UITableData.Data)==0
%                 displayData(app);
%             end
% 
%             selectedfortesting=cellfun(@(x) x==0,app.UITableData.Data(:,1));
% 
%             roiobj=classiObj.roi(selectedfortesting);
% 
%             d = uiprogressdlg(app.ClassifierUIFigure,'Title','Please Wait...',...
%                 'Message','Checking network classifier performance using groundtruth data // test dataset; Please wait...');
%             d.Value=0.2;
% 
%             arg={};
%             cc=1;
%             if strcmp(answer{1},'1')
%                 arg{cc}='RoiWithGT';
%                 cc=cc+1;
%             end
% 
% %             if strcmp(answer{3},'1')
% %                 arg{cc}='Parallel';
% %                 cc=cc+1;
% %             end
% 
%             arg{cc}='Frames';   
%             cc=cc+1;
%             arg{cc}=answer{2};
%             cc=cc+1;
% 
%             if strcmp(answer{3},'1')
%                 arg{cc}='ClassifierCNN';
%                 cc=cc+1;
%             end
% 
%             arg{cc}='Progress';
%             cc=cc+1;
%             arg{cc}=d;
%             cc=cc+1;
% 
%             classiObj.validateTrainingData(roiobj,arg{:});
% 
%             d.Value=1;
% 
%             pause(1);
%             close(d)
%                uialert(app.ClassifierUIFigure,'Validation is complete!','Success','Icon','success');
        end

        % Menu selected function: FormattrainingsetMenu
        function FormattrainingsetMenuSelected(app, event)
  
    classiObj = app.Data.classiObj;
    nrois = double(classiObj.trainingset(:).');
    if isempty(nrois)
        try, nrois = classiObj.getTrainingROIIndices(); catch, end
    end

    if numel(nrois) == 0
        uialert(app.ClassifierUIFigure, ...
            'You must select at least one ROI in the Dataset panel  !', ...
            'Error');
        return;
    end

    [nrois, selectionReady] = excludeMissingFormattingRois( ...
        app, classiObj, nrois);
    if ~selectionReady
        return;
    end

    if ~confirmTrainingRoisReady(app, nrois)
        return;
    end

    [formatReady, packageArgs] = ensurePackageFormattingParameters( ...
        app, classiObj, nrois);
    if ~formatReady
        return;
    end

    d = uiprogressdlg(app.ClassifierUIFigure, ...
        'Title','Please Wait...', ...
        'Message','Exporting the persistent per-ROI training frames...');
    d.Value = 0.33;

    args = [{'Frames', [], 'Rois', nrois}, packageArgs];

    % Call
    try
        output = app.Data.classiObj.formatDataForTraining(args{:});
    catch ME
        try
            if ~isempty(d) && isvalid(d), close(d); end
        catch
        end
        uialert(app.ClassifierUIFigure, localGuiErrorMessage(app, ME), ...
            'Training-set formatting failed', 'Icon', 'error');
        return;
    end

    d.Value = 0.66;

    % Handle numeric OR struct output
    nExport = 0;
    if isnumeric(output)
        nExport = output;
    elseif isstruct(output) && isfield(output,'metrics') && isfield(output.metrics,'outputCount')
        nExport = output.metrics.outputCount;
    elseif isstruct(output) && isfield(output,'metrics') && isfield(output.metrics,'framebankFrames')
        nExport = output.metrics.framebankFrames;
    elseif isstruct(output) && isfield(output,'metrics') && isfield(output.metrics,'rows')
        nExport = output.metrics.rows;
    end
    formatNotes = {};
    if isstruct(output) && isfield(output, 'metrics')
        if isfield(output.metrics, 'skippedEmptyMaskFrames') && output.metrics.skippedEmptyMaskFrames > 0
            formatNotes{end+1} = sprintf('%d frame(s) without GT masks were not exported.', ...
                output.metrics.skippedEmptyMaskFrames); %#ok<AGROW>
            if isfield(output.metrics, 'skippedEmptyMaskDetails') && ~isempty(output.metrics.skippedEmptyMaskDetails)
                details = output.metrics.skippedEmptyMaskDetails;
                if ischar(details) || isstring(details)
                    details = cellstr(string(details));
                end
                maxDetails = min(numel(details), 12);
                for ii = 1:maxDetails
                    formatNotes{end+1} = [' - ' char(string(details{ii}))]; %#ok<AGROW>
                end
                if numel(details) > maxDetails
                    formatNotes{end+1} = sprintf(' - ... %d more item(s)', numel(details) - maxDetails); %#ok<AGROW>
                end
            end
        elseif isfield(output.metrics, 'skippedFrames') && output.metrics.skippedFrames > 0
            formatNotes{end+1} = sprintf('%d frame(s) were not exported.', output.metrics.skippedFrames); %#ok<AGROW>
        end
    end

    if nExport > 0
        d.Message = [num2str(nExport) ' files/images were exported; The classifier is ready to be trained!'];
        strr = d.Message;
    else
        d.Message = 'No file was exported; Check your trainingset!';
        strr = d.Message;
        pause(1);
    end
    if ~isempty(formatNotes)
        strr = sprintf('%s\n\n%s', strr, strjoin(formatNotes, newline));
    end

    close(d);
    displayProperties(app);
    uialert(app.ClassifierUIFigure, strr, 'Success', 'Icon','success');
            



        end

        function [roiIndices, proceed] = excludeMissingFormattingRois( ...
                app, classiObj, roiIndices)
            proceed = true;
            pkg = '';
            try pkg = char(string(classiObj.classifierPkg)); catch, end
            if ~strcmpi(pkg, 'cellLatentModel')
                return;
            end
            try
                rows = annotationSummaryRows(app, classiObj, roiIndices, ...
                    'Fast', true);
            catch
                return;
            end
            if isempty(rows), return; end
            missing = rows(strcmpi(string({rows.status}), 'missing'));
            if isempty(missing), return; end
            ready = setdiff(roiIndices, [missing.roiIndex], 'stable');
            details = string({missing.roiId});
            limit = min(numel(details), 12);
            shown = details(1:limit);
            if numel(details) > limit
                shown(end+1) = sprintf('... and %d more ROI(s)', ...
                    numel(details) - limit); %#ok<AGROW>
            end
            if isempty(ready)
                uialert(app.ClassifierUIFigure, sprintf([ ...
                    'None of the selected ROIs has initialized GT.\n\n%s\n\n' ...
                    'Initialize and validate GT before formatting.'], ...
                    strjoin(shown, newline)), ...
                    'No formatting-ready ROI', 'Icon', 'error');
                proceed = false;
                return;
            end
            choice = uiconfirm(app.ClassifierUIFigure, sprintf([ ...
                '%d selected ROI(s) have no initialized GT and cannot be ' ...
                'formatted:\n\n%s\n\nUse only the %d ROI(s) that contain GT?'], ...
                numel(missing), strjoin(shown, newline), numel(ready)), ...
                'ROIs without ground truth', ...
                'Options', {'Use GT ROIs only','Cancel'}, ...
                'DefaultOption', 1, 'CancelOption', 2, 'Icon', 'warning');
            if ~strcmp(choice, 'Use GT ROIs only')
                proceed = false;
                return;
            end
            roiIndices = ready;
            setClassifierTrainingSelection(app, roiIndices);
            checkStatus(app, false);
            displayData(app);
        end

        function [ready, extraArgs] = ensurePackageFormattingParameters( ...
                app, classiObj, roiIndices)
            ready = true;
            extraArgs = {};
            pkg = '';
            try pkg = char(string(classiObj.classifierPkg)); catch, end
            if ~strcmpi(pkg, 'cellLatentModel')
                return;
            end

            ctx = struct('params', struct());
            try ctx = classiObj.buildCtx('format', ctx); catch, end
            try
                cellLatentModel.preflightFormat(classiObj, roiIndices, ctx);
                return;
            catch ME
                if ~strcmp(ME.identifier, ...
                        'cellLatentModel:MissingFrameInterval')
                    uialert(app.ClassifierUIFigure, ...
                        localGuiErrorMessage(app, ME), ...
                        'Invalid formatting parameters', 'Icon', 'error');
                    ready = false;
                    return;
                end
            end

            suggested = '';
            try
                value = double(classiObj.executionParam.frameIntervalMinutes);
                if isscalar(value) && isfinite(value) && value > 0
                    suggested = sprintf('%.12g', value);
                end
            catch
            end
            answer = inputdlg({sprintf([ ...
                'Physical interval between consecutive frames (minutes).\n' ...
                'This value is mandatory for continuous-lineage training:'])}, ...
                'Continuous-lineage timing', [2 72], {suggested});
            if isempty(answer)
                ready = false;
                return;
            end
            raw = strrep(strtrim(char(string(answer{1}))), ',', '.');
            interval = str2double(raw);
            if ~isscalar(interval) || ~isfinite(interval) || interval <= 0
                uialert(app.ClassifierUIFigure, ...
                    'Enter a strictly positive frame interval in minutes.', ...
                    'Invalid frame interval', 'Icon', 'error');
                ready = false;
                return;
            end

            if ~isstruct(classiObj.trainingParam)
                classiObj.trainingParam = struct();
            end
            classiObj.trainingParam.frameIntervalMinutes = interval;
            ctx.params.frameIntervalMinutes = interval;
            try
                cellLatentModel.preflightFormat(classiObj, roiIndices, ctx);
            catch ME
                uialert(app.ClassifierUIFigure, ...
                    localGuiErrorMessage(app, ME), ...
                    'Invalid formatting parameters', 'Icon', 'error');
                ready = false;
                return;
            end
            extraArgs = {'frameIntervalMinutes', interval};
            try refreshTypedTrainingBindingChoices(app); catch, end
            checkStatus(app, false);
        end

        % Menu selected function: TrainClassifierMenu
        function TrainClassifierMenuSelected(app, event)
            classiObj=app.Data.classiObj;

            if app.StatusSaved.Color==[1 0 0]
                uialert(app.ClassifierUIFigure,'Error','Training parameters were not saved !')
               
                 return;
            end

            if ~isempty(app.UITableData.Data)
                selectedfortraining = cellfun(@(x) x==1, app.UITableData.Data(:,1));
                selectedfortest = cellfun(@(x) x==1, app.UITableData.Data(:,2));
                nrois = find(selectedfortraining');
                testrois = find(selectedfortest');
                classiObj.trainingset = nrois;
                try
                    if ~isprop(classiObj,'dataset') || ~isstruct(classiObj.dataset)
                        classiObj.dataset = struct('classes', {{}}, 'channels', {{}}, ...
                            'split', struct('train', [], 'val', [], 'test', []));
                    end
                    if ~isfield(classiObj.dataset,'split') || ~isstruct(classiObj.dataset.split)
                        classiObj.dataset.split = struct('train', [], 'val', [], 'test', []);
                    end
                    classiObj.dataset.split.train = nrois;
                    classiObj.dataset.split.val = [];
                    classiObj.dataset.split.test = testrois;
                catch
                end
                app.Data.classiObj = classiObj;
            else
                nrois=classiObj.trainingset;
            end
            if numel(nrois)==0
                  uialert(app.ClassifierUIFigure,'You must select at least one ROI in the Dataset panel  !','Error')
                 return;
            end

            d = [];
            try
                d = uiprogressdlg(app.ClassifierUIFigure, ...
                    'Title', 'Preparing training run', ...
                    'Message', 'Preparing classifier training pipeline...', ...
                    'Indeterminate', 'on', ...
                    'Cancelable', 'off');
                drawnow;
            catch
            end

            try
                if ~isempty(d) && isvalid(d)
                    d.Message = 'Checking classifier inputs and opening pipeline2...';
                    drawnow;
                end
                classifierOpenTrainingPipeline(classiObj, ...
                    'Rois', nrois, ...
                    'OutputPolicy', 'replace', ...
                    'Execution', 'Auto');
                if ~isempty(d) && isvalid(d)
                    close(d);
                end
            catch ME
                if ~isempty(d) && isvalid(d)
                    close(d);
                end
                msg = localGuiErrorMessage(app, ME);
                uialert(app.ClassifierUIFigure, msg, 'Training pipeline failed', 'Icon','error');
            end
        end

        % Menu selected function: SaveclassifierMenu
        function SaveclassifierMenuSelected(app, event)
            disp('Saving classifiers')

            d = uiprogressdlg(app.ClassifierUIFigure,'Title','Please Wait...',...
                'Message','Saving current classifier and trainingset...');
            d.Value=0.33;

            if ~isempty(app.UITableData.Data)
    selectedfortraining = cellfun(@(x) x==1, app.UITableData.Data(:,1));
    app.Data.classiObj.trainingset = find(selectedfortraining');
elseif isempty(app.Data.classiObj.trainingset)
    % fallback une seule fois dans la vie du classif, au tout début
    app.Data.classiObj.trainingset = 1:numel(app.Data.classiObj.roi);
end


           % app.Data.classiObj.trainingParam=app.SettrainingparametersTab.UserData;

            classiSave(app.Data.classiObj);

            d.Value=0.67;
            d.Message='Saving training parameters...';

            %a=app.Data.classiObj.path

            pause(0.1);
            close(d)

            checkStatus(app,true)
        end

        % Callback function
        function ChannelsavailableintrainingsetDropDownValueChanged(app, event)
            value = app.ChannelsavailableintrainingsetDropDown.Value;

            app.ChannelnameusedasinputEditField.Value=value;
            app.Data.classiObj.channelName=value;
            app.Data.classiObj.channel(1)= find(matches(app.ChannelsavailableintrainingsetDropDown.Items,value));
            checkStatus(app,false)
        end

        % Callback function
        function ChannelsavailableintrainingsetDropDown_2ValueChanged(app, event)
            value = app.ChannelsavailableintrainingsetDropDown_2.Value;
            app.AdditionalchannelforclassificationobjectsorregressionEditField.Value=value;
            app.Data.classiObj.channelName2=value;
            app.Data.classiObj.channel(2)= find(matches(app.ChannelsavailableintrainingsetDropDown_2.Items,value));
            checkStatus(app,false)
        end

        % Value changed function: WatershedCheckBox
        function WatershedCheckBoxValueChanged(app, event)
            value = app.WatershedCheckBox.Value;
            str= app.Data.classiObj.outputArg;

            if value==false
                str=setxor(str,'watershed','stable') ;
            else
                str=[str 'watershed'];
            end


            app.Data.classiObj.outputArg=str;
            checkStatus(app,false);
            displayClassi(app);
        end

        % Value changed function: FilteroutsmallobjectsCheckBox
        function FilteroutsmallobjectsCheckBoxValueChanged(app, event)
            value = app.FilteroutsmallobjectsCheckBox.Value;
            str= app.Data.classiObj.outputArg;

            if value==false
                pix=find(matches(str,'sizethreshold'));
                if numel(pix)
                    val=str(pix+1);
                    str=setxor(str,val{1},'stable');
                end
                str=setxor(str,'sizethreshold','stable');
                %       str
            else
                str=[str 'sizethreshold' num2str(app.SizepixelEditField.Value)];
            end

            app.Data.classiObj.outputArg=str;
            checkStatus(app,false);
            displayClassi(app);
        end

        % Value changed function: SizepixelEditField
        function SizepixelEditFieldValueChanged(app, event)
            value = app.SizepixelEditField.Value;
            str= app.Data.classiObj.outputArg;

            pix=find(matches(str,'sizethreshold'));
            if numel(pix)
                val=str(pix+1);
                str{pix+1}=num2str(value);
                app.Data.classiObj.outputArg=str;
                checkStatus(app,false);
                displayClassi(app);
            end

        end

        % Selection changed function: ThresholdingButtonGroup
        function ThresholdingButtonGroupSelectionChanged(app, event)
            selectedButton = app.ThresholdingButtonGroup.SelectedObject;

            str= app.Data.classiObj.outputArg;

            switch selectedButton.Text
                case 'Maximum probability'

                    pix=find(matches(str,'maxproba'));
                    if numel(pix)==0
                        str=[str 'maxproba'];
                    end

                    pix=find(matches(str,'adaptivethreshold'));
                    if numel(pix)
                        str=setxor(str,'adaptivethreshold','stable');
                    end

                    pix=find(matches(str,'threshold'));
                    if numel(pix)
                        val=str(pix+1);
                        str=setxor(str,val{1},'stable');
                        str=setxor(str,'threshold','stable');
                    end

                case 'Adaptive threshold (Otsu method)'

                    pix=find(matches(str,'adaptivethreshold'));
                    if numel(pix)==0
                        str=[str 'adaptivethreshold'];
                    end

                    pix=find(matches(str,'maxproba'));
                    if numel(pix)
                        str=setxor(str,'maxproba','stable');
                    end

                    pix=find(matches(str,'threshold'));

                    if numel(pix)
                        val=str(pix+1);
                        str=setxor(str,val{1},'stable');
                        str=setxor(str,'threshold','stable');
                    end



                case 'Fixed threshold'

                    pix=find(matches(str,'threshold'));

                    if numel(pix)==0
                        str=[str 'threshold' num2str(app.ValueEditField.Value)];
                    end

                    pix=find(matches(str,'maxproba'));
                    if numel(pix)
                        str=setxor(str,'maxproba','stable');
                    end

                    pix=find(matches(str,'adaptivethreshold'));
                    if numel(pix)
                        str=setxor(str,'adaptivethreshold','stable');
                    end

            end

            app.Data.classiObj.outputArg=str;
            checkStatus(app,false)
            displayClassi(app);

        end

        % Value changed function: ValueEditField
        function ValueEditFieldValueChanged(app, event)
            value = app.ValueEditField.Value;

            str= app.Data.classiObj.outputArg;

            pix=find(matches(str,'threshold'));
            if numel(pix)
                val=str(pix+1);
                str{pix+1}=num2str(value);
                app.Data.classiObj.outputArg=str;
                checkStatus(app,false)
                displayClassi(app);
            end

        end

        % Menu selected function: LoadclassifierMenu
        function LoadclassifierMenuSelected(app, event)

            classiObj=app.Data.classiObj;
            classifier=classiObj.loadClassifier;
            %assignin('base',classiObj.strid,classifier);
            checkStatus(app)
        end

        % Menu selected function: CheckstatusMenu
        function CheckstatusMenuSelected(app, event)
            checkStatus(app)
        end

        % Button pushed function: SelectButton
        function SelectButtonPushed(app, event)
            if app.isRefreshing, return; end

            classiObj=app.Data.classiObj;
            value=app.ChannelListBox.Value;

            if numel(app.ChannelListBoxSel.Items)==0 | matches(app.ChannelListBoxSel.Items,value)==false
                app.ChannelListBoxSel.Items=[app.ChannelListBoxSel.Items value];
            end

            classiObj.channelName= app.ChannelListBoxSel.Items;
            app.Data.classiObj=classiObj;
            displayClassi(app);

        end

        % Button pushed function: DeSelectButton
        function DeSelectButtonPushed(app, event)
            if app.isRefreshing, return; end

            classiObj=app.Data.classiObj;
            value=app.ChannelListBoxSel.Value;


            app.ChannelListBoxSel.Items=setxor(app.ChannelListBoxSel.Items,value);

            classiObj.channelName= app.ChannelListBoxSel.Items;
            app.Data.classiObj=classiObj;
            displayClassi(app);
        end

        % Callback function
        function BackupcurrentclassifierversionMenuSelected(app, event)
           disp('Backuping current version of the classifier')

            d = uiprogressdlg(app.ClassifierUIFigure,'Title','Please Wait...',...
                'Message','Saving current classifier model and network');
            d.Value=0.33;

            if numel(app.UITableData.Data)
                selectedfortraining=cellfun(@(x) x==1,app.UITableData.Data(:,1));
                app.Data.classiObj.trainingset=find(selectedfortraining');
            else
                app.Data.classiObj.trainingset =1:numel(app.Data.classiObj.roi);
            end

            app.Data.classiObj.trainingParam=app.SettrainingparametersTab.UserData;

            app.Data.classiObj.bk; % backs up classification and classifier
            
            d.Value=0.67;
            d.Message='Saving training parameters...';

            %a=app.Data.classiObj.path


            pause(0.5);
            close(d)

            checkStatus(app,true)
            
            startupFcn(app,app.Data.classiObj);

            displayProperties(app)
            
        end

        % Menu selected function: RestorepreviousclassifierMenu
        function RestorepreviousclassifierMenuSelected(app, event)
           bk = classifierBKGUI(app, app.Data.classiObj);
    uiwait(bk.TrainingrusselectionUIFigure);   % attendre que BKGUI ferme (restore ou cancel)

    % Si BKGUI a été fermé sans restore, bk peut être invalid -> protège
    didRestore = false;
    try
        didRestore = bk.Result.didRestore;
    catch
    end

    if didRestore
        app.refreshAll('RebuildTrainingParam', true);
    end
        end

        % Value changed function: SelectROIsEditField
        function SelectROIsEditFieldValueChanged(app, event)
            value = app.SelectROIsEditField.Value;
            
            value=str2num(value);
            
            t=size(app.UITableData.Data,1);
            value=intersect(value,1:t);
            
            if numel(value)==0
                return
            end
            
            dt=cell(1,t);
            dt(:)={false};
            dt(value)={true}; 
          
            app.UITableData.Data(:,1)=dt';

            selectedfortraining=cellfun(@(x) x==1,app.UITableData.Data(:,1));
            app.Data.classiObj.trainingset=find(selectedfortraining');
            checkStatus(app,false)
            displayData(app);
            
        end

        % Value changed function: ShuffleROIsfractionEditField
        function ShuffleROIsfractionEditFieldValueChanged(app, event)
            value = app.ShuffleROIsfractionEditField.Value;
            
            value=str2num(value);
            
            t=size(app.UITableData.Data,1);
            id=randperm(t);
            
            value=min(value,1);
            value=max(value,0);
            
            dt=cell(1,t);
            dt(:)={false};
            
            dt(id(1:round(value*t)))={true};
  
            app.UITableData.Data(:,1)=dt';

            selectedfortraining=cellfun(@(x) x==1,app.UITableData.Data(:,1));
            app.Data.classiObj.trainingset=find(selectedfortraining');
            checkStatus(app,false)
            displayData(app);
            
        end

        % Button down function: ClassifierPropertiesTab
        function ClassifierPropertiesTabButtonDown(app, event)
          %  disp('ok')
        %h = app.TabGroup.Children(2)
       % pause(1)
       % app.TabGroup.SelectedTab = h;
       displayData(app);
       displayProperties(app)
        end

        % Button pushed function: ManageROIsformattrainingsetButton
        function ManageROIsformattrainingsetButtonPushed(app, event)
            h = app.TabGroup.Children(4);
            app.TabGroup.SelectedTab = h;
            displayData(app);
        end

        % Button pushed function: BackupButton
        function BackupButtonPushed(app, event)
             app.BackupcurrentclassifierversionMenuSelected;
        end

        % Button pushed function: RestoreButton
        function RestoreButtonPushed(app, event)
           bk = classifierBKGUI(app, app.Data.classiObj);
    uiwait(bk.TrainingrusselectionUIFigure);

    didRestore = false;
    try
        didRestore = bk.Result.didRestore;
    catch
    end

    if didRestore
        app.refreshAll('RebuildTrainingParam', true);
    end
        end

        % Button pushed function: OpenfolderButton
        function OpenfolderButtonPushed(app, event)
            pth=app.Data.classiObj.getPath;
            if ispc
            eval(['!explorer "' pth '"']);
            else
disp('unable to display folder with this OS');
            end
        end

        % Button pushed function: DisplaysampleimagesButton
        function DisplaysampleimagesButtonPushed(app, event)
            classiObj=app.Data.classiObj;

            [catCell, ~] = classiNormalizeCategory(classiObj.category);
            if ~strcmp(char(string(catCell{1})),'Timeseries')
                [ k, himg]=classiObj.displayFormattedTrainingSet('Display','Nimages',9);
            else
                uialert(app.ClassifierUIFigure,'This is not avaiable for this type of classifier','Error')
            end
        end

        % Button pushed function: SetclassfierparametersButton
        function SetclassfierparametersButtonPushed(app, event)
                  h = app.TabGroup.Children(2);
            app.TabGroup.SelectedTab = h;
            displayData(app);
        end

        % Button pushed function: SettrainingparametersButton
        function SettrainingparametersButtonPushed(app, event)
                  h = app.TabGroup.Children(3);
            app.TabGroup.SelectedTab = h;
            displayData(app);
        end

        % Value changed function: UsercommentsEditField_2
        function UsercommentsEditField_2ValueChanged(app, event)
            value = app.UsercommentsEditField_2.Value;
            app.Data.classiObj.description{2}=value;
             checkStatus(app,false)
            displayProperties(app);
        end

        % Button pushed function: FormattrainingsetfortrainingButton
        function FormattrainingsetfortrainingButtonPushed(app, event)
            FormattrainingsetMenuSelected(app, event);
        end

        % Button pushed function: TrainClassifierButton
        function TrainClassifierButtonPushed(app, event)
            TrainClassifierMenuSelected(app, event)
        end

        % Button pushed function: ValidateclassifierButton
        function ValidateclassifierButtonPushed(app, event)
            ValidateclassifierusingtestsetMenuSelected(app, event);
        end

        % Button pushed function: DisplayclassifierstatisticsButton
        function DisplayclassifierstatisticsButtonPushed(app, event)
            DisplaystatisticsMenuSelected(app, event)
        end

        % Button pushed function: displayROIsusedforvalidationButton
        function displayROIsusedforvalidationButtonPushed(app, event)
              h = app.TabGroup.Children(4);
            app.TabGroup.SelectedTab = h;
            displayData(app);
        end

        % Button pushed function: SaveclassifierButton
        function SaveclassifierButtonPushed(app, event)
            SaveclassifierMenuSelected(app, event)
        end

        % Callback function
        function CustomboundsCheckBoxValueChanged(app, event)
            value = app.CustomboundsCheckBox.Value;
            
            if value
                app.MaxframeEditField.Visible="on";
                app.MinframeEditField.Visible="on";
                app.ApplyrulestoallROIsButton.Visible="on";
                app.SetboundsselectionrulesButton.Visible="on";
            else
                 app.MaxframeEditField.Visible="off";
                app.MinframeEditField.Visible="off";
                app.ApplyrulestoallROIsButton.Visible="off";
                app.SetboundsselectionrulesButton.Visible="off";
            end
        end

        % Button pushed function: SetboundsselectionrulesButton
        function SetboundsselectionrulesButtonPushed(app, event)
            classiObj = app.Data.classiObj;
            selectedIndices = selectedAnnotationRoiIndices(app);
            selection = trainingFrameBoundsDialog( ...
                app.ClassifierUIFigure, classiObj, selectedIndices);
            if ~selection.accepted, return; end
            try
                report = trainingBounds.apply(classiObj, ...
                    selection.roiIndices, selection.mode, ...
                    'Bounds', selection.bounds);
            catch ME
                uialert(app.ClassifierUIFigure, ME.message, ...
                    'Could not set training frames', 'Icon', 'error');
                return;
            end
            displayData(app);
            checkStatus(app,false);
            if strcmp(report.mode, 'per_roi')
                message = ['Per-ROI editing is active. Edit the Frame bounds ' ...
                    'cells directly; enter "all" to clear one ROI.'];
            elseif strcmp(report.mode, 'all')
                message = sprintf('All frames selected for %d ROI(s).', ...
                    report.count);
            else
                message = sprintf('Shared frame range applied to %d ROI(s).', ...
                    report.count);
            end
            uialert(app.ClassifierUIFigure, message, ...
                'Training frames updated', 'Icon', 'success');
        end

        % Button pushed function: DisplayaugmentedimagesButton
        function DisplayaugmentedimagesButtonPushed(app, event)
            classiObj = app.Data.classiObj;

    % 1) Vérifier que les paramètres de training sont sauvegardés
    if isequal(app.StatusSaved.Color, [1 0 0])
        uialert(app.ClassifierUIFigure, ...
            'Training parameters were not saved !', ...
            'Error');
        return;
    end

    % 2) Vérifier qu''il y a au moins une ROI dans le trainingset
    nrois = classiObj.trainingset;
    if numel(nrois) == 0
        uialert(app.ClassifierUIFigure, ...
            'You must select at least one ROI in the Dataset panel !', ...
            'Error');
        return;
    end

    % 3) Progress dialog
    d = uiprogressdlg(app.ClassifierUIFigure, ...
        'Title',   'Please wait...', ...
        'Message', 'Preparing augmentation preview...', ...
        'Indeterminate', 'on');  % plus simple ici, ou bien tu gères Value

    try
        % Optionnel : mise à jour de l'état de l''app
        checkStatus(app);

        % 4) Appel de la méthode de classi
        %    - Mode 'Augmentation' pour les deux figures (paires + types)
        %    - NAugPerType peut être ajusté
        classiObj.displayFormattedTrainingSet('Mode','Augmentation', ...
                                              'NAugPerType',4);

        % Si tu préfères voir aussi le montage RAW :
        % classiObj.displayFormattedTrainingSet('Display','Mode','raw');

    catch ME
        % En cas d'erreur on ferme la progress bar et on remonte l'erreur
        close(d);
        rethrow(ME);
    end

    % 5) Fin : on ferme la progress bar
    close(d);
        end

        % Callback function
        function DownValueChanged(app, event)
            value = app.PostprocessingDropDown.Value;
            
        end

        % Button pushed function: GenerateDraftButton
        function GenerateDraftButtonPushed(app, event)
            indices = selectedAnnotationRoiIndices(app);
            if isempty(indices)
                uialert(app.ClassifierUIFigure, 'Select at least one ROI.', ...
                    'Initialize ground truth');
                return;
            end
            try
                firstSession = annotationSessionForClassifier( ...
                    app, app.Data.classiObj, indices(1));
                catalog = firstSession.initializationCatalog();
                catalogs = {catalog};
                hasExistingPrediction = catalog.prediction.available;
                for predictionRoiIndex = indices(2:end)
                    predictionSession = annotationSessionForClassifier( ...
                        app, app.Data.classiObj, predictionRoiIndex);
                    predictionCatalog = predictionSession.initializationCatalog();
                    catalogs{end+1} = predictionCatalog; %#ok<AGROW>
                    hasExistingPrediction = hasExistingPrediction || ...
                        predictionCatalog.prediction.available;
                end
                catalog = annotationCommonInitializationCatalog(catalogs);
                predictionPlan = [];
                activeModel = annotationActiveModelInfo( ...
                    app.Data.classiObj, indices);
                if activeModel.supported
                    try
                        predictionPlan = classifierPredictForAnnotation( ...
                            app.Data.classiObj, indices, 'PlanOnly', true);
                        activeModel = annotationActiveModelInfo( ...
                            app.Data.classiObj, indices, predictionPlan);
                    catch ME
                        activeModel.inputsResolved = false;
                        activeModel.issues = {ME.message};
                    end
                end
                [recipe, hasInitializationSource] = ...
                    annotationInitializationDefaultRecipe(catalog, activeModel);
                if ~hasInitializationSource
                    uialert(app.ClassifierUIFigure, ...
                        annotationInitializationUnavailableMessage(), ...
                        'Existing prediction required', 'Icon', 'info');
                    return;
                end
                rows = annotationSummaryRows(app, app.Data.classiObj, indices);
                overwrite = any(~strcmpi(string({rows.status}), 'missing'));
                if isempty(event)
                    accepted = true;
                else
                    [recipe, accepted] = annotationInitializationDialog( ...
                        app.ClassifierUIFigure, catalog, ...
                        'RoiCount', numel(indices), 'HasExistingGT', overwrite, ...
                        'ActiveModel', activeModel);
                end
                if ~accepted, return; end
            catch ME
                uialert(app.ClassifierUIFigure, ME.message, ...
                    'Initialize ground truth');
                return;
            end
            if strcmp(recipe.mode, 'run_prediction')
                selectedInput = '';
                try, selectedInput = char(string(recipe.inputChannelName)); catch, end
                if ~isempty(selectedInput)
                    selectedOverride = struct( ...
                        'inputChannelName', selectedInput);
                    try
                        predictionPlan = classifierPredictForAnnotation( ...
                            app.Data.classiObj, indices, 'PlanOnly', true, ...
                            'InputOverrides', selectedOverride);
                    catch ME
                        uialert(app.ClassifierUIFigure, ME.message, ...
                            'Cannot prepare CellposeSAM input', 'Icon', 'error');
                        return;
                    end
                end
                [predictionPlan, inputOverrides, ready] = ...
                    annotationResolvePredictionInputs( ...
                    app.ClassifierUIFigure, app.Data.classiObj, indices, ...
                    predictionPlan);
                if ~ready, return; end
                if ~isempty(selectedInput)
                    inputOverrides.inputChannelName = selectedInput;
                end
                uiText = annotationPredictionUiText(activeModel, overwrite);
                if overwrite || hasExistingPrediction
                    choice = uiconfirm(app.ClassifierUIFigure, ...
                        uiText.confirmation, uiText.confirmTitle, ...
                        'Options', {'Cancel','Apply and replace'}, ...
                        'DefaultOption', 1, 'CancelOption', 1, 'Icon', 'warning');
                    if ~strcmp(choice, 'Apply and replace'), return; end
                end
                progress = uiprogressdlg(app.ClassifierUIFigure, ...
                    'Title', uiText.progressTitle, ...
                    'Message', uiText.progressMessage, ...
                    'Indeterminate', 'on', 'Cancelable', 'off');
                try
                    arguments = {'InitializeGT', true, ...
                        'OverwriteGT', overwrite, 'Save', true, ...
                        'Progress', progress};
                    if ~isempty(fieldnames(inputOverrides))
                        arguments = [arguments {'InputOverrides', inputOverrides}];
                    end
                    report = classifierPredictForAnnotation( ...
                        app.Data.classiObj, indices, arguments{:});
                    if isvalid(progress), close(progress); end
                    checkStatus(app,false);
                    displayData(app, 'full');
                    uialert(app.ClassifierUIFigure, sprintf( ...
                        uiText.classifierSuccess, ...
                        numel(report.items), ...
                        char(string(report.runId))), ...
                        uiText.successTitle, ...
                        'Icon', 'success');
                catch ME
                    if isvalid(progress), close(progress); end
                    uialert(app.ClassifierUIFigure, ME.message, ...
                        'Prediction-based GT initialization failed', ...
                        'Icon', 'error');
                end
                return;
            end
            errors = strings(0,1);
            changed = 0;
            progress = [];
            if numel(indices) > 1
                progress = uiprogressdlg(app.ClassifierUIFigure, ...
                    'Title', 'Initialize ground truth', ...
                    'Message', 'Preparing selected ROIs...', 'Value', 0);
            end
            for roiIndex = indices
                try
                    session = annotationSessionForClassifier( ...
                        app, app.Data.classiObj, roiIndex);
                    session.initialize(recipe, 'Overwrite', overwrite);
                    changed = changed + 1;
                catch ME
                    errors(end+1) = sprintf('ROI %d: %s', roiIndex, ME.message); %#ok<AGROW>
                end
                if ~isempty(progress) && isvalid(progress)
                    position = find(indices == roiIndex, 1, 'first');
                    progress.Value = position / numel(indices);
                    progress.Message = sprintf('Processed ROI %d/%d', ...
                        position, numel(indices));
                    drawnow limitrate;
                end
            end
            if ~isempty(progress) && isvalid(progress), close(progress); end
            checkStatus(app,false);
            displayData(app);
            if ~isempty(errors)
                uialert(app.ClassifierUIFigure, strjoin(errors, newline), ...
                    'GT initialization incomplete', 'Icon', 'warning');
            elseif changed > 0
                uialert(app.ClassifierUIFigure, ...
                    sprintf('Initialized GT for %d ROI(s).', changed), ...
                    'Ground truth initialized', 'Icon', 'success');
            end
        end

        % Button pushed function: StartBlankGTButton
        function StartBlankGTButtonPushed(app, event)
            indices = selectedAnnotationRoiIndices(app);
            if isempty(indices)
                uialert(app.ClassifierUIFigure, 'Select at least one ROI.', ...
                    'Start blank GT');
                return;
            end
            overwrite = false;
            try
                rows = annotationSummaryRows(app, app.Data.classiObj, indices);
                overwrite = any(~strcmpi(string({rows.status}), 'missing'));
            catch
            end
            if overwrite
                choice = uiconfirm(app.ClassifierUIFigure, ...
                    ['At least one selected ROI already contains draft or ready GT. ' ...
                    'Replace it with blank GT?'], 'Replace ground truth', ...
                    'Options', {'Cancel','Replace GT'}, 'DefaultOption', 1, ...
                    'CancelOption', 1, 'Icon', 'warning');
                if ~strcmp(choice, 'Replace GT'), return; end
            end
            errors = strings(0,1);
            changed = 0;
            for roiIndex = indices
                try
                    session = annotationSessionForClassifier( ...
                        app, app.Data.classiObj, roiIndex);
                    session.startBlank('Overwrite', overwrite);
                    changed = changed + 1;
                catch ME
                    errors(end+1) = sprintf('ROI %d: %s', roiIndex, ME.message); %#ok<AGROW>
                end
            end
            checkStatus(app,false);
            displayData(app);
            if ~isempty(errors)
                uialert(app.ClassifierUIFigure, strjoin(errors, newline), ...
                    'Blank GT incomplete', 'Icon', 'warning');
            elseif changed > 0
                uialert(app.ClassifierUIFigure, ...
                    sprintf('Created blank GT for %d ROI(s).', changed), ...
                    'Blank GT created', 'Icon', 'success');
            end
        end

        % Button pushed function: RefreshAnnotationStatusButton
        function RefreshAnnotationStatusButtonPushed(app, event)
            displayData(app, 'full');
        end

        % Value changed function: AnnotationFilterDropDown
        function AnnotationFilterDropDownValueChanged(app, event)
            app.Data.selected = [];
            app.UITableData.Selection = [];
            displayData(app);
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Get the file path for locating images
            pathToMLAPP = fileparts(mfilename('fullpath'));

            % Create ClassifierUIFigure and hide until all components are created
            app.ClassifierUIFigure = uifigure('Visible', 'off');
            app.ClassifierUIFigure.Position = [100 100 1104 676];
            app.ClassifierUIFigure.Name = 'Classifier';
            app.ClassifierUIFigure.Icon = fullfile(pathToMLAPP, 'brain.png');
            app.ClassifierUIFigure.CloseRequestFcn = createCallbackFcn(app, @ClassifierUIFigureCloseRequest, true);

            % Create FileMenu
            app.FileMenu = uimenu(app.ClassifierUIFigure);
            app.FileMenu.Text = 'File';

            % Create SaveclassifierMenu
            app.SaveclassifierMenu = uimenu(app.FileMenu);
            app.SaveclassifierMenu.MenuSelectedFcn = createCallbackFcn(app, @SaveclassifierMenuSelected, true);
            app.SaveclassifierMenu.Text = 'Save classifier';

            % Create RestorepreviousclassifierMenu
            app.RestorepreviousclassifierMenu = uimenu(app.FileMenu);
            app.RestorepreviousclassifierMenu.MenuSelectedFcn = createCallbackFcn(app, @RestorepreviousclassifierMenuSelected, true);
            app.RestorepreviousclassifierMenu.Text = 'Restore previous classifier...';

            % Create ClassifierMenu
            app.ClassifierMenu = uimenu(app.ClassifierUIFigure);
            app.ClassifierMenu.Text = 'Classifier';

            % Create FormattrainingsetMenu
            app.FormattrainingsetMenu = uimenu(app.ClassifierMenu);
            app.FormattrainingsetMenu.MenuSelectedFcn = createCallbackFcn(app, @FormattrainingsetMenuSelected, true);
            app.FormattrainingsetMenu.Text = 'Format training set...';

            % Create TrainClassifierMenu
            app.TrainClassifierMenu = uimenu(app.ClassifierMenu);
            app.TrainClassifierMenu.MenuSelectedFcn = createCallbackFcn(app, @TrainClassifierMenuSelected, true);
            app.TrainClassifierMenu.Text = 'Train Classifier...';

            % Create ValidateclassifierusingtestsetMenu
            app.ValidateclassifierusingtestsetMenu = uimenu(app.ClassifierMenu);
            app.ValidateclassifierusingtestsetMenu.MenuSelectedFcn = createCallbackFcn(app, @ValidateclassifierusingtestsetMenuSelected, true);
            app.ValidateclassifierusingtestsetMenu.Text = 'Validate classifier using test set...';

            % Create DisplaystatisticsMenu
            app.DisplaystatisticsMenu = uimenu(app.ClassifierMenu);
            app.DisplaystatisticsMenu.MenuSelectedFcn = createCallbackFcn(app, @DisplaystatisticsMenuSelected, true);
            app.DisplaystatisticsMenu.Text = 'Display statistics...';

            % Create LoadclassifierMenu
            app.LoadclassifierMenu = uimenu(app.ClassifierMenu);
            app.LoadclassifierMenu.MenuSelectedFcn = createCallbackFcn(app, @LoadclassifierMenuSelected, true);
            app.LoadclassifierMenu.Text = 'Load classifier';

            % Create CheckstatusMenu
            app.CheckstatusMenu = uimenu(app.ClassifierMenu);
            app.CheckstatusMenu.MenuSelectedFcn = createCallbackFcn(app, @CheckstatusMenuSelected, true);
            app.CheckstatusMenu.Separator = 'on';
            app.CheckstatusMenu.Text = 'Check status...';

            % Create TabGroup
            app.TabGroup = uitabgroup(app.ClassifierUIFigure);
            app.TabGroup.Position = [16 53 1066 614];

            % Create ClassifierPropertiesTab
            app.ClassifierPropertiesTab = uitab(app.TabGroup);
            app.ClassifierPropertiesTab.Title = 'Classifier Properties';
            app.ClassifierPropertiesTab.ButtonDownFcn = createCallbackFcn(app, @ClassifierPropertiesTabButtonDown, true);

            % Create ClassifierquickinfoPanel
            app.ClassifierquickinfoPanel = uipanel(app.ClassifierPropertiesTab);
            app.ClassifierquickinfoPanel.Title = 'Classifier quick info';
            app.ClassifierquickinfoPanel.Position = [38 440 1020 140];

            % Create PathEditFieldLabel
            app.PathEditFieldLabel = uilabel(app.ClassifierquickinfoPanel);
            app.PathEditFieldLabel.HorizontalAlignment = 'right';
            app.PathEditFieldLabel.Position = [11 91 30 22];
            app.PathEditFieldLabel.Text = 'Path';

            % Create PathEditField
            app.PathEditField = uieditfield(app.ClassifierquickinfoPanel, 'text');
            app.PathEditField.Editable = 'off';
            app.PathEditField.Position = [56 91 840 22];

            % Create TypeEditFieldLabel
            app.TypeEditFieldLabel = uilabel(app.ClassifierquickinfoPanel);
            app.TypeEditFieldLabel.HorizontalAlignment = 'right';
            app.TypeEditFieldLabel.Position = [9 65 32 22];
            app.TypeEditFieldLabel.Text = 'Type';

            % Create TypeEditField
            app.TypeEditField = uieditfield(app.ClassifierquickinfoPanel, 'text');
            app.TypeEditField.Editable = 'off';
            app.TypeEditField.Position = [56 65 388 22];

            % Create ClassesEditFieldLabel
            app.ClassesEditFieldLabel = uilabel(app.ClassifierquickinfoPanel);
            app.ClassesEditFieldLabel.HorizontalAlignment = 'right';
            app.ClassesEditFieldLabel.Position = [-2 39 48 22];
            app.ClassesEditFieldLabel.Text = 'Classes';

            % Create ClassesEditField
            app.ClassesEditField = uieditfield(app.ClassifierquickinfoPanel, 'text');
            app.ClassesEditField.Editable = 'off';
            app.ClassesEditField.Position = [56 39 388 22];

            % Create backupversionsEditFieldLabel
            app.backupversionsEditFieldLabel = uilabel(app.ClassifierquickinfoPanel);
            app.backupversionsEditFieldLabel.HorizontalAlignment = 'right';
            app.backupversionsEditFieldLabel.Position = [1 9 96 22];
            app.backupversionsEditFieldLabel.Text = 'backup versions:';

            % Create backupversionsEditField
            app.backupversionsEditField = uieditfield(app.ClassifierquickinfoPanel, 'text');
            app.backupversionsEditField.Editable = 'off';
            app.backupversionsEditField.Position = [100 9 39 22];

            % Create RestoreButton
            app.RestoreButton = uibutton(app.ClassifierquickinfoPanel, 'push');
            app.RestoreButton.ButtonPushedFcn = createCallbackFcn(app, @RestoreButtonPushed, true);
            app.RestoreButton.Position = [209 8 57 22];
            app.RestoreButton.Text = 'Restore...';

            % Create BackupButton
            app.BackupButton = uibutton(app.ClassifierquickinfoPanel, 'push');
            app.BackupButton.ButtonPushedFcn = createCallbackFcn(app, @BackupButtonPushed, true);
            app.BackupButton.Position = [144 9 58 22];
            app.BackupButton.Text = 'Back up!';

            % Create OpenfolderButton
            app.OpenfolderButton = uibutton(app.ClassifierquickinfoPanel, 'push');
            app.OpenfolderButton.ButtonPushedFcn = createCallbackFcn(app, @OpenfolderButtonPushed, true);
            app.OpenfolderButton.Position = [907 89 100 25];
            app.OpenfolderButton.Text = 'Open folder...';

            % Create SetclassfierparametersButton
            app.SetclassfierparametersButton = uibutton(app.ClassifierquickinfoPanel, 'push');
            app.SetclassfierparametersButton.ButtonPushedFcn = createCallbackFcn(app, @SetclassfierparametersButtonPushed, true);
            app.SetclassfierparametersButton.Tooltip = {'Click his button to define the type of classifier'};
            app.SetclassfierparametersButton.Position = [276 8 166 24];
            app.SetclassfierparametersButton.Text = 'Set classfier parameters...';

            % Create UsercommentsEditFieldLabel
            app.UsercommentsEditFieldLabel = uilabel(app.ClassifierquickinfoPanel);
            app.UsercommentsEditFieldLabel.HorizontalAlignment = 'right';
            app.UsercommentsEditFieldLabel.Position = [446 63 90 22];
            app.UsercommentsEditFieldLabel.Text = 'User comments';

            % Create UsercommentsEditField
            app.UsercommentsEditField = uieditfield(app.ClassifierquickinfoPanel, 'text');
            app.UsercommentsEditField.Editable = 'off';
            app.UsercommentsEditField.Position = [550 9 458 76];

            % Create TrainingvalidationsetPanel
            app.TrainingvalidationsetPanel = uipanel(app.ClassifierPropertiesTab);
            app.TrainingvalidationsetPanel.Title = 'Training & validation set';
            app.TrainingvalidationsetPanel.Position = [38 255 1020 170];

            % Create NumberofROIsusedfortrainingvalidationLabel
            app.NumberofROIsusedfortrainingvalidationLabel = uilabel(app.TrainingvalidationsetPanel);
            app.NumberofROIsusedfortrainingvalidationLabel.HorizontalAlignment = 'right';
            app.NumberofROIsusedfortrainingvalidationLabel.Position = [-2 121 255 22];
            app.NumberofROIsusedfortrainingvalidationLabel.Text = 'Number of ROIs used for training or validation:';

            % Create NumberROIS
            app.NumberROIS = uieditfield(app.TrainingvalidationsetPanel, 'text');
            app.NumberROIS.Editable = 'off';
            app.NumberROIS.Tooltip = {'You must have at least one ROI to proceed with the training procedure'};
            app.NumberROIS.Position = [268 121 100 22];

            % Create ManageROIsformattrainingsetButton
            app.ManageROIsformattrainingsetButton = uibutton(app.TrainingvalidationsetPanel, 'push');
            app.ManageROIsformattrainingsetButton.ButtonPushedFcn = createCallbackFcn(app, @ManageROIsformattrainingsetButtonPushed, true);
            app.ManageROIsformattrainingsetButton.Position = [778 120 230 24];
            app.ManageROIsformattrainingsetButton.Text = 'Manage ROIs & format trainingset...';

            % Create NumberofROIsusedfortrainingvalidationLabel_2
            app.NumberofROIsusedfortrainingvalidationLabel_2 = uilabel(app.TrainingvalidationsetPanel);
            app.NumberofROIsusedfortrainingvalidationLabel_2.HorizontalAlignment = 'right';
            app.NumberofROIsusedfortrainingvalidationLabel_2.Position = [395 121 228 22];
            app.NumberofROIsusedfortrainingvalidationLabel_2.Text = 'Fraction of ROIs for training vs validation:';

            % Create NumberROIS_2
            app.NumberROIS_2 = uieditfield(app.TrainingvalidationsetPanel, 'text');
            app.NumberROIS_2.Editable = 'off';
            app.NumberROIS_2.Tooltip = {'Some ROIs should be left for th validaton procedure'};
            app.NumberROIS_2.Position = [638 122 100 22];

            % Create formatLabel
            app.formatLabel = uilabel(app.TrainingvalidationsetPanel);
            app.formatLabel.VerticalAlignment = 'top';
            app.formatLabel.Tooltip = {'If there is no formated image, youmust formt the training set bfor traning.'};
            app.formatLabel.Position = [318 -8 280 113];
            app.formatLabel.Text = 'formatLabel';

            % Create DisplaysampleimagesButton
            app.DisplaysampleimagesButton = uibutton(app.TrainingvalidationsetPanel, 'push');
            app.DisplaysampleimagesButton.ButtonPushedFcn = createCallbackFcn(app, @DisplaysampleimagesButtonPushed, true);
            app.DisplaysampleimagesButton.WordWrap = 'on';
            app.DisplaysampleimagesButton.Tooltip = {'Format training set is mandatory before training; Press this button if there are no formatted images'};
            app.DisplaysampleimagesButton.Position = [12 13 115 56];
            app.DisplaysampleimagesButton.Text = 'Display sample images';

            % Create SettrainingparametersButton
            app.SettrainingparametersButton = uibutton(app.TrainingvalidationsetPanel, 'push');
            app.SettrainingparametersButton.ButtonPushedFcn = createCallbackFcn(app, @SettrainingparametersButtonPushed, true);
            app.SettrainingparametersButton.Position = [778 87 229 24];
            app.SettrainingparametersButton.Text = 'Set training parameters...';

            % Create AvailableformattedtrainingsetLabel
            app.AvailableformattedtrainingsetLabel = uilabel(app.TrainingvalidationsetPanel);
            app.AvailableformattedtrainingsetLabel.HorizontalAlignment = 'center';
            app.AvailableformattedtrainingsetLabel.WordWrap = 'on';
            app.AvailableformattedtrainingsetLabel.Position = [11 72 314 57];
            app.AvailableformattedtrainingsetLabel.Text = 'Available formatted trainingset: ';

            % Create TrainClassifierButton
            app.TrainClassifierButton = uibutton(app.TrainingvalidationsetPanel, 'push');
            app.TrainClassifierButton.ButtonPushedFcn = createCallbackFcn(app, @TrainClassifierButtonPushed, true);
            app.TrainClassifierButton.Position = [780 13 227 65];
            app.TrainClassifierButton.Text = 'Train Classifier...';

            % Create DisplayaugmentedimagesButton
            app.DisplayaugmentedimagesButton = uibutton(app.TrainingvalidationsetPanel, 'push');
            app.DisplayaugmentedimagesButton.ButtonPushedFcn = createCallbackFcn(app, @DisplayaugmentedimagesButtonPushed, true);
            app.DisplayaugmentedimagesButton.Position = [137 15 160 51];
            app.DisplayaugmentedimagesButton.Text = 'Display augmented images';

            % Create OutputandstatisticsPanel
            app.OutputandstatisticsPanel = uipanel(app.ClassifierPropertiesTab);
            app.OutputandstatisticsPanel.Title = 'Output and statistics';
            app.OutputandstatisticsPanel.Position = [38 65 1020 174];

            % Create DisplayclassifierstatisticsButton
            app.DisplayclassifierstatisticsButton = uibutton(app.OutputandstatisticsPanel, 'push');
            app.DisplayclassifierstatisticsButton.ButtonPushedFcn = createCallbackFcn(app, @DisplayclassifierstatisticsButtonPushed, true);
            app.DisplayclassifierstatisticsButton.Position = [780 10 227 48];
            app.DisplayclassifierstatisticsButton.Text = 'Display classifier statistics....';

            % Create ValidateclassifierButton
            app.ValidateclassifierButton = uibutton(app.OutputandstatisticsPanel, 'push');
            app.ValidateclassifierButton.ButtonPushedFcn = createCallbackFcn(app, @ValidateclassifierButtonPushed, true);
            app.ValidateclassifierButton.Position = [778 67 232 49];
            app.ValidateclassifierButton.Text = 'Validate classifier....';

            % Create displayROIsusedforvalidationButton
            app.displayROIsusedforvalidationButton = uibutton(app.OutputandstatisticsPanel, 'push');
            app.displayROIsusedforvalidationButton.ButtonPushedFcn = createCallbackFcn(app, @displayROIsusedforvalidationButtonPushed, true);
            app.displayROIsusedforvalidationButton.Position = [774 124 230 24];
            app.displayROIsusedforvalidationButton.Text = 'display ROIs used for validation...';

            % Create NumberofannotatedROIsEditFieldLabel
            app.NumberofannotatedROIsEditFieldLabel = uilabel(app.OutputandstatisticsPanel);
            app.NumberofannotatedROIsEditFieldLabel.HorizontalAlignment = 'right';
            app.NumberofannotatedROIsEditFieldLabel.Position = [7 123 152 22];
            app.NumberofannotatedROIsEditFieldLabel.Text = 'Number of annotated ROIs:';

            % Create NumberofannotatedROIsEditField
            app.NumberofannotatedROIsEditField = uieditfield(app.OutputandstatisticsPanel, 'text');
            app.NumberofannotatedROIsEditField.Editable = 'off';
            app.NumberofannotatedROIsEditField.Position = [174 123 100 22];

            % Create AnnotatedROIswithvalidationdataEditFieldLabel
            app.AnnotatedROIswithvalidationdataEditFieldLabel = uilabel(app.OutputandstatisticsPanel);
            app.AnnotatedROIswithvalidationdataEditFieldLabel.HorizontalAlignment = 'right';
            app.AnnotatedROIswithvalidationdataEditFieldLabel.Position = [-2 94 201 22];
            app.AnnotatedROIswithvalidationdataEditFieldLabel.Text = 'Annotated ROIs with validation data:';

            % Create AnnotatedROIswithvalidationdataEditField
            app.AnnotatedROIswithvalidationdataEditField = uieditfield(app.OutputandstatisticsPanel, 'text');
            app.AnnotatedROIswithvalidationdataEditField.Editable = 'off';
            app.AnnotatedROIswithvalidationdataEditField.Position = [212 94 100 22];

            % Create Label_3
            app.Label_3 = uilabel(app.ClassifierPropertiesTab);
            app.Label_3.FontSize = 24;
            app.Label_3.FontWeight = 'bold';
            app.Label_3.Position = [12 550 25 31];
            app.Label_3.Text = '1';

            % Create Label_4
            app.Label_4 = uilabel(app.ClassifierPropertiesTab);
            app.Label_4.FontSize = 24;
            app.Label_4.FontWeight = 'bold';
            app.Label_4.Position = [11 397 25 31];
            app.Label_4.Text = '2';

            % Create Label_5
            app.Label_5 = uilabel(app.ClassifierPropertiesTab);
            app.Label_5.FontSize = 24;
            app.Label_5.FontWeight = 'bold';
            app.Label_5.Position = [9 216 25 31];
            app.Label_5.Text = '3';

            % Create SetclassifierparametersTab
            app.SetclassifierparametersTab = uitab(app.TabGroup);
            app.SetclassifierparametersTab.Title = 'Set classifier parameters';

            % Create TypeLabel
            app.TypeLabel = uilabel(app.SetclassifierparametersTab);
            app.TypeLabel.HorizontalAlignment = 'right';
            app.TypeLabel.Position = [144 559 35 22];
            app.TypeLabel.Text = 'Type:';

            % Create TypeDropDown
            app.TypeDropDown = uidropdown(app.SetclassifierparametersTab);
            app.TypeDropDown.ValueChangedFcn = createCallbackFcn(app, @TypeDropDownValueChanged, true);
            app.TypeDropDown.Position = [186 559 314 22];

            % Create SpaceseparatedclassnamesLabel
            app.SpaceseparatedclassnamesLabel = uilabel(app.SetclassifierparametersTab);
            app.SpaceseparatedclassnamesLabel.HorizontalAlignment = 'right';
            app.SpaceseparatedclassnamesLabel.Position = [11 493 174 22];
            app.SpaceseparatedclassnamesLabel.Text = 'Space-separated class names: ';

            % Create SpaceseparatedclassnamesEditField
            app.SpaceseparatedclassnamesEditField = uieditfield(app.SetclassifierparametersTab, 'text');
            app.SpaceseparatedclassnamesEditField.ValueChangedFcn = createCallbackFcn(app, @SpaceseparatedclassnamesEditFieldValueChanged, true);
            app.SpaceseparatedclassnamesEditField.Tooltip = {'For classification, class definition is mandaztory; If emtpy, the classifier will output a regression'};
            app.SpaceseparatedclassnamesEditField.Position = [189 493 444 22];

            % Create PostprocessingcustomfunctionhandleEditFieldLabel
            app.PostprocessingcustomfunctionhandleEditFieldLabel = uilabel(app.SetclassifierparametersTab);
            app.PostprocessingcustomfunctionhandleEditFieldLabel.HorizontalAlignment = 'right';
            app.PostprocessingcustomfunctionhandleEditFieldLabel.Position = [22 236 224 22];
            app.PostprocessingcustomfunctionhandleEditFieldLabel.Text = 'Post-processing custom function handle:';

            % Create PostprocessingcustomfunctionhandleEditField
            app.PostprocessingcustomfunctionhandleEditField = uieditfield(app.SetclassifierparametersTab, 'text');
            app.PostprocessingcustomfunctionhandleEditField.ValueChangedFcn = createCallbackFcn(app, @PostprocessingcustomfunctionhandleEditFieldValueChanged2, true);
            app.PostprocessingcustomfunctionhandleEditField.Position = [261 236 168 22];

            % Create ClassiDetailsLabel
            app.ClassiDetailsLabel = uilabel(app.SetclassifierparametersTab);
            app.ClassiDetailsLabel.WordWrap = 'on';
            app.ClassiDetailsLabel.Position = [187 531 495 22];
            app.ClassiDetailsLabel.Text = 'ClassiDetails';

            % Create PostprocessingDropDownLabel
            app.PostprocessingDropDownLabel = uilabel(app.SetclassifierparametersTab);
            app.PostprocessingDropDownLabel.HorizontalAlignment = 'right';
            app.PostprocessingDropDownLabel.Position = [23 286 92 22];
            app.PostprocessingDropDownLabel.Text = 'Post-processing';

            % Create PostprocessingDropDown
            app.PostprocessingDropDown = uidropdown(app.SetclassifierparametersTab);
            app.PostprocessingDropDown.Items = {'plain output / probabilities for each class', 'plain output / semantic segmentation', 'postprocessing', 'custom function (see below)'};
            app.PostprocessingDropDown.ValueChangedFcn = createCallbackFcn(app, @PostprocessingDropDownValueChanged, true);
            app.PostprocessingDropDown.Position = [130 284 299 22];
            app.PostprocessingDropDown.Value = 'plain output / probabilities for each class';

            % Create PostprocessingparametersPanel
            app.PostprocessingparametersPanel = uipanel(app.SetclassifierparametersTab);
            app.PostprocessingparametersPanel.Title = 'Post-processing parameters';
            app.PostprocessingparametersPanel.Position = [455 205 584 128];

            % Create WatershedCheckBox
            app.WatershedCheckBox = uicheckbox(app.PostprocessingparametersPanel);
            app.WatershedCheckBox.ValueChangedFcn = createCallbackFcn(app, @WatershedCheckBoxValueChanged, true);
            app.WatershedCheckBox.Tooltip = {'Applies a watershed segmentation on the output'};
            app.WatershedCheckBox.Text = 'Watershed';
            app.WatershedCheckBox.Position = [16 78 80 22];

            % Create ThresholdingButtonGroup
            app.ThresholdingButtonGroup = uibuttongroup(app.PostprocessingparametersPanel);
            app.ThresholdingButtonGroup.SelectionChangedFcn = createCallbackFcn(app, @ThresholdingButtonGroupSelectionChanged, true);
            app.ThresholdingButtonGroup.Title = 'Thresholding';
            app.ThresholdingButtonGroup.Position = [215 7 359 95];

            % Create FixedthresholdButton
            app.FixedthresholdButton = uiradiobutton(app.ThresholdingButtonGroup);
            app.FixedthresholdButton.Text = 'Fixed threshold';
            app.FixedthresholdButton.Position = [11 49 104 22];
            app.FixedthresholdButton.Value = true;

            % Create AdaptivethresholdOtsumethodButton
            app.AdaptivethresholdOtsumethodButton = uiradiobutton(app.ThresholdingButtonGroup);
            app.AdaptivethresholdOtsumethodButton.Text = 'Adaptive threshold (Otsu method)';
            app.AdaptivethresholdOtsumethodButton.Position = [11 27 202 22];

            % Create MaximumprobabilityButton
            app.MaximumprobabilityButton = uiradiobutton(app.ThresholdingButtonGroup);
            app.MaximumprobabilityButton.Text = 'Maximum probability';
            app.MaximumprobabilityButton.Position = [11 5 132 22];

            % Create ValueEditFieldLabel
            app.ValueEditFieldLabel = uilabel(app.ThresholdingButtonGroup);
            app.ValueEditFieldLabel.HorizontalAlignment = 'right';
            app.ValueEditFieldLabel.Position = [117 49 39 22];
            app.ValueEditFieldLabel.Text = 'Value:';

            % Create ValueEditField
            app.ValueEditField = uieditfield(app.ThresholdingButtonGroup, 'text');
            app.ValueEditField.ValueChangedFcn = createCallbackFcn(app, @ValueEditFieldValueChanged, true);
            app.ValueEditField.Position = [171 49 51 22];
            app.ValueEditField.Value = '0.9';

            % Create FilteroutsmallobjectsCheckBox
            app.FilteroutsmallobjectsCheckBox = uicheckbox(app.PostprocessingparametersPanel);
            app.FilteroutsmallobjectsCheckBox.ValueChangedFcn = createCallbackFcn(app, @FilteroutsmallobjectsCheckBoxValueChanged, true);
            app.FilteroutsmallobjectsCheckBox.Tooltip = {'Applies a watershed segmentation on the output'};
            app.FilteroutsmallobjectsCheckBox.Text = 'Filter out small objects';
            app.FilteroutsmallobjectsCheckBox.Position = [16 50 141 22];

            % Create SizepixelEditFieldLabel
            app.SizepixelEditFieldLabel = uilabel(app.PostprocessingparametersPanel);
            app.SizepixelEditFieldLabel.HorizontalAlignment = 'right';
            app.SizepixelEditFieldLabel.Position = [22 21 68 22];
            app.SizepixelEditFieldLabel.Text = 'Size (pixel):';

            % Create SizepixelEditField
            app.SizepixelEditField = uieditfield(app.PostprocessingparametersPanel, 'numeric');
            app.SizepixelEditField.ValueChangedFcn = createCallbackFcn(app, @SizepixelEditFieldValueChanged, true);
            app.SizepixelEditField.Position = [97 21 60 22];

            % Create AvailablechannelstakenfromtrainingdatasetROIsLabel
            app.AvailablechannelstakenfromtrainingdatasetROIsLabel = uilabel(app.SetclassifierparametersTab);
            app.AvailablechannelstakenfromtrainingdatasetROIsLabel.WordWrap = 'on';
            app.AvailablechannelstakenfromtrainingdatasetROIsLabel.Position = [20 451 307 42];
            app.AvailablechannelstakenfromtrainingdatasetROIsLabel.Text = 'Available channels (taken from training dataset (ROIs):';

            % Create ChannelListBox
            app.ChannelListBox = uilistbox(app.SetclassifierparametersTab);
            app.ChannelListBox.Items = {};
            app.ChannelListBox.Tooltip = {'This is only activated after ROIs have been imported to this classifier (see tab #3 in this GUI).'};
            app.ChannelListBox.Position = [16 345 295 112];
            app.ChannelListBox.Value = {};

            % Create SelectedchannelsasclassificationinputLabel
            app.SelectedchannelsasclassificationinputLabel = uilabel(app.SetclassifierparametersTab);
            app.SelectedchannelsasclassificationinputLabel.HorizontalAlignment = 'center';
            app.SelectedchannelsasclassificationinputLabel.WordWrap = 'on';
            app.SelectedchannelsasclassificationinputLabel.Position = [381 447 255 42];
            app.SelectedchannelsasclassificationinputLabel.Text = 'Selected channels as classification input:';

            % Create ChannelListBoxSel
            app.ChannelListBoxSel = uilistbox(app.SetclassifierparametersTab);
            app.ChannelListBoxSel.Items = {};
            app.ChannelListBoxSel.Tooltip = {'It is not allowed to have more than 3 channels for all classification schemes, except the U-Net model'};
            app.ChannelListBoxSel.Position = [398 344 301 110];
            app.ChannelListBoxSel.Value = {};

            % Create SelectButton
            app.SelectButton = uibutton(app.SetclassifierparametersTab, 'push');
            app.SelectButton.ButtonPushedFcn = createCallbackFcn(app, @SelectButtonPushed, true);
            app.SelectButton.Position = [330 409 48 22];
            app.SelectButton.Text = '>';

            % Create DeSelectButton
            app.DeSelectButton = uibutton(app.SetclassifierparametersTab, 'push');
            app.DeSelectButton.ButtonPushedFcn = createCallbackFcn(app, @DeSelectButtonPushed, true);
            app.DeSelectButton.Position = [329 375 48 22];
            app.DeSelectButton.Text = '<';

            % Create UsercommentsEditField_2Label
            app.UsercommentsEditField_2Label = uilabel(app.SetclassifierparametersTab);
            app.UsercommentsEditField_2Label.HorizontalAlignment = 'right';
            app.UsercommentsEditField_2Label.Position = [23 162 93 22];
            app.UsercommentsEditField_2Label.Text = 'User comments:';

            % Create UsercommentsEditField_2
            app.UsercommentsEditField_2 = uieditfield(app.SetclassifierparametersTab, 'text');
            app.UsercommentsEditField_2.ValueChangedFcn = createCallbackFcn(app, @UsercommentsEditField_2ValueChanged, true);
            app.UsercommentsEditField_2.Position = [131 160 898 28];

            % Create SettrainingparametersTab
            app.SettrainingparametersTab = uitab(app.TabGroup);
            app.SettrainingparametersTab.AutoResizeChildren = 'off';
            app.SettrainingparametersTab.Title = 'Set training parameters';
            app.SettrainingparametersTab.ButtonDownFcn = createCallbackFcn(app, @SettrainingparametersTabButtonDown, true);

            % Create UITableParam
            app.UITableParam = uitable(app.SettrainingparametersTab);
            app.UITableParam.ColumnName = {'Column 1'; 'Column 2'; 'Column 3'; 'Column 4'};
            app.UITableParam.RowName = {};
            app.UITableParam.Position = [14 55 677 525];

            % Create SettrainingandvalidationsetROIsTab
            app.SettrainingandvalidationsetROIsTab = uitab(app.TabGroup);
            app.SettrainingandvalidationsetROIsTab.Title = 'Set training and validation set (ROIs)';
            app.SettrainingandvalidationsetROIsTab.ButtonDownFcn = createCallbackFcn(app, @SettrainingandvalidationsetROIsTabButtonDown, true);
            app.SettrainingandvalidationsetROIsTab.Tag = 'list';

            % Create UITableData
            app.UITableData = uitable(app.SettrainingandvalidationsetROIsTab);
            app.UITableData.ColumnName = {'Column 1'; 'Column 2'; 'Column 3'; 'Column 4'};
            app.UITableData.RowName = {};
            app.UITableData.CellEditCallback = createCallbackFcn(app, @UITableDataCellEdit, true);
            app.UITableData.CellSelectionCallback = createCallbackFcn(app, @UITableDataCellSelection, true);
            app.UITableData.Position = [8 162 1040 419];

            % Create ImportROIsButton
            app.ImportROIsButton = uibutton(app.SettrainingandvalidationsetROIsTab, 'push');
            app.ImportROIsButton.ButtonPushedFcn = createCallbackFcn(app, @ImportROIsButtonPushed, true);
            app.ImportROIsButton.Position = [398 8 100 50];
            app.ImportROIsButton.Text = 'Import ROIs...';

            % Create AnnotateselectedROIButton
            app.AnnotateselectedROIButton = uibutton(app.SettrainingandvalidationsetROIsTab, 'push');
            app.AnnotateselectedROIButton.ButtonPushedFcn = createCallbackFcn(app, @AnnotateselectedROIButtonPushed, true);
            app.AnnotateselectedROIButton.Tooltip = {'Select a ROI in the ROI Index column first'};
            app.AnnotateselectedROIButton.Position = [510 9 146 50];
            app.AnnotateselectedROIButton.Text = 'Annotate selected ROI...';

            % Create SelectallButton
            app.SelectallButton = uibutton(app.SettrainingandvalidationsetROIsTab, 'push');
            app.SelectallButton.ButtonPushedFcn = createCallbackFcn(app, @SelectallButtonPushed, true);
            app.SelectallButton.Position = [262 36 100 22];
            app.SelectallButton.Text = 'Select all';

            % Create DeselectallButton
            app.DeselectallButton = uibutton(app.SettrainingandvalidationsetROIsTab, 'push');
            app.DeselectallButton.ButtonPushedFcn = createCallbackFcn(app, @DeselectallButtonPushed, true);
            app.DeselectallButton.Position = [263 8 100 22];
            app.DeselectallButton.Text = 'Deselect all';

            % Create removeselectedROIButton
            app.removeselectedROIButton = uibutton(app.SettrainingandvalidationsetROIsTab, 'push');
            app.removeselectedROIButton.ButtonPushedFcn = createCallbackFcn(app, @removeselectedROIButtonPushed, true);
            app.removeselectedROIButton.Position = [667 9 128 49];
            app.removeselectedROIButton.Text = 'remove selected ROI';

            % Create SelectROIsEditFieldLabel
            app.SelectROIsEditFieldLabel = uilabel(app.SettrainingandvalidationsetROIsTab);
            app.SelectROIsEditFieldLabel.HorizontalAlignment = 'right';
            app.SelectROIsEditFieldLabel.Position = [45 36 80 22];
            app.SelectROIsEditFieldLabel.Text = 'Select ROIs #';

            % Create SelectROIsEditField
            app.SelectROIsEditField = uieditfield(app.SettrainingandvalidationsetROIsTab, 'text');
            app.SelectROIsEditField.ValueChangedFcn = createCallbackFcn(app, @SelectROIsEditFieldValueChanged, true);
            app.SelectROIsEditField.Position = [140 36 100 22];

            % Create ShuffleROIsfractionEditFieldLabel
            app.ShuffleROIsfractionEditFieldLabel = uilabel(app.SettrainingandvalidationsetROIsTab);
            app.ShuffleROIsfractionEditFieldLabel.HorizontalAlignment = 'right';
            app.ShuffleROIsfractionEditFieldLabel.Position = [12 8 116 22];
            app.ShuffleROIsfractionEditFieldLabel.Text = 'Shuffle ROIs fraction';

            % Create ShuffleROIsfractionEditField
            app.ShuffleROIsfractionEditField = uieditfield(app.SettrainingandvalidationsetROIsTab, 'text');
            app.ShuffleROIsfractionEditField.ValueChangedFcn = createCallbackFcn(app, @ShuffleROIsfractionEditFieldValueChanged, true);
            app.ShuffleROIsfractionEditField.Position = [141 8 100 22];
            app.ShuffleROIsfractionEditField.Value = '1';

            % Create FormattrainingsetfortrainingButton
            app.FormattrainingsetfortrainingButton = uibutton(app.SettrainingandvalidationsetROIsTab, 'push');
            app.FormattrainingsetfortrainingButton.ButtonPushedFcn = createCallbackFcn(app, @FormattrainingsetfortrainingButtonPushed, true);
            app.FormattrainingsetfortrainingButton.Position = [804 9 186 49];
            app.FormattrainingsetfortrainingButton.Text = 'Format training set for training...';

            % Create SetboundsselectionrulesButton
            app.SetboundsselectionrulesButton = uibutton(app.SettrainingandvalidationsetROIsTab, 'push');
            app.SetboundsselectionrulesButton.ButtonPushedFcn = createCallbackFcn(app, @SetboundsselectionrulesButtonPushed, true);
            app.SetboundsselectionrulesButton.Position = [13 68 169 33];
            app.SetboundsselectionrulesButton.Text = 'Set training frames...';

            % Create BoundsnoticeLabel
            app.BoundsnoticeLabel = uilabel(app.SettrainingandvalidationsetROIsTab);
            app.BoundsnoticeLabel.Position = [203 75 731 22];
            app.BoundsnoticeLabel.Text = 'Bounds notice';

            % Create GenerateDraftButton
            app.GenerateDraftButton = uibutton(app.SettrainingandvalidationsetROIsTab, 'push');
            app.GenerateDraftButton.ButtonPushedFcn = createCallbackFcn(app, @GenerateDraftButtonPushed, true);
            app.GenerateDraftButton.Position = [10 121 293 23];
            app.GenerateDraftButton.Text = 'Initialize GT...';

            % Create StartBlankGTButton
            app.StartBlankGTButton = uibutton(app.SettrainingandvalidationsetROIsTab, 'push');
            app.StartBlankGTButton.ButtonPushedFcn = createCallbackFcn(app, @StartBlankGTButtonPushed, true);
            app.StartBlankGTButton.Position = [203 122 100 23];
            app.StartBlankGTButton.Text = 'Start blank GT';
            app.StartBlankGTButton.Visible = 'off';

            % Create RefreshAnnotationStatusButton
            app.RefreshAnnotationStatusButton = uibutton(app.SettrainingandvalidationsetROIsTab, 'push');
            app.RefreshAnnotationStatusButton.ButtonPushedFcn = createCallbackFcn(app, @RefreshAnnotationStatusButtonPushed, true);
            app.RefreshAnnotationStatusButton.Position = [327 122 100 23];
            app.RefreshAnnotationStatusButton.Text = 'Refresh status';

            % Create AnnotationFilterDropDownLabel
            app.AnnotationFilterDropDownLabel = uilabel(app.SettrainingandvalidationsetROIsTab);
            app.AnnotationFilterDropDownLabel.HorizontalAlignment = 'right';
            app.AnnotationFilterDropDownLabel.Position = [482 122 35 22];
            app.AnnotationFilterDropDownLabel.Text = 'Show';

            % Create AnnotationFilterDropDown
            app.AnnotationFilterDropDown = uidropdown(app.SettrainingandvalidationsetROIsTab);
            app.AnnotationFilterDropDown.Items = {'All', 'Missing', 'Draft', 'Invalid', 'Ready'};
            app.AnnotationFilterDropDown.ValueChangedFcn = createCallbackFcn(app, @AnnotationFilterDropDownValueChanged, true);
            app.AnnotationFilterDropDown.Position = [532 122 100 22];
            app.AnnotationFilterDropDown.Value = 'All';

            % Create StatusSaved
            app.StatusSaved = uilamp(app.ClassifierUIFigure);
            app.StatusSaved.Tooltip = {'Classifier status'};
            app.StatusSaved.Position = [146 9 20 20];
            app.StatusSaved.Color = [1 0 0];

            % Create StatusLoad
            app.StatusLoad = uilamp(app.ClassifierUIFigure);
            app.StatusLoad.Tooltip = {'Classifier loaded in memory'};
            app.StatusLoad.Position = [1030 8 20 20];
            app.StatusLoad.Color = [1 0 0];

            % Create ParametersaresavedLabel
            app.ParametersaresavedLabel = uilabel(app.ClassifierUIFigure);
            app.ParametersaresavedLabel.Position = [17 8 127 22];
            app.ParametersaresavedLabel.Text = 'Parameters are saved:';

            % Create ClassifierisloadedinworksapcememoryLabel
            app.ClassifierisloadedinworksapcememoryLabel = uilabel(app.ClassifierUIFigure);
            app.ClassifierisloadedinworksapcememoryLabel.Position = [789 7 240 22];
            app.ClassifierisloadedinworksapcememoryLabel.Text = 'Classifier is loaded in worksapce (memory):';

            % Create SaveclassifierButton
            app.SaveclassifierButton = uibutton(app.ClassifierUIFigure, 'push');
            app.SaveclassifierButton.ButtonPushedFcn = createCallbackFcn(app, @SaveclassifierButtonPushed, true);
            app.SaveclassifierButton.Position = [187 2 588 31];
            app.SaveclassifierButton.Text = 'Save classifier';

            % Show the figure after all components are created
            app.ClassifierUIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = classifierGUI(varargin)

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.ClassifierUIFigure)

            % Execute the startup function
            runStartupFcn(app, @(app)startupFcn(app, varargin{:}))

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            try
                if isfield(app.Data, 'annotationSessionListener') && ...
                        ~isempty(app.Data.annotationSessionListener)
                    delete(app.Data.annotationSessionListener);
                end
                if isfield(app.Data, 'annotationBoundsListener') && ...
                        ~isempty(app.Data.annotationBoundsListener)
                    delete(app.Data.annotationBoundsListener);
                end
            catch
            end
            % Delete UIFigure when app is deleted
            delete(app.ClassifierUIFigure)
        end
    end
end
