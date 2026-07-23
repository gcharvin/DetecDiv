function report = sync_mlapp_code(mode, targets, guiDir, opts)
%SYNC_MLAPP_CODE Sync App Designer code between .mlapp and .m files.
%   report = sync_mlapp_code("extract")
%   report = sync_mlapp_code("pack")
%   report = sync_mlapp_code("extract", "workflow")
%   report = sync_mlapp_code("pack", ["workflow","detecdiv"])
%   report = sync_mlapp_code("pack", "workflow", [], struct("Backup", true))
%
% Modes:
%   "extract"  : copy code from .mlapp to *_extracted.m
%   "pack"     : write *_extracted.m code back into .mlapp (layout preserved)
%   "roundtrip": extract then pack
%
% Defaults:
%   opts.Backup     = true
%   opts.BackupRoot = <repo>/backups/mlapp_sync
%   opts.AllowWorkflowExtract = false (safe default)
%
% Pair discovery:
%   By default, this function scans structure/GUI and keeps apps that have
%   both "<name>.mlapp" and "<name>_extracted.m".

    if nargin < 1 || isempty(mode)
        mode = "extract";
    end
    if nargin < 2
        targets = string.empty(0, 1);
    end

    repoRoot = fileparts(mfilename("fullpath"));

    if nargin < 3 || isempty(guiDir)
        guiDir = fullfile(repoRoot, "structure", "GUI");
    end
    if nargin < 4 || isempty(opts)
        opts = struct();
    end

    mode = lower(string(mode));
    targets = string(targets);
    targets = targets(:);
    opts = localNormalizeOptions(opts, repoRoot);

    pairs = localDiscoverPairs(guiDir);
    if ~isempty(targets)
        pairs = localFilterPairs(pairs, targets);
    end
    if isempty(pairs)
        error("sync_mlapp_code:NoPairs", "No .mlapp/*_extracted.m pairs found.");
    end


    if mode == "extract" && ~opts.AllowWorkflowExtract
        names = lower(string({pairs.name}));
        if any(names == "workflow")
            error("sync_mlapp_code:WorkflowExtractBlocked", ...
                ["Extract is blocked for workflow by default because AppDesigner layout saves can overwrite code. " ...
                 "Use sync_workflow_layout instead, or pass opts.AllowWorkflowExtract=true if you really want extract."]);
        end
    end

    switch mode
        case "extract"
            report = localRunExtract(pairs, opts, repoRoot);
        case "pack"
            report = localRunPack(pairs, opts, repoRoot);
        case "roundtrip"
            localRunExtract(pairs, opts, repoRoot);
            report = localRunPack(pairs, opts, repoRoot);
        otherwise
            error("sync_mlapp_code:BadMode", ...
                "Unknown mode '%s'. Use extract, pack, or roundtrip.", mode);
    end
end

function opts = localNormalizeOptions(opts, repoRoot)
    if ~isfield(opts, "Backup") || isempty(opts.Backup)
        opts.Backup = true;
    end
    if ~isfield(opts, "BackupRoot") || isempty(opts.BackupRoot)
        opts.BackupRoot = fullfile(repoRoot, "backups", "mlapp_sync");
    end
    if ~isfield(opts, "RunId") || isempty(opts.RunId)
        opts.RunId = string(datestr(now, "yyyymmdd_HHMMSS"));
    end

    if ~isfield(opts, "AllowWorkflowExtract") || isempty(opts.AllowWorkflowExtract)
        opts.AllowWorkflowExtract = false;
    end

    opts.Backup = logical(opts.Backup);
    opts.AllowWorkflowExtract = logical(opts.AllowWorkflowExtract);
    opts.BackupRoot = char(string(opts.BackupRoot));
    opts.RunId = char(string(opts.RunId));

    if opts.Backup
        runDir = fullfile(opts.BackupRoot, opts.RunId);
        if exist(runDir, "dir") ~= 7
            mkdir(runDir);
        end
        opts.RunBackupDir = runDir;
    else
        opts.RunBackupDir = "";
    end
end

function pairs = localDiscoverPairs(guiDir)
    mlapps = dir(fullfile(guiDir, "*.mlapp"));
    pairs = struct("name", {}, "mlapp", {}, "m", {});

    for i = 1:numel(mlapps)
        [~, base] = fileparts(mlapps(i).name);
        mFile = fullfile(guiDir, base + "_extracted.m");
        if exist(mFile, "file") == 2
            item.name = string(base); %#ok<AGROW>
            item.mlapp = string(fullfile(guiDir, mlapps(i).name));
            item.m = string(mFile);
            pairs(end + 1) = item; %#ok<AGROW>
        end
    end
end

function out = localFilterPairs(pairs, targets)
    targets = lower(targets);
    out = pairs([]);

    for i = 1:numel(pairs)
        nm = lower(pairs(i).name);
        if any(targets == nm)
            out(end + 1) = pairs(i); %#ok<AGROW>
        end
    end
end

