function report = sync_classifier_layout()
%SYNC_CLASSIFIER_LAYOUT Merge classifierGUI layout into its code reference.
% The isolated .mlapp owns component properties and createComponents only.
% classifierGUI_runtime_code.m owns callbacks, helpers and business wiring.

repoRoot = fileparts(mfilename('fullpath'));
guiDir = fullfile(repoRoot, 'structure', 'GUI');
runtimePath = fullfile(guiDir, 'classifierGUI.mlapp');
layoutPath = fullfile(guiDir, 'classifier', 'private', 'layout', ...
    'classifierGUI.mlapp');
codePath = fullfile(guiDir, 'classifier', 'private', ...
    'classifierGUI_runtime_code.m');

localAssertFile(runtimePath, 'runtime classifierGUI.mlapp');
localAssertFile(layoutPath, 'App Designer classifierGUI layout');
localAssertFile(codePath, 'classifierGUI code reference');
localAssertSerializationApi();

layoutReader = appdesigner.internal.serialization.FileReader(layoutPath);
layoutCode = layoutReader.readMATLABCodeText();
referenceCode = fileread(codePath);
componentProperties = localNormalizeLayoutNames( ...
    localExtractComponentProperties(layoutCode));
createComponents = localNormalizeLayoutNames( ...
    localExtractCreateComponents(layoutCode));
mergedCode = localReplaceComponentProperties(referenceCode, componentProperties);
mergedCode = localReplaceCreateComponents(mergedCode, createComponents);
localValidateMergedCode(mergedCode);

runtimeReader = appdesigner.internal.serialization.FileReader(runtimePath);
runtimeCode = runtimeReader.readMATLABCodeText();
runtimeMatches = strcmp(localNormalize(runtimeCode), localNormalize(mergedCode));
referenceMatches = strcmp(localNormalize(referenceCode), localNormalize(mergedCode));
if runtimeMatches && referenceMatches
    report = localReport(runtimePath, layoutPath, codePath, '', 'unchanged');
    return;
end

runId = datestr(now, 'yyyymmdd_HHMMSS');
backupDir = fullfile(repoRoot, 'backups', 'classifier_layout_sync', runId, ...
    'structure', 'GUI');
layoutBackupDir = fullfile(backupDir, 'classifier', 'private', 'layout');
if exist(layoutBackupDir, 'dir') ~= 7
    mkdir(layoutBackupDir);
end
copyfile(runtimePath, fullfile(backupDir, 'classifierGUI.mlapp'), 'f');
copyfile(layoutPath, fullfile(layoutBackupDir, 'classifierGUI.mlapp'), 'f');
copyfile(codePath, fullfile(backupDir, 'classifierGUI_runtime_code.m'), 'f');

localWriteText(codePath, mergedCode);
runtimeReader = appdesigner.internal.serialization.FileReader(runtimePath);
appCodeData = localReadAppCodeData(runtimeReader);
appMetadata = localReadAppMetadata(runtimeReader);
writer = appdesigner.internal.serialization.FileWriter(runtimePath);
writer.writeAppCodeData(mergedCode, appCodeData, appMetadata);

verifyReader = appdesigner.internal.serialization.FileReader(runtimePath);
embeddedCode = verifyReader.readMATLABCodeText();
if ~strcmp(localNormalize(embeddedCode), localNormalize(mergedCode))
    error('sync_classifier_layout:Verification', ...
        'Runtime embedded code differs from the merged reference.');
end

report = localReport(runtimePath, layoutPath, codePath, backupDir, 'ok');
fprintf('[classifier-sync] layout merged and code restored.\n');
fprintf('[classifier-sync] backup: %s\n', backupDir);
end

function report = localReport(runtimePath, layoutPath, codePath, backup, status)
report = struct('runtimeMlapp', string(runtimePath), ...
    'layoutMlapp', string(layoutPath), 'codeReference', string(codePath), ...
    'backup', string(backup), 'status', string(status));
end

function block = localExtractComponentProperties(code)
pattern = ['(?s)    % Properties that correspond to app components\r?\n' ...
    '    properties \(Access = public\).*?\r?\n    end'];
