function report = sync_score_layout()
%SYNC_SCORE_LAYOUT Build the runtime score.mlapp from its design source.
% Edit structure/GUI/score/private/layout/score.mlapp in App Designer, then
% run this
% function. The runtime structure/GUI/score/score.mlapp is never the design
% source and therefore cannot be damaged by an App Designer save.
%
% The design .mlapp is authoritative for component properties and
% createComponents. The private score_runtime_code.m is authoritative for
% callbacks and helper methods.

repoRoot = fileparts(mfilename('fullpath'));
guiDir = fullfile(repoRoot, 'structure', 'GUI');
runtimeMlappPath = fullfile(guiDir, 'score', 'score.mlapp');
layoutMlappPath = fullfile(guiDir, 'score', 'private', 'layout', 'score.mlapp');
codePath = fullfile(guiDir, 'score', 'private', 'score_runtime_code.m');

localAssertFile(runtimeMlappPath, 'runtime score.mlapp');
localAssertFile(layoutMlappPath, 'App Designer score layout');
localAssertFile(codePath, 'score code reference');
localAssertSerializationApi();

runId = datestr(now, 'yyyymmdd_HHMMSS');
backupDir = fullfile(repoRoot, 'backups', 'score_layout_sync', runId, ...
    'structure', 'GUI');

layoutReader = appdesigner.internal.serialization.FileReader(layoutMlappPath);
layoutCode = layoutReader.readMATLABCodeText();
fullCode = fileread(codePath);

componentProperties = localExtractComponentProperties(layoutCode);
createComponents = localExtractCreateComponents(layoutCode);
componentProperties = localNormalizeAnnotationComponents(componentProperties);
createComponents = localNormalizeAnnotationComponents(createComponents);
componentProperties = localRestoreCodeOwnedProperties(componentProperties);
createComponents = localRestoreCodeOwnedLayout(createComponents);
createComponents = localConfigureLineageControls(createComponents);
createComponents = localConfigureAnnotationControls(createComponents);

mergedCode = localReplaceComponentProperties(fullCode, componentProperties);
mergedCode = localReplaceCreateComponents(mergedCode, createComponents);
localValidateMergedCode(mergedCode);

runtimeReader = appdesigner.internal.serialization.FileReader(runtimeMlappPath);
runtimeCode = runtimeReader.readMATLABCodeText();
runtimeMatches = strcmp(localNormalizeNewlines(runtimeCode), ...
    localNormalizeNewlines(mergedCode));
referenceMatches = strcmp(localNormalizeNewlines(fullCode), ...
    localNormalizeNewlines(mergedCode));
if runtimeMatches && referenceMatches
    report = struct( ...
        'runtimeMlapp', string(runtimeMlappPath), ...
        'layoutMlapp', string(layoutMlappPath), ...
        'codeReference', string(codePath), ...
        'backup', "", ...
        'status', "unchanged");
    return;
end

scoreBackupDir = fullfile(backupDir, 'score');
layoutBackupDir = fullfile(scoreBackupDir, 'layout');
if exist(layoutBackupDir, 'dir') ~= 7
    mkdir(layoutBackupDir);
end
copyfile(runtimeMlappPath, fullfile(scoreBackupDir, 'score.mlapp'), 'f');
copyfile(layoutMlappPath, fullfile(layoutBackupDir, 'score.mlapp'), 'f');
copyfile(codePath, fullfile(backupDir, 'score_runtime_code.m'), 'f');

localWriteText(codePath, mergedCode);

runtimeReader = appdesigner.internal.serialization.FileReader(runtimeMlappPath);
appCodeData = localReadAppCodeData(runtimeReader);
appMetadata = localReadAppMetadata(runtimeReader);
writer = appdesigner.internal.serialization.FileWriter(runtimeMlappPath);
writer.writeAppCodeData(mergedCode, appCodeData, appMetadata);

