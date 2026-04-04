function [pipe, msg] = pipelineLoad(inputPath)
% pipelineLoad  Load pipeline from JSON file or folder.

    msg = '';
    pipe = [];

    if nargin == 0 || isempty(inputPath)
        [file, path] = uigetfile('*.json', 'Select pipeline.json', pwd);
        if isequal(file, 0)
            msg = 'User cancelled.';
            return;
        end
        inputPath = fullfile(path, file);
    end

    [jsonFile, inputPath, msg] = resolvePipelineJsonTarget(inputPath);
    if ~isempty(msg)
        return;
    end

    if ~exist(jsonFile,'file')
        msg = ['Pipeline JSON not found: ' jsonFile];
        return;
    end

    txt = fileread(jsonFile);
    S = jsondecode(txt);

    pipe = pipelineConstruct('', '', 1);
    try
        pipe.id = getField(S,'id',1);
        pipe.strid = getField(S,'name','pipeline');
        pipe.version = getField(S,'version','1.0');
        pipe.description = getField(S,'description','');
        pipe.nodes = getField(S,'nodes',struct([]));
        pipe.edges = getField(S,'edges',struct([]));
        pipe.branches = getField(S,'branches',struct([]));
        pipe.runState = getField(S,'runState',struct());
        pipe.runProfiles = getField(S,'runProfiles',struct());
        pipe.path = inputPath;
    catch ME
        msg = ME.message;
        pipe = [];
        return;
    end

    pipe.log(['Pipeline loaded from ' jsonFile], 'Load');
end

function v = getField(S, name, default)
    if isfield(S, name)
        v = S.(name);
    else
        v = default;
    end
end

function [jsonFile, basePath, msg] = resolvePipelineJsonTarget(inputPath)
    msg = '';
    jsonFile = '';
    basePath = '';

    inputPath = char(string(inputPath));
    if exist(inputPath, 'dir')
        basePath = inputPath;
        directJson = fullfile(basePath, 'pipeline.json');
        if exist(directJson, 'file') == 2
            jsonFile = directJson;
            return;
        end

        manifestPath = fullfile(basePath, 'export_manifest.json');
        if exist(manifestPath, 'file') == 2
            [jsonFile, msg] = resolvePipelineJsonFromManifest(manifestPath, basePath);
            if isempty(msg)
                basePath = fileparts(jsonFile);
            end
            return;
        end

        pipelineSub = fullfile(basePath, 'pipeline', 'pipeline.json');
        if exist(pipelineSub, 'file') == 2
            jsonFile = pipelineSub;
            basePath = fileparts(jsonFile);
            return;
        end

        msg = ['Pipeline JSON not found in folder: ' inputPath];
        return;
    end

    jsonFile = inputPath;
    basePath = fileparts(jsonFile);

    [~, fname, ext] = fileparts(jsonFile);
    if strcmpi(ext, '.json') && strcmpi(fname, 'export_manifest')
        [jsonFile, msg] = resolvePipelineJsonFromManifest(jsonFile, basePath);
        if isempty(msg)
            basePath = fileparts(jsonFile);
        end
    end
end

function [jsonFile, msg] = resolvePipelineJsonFromManifest(manifestPath, basePath)
    msg = '';
    jsonFile = '';
    try
        txt = fileread(manifestPath);
        S = jsondecode(txt);
    catch ME
        msg = ['Could not read export manifest: ' ME.message];
        return;
    end

    if ~isstruct(S) || ~isfield(S, 'pipeline') || ~isstruct(S.pipeline) || ...
            ~isfield(S.pipeline, 'bundlePipelinePath') || isempty(S.pipeline.bundlePipelinePath)
        msg = ['Invalid export manifest: ' manifestPath];
        return;
    end

    relPath = char(string(S.pipeline.bundlePipelinePath));
    if isAbsolutePathLocal(relPath)
        candidate = relPath;
    else
        candidate = fullfile(basePath, relPath);
    end
    if exist(candidate, 'file') ~= 2
        msg = ['Bundle pipeline JSON not found from manifest: ' candidate];
        return;
    end
    jsonFile = candidate;
end

function tf = isAbsolutePathLocal(p)
    tf = false;
    p = char(string(p));
    if isempty(p)
        return;
    end
    if ispc
        tf = ~isempty(regexp(p, '^[A-Za-z]:[\\/]', 'once')) || startsWith(p, '\\');
    else
        tf = startsWith(p, '/');
    end
end
