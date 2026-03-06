function sync_workflow_layout()
%SYNC_WORKFLOW_LAYOUT Merge AppDesigner workflow layout into code-rich workflow_extracted.
% Use after editing structure/GUI/workflow.mlapp in AppDesigner.

repoRoot = fileparts(mfilename('fullpath'));
guiDir = fullfile(repoRoot, 'structure', 'GUI');
mlappPath = fullfile(guiDir, 'workflow.mlapp');
extractedPath = fullfile(guiDir, 'workflow_extracted.m');

if exist(mlappPath, 'file') ~= 2
    error('sync_workflow_layout:MissingMlapp', 'Missing %s', mlappPath);
end
if exist(extractedPath, 'file') ~= 2
    error('sync_workflow_layout:MissingExtracted', 'Missing %s', extractedPath);
end

runId = datestr(now, 'yyyymmdd_HHMMSS');
bkRoot = fullfile(repoRoot, 'backups', 'workflow_layout_sync', runId, 'structure', 'GUI');
if exist(bkRoot, 'dir') ~= 7
    mkdir(bkRoot);
end
copyfile(mlappPath, fullfile(bkRoot, 'workflow.mlapp'), 'f');
copyfile(extractedPath, fullfile(bkRoot, 'workflow_extracted.m'), 'f');

fr = appdesigner.internal.serialization.FileReader(mlappPath);
shellCode = fr.readMATLABCodeText();
fullCode = fileread(extractedPath);

pubShell = localExtractByRegex(shellCode, '(?s)properties \(Access = public\).*?\n\s*end');
fullCode = localReplaceFirstByRegex(fullCode, '(?s)properties \(Access = public\).*?\n\s*end', pubShell);

ccShell = localExtractByRegex(shellCode, '(?s)function createComponents\(app\).*?\n\s*end');
fullCode = localReplaceLastCreateComponents(fullCode, ccShell);

fullCode = localApplyCompatRenames(fullCode);
localWriteText(extractedPath, fullCode);

sync_mlapp_code('pack', 'workflow');
fprintf('[workflow-sync] done. Backup: %s\n', bkRoot);
end

function blk = localExtractByRegex(txt, ptn)
m = regexp(txt, ptn, 'match', 'once');
if isempty(m)
    error('sync_workflow_layout:Parse', 'Pattern not found: %s', ptn);
end
blk = m;
end

function txt = localReplaceFirstByRegex(txt, ptn, repl)
[s,e] = regexp(txt, ptn, 'start', 'end', 'once');
if isempty(s)
    error('sync_workflow_layout:Parse', 'Pattern not found in extracted code: %s', ptn);
end
txt = [txt(1:s-1) repl txt(e+1:end)];
end

function txt = localReplaceLastCreateComponents(txt, repl)
idx = regexp(txt, 'function createComponents\(app\)', 'start');
if isempty(idx)
    error('sync_workflow_layout:Parse', 'createComponents not found in extracted code.');
end
s = idx(end);
rest = txt(s:end);
m = regexp(rest, '(?s)^function createComponents\(app\).*?\n\s*end', 'match', 'once');
if isempty(m)
    error('sync_workflow_layout:Parse', 'createComponents block not parseable in extracted code.');
end
e = s + length(m) - 1;
txt = [txt(1:s-1) repl txt(e+1:end)];
end

function out = localApplyCompatRenames(out)
repls = {
    'DisplaycolorColorPickerLabel', 'colorColorPickerLabel';
    'DisplaycolorColorPicker', 'colorColorPicker';
    'DrawpatternButton', 'SavepatternButton';
    'UIDisplayPanel', 'ChannelsPanel';
    'SelectallButton', 'selectallButton';
    'DeselectallButton', 'deselectallButton';
    'RemoveselectedButton', 'removeselectedButton';
    'app.TabGroup.SelectedTab = app.DisplayTab;', 'app.TabGroup.SelectedTab = app.DataloaderTab;';
    'app.ROIgenerationmodeButtonGroup.SelectedObject = app.TrackedmasksButton;', 'app.ROIgenerationmodeButtonGroup.SelectedObject = app.PatterndetectionpatternButton;';
    'elseif isequal(app.ROIgenerationmodeButtonGroup.SelectedObject, app.TrackedmasksButton)', 'elseif strcmpi(app.getCurrentRoiMode(),''tracked'')'
    };
for i = 1:size(repls,1)
    out = strrep(out, repls{i,1}, repls{i,2});
end
end

function localWriteText(pathStr, txt)
fid = fopen(pathStr, 'w');
if fid < 0
    error('sync_workflow_layout:Write', 'Cannot open %s for writing.', pathStr);
end
cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
fwrite(fid, txt, 'char');
end