report = struct( ...
    'runtimeMlapp', string(runtimeMlappPath), ...
    'layoutMlapp', string(layoutMlappPath), ...
    'codeReference', string(codePath), ...
    'backup', string(backupDir), ...
    'status', "ok");

fprintf('[score-sync] layout merged and code restored.\n');
fprintf('[score-sync] backup: %s\n', backupDir);
end

function text = localNormalizeNewlines(text)
text = strrep(text, sprintf('\r\n'), sprintf('\n'));
end

function code = localRestoreCodeOwnedProperties(code)
% These movie controls predate the current App Designer layout but are used
% by the code-rich implementation. Keep them until they are migrated into
% the visual component tree.
code = localRestoreRoiPropertyOrder(code);
requiredProperties = { ...
    'MovieeventmarkersEditField      matlab.ui.control.EditField', ...
    'MovieeventmarkersEditFieldLabel  matlab.ui.control.Label', ...
    'LineageLinkWidthEditField        matlab.ui.control.NumericEditField', ...
    'LineageLinkWidthEditFieldLabel   matlab.ui.control.Label', ...
    'ReviewWhileNavigatingCheckBox    matlab.ui.control.CheckBox', ...
    'MarkThroughCurrentButton         matlab.ui.control.Button'};
anchor = '        ShowmovieandfolderButton';
anchorIndex = strfind(code, anchor);
if numel(anchorIndex) ~= 1
    error('sync_score_layout:MoviePropertyAnchor', ...
        'Could not locate ShowmovieandfolderButton in component properties.');
end

newline = localNewline(code);
for i = numel(requiredProperties):-1:1
    propertyLine = ['        ' requiredProperties{i}];
    if ~contains(code, propertyLine)
        anchorIndex = strfind(code, anchor);
        line = [propertyLine newline];
        code = [code(1:anchorIndex - 1) line code(anchorIndex:end)];
    end
end
end

function code = localRestoreRoiPropertyOrder(code)
names = {'ROIslistTab','ROisPanel','UIROITable'};
lines = cell(1, numel(names));
for i = 1:numel(names)
    pattern = ['(?m)^\s{8}' names{i} '\s+[^\r\n]+\r?\n'];
    lines{i} = regexp(code, pattern, 'match', 'once');
    if isempty(lines{i})
        error('sync_score_layout:RoiProperty', ...
            'Could not locate component property %s.', names{i});
    end
    code = regexprep(code, pattern, '', 'once');
end
anchor = regexp(code, '(?m)^\s{8}TabGroup\s+[^\r\n]+\r?\n', ...
    'match', 'once');
anchorIndex = strfind(code, anchor);
if numel(anchorIndex) ~= 1
    error('sync_score_layout:RoiPropertyAnchor', ...
        'Could not locate the TabGroup component property.');
end
insertAt = anchorIndex + numel(anchor);
block = [lines{:}];
code = [code(1:insertAt-1) block code(insertAt:end)];
end

function code = localRestoreCodeOwnedLayout(code)
% Preserve settings introduced in code and still required by table logic.
code = localRestoreRoiTabOrder(code);
code = localInsertLineAfter(code, ...
    "            app.UIROITable.ColumnName = {'Display'; 'Name'; 'Size'};", ...
    "            app.UIROITable.ColumnWidth = {70, 400, 100};");

code = strrep(code, ...
    char("            app.UIChannelTable.ColumnName = {'Display'; 'Name'; 'Levels'; 'RGB'; 'Weight'; 'Auto'; 'Log'};"), ...
    char("            app.UIChannelTable.ColumnName = {'Display'; 'Name'; 'Scale'; 'Levels'; 'RGB'; 'Weight'; 'Auto'; 'Log'};"));
code = localReplacePropertyLine(code, 'UIChannelTable', 'ColumnWidth', ...
    "            app.UIChannelTable.ColumnWidth = {70, 200, 55, 70, 70, 70, 50, 50};");
