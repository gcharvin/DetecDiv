function sync_workflow2_layout()
%SYNC_WORKFLOW2_LAYOUT Merge App Designer workflow2 layout into rich code.
%   Use after editing structure/GUI/workflow2.mlapp in App Designer. The
%   .mlapp layout is kept as the source of truth for createComponents, while
%   workflow2_extracted.m keeps the runtime/business callbacks.

repoRoot = fileparts(mfilename('fullpath'));
guiDir = fullfile(repoRoot, 'structure', 'GUI');
mlappPath = fullfile(guiDir, 'workflow2.mlapp');
extractedPath = fullfile(guiDir, 'workflow2_extracted.m');

if exist(mlappPath, 'file') ~= 2
    error('sync_workflow2_layout:MissingMlapp', 'Missing %s', mlappPath);
end
if exist(extractedPath, 'file') ~= 2
    error('sync_workflow2_layout:MissingExtracted', 'Missing %s', extractedPath);
end

runId = datestr(now, 'yyyymmdd_HHMMSS');
bkRoot = fullfile(repoRoot, 'backups', 'workflow2_layout_sync', runId, 'structure', 'GUI');
if exist(bkRoot, 'dir') ~= 7
    mkdir(bkRoot);
end
copyfile(mlappPath, fullfile(bkRoot, 'workflow2.mlapp'), 'f');
copyfile(extractedPath, fullfile(bkRoot, 'workflow2_extracted.m'), 'f');

fr = appdesigner.internal.serialization.FileReader(mlappPath);
shellCode = fr.readMATLABCodeText();
fullCode = fileread(extractedPath);

pubShell = localExtractByRegex(shellCode, '(?s)properties \(Access = public\).*?\n\s*end');
pubFull = localExtractByRegex(fullCode, '(?s)properties \(Access = public\).*?\n\s*end');
pubMerged = localMergePublicProperties(pubFull, pubShell);
fullCode = localReplaceFirstByRegex(fullCode, '(?s)properties \(Access = public\).*?\n\s*end', pubMerged);

ccShell = localExtractCreateComponents(shellCode);
fullCode = localReplaceLastCreateComponents(fullCode, ccShell);
fullCode = localApplyCompatRenames(fullCode);

localWriteText(extractedPath, fullCode);
sync_mlapp_code('pack', 'workflow2');
fprintf('[workflow2-sync] done. Backup: %s\n', bkRoot);
end

function blk = localExtractByRegex(txt, ptn)
m = regexp(txt, ptn, 'match', 'once');
if isempty(m)
    error('sync_workflow2_layout:Parse', 'Pattern not found: %s', ptn);
end
blk = m;
end

function txt = localReplaceFirstByRegex(txt, ptn, repl)
[s,e] = regexp(txt, ptn, 'start', 'end', 'once');
if isempty(s)
    error('sync_workflow2_layout:Parse', 'Pattern not found in extracted code: %s', ptn);
end
txt = [txt(1:s-1) repl txt(e+1:end)];
end

function txt = localReplaceLastCreateComponents(txt, repl)
idx = regexp(txt, 'function createComponents\(app\)', 'start');
if isempty(idx)
    error('sync_workflow2_layout:Parse', 'createComponents not found in extracted code.');
end
s = idx(end);
nextMethods = regexp(txt(s:end), '\n\s*methods \(Access = public\)', 'start', 'once');
if isempty(nextMethods)
    error('sync_workflow2_layout:Parse', 'Public methods marker not found after createComponents.');
end
e = s + nextMethods - 2;
txt = [txt(1:s-1) repl txt(e+1:end)];
end

function blk = localExtractCreateComponents(txt)
idx = regexp(txt, 'function createComponents\(app\)', 'start');
if isempty(idx)
    error('sync_workflow2_layout:Parse', 'createComponents not found in shell code.');
end
s = idx(end);
nextMethods = regexp(txt(s:end), '\n\s*methods \(Access = public\)', 'start', 'once');
if isempty(nextMethods)
    error('sync_workflow2_layout:Parse', 'Public methods marker not found after shell createComponents.');
end
e = s + nextMethods - 2;
blk = txt(s:e);
end

function merged = localMergePublicProperties(fullBlock, shellBlock)
fullLines = regexp(fullBlock, '\r?\n', 'split')';
shellLines = regexp(shellBlock, '\r?\n', 'split')';
existing = localPropertyNames(fullLines);
shellNames = localPropertyNames(shellLines);

for i = 1:numel(fullLines)
    nm = localPropertyName(fullLines{i});
    if strlength(nm) == 0
        continue;
    end
    j = find(shellNames == nm, 1, 'first');
    if ~isempty(j)
        fullLines{i} = shellLines{j};
    end
end

toAdd = {};

for i = 1:numel(shellLines)
    if startsWith(strtrim(shellLines{i}), "properties") || strcmp(strtrim(shellLines{i}), "end")
        continue;
    end
    nm = localPropertyName(shellLines{i});
    if strlength(nm) == 0 || any(existing == nm)
        continue;
    end
    toAdd{end+1,1} = shellLines{i}; %#ok<AGROW>
    existing(end+1,1) = nm; %#ok<AGROW>
end

if isempty(toAdd)
    merged = fullBlock;
    return;
end

insertAt = find(strcmp(strtrim(fullLines), 'end'), 1, 'last');
if isempty(insertAt)
    error('sync_workflow2_layout:Parse', 'Public property block has no end.');
end
mergedLines = [fullLines(1:insertAt-1); toAdd; fullLines(insertAt:end)];
merged = strjoin(mergedLines, newline);
end

function names = localPropertyNames(lines)
names = strings(0,1);
for i = 1:numel(lines)
    nm = localPropertyName(lines{i});
    if strlength(nm) > 0
        names(end+1,1) = nm; %#ok<AGROW>
    end
end
end

function nm = localPropertyName(line)
tok = regexp(line, '^\s*([A-Za-z]\w*)\s+[\w.]+', 'tokens', 'once');
if isempty(tok)
    nm = "";
else
    nm = string(tok{1});
end
end

function out = localApplyCompatRenames(out)
% Keep method names stable, only redirect component references to the new
% App Designer names introduced in workflow2.
out = strrep(out, 'app.RoiManualRectEditField', 'app.CurrentROIsizeEditField');
out = strrep(out, 'app.RoiManualRectLabel', 'app.CurrentROIsizeEditFieldLabel');
end

function localWriteText(pathStr, txt)
fid = fopen(pathStr, 'w');
if fid < 0
    error('sync_workflow2_layout:Write', 'Cannot open %s for writing.', pathStr);
end
cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
fwrite(fid, txt, 'char');
end