function report = localRunExtract(pairs, opts, repoRoot)
    localAssertSerializationApi();
    report = localInitReport();

    for i = 1:numel(pairs)
        appName = pairs(i).name;
        backupPath = "";
        try
            if opts.Backup
                backupPath = localBackupFile(char(pairs(i).m), opts, repoRoot);
            end
            fr = appdesigner.internal.serialization.FileReader(char(pairs(i).mlapp));
            code = fr.readMATLABCodeText();
            localWriteTextFile(char(pairs(i).m), code);
            fprintf("[sync] extract  %s -> %s\n", appName, pairs(i).m);
            row = {appName, "extract", pairs(i).m, string(backupPath), "ok"};
        catch ME
            warning("[sync] extract failed for %s: %s", appName, ME.message);
            row = {appName, "extract", pairs(i).m, string(backupPath), "error: " + string(ME.message)};
        end
        report = [report; row]; %#ok<AGROW>
    end
end

function report = localRunPack(pairs, opts, repoRoot)
    localAssertSerializationApi();
    report = localInitReport();

    for i = 1:numel(pairs)
        appName = pairs(i).name;
        backupPath = "";
        try
            if opts.Backup
                backupPath = localBackupFile(char(pairs(i).mlapp), opts, repoRoot);
            end
            code = fileread(char(pairs(i).m));
            % Prevent BOM from being embedded into mlapp code (can break parsing).
            if ~isempty(code) && double(code(1)) == 65279
                code = code(2:end);
            end
            fr = appdesigner.internal.serialization.FileReader(char(pairs(i).mlapp));
            appCodeData = localReadAppCodeData(fr);
            appMetadata = localReadAppMetadata(fr);
            fw = appdesigner.internal.serialization.FileWriter(char(pairs(i).mlapp));
            fw.writeAppCodeData(code, appCodeData, appMetadata);
            % FileWriter may normalize line endings. Re-read the mlapp and
            % verify that its embedded MATLAB code is otherwise identical
            % to the extracted source before reporting a successful pack.
            verifyReader = appdesigner.internal.serialization.FileReader(char(pairs(i).mlapp));
            embeddedCode = verifyReader.readMATLABCodeText();
            if ~strcmp(localNormalizeCodeText(embeddedCode), localNormalizeCodeText(code))
                error("sync_mlapp_code:PackVerificationFailed", ...
                    "Embedded code differs from %s after packing %s.", pairs(i).m, appName);
            end
            fprintf("[sync] pack     %s <- %s\n", appName, pairs(i).m);
            row = {appName, "pack", pairs(i).mlapp, string(backupPath), "ok"};
        catch ME
            warning("[sync] pack failed for %s: %s", appName, ME.message);
            row = {appName, "pack", pairs(i).mlapp, string(backupPath), "error: " + string(ME.message)};
        end
        report = [report; row]; %#ok<AGROW>
    end
end

function report = localInitReport()
    report = table('Size', [0 5], ...
        'VariableTypes', {'string','string','string','string','string'}, ...
        'VariableNames', {'app','action','path','backup','status'});
end

function backupPath = localBackupFile(srcPath, opts, repoRoot)
    srcPath = char(srcPath);
    if exist(srcPath, "file") ~= 2
        backupPath = "";
        return;
    end

    rel = localRelativePath(srcPath, repoRoot);
    if startsWith(rel, [".." filesep]) || strcmp(rel, "..")
        [~, n, e] = fileparts(srcPath);
        rel = fullfile("external", [n e]);
    end

    backupPath = fullfile(opts.RunBackupDir, rel);
    backupDir = fileparts(backupPath);
    if exist(backupDir, "dir") ~= 7
        mkdir(backupDir);
    end
    copyfile(srcPath, backupPath, "f");
end

function rel = localRelativePath(pathStr, rootStr)
    pathStr = char(pathStr);
    rootStr = char(rootStr);
    pathNorm = localNormalizePath(pathStr);
    rootNorm = localNormalizePath(rootStr);

    if startsWith(pathNorm, [rootNorm filesep], 'IgnoreCase', true)
        rel = pathNorm(numel(rootNorm) + 2:end);
    elseif strcmpi(pathNorm, rootNorm)
        rel = "";
    else
        rel = pathNorm;
    end
end

function p = localNormalizePath(p)
    p = char(string(p));
    p = strrep(p, '/', filesep);
    while endsWith(p, filesep)
        p(end) = [];
    end
end

function localAssertSerializationApi()
    hasReader = exist("appdesigner.internal.serialization.FileReader", "class") == 8;
    hasWriter = exist("appdesigner.internal.serialization.FileWriter", "class") == 8;
    if ~(hasReader && hasWriter)
        error("sync_mlapp_code:ApiMissing", ...
            "App Designer serialization API not found in this MATLAB session.");
    end
end

function data = localReadAppCodeData(fr)
    try
        data = fr.readAppCodeData();
        return;
    catch
    end
    try
        data = fr.readAppDesignerData();
        return;
    catch
    end
    error("sync_mlapp_code:ReadCodeDataMissing", ...
        "Cannot read AppDesigner code data from mlapp.");
end

function metadata = localReadAppMetadata(fr)
    try
        metadata = fr.readAppMetadata();
    catch
        metadata = struct();
    end
end

function localWriteTextFile(pathStr, txt)
    fid = fopen(pathStr, "w");
    if fid < 0
        error("sync_mlapp_code:OpenFailed", "Cannot open file for writing: %s", pathStr);
    end
    cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
    fwrite(fid, txt, "char");
end

function txt = localNormalizeCodeText(txt)
    txt = char(txt);
    if ~isempty(txt) && double(txt(1)) == 65279
        txt = txt(2:end);
    end
    txt = regexprep(txt, '\r\n?|\n', '\n');
end