block = regexp(code, pattern, 'match', 'once');
if isempty(block)
    error('sync_classifier_layout:ParseProperties', ...
        'The layout component-properties block was not found.');
end
end

function code = localReplaceComponentProperties(code, replacement)
pattern = ['(?s)    % Properties that correspond to app components\r?\n' ...
    '    properties \(Access = public\).*?\r?\n    end'];
[first, last] = regexp(code, pattern, 'start', 'end', 'once');
if isempty(first)
    error('sync_classifier_layout:ReferenceProperties', ...
        'The reference component-properties block was not found.');
end
code = [code(1:first - 1) replacement code(last + 1:end)];
end

function block = localExtractCreateComponents(code)
pattern = ['(?s)        function createComponents\(app\).*?\r?\n' ...
    '        end(?=\r?\n    end\r?\n\r?\n    % App creation and deletion)'];
block = regexp(code, pattern, 'match', 'once');
if isempty(block)
    error('sync_classifier_layout:ParseCreateComponents', ...
        'The layout createComponents method was not found.');
end
end

function code = localReplaceCreateComponents(code, replacement)
pattern = ['(?s)        function createComponents\(app\).*?\r?\n' ...
    '        end(?=\r?\n    end\r?\n\r?\n    % App creation and deletion)'];
[first, last] = regexp(code, pattern, 'start', 'end', 'once');
if isempty(first)
    error('sync_classifier_layout:ReferenceCreateComponents', ...
        'The reference createComponents method was not found.');
end
code = [code(1:first - 1) replacement code(last + 1:end)];
end

function localValidateMergedCode(code)
required = { ...
    'localGuiErrorMessage(', ...
    'isSam31Classifier(', ...
    'parseTrainingFrameSelection(', ...
    'GenerateDraftButton', ...
    'StartBlankGTButton', ...
    'RefreshAnnotationStatusButton', ...
    'AnnotationFilterDropDown'};
for i = 1:numel(required)
    if ~contains(code, required{i})
        error('sync_classifier_layout:Validation', ...
            'Required code is missing after merge: %s', required{i});
    end
end

tokens = regexp(code, 'createCallbackFcn\(app,\s*@([A-Za-z]\w*)', 'tokens');
callbackNames = unique(string(cellfun(@(x)x{1}, tokens, ...
    'UniformOutput', false)));
for i = 1:numel(callbackNames)
    methodPattern = ['(?m)^\s*function\s+' ...
        '(?:(?:\[[^\]]*\]|[A-Za-z]\w*)\s*=\s*)?' ...
        regexptranslate('escape', char(callbackNames(i))) '\s*\('];
    if isempty(regexp(code, methodPattern, 'once'))
        error('sync_classifier_layout:MissingCallback', ...
            'Layout callback %s is absent from the code reference.', ...
            callbackNames(i));
    end
end
end

function code = localNormalizeLayoutNames(code)
% Correct the initial App Designer component typo at every layout merge.
code = strrep(code, 'GenarateDraftButton', 'GenerateDraftButton');
code = strrep(code, 'StartblankGTButton', 'StartBlankGTButton');
end

function text = localNormalize(text)
text = char(text);
if ~isempty(text) && double(text(1)) == 65279
    text = text(2:end);
end
text = regexprep(text, '\r\n?|\n', '\n');
end

function localAssertFile(pathStr, label)
if exist(pathStr, 'file') ~= 2
    error('sync_classifier_layout:MissingFile', 'Missing %s: %s', label, pathStr);
end
end

function localAssertSerializationApi()
hasReader = exist('appdesigner.internal.serialization.FileReader', 'class') == 8;
hasWriter = exist('appdesigner.internal.serialization.FileWriter', 'class') == 8;
if ~(hasReader && hasWriter)
    error('sync_classifier_layout:ApiMissing', ...
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
error('sync_classifier_layout:ReadCodeData', ...
    'Could not read App Designer code metadata.');
end

function data = localReadAppMetadata(reader)
try
    data = reader.readAppMetadata();
catch
    data = struct();
end
end

function localWriteText(pathStr, text)
fid = fopen(pathStr, 'w');
if fid < 0
    error('sync_classifier_layout:Write', 'Cannot open %s for writing.', pathStr);
end
cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
fwrite(fid, text, 'char');
end
