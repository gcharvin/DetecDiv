function sync_detecdiv_layout()
%SYNC_DETECDIV_LAYOUT Merge AppDesigner detecdiv layout into the
% code-rich detecdiv_extracted file, then repack the mlapp.
%
% Use this only after editing structure/GUI/detecdiv.mlapp in AppDesigner.
% The AppDesigner layout is treated as the source of truth for:
% - public component properties
% - createComponents(app)
%
% All other custom runtime logic stays in detecdiv_extracted.m.

repoRoot = fileparts(mfilename('fullpath'));
guiDir = fullfile(repoRoot, 'structure', 'GUI');
mlappPath = fullfile(guiDir, 'detecdiv.mlapp');
extractedPath = fullfile(guiDir, 'detecdiv_extracted.m');

if exist(mlappPath, 'file') ~= 2
    error('sync_detecdiv_layout:MissingMlapp', 'Missing %s', mlappPath);
end
if exist(extractedPath, 'file') ~= 2
    error('sync_detecdiv_layout:MissingExtracted', 'Missing %s', extractedPath);
end

runId = datestr(now, 'yyyymmdd_HHMMSS');
bkRoot = fullfile(repoRoot, 'backups', 'detecdiv_layout_sync', runId, 'structure', 'GUI');
if exist(bkRoot, 'dir') ~= 7
    mkdir(bkRoot);
end
copyfile(mlappPath, fullfile(bkRoot, 'detecdiv.mlapp'), 'f');
copyfile(extractedPath, fullfile(bkRoot, 'detecdiv_extracted.m'), 'f');

fr = appdesigner.internal.serialization.FileReader(mlappPath);
shellCode = fr.readMATLABCodeText();
fullCode = fileread(extractedPath);

pubShell = localExtractByRegex(shellCode, '(?s)properties \(Access = public\).*?\n\s*end');
fullCode = localReplaceFirstByRegex(fullCode, '(?s)properties \(Access = public\).*?\n\s*end', pubShell);

ccShell = localExtractByRegex(shellCode, '(?s)function createComponents\(app\).*?\n\s*end');
fullCode = localReplaceLastCreateComponents(fullCode, ccShell);

localWriteText(extractedPath, fullCode);

sync_mlapp_code('pack', 'detecdiv');
fprintf('[detecdiv-sync] done. Backup: %s\n', bkRoot);
end

function blk = localExtractByRegex(txt, ptn)
m = regexp(txt, ptn, 'match', 'once');
if isempty(m)
    error('sync_detecdiv_layout:Parse', 'Pattern not found: %s', ptn);
end
blk = m;
end

function txt = localReplaceFirstByRegex(txt, ptn, repl)
[s,e] = regexp(txt, ptn, 'start', 'end', 'once');
if isempty(s)
    error('sync_detecdiv_layout:Parse', 'Pattern not found in extracted code: %s', ptn);
end
txt = [txt(1:s-1) repl txt(e+1:end)];
end

function txt = localReplaceLastCreateComponents(txt, repl)
idx = regexp(txt, 'function createComponents\(app\)', 'start');
if isempty(idx)
    error('sync_detecdiv_layout:Parse', 'createComponents not found in extracted code.');
end
s = idx(end);
rest = txt(s:end);
m = regexp(rest, '(?s)^function createComponents\(app\).*?\n\s*end', 'match', 'once');
if isempty(m)
    error('sync_detecdiv_layout:Parse', 'createComponents block not parseable in extracted code.');
end
e = s + length(m) - 1;
txt = [txt(1:s-1) repl txt(e+1:end)];
end

function localWriteText(pathStr, txt)
fid = fopen(pathStr, 'w');
if fid < 0
    error('sync_detecdiv_layout:Write', 'Cannot open %s for writing.', pathStr);
end
cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
fwrite(fid, txt, 'char');
end
