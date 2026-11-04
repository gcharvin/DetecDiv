function inventory = progressLegacyTest(outputPath)
%PROGRESSLEGACYTEST Verify packed source and audit lifecycle coverage.
if nargin < 1, outputPath = ''; end
root = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
gui = fullfile(root,'structure','GUI');
for name = {'detecdiv','pipeline2','workflow','workflow2','score'}
    if strcmp(name{1},'score')
        app = fullfile(gui,'score','score.mlapp');
        source = fullfile(gui,'score','private','score_runtime_code.m');
    else
        app = fullfile(gui,[name{1} '.mlapp']); source = fullfile(gui,[name{1} '_extracted.m']);
    end
    reader = appdesigner.internal.serialization.FileReader(app);
    assert(strcmp(normalize(reader.readMATLABCodeText()),normalize(fileread(source))), ...
        'detecdivui:ProgressSync','Runtime MLAPP differs from its source: %s',app);
end
inventory = detecdivui.progressAudit(outputPath);
apps = {'structure/GUI/detecdiv.mlapp','structure/GUI/pipeline2.mlapp', ...
    'structure/GUI/workflow.mlapp','structure/GUI/workflow2.mlapp','structure/GUI/score/score.mlapp'};
dialogs = inventory(strcmp(inventory.API,'uiprogressdlg') & ismember(inventory.File,apps),:);
assert(height(dialogs) >= 50,'Expected runtime progress dialogs are missing from the audit.');
persistentDialogs = contains(dialogs.Function,{'startRoiTreeBuild','RefreshtreewindowMenuSelected', ...
    'createPipelineRunProgressDialog','openRuntimeProgress'});
assert(all(contains(dialogs.CleanupHint(~persistentDialogs),'onCleanup')), ...
    'A synchronous dialog lacks scoped cleanup. Review the progress inventory.');
disp('Legacy progress test passed: five runtime/source pairs match; synchronous dialogs have scoped cleanup.');
end
function text = normalize(text)
text = strrep(text,sprintf('\r\n'),newline);
text = erase(text,char(65279));
end