code = localReplacePropertyLine(code, 'UISubDataTable', 'ColumnWidth', ...
    "            app.UISubDataTable.ColumnWidth = {50, 200, 100, 70, 50, 100};");
code = localReplacePropertyLine(code, 'UISubDataTable', 'ColumnEditable', ...
    "            app.UISubDataTable.ColumnEditable = [true true false true true true];");
code = localReplacePropertyLine(code, 'UIGroupTable', 'ColumnWidth', ...
    "            app.UIGroupTable.ColumnWidth = {250, 120, 100, 100};");
code = localInsertLineAfter(code, ...
    "            app.UIAnnotationTable.ColumnName = {'Display'; 'Name'; 'Class'; 'Weight'; 'Contour'; 'Width'};", ...
    "            app.UIAnnotationTable.ColumnWidth = {70, 200, 100, 70, 70, 70};");

if ~contains(code, 'app.MovieeventmarkersEditField =')
    marker = '            % Create ShowmovieandfolderButton';
    markerIndex = strfind(code, marker);
    if numel(markerIndex) ~= 1
        error('sync_score_layout:MovieControlAnchor', ...
            'Could not locate the movie control insertion point.');
    end
    newline = localNewline(code);
    block = strjoin({ ...
        '            % Create MovieeventmarkersEditFieldLabel', ...
        '            app.MovieeventmarkersEditFieldLabel = uilabel(app.MoviePanel);', ...
        '            app.MovieeventmarkersEditFieldLabel.HorizontalAlignment = ''right'';', ...
        '            app.MovieeventmarkersEditFieldLabel.Position = [230 169 105 22];', ...
        '            app.MovieeventmarkersEditFieldLabel.Text = ''Movie events fr'';', ...
        '', ...
        '            % Create MovieeventmarkersEditField', ...
        '            app.MovieeventmarkersEditField = uieditfield(app.MoviePanel, ''text'');', ...
        '            app.MovieeventmarkersEditField.Position = [350 169 150 22];', ...
        '            app.MovieeventmarkersEditField.Value = '''';', ...
        ''}, newline);
    code = [code(1:markerIndex - 1) block code(markerIndex:end)];
end
code = localConfigureLinkWidthLayout(code);
code = localConfigureAnnotationReviewLayout(code);
end

function code = localConfigureAnnotationReviewLayout(code)
code = localReplacePropertyLine(code, 'AnnotationSessionPanel', 'Position', ...
    "            app.AnnotationSessionPanel.Position = [11 680 599 175];");
positions = { ...
    'AnnotationTargetLabel', '[13 124 210 22]'; ...
    'AnnotationStatusLabel', '[13 101 220 22]'; ...
    'AnnotationCoverageLabel', '[13 38 220 60]'; ...
    'CreateFromPredictionButton', '[247 124 154 23]'; ...
    'StartBlankGTButton', '[251 95 145 23]'; ...
    'MarkFrameReviewedButton', '[253 66 143 23]'; ...
    'NextIncompleteButton', '[421 124 170 23]'; ...
    'ValidateAnnotationButton', '[423 95 100 23]'; ...
    'ApproveAnnotationButton', '[424 66 100 23]'; ...
    'ShowPredictionCheckBox', '[256 5 153 22]'};
for i = 1:size(positions, 1)
    code = localReplacePropertyLine(code, positions{i,1}, 'Position', ...
        sprintf('            app.%s.Position = %s;', ...
        positions{i,1}, positions{i,2}));
end
if ~contains(code, 'app.AnnotationCoverageLabel.WordWrap =')
    code = localInsertLineAfter(code, ...
        '            app.AnnotationCoverageLabel = uilabel(app.AnnotationSessionPanel);', ...
        '            app.AnnotationCoverageLabel.WordWrap = ''on'';');
end

if contains(code, 'app.MarkThroughCurrentButton =')
    return;
end
marker = '            % Create ShowPredictionCheckBox';
markerIndex = strfind(code, marker);
if numel(markerIndex) ~= 1
    error('sync_score_layout:AnnotationReviewAnchor', ...
        'Could not locate the annotation review insertion point.');
end
newline = localNewline(code);
block = strjoin({ ...
    '            % Create MarkThroughCurrentButton', ...
    '            app.MarkThroughCurrentButton = uibutton(app.AnnotationSessionPanel, ''push'');', ...
    '            app.MarkThroughCurrentButton.Position = [247 36 154 23];', ...
    '            app.MarkThroughCurrentButton.Text = ''Review 1 -> current...'';', ...
    '', ...
    '            % Create ReviewWhileNavigatingCheckBox', ...
    '            app.ReviewWhileNavigatingCheckBox = uicheckbox(app.AnnotationSessionPanel);', ...
    '            app.ReviewWhileNavigatingCheckBox.Text = ''Review while navigating'';', ...
    '            app.ReviewWhileNavigatingCheckBox.Position = [421 36 166 22];', ...
    '            app.ReviewWhileNavigatingCheckBox.Value = false;', ...
    ''}, newline);
code = [code(1:markerIndex - 1) block code(markerIndex:end)];
end

function code = localConfigureLinkWidthLayout(code)
% This compact control was introduced programmatically while the rest of
% the panel remains owned by App Designer. Reapply it after every merge so
% a future layout save cannot silently remove it.
code = localReplacePropertyLine(code, 'ObjectColorsPanel', 'Position', ...
    "            app.ObjectColorsPanel.Position = [354 44 218 245];");
positions = { ...
    'FamilyColorPickerLabel', '[35 184 70 22]'; ...
    'FamilyColorPicker', '[120 184 38 22]'; ...
    'SemanticValueDropDownLabel', '[12 147 87 22]'; ...
    'SemanticValueDropDown', '[120 147 84 22]'; ...
    'SemanticValueColorPickerLabel', '[17 111 88 22]'; ...
    'SemanticValueColorPicker', '[120 111 38 22]'; ...
    'BudlinkcolorColorPickerLabel', '[41 77 77 22]'; ...
    'BudlinkcolorColorPicker', '[121 77 38 22]'; ...
    'GenealogyLinkColorPickerLabel', '[-1 46 114 22]'; ...
    'GenealogyLinkColorPicker', '[119 46 38 22]'};
for i = 1:size(positions, 1)
    code = localReplacePropertyLine(code, positions{i,1}, 'Position', ...
        sprintf('            app.%s.Position = %s;', ...
        positions{i,1}, positions{i,2}));
end

if contains(code, 'app.LineageLinkWidthEditField =')
    return;
end
marker = '            % Create SelectedObjectIDLabel';
markerIndex = strfind(code, marker);
if numel(markerIndex) ~= 1
    error('sync_score_layout:LineageWidthAnchor', ...
        'Could not locate the lineage width insertion point.');
end
newline = localNewline(code);
block = strjoin({ ...
    '            % Create LineageLinkWidthEditFieldLabel', ...
    '            app.LineageLinkWidthEditFieldLabel = uilabel(app.ObjectColorsPanel);', ...
    '            app.LineageLinkWidthEditFieldLabel.HorizontalAlignment = ''right'';', ...
    '            app.LineageLinkWidthEditFieldLabel.Position = [12 9 101 22];', ...
    '            app.LineageLinkWidthEditFieldLabel.Text = ''Link width (px)'';', ...
    '', ...
    '            % Create LineageLinkWidthEditField', ...
    '            app.LineageLinkWidthEditField = uieditfield(app.ObjectColorsPanel, ''numeric'');', ...
    '            app.LineageLinkWidthEditField.Limits = [1 20];', ...
    '            app.LineageLinkWidthEditField.RoundFractionalValues = ''on'';', ...
    '            app.LineageLinkWidthEditField.Position = [121 9 62 22];', ...
    '            app.LineageLinkWidthEditField.Value = 1;', ...
    ''}, newline);
code = [code(1:markerIndex - 1) block code(markerIndex:end)];
end

function code = localRestoreRoiTabOrder(code)
pattern = ['(?s)\r?\n            % Create ROIslistTab\r?\n' ...
    '.*?(?=\r?\n            % Show the figure after all components are created)'];
block = regexp(code, pattern, 'match', 'once');
if isempty(block)
    error('sync_score_layout:RoiTabBlock', ...
        'Could not isolate the ROIs list tab creation block.');
end
code = regexprep(code, pattern, '', 'once');
anchor = '            % Create DisplaySettingsTab';
anchorIndex = strfind(code, anchor);
if numel(anchorIndex) ~= 1
    error('sync_score_layout:RoiTabAnchor', ...
        'Could not locate the Display Settings tab creation block.');
end
newline = localNewline(code);
block = regexprep(block, '^\r?\n', '');
code = [code(1:anchorIndex-1) block newline newline code(anchorIndex:end)];
end

function code = localInsertLineAfter(code, anchorLine, insertedLine)
anchorLine = char(anchorLine);
insertedLine = char(insertedLine);
if contains(code, insertedLine)
    return;
end
anchorIndex = strfind(code, anchorLine);
if numel(anchorIndex) ~= 1
    error('sync_score_layout:LayoutAnchor', ...
        'Expected exactly one layout anchor: %s', strtrim(anchorLine));
end
lineEnd = regexp(code(anchorIndex:end), '\r?\n', 'end', 'once');
lineEnd = anchorIndex + lineEnd - 1;
newline = localNewline(code);
code = [code(1:lineEnd) insertedLine newline code(lineEnd + 1:end)];
end

function code = localReplacePropertyLine(code, componentName, propertyName, replacement)
token = sprintf('app.%s.%s =', componentName, propertyName);
tokenIndex = strfind(code, token);
if numel(tokenIndex) ~= 1
    error('sync_score_layout:PropertyLine', ...
        'Expected exactly one %s.%s assignment.', componentName, propertyName);
end
newline = localNewline(code);
lineStart = find(code(1:tokenIndex) == newline(end), 1, 'last') + 1;
lineEndRelative = regexp(code(tokenIndex:end), '\r?\n', 'start', 'once');
lineEnd = tokenIndex + lineEndRelative - 2;
code = [code(1:lineStart - 1) char(replacement) code(lineEnd + 1:end)];
end

function block = localExtractComponentProperties(code)
pattern = ['(?s)    % Properties that correspond to app components\r?\n' ...
    '    properties \(Access = public\).*?\r?\n    end'];
block = regexp(code, pattern, 'match', 'once');
if isempty(block)
    error('sync_score_layout:ParseProperties', ...
        'The App Designer component properties block was not found.');
end
end

function code = localReplaceComponentProperties(code, replacement)
pattern = ['(?s)    % Properties that correspond to app components\r?\n' ...
    '    properties \(Access = public\).*?\r?\n    end'];
[startIndex, endIndex] = regexp(code, pattern, 'start', 'end', 'once');
if isempty(startIndex)
    error('sync_score_layout:ParseReferenceProperties', ...
        'The component properties block was not found in the code reference.');
end
code = [code(1:startIndex - 1) replacement code(endIndex + 1:end)];
end

function block = localExtractCreateComponents(code)
pattern = ['(?s)        function createComponents\(app\).*?\r?\n' ...
    '        end(?=\r?\n    end\r?\n\r?\n    % App creation and deletion)'];
block = regexp(code, pattern, 'match', 'once');
if isempty(block)
    error('sync_score_layout:ParseCreateComponents', ...
        'createComponents could not be isolated from the App Designer code.');
end
end

function code = localReplaceCreateComponents(code, replacement)
pattern = ['(?s)        function createComponents\(app\).*?\r?\n' ...
    '        end(?=\r?\n    end\r?\n\r?\n    % App creation and deletion)'];
[startIndex, endIndex] = regexp(code, pattern, 'start', 'end', 'once');
if isempty(startIndex)
    error('sync_score_layout:ParseReferenceCreateComponents', ...
        'createComponents was not found in the code reference.');
end
code = [code(1:startIndex - 1) replacement code(endIndex + 1:end)];
end

function code = localConfigureLineageControls(code)
% Transitional support for the legacy checkboxes. When the design source
% replaces them with LineageDisplayButtonGroup, the generic merge simply
% skips this block instead of rejecting the new layout.
if contains(code, 'app.DisplayBudPairingCheckBox = uicheckbox')
    code = localInsertCallback(code, 'DisplayBudPairingCheckBox', ...
        'LineageDisplayCheckBoxValueChanged');
    code = localSetControlValue(code, 'DisplayBudPairingCheckBox', 'true');
end
if contains(code, 'app.DisplayLineageCheckBox = uicheckbox')
    code = localInsertCallback(code, 'DisplayLineageCheckBox', ...
        'LineageDisplayCheckBoxValueChanged');
    code = localSetControlValue(code, 'DisplayLineageCheckBox', 'false');
end
end

function code = localNormalizeAnnotationComponents(code)
% Normalize the two provisional App Designer names without requiring the
% visual layout to be reopened. Future layout saves remain safe because the
% same normalization is applied on every merge.
code = strrep(code, 'MarkframereviewedButton', 'MarkFrameReviewedButton');
code = strrep(code, 'PreviousIncompleteButton', 'NextIncompleteButton');
end

function code = localConfigureAnnotationControls(code)
controls = { ...
    'CreateFromPredictionButton', 'uibutton', 'ButtonPushedFcn', ...
        'CreateFromPredictionButtonPushed'; ...
    'StartBlankGTButton', 'uibutton', 'ButtonPushedFcn', ...
        'StartBlankGTButtonPushed'; ...
    'MarkFrameReviewedButton', 'uibutton', 'ButtonPushedFcn', ...
        'MarkFrameReviewedButtonPushed'; ...
    'MarkThroughCurrentButton', 'uibutton', 'ButtonPushedFcn', ...
        'MarkThroughCurrentButtonPushed'; ...
    'NextIncompleteButton', 'uibutton', 'ButtonPushedFcn', ...
        'NextIncompleteButtonPushed'; ...
    'ValidateAnnotationButton', 'uibutton', 'ButtonPushedFcn', ...
        'ValidateAnnotationButtonPushed'; ...
    'ApproveAnnotationButton', 'uibutton', 'ButtonPushedFcn', ...
        'ApproveAnnotationButtonPushed'; ...
    'ShowPredictionCheckBox', 'uicheckbox', 'ValueChangedFcn', ...
        'ShowPredictionCheckBoxValueChanged'};
for i = 1:size(controls, 1)
    code = localInsertControlCallback(code, controls{i,1}, controls{i,2}, ...
        controls{i,3}, controls{i,4});
end

code = localReplacePropertyLine(code, 'CreateFromPredictionButton', 'Text', ...
    "            app.CreateFromPredictionButton.Text = 'Initialize GT...';");
if contains(code, 'app.StartBlankGTButton.Visible =')
    code = localReplacePropertyLine(code, 'StartBlankGTButton', 'Visible', ...
        "            app.StartBlankGTButton.Visible = 'off';");
else
    code = localInsertLineAfter(code, ...
        '            app.StartBlankGTButton = uibutton(app.AnnotationSessionPanel, ''push'');', ...
        '            app.StartBlankGTButton.Visible = ''off'';');
end

if ~contains(code, 'app.AnnotationSessionPanel.Visible =')
    code = localInsertLineAfter(code, ...
        '            app.AnnotationSessionPanel = uipanel(app.AnnotationPanel);', ...
        '            app.AnnotationSessionPanel.Visible = ''off'';');
end
end

function code = localInsertControlCallback(code, componentName, constructor, ...
        callbackProperty, callbackName)
callbackToken = sprintf('app.%s.%s', componentName, callbackProperty);
if contains(code, callbackToken), return; end

assignmentToken = sprintf('app.%s = %s', componentName, constructor);
assignmentIndex = strfind(code, assignmentToken);
if numel(assignmentIndex) ~= 1
    error('sync_score_layout:AnnotationControl', ...
        'Expected exactly one creation line for %s.', componentName);
end
lineEnd = regexp(code(assignmentIndex:end), '\r?\n', 'end', 'once');
if isempty(lineEnd)
    error('sync_score_layout:AnnotationControlLine', ...
        'Could not find the end of the %s creation line.', componentName);
end
lineEnd = assignmentIndex + lineEnd - 1;
newline = localNewline(code);
callbackLine = sprintf( ...
    '            app.%s.%s = createCallbackFcn(app, @%s, true);', ...
    componentName, callbackProperty, callbackName);
code = [code(1:lineEnd) callbackLine newline code(lineEnd + 1:end)];
end

function code = localInsertCallback(code, componentName, callbackName)
callbackToken = sprintf('app.%s.ValueChangedFcn', componentName);
if contains(code, callbackToken)
    return;
end

assignmentToken = sprintf('app.%s = uicheckbox', componentName);
assignmentIndex = strfind(code, assignmentToken);
if numel(assignmentIndex) ~= 1
    error('sync_score_layout:LineageControl', ...
        'Expected exactly one creation line for %s.', componentName);
end

lineEnd = regexp(code(assignmentIndex:end), '\r?\n', 'end', 'once');
if isempty(lineEnd)
    error('sync_score_layout:LineageControlLine', ...
        'Could not find the end of the %s creation line.', componentName);
end
lineEnd = assignmentIndex + lineEnd - 1;
newline = localNewline(code);
callbackLine = sprintf('            app.%s.ValueChangedFcn = createCallbackFcn(app, @%s, true);', ...
    componentName, callbackName);
code = [code(1:lineEnd) callbackLine newline code(lineEnd + 1:end)];
end

function code = localSetControlValue(code, componentName, valueText)
valueToken = sprintf('app.%s.Value =', componentName);
valueIndex = strfind(code, valueToken);
newline = localNewline(code);
valueLine = sprintf('            app.%s.Value = %s;', componentName, valueText);

if isempty(valueIndex)
    textToken = sprintf('app.%s.Text =', componentName);
    textIndex = strfind(code, textToken);
    if numel(textIndex) ~= 1
        error('sync_score_layout:LineageControlText', ...
            'Expected exactly one Text line for %s.', componentName);
    end
    lineEnd = regexp(code(textIndex:end), '\r?\n', 'end', 'once');
    lineEnd = textIndex + lineEnd - 1;
    code = [code(1:lineEnd) valueLine newline code(lineEnd + 1:end)];
    return;
end

if numel(valueIndex) ~= 1
    error('sync_score_layout:LineageControlValue', ...
        'Expected at most one Value line for %s.', componentName);
end
lineStart = find(code(1:valueIndex) == newline(end), 1, 'last') + 1;
lineEndRelative = regexp(code(valueIndex:end), '\r?\n', 'start', 'once');
if isempty(lineEndRelative)
    lineEnd = numel(code);
else
    lineEnd = valueIndex + lineEndRelative - 2;
end
code = [code(1:lineStart - 1) valueLine code(lineEnd + 1:end)];
end

function newline = localNewline(code)
if contains(code, sprintf('\r\n'))
    newline = sprintf('\r\n');
else
    newline = sprintf('\n');
end
end

function localValidateMergedCode(code)
required = { ...
    'function LineageDisplayCheckBoxValueChanged', ...
    'syncLineageDisplayForPaintChannel(app)', ...
    'refreshROIDataFromDisk(app, roiobj)', ...
    'function setupBrushSizeMenu', ...
    'function setAnnotationSession', ...
    'AnnotationSessionPanel', ...
    'CreateFromPredictionButtonPushed', ...
    'ApproveAnnotationButtonPushed', ...
    'SelectedchannelpropertiesPanel', ...
    'LineageLinkWidthEditField', ...
    'ReviewWhileNavigatingCheckBox', ...
    'MarkThroughCurrentButton', ...
    'MovieeventmarkersEditField', ...
    '''Scale''; ''Levels''', ...
    'app.UIAnnotationTable.ColumnWidth'};
for i = 1:numel(required)
    if ~contains(code, required{i})
        error('sync_score_layout:Validation', ...
            'Required code is missing after merge: %s', required{i});
    end
end

callbackTokens = regexp(code, ...
    'createCallbackFcn\(app,\s*@([A-Za-z]\w*)', 'tokens');
callbackNames = unique(string(cellfun(@(x)x{1}, callbackTokens, ...
    'UniformOutput', false)));
for i = 1:numel(callbackNames)
    methodPattern = ['(?m)^\s*function\s+' ...
        '(?:(?:\[[^\]]*\]|[A-Za-z]\w*)\s*=\s*)?' ...
        regexptranslate('escape', char(callbackNames(i))) '\s*\('];
    if isempty(regexp(code, methodPattern, 'once'))
        error('sync_score_layout:MissingCallbackMethod', ...
            'Layout callback %s is absent from the runtime code reference.', ...
            callbackNames(i));
    end
end

legacyLineageControls = { ...
    'DisplayBudPairingCheckBox', ...
    'DisplayLineageCheckBox'};
for i = 1:numel(legacyLineageControls)
    componentName = legacyLineageControls{i};
    if contains(code, ['app.' componentName ' = uicheckbox']) && ...
            ~contains(code, ['app.' componentName '.ValueChangedFcn'])
        error('sync_score_layout:LegacyLineageCallback', ...
            'Legacy control %s exists without its callback.', componentName);
    end
end

removed = {'ComputemetricsButton', 'copyobjectstonextframeButton'};
for i = 1:numel(removed)
    if contains(code, removed{i})
        error('sync_score_layout:RemovedControlRestored', ...
            'Removed control was unexpectedly restored: %s', removed{i});
    end
end
end

function localAssertFile(pathStr, label)
if exist(pathStr, 'file') ~= 2
    error('sync_score_layout:MissingFile', 'Missing %s: %s', label, pathStr);
end
end

function localAssertSerializationApi()
hasReader = exist('appdesigner.internal.serialization.FileReader', 'class') == 8;
hasWriter = exist('appdesigner.internal.serialization.FileWriter', 'class') == 8;
if ~(hasReader && hasWriter)
    error('sync_score_layout:ApiMissing', ...
        'The App Designer serialization API is unavailable.');
end
end

function data = localReadAppCodeData(reader)
try
    data = reader.readAppCodeData();
    return;
catch
end
try
    data = reader.readAppDesignerData();
    return;
catch
end
error('sync_score_layout:ReadCodeData', ...
    'Could not read App Designer code metadata.');
end

function data = localReadAppMetadata(reader)
try
    data = reader.readAppMetadata();
    return;
catch
end
try
    data = reader.readAppDesignerMetadata();
    return;
catch
end
error('sync_score_layout:ReadMetadata', ...
    'Could not read App Designer metadata.');
end

function localWriteText(pathStr, text)
fid = fopen(pathStr, 'w');
if fid < 0
    error('sync_score_layout:Write', 'Cannot open %s for writing.', pathStr);
end
cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
fwrite(fid, text, 'char');
end
