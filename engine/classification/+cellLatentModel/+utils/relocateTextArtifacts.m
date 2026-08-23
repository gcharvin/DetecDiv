function audit = relocateTextArtifacts(root,sourceRoot,targetRoot)
%RELOCATETEXTARTIFACTS Finalize paths embedded in bundle text artifacts.
%   Training components are first written below a transient .partial_UUID
%   directory and then moved atomically to their immutable bundle.  JSON
%   reports/configs also contain paths and must be rewritten after that move;
%   relocating only the MATLAB manifest structs leaves stale provenance.

root = char(string(root));
sourceRoot = char(string(sourceRoot));
targetRoot = char(string(targetRoot));
if ~isfolder(root)
    error('cellLatentModel:MissingBundleDirectory', ...
        'Cannot relocate text artifacts below missing directory %s.',root);
end

entries = dir(fullfile(root,'**','*'));
entries = entries(~[entries.isdir]);
checked = 0;
rewritten = 0;
relocated = 0;
remaining = 0;
for index = 1:numel(entries)
    filename = fullfile(entries(index).folder,entries(index).name);
    [~,~,extension] = fileparts(filename);
    extension = lower(extension);
    if ~ismember(extension,{'.json','.txt','.yaml','.yml','.csv'})
        continue;
    end
    checked = checked + 1;
    if strcmp(extension,'.json')
        [changed,count,left] = relocateJsonFile( ...
            filename,sourceRoot,targetRoot);
    else
        [changed,count,left] = relocatePlainTextFile( ...
            filename,sourceRoot,targetRoot);
    end
    rewritten = rewritten + double(changed);
    relocated = relocated + count;
    remaining = remaining + left;
end

audit = struct( ...
    'schema_version',1, ...
    'target_root',normalizedPath(targetRoot), ...
    'checked_file_count',double(checked), ...
    'rewritten_file_count',double(rewritten), ...
    'relocated_path_count',double(relocated), ...
    'source_paths_remaining',double(remaining), ...
    'verified_no_transient_paths',remaining == 0);
end

function [changed,count,remaining] = relocateJsonFile( ...
        filename,sourceRoot,targetRoot)
text = fileread(filename);
[text,count] = replaceRoot(text,sourceRoot,targetRoot);
try
    % Parse only to validate the rewritten document.  Do not round-trip via
    % jsondecode/jsonencode: MATLAB sanitizes legal JSON dictionary keys such
    % as "0.5" and "checkpoint/manifest.json" into struct field names.
    jsondecode(text);
catch ME
    error('cellLatentModel:InvalidBundleJson', ...
        'Cannot parse bundle JSON %s: %s',filename,ME.message);
end
changed = count > 0;
if changed
    writeTextAtomic(filename,text);
end
[~,remaining] = replaceRoot(text,sourceRoot,targetRoot);
end

function [changed,count,remaining] = relocatePlainTextFile( ...
        filename,sourceRoot,targetRoot)
text = fileread(filename);
[text,count] = replaceRoot(text,sourceRoot,targetRoot);
changed = count > 0;
if changed
    writeTextAtomic(filename,text);
end
[~,remaining] = replaceRoot(text,sourceRoot,targetRoot);
end

function [text,count] = replaceRoot(text,sourceRoot,targetRoot)
sourceForward = normalizedPath(sourceRoot);
targetForward = normalizedPath(targetRoot);
sourceNative = strrep(sourceForward,'/','\');
sourceJsonNative = strrep(sourceNative,'\','\\');
patterns = {sourceJsonNative,sourceForward,sourceNative};
% Always emit the portable forward-slash spelling. Backslashes in a
% regexprep replacement are escape characters and could silently turn
% C:\models into C:models.
replacements = {targetForward,targetForward,targetForward};
count = 0;
for index = 1:numel(patterns)
    baseExpression = regexptranslate('escape',patterns{index});
    pathExpression = [baseExpression '[/\\]+'];
    pathMatches = regexp(text,pathExpression,'ignorecase');
    count = count + numel(pathMatches);
    if ~isempty(pathMatches)
        text = regexprep(text,pathExpression, ...
            [replacements{index} '/'],'ignorecase');
    end
    expression = [baseExpression ...
        '(?=([/\\]|$|["''\s]))'];
    matches = regexp(text,expression,'ignorecase');
    count = count + numel(matches);
    if ~isempty(matches)
        text = regexprep(text,expression,replacements{index},'ignorecase');
    end
end
end

function writeTextAtomic(filename,text)
temporary = [filename '.tmp_' char(java.util.UUID.randomUUID)];
cleanup = onCleanup(@()deleteIfPresent(temporary));
fid = fopen(temporary,'w');
if fid < 0
    error('cellLatentModel:BundleTextWriteFailed', ...
        'Cannot write temporary bundle artifact %s.',temporary);
end
fileCleanup = onCleanup(@()fclose(fid));
fwrite(fid,text,'char');
clear fileCleanup;
[ok,message] = movefile(temporary,filename,'f');
if ~ok
    error('cellLatentModel:BundleTextPublishFailed', ...
        'Cannot publish bundle artifact %s: %s',filename,message);
end
clear cleanup;
end

function deleteIfPresent(filename)
if isfile(filename),delete(filename);end
end

function value = normalizedPath(value)
value = strrep(char(string(value)),'\','/');
while numel(value) > 3 && endsWith(value,'/'),value(end)=[];end
end
