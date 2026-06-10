function sync_pipeline2_layout()
%SYNC_PIPELINE2_LAYOUT Merge AppDesigner pipeline2 layout into the
% code-rich pipeline2_extracted file, then repack the mlapp.
%
% Use this only after editing structure/GUI/pipeline2.mlapp in
% AppDesigner. The AppDesigner layout is treated as the source of truth for:
% - public component properties
% - createComponents(app)
%
% All other custom runtime logic stays in pipeline2_extracted.m.

repoRoot = fileparts(mfilename('fullpath'));
guiDir = fullfile(repoRoot, 'structure', 'GUI');
mlappPath = fullfile(guiDir, 'pipeline2.mlapp');
extractedPath = fullfile(guiDir, 'pipeline2_extracted.m');

if exist(mlappPath, 'file') ~= 2
    error('sync_pipeline2_layout:MissingMlapp', 'Missing %s', mlappPath);
end
if exist(extractedPath, 'file') ~= 2
    error('sync_pipeline2_layout:MissingExtracted', 'Missing %s', extractedPath);
end

runId = datestr(now, 'yyyymmdd_HHMMSS');
bkRoot = fullfile(repoRoot, 'backups', 'pipeline2_layout_sync', runId, 'structure', 'GUI');
if exist(bkRoot, 'dir') ~= 7
    mkdir(bkRoot);
end
copyfile(mlappPath, fullfile(bkRoot, 'pipeline2.mlapp'), 'f');
copyfile(extractedPath, fullfile(bkRoot, 'pipeline2_extracted.m'), 'f');

fr = appdesigner.internal.serialization.FileReader(mlappPath);
shellCode = fr.readMATLABCodeText();
fullCode = fileread(extractedPath);

pubShell = localExtractByRegex(shellCode, '(?s)properties \(Access = public\).*?\n\s*end');
fullCode = localReplaceFirstByRegex(fullCode, '(?s)properties \(Access = public\).*?\n\s*end', pubShell);

ccShell = localExtractByRegex(shellCode, '(?s)function createComponents\(app\).*?\n\s*end');
fullCode = localReplaceLastCreateComponents(fullCode, ccShell);

localWriteText(extractedPath, fullCode);

sync_mlapp_code('pack', 'pipeline2');
fprintf('[pipeline2-sync] done. Backup: %s\n', bkRoot);
end

function blk = localExtractByRegex(txt, ptn)
m = regexp(txt, ptn, 'match', 'once');
if isempty(m)
    error('sync_pipeline2_layout:Parse', 'Pattern not found: %s', ptn);
end
blk = m;
end

function txt = localReplaceFirstByRegex(txt, ptn, repl)
[s,e] = regexp(txt, ptn, 'start', 'end', 'once');
if isempty(s)
    error('sync_pipeline2_layout:Parse', 'Pattern not found in extracted code: %s', ptn);
end
txt = [txt(1:s-1) repl txt(e+1:end)];
end

function txt = localReplaceLastCreateComponents(txt, repl)
idx = regexp(txt, 'function createComponents\(app\)', 'start');
if isempty(idx)
    error('sync_pipeline2_layout:Parse', 'createComponents not found in extracted code.');
end
s = idx(end);
rest = txt(s:end);
m = regexp(rest, '(?s)^function createComponents\(app\).*?\n\s*end', 'match', 'once');
if isempty(m)
    error('sync_pipeline2_layout:Parse', 'createComponents block not parseable in extracted code.');
end
e = s + length(m) - 1;
txt = [txt(1:s-1) repl txt(e+1:end)];
end

function localWriteText(pathStr, txt)
fid = fopen(pathStr, 'w');
if fid < 0
    error('sync_pipeline2_layout:Write', 'Cannot open %s for writing.', pathStr);
end
cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
fwrite(fid, txt, 'char');
end
