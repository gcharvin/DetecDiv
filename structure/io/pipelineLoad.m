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

    [jsonFile, inputPath, msg, bundleRoot] = resolvePipelineJsonTarget(inputPath);
    if ~isempty(msg)
        return;
    end

    if ~exist(jsonFile,'file')
        msg = ['Pipeline JSON not found: ' jsonFile];
        return;
    end

    txt = fileread(jsonFile);
    S = jsondecode(txt);
    S = relinkPipelineRelativePaths(S, fileparts(jsonFile), bundleRoot);

    pipe = pipelineConstruct('', '', 1);
    try
        pipe.id = getField(S,'id',1);
        pipe.strid = getField(S,'name','pipeline');
        pipe.version = getField(S,'version','1.0');
        pipe.description = getField(S,'description','');
        pipe.nodes = pipelineNormalizeNodes(getField(S,'nodes',struct([])), 'persist');
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

function [jsonFile, basePath, msg, bundleRoot] = resolvePipelineJsonTarget(inputPath)
    msg = '';
    jsonFile = '';
    basePath = '';
    bundleRoot = '';

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
                bundleRoot = fileparts(manifestPath);
            end
            return;
        end

        pipelineSub = fullfile(basePath, 'pipeline', 'pipeline.json');
        if exist(pipelineSub, 'file') == 2
            jsonFile = pipelineSub;
            basePath = fileparts(jsonFile);
            if exist(fullfile(inputPath, 'export_manifest.json'), 'file') == 2
                bundleRoot = inputPath;
            end
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
            bundleRoot = basePath;
            basePath = fileparts(jsonFile);
        end
    else
        parent = fileparts(basePath);
        manifestPath = fullfile(parent, 'export_manifest.json');
        if exist(manifestPath, 'file') == 2 && manifestPointsToJson(manifestPath, parent, jsonFile)
            bundleRoot = parent;
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

function tf = manifestPointsToJson(manifestPath, bundleRoot, jsonFile)
    tf = false;
    try
        S = jsondecode(fileread(manifestPath));
        relPath = char(string(S.pipeline.bundlePipelinePath));
        if isAbsolutePathLocal(relPath)
            candidate = relPath;
        else
            candidate = fullfile(bundleRoot, relPath);
        end
        tf = strcmpi(canonicalPathLocal(candidate), canonicalPathLocal(jsonFile));
    catch
        tf = false;
    end
end

function S = relinkPipelineRelativePaths(S, pipelineRoot, bundleRoot)
    if ~isstruct(S) || ~isfield(S, 'nodes') || isempty(S.nodes)
        return;
    end
    for i = 1:numel(S.nodes)
        S.nodes(i) = relinkNodeRelativePaths(S.nodes(i), pipelineRoot, bundleRoot);
        if isfield(S.nodes(i), 'params') && isstruct(S.nodes(i).params)
            S.nodes(i).params = relinkRelativePathParams(S.nodes(i).params, pipelineRoot, bundleRoot);
        end
    end
    if ~isempty(bundleRoot)
        if ~isfield(S, 'runProfiles') || ~isstruct(S.runProfiles)
            S.runProfiles = struct();
        end
        S.runProfiles.bundle = struct( ...
            'bundleRoot', char(string(bundleRoot)), ...
            'pipelineRoot', char(string(pipelineRoot)), ...
            'loadedAt', char(datetime('now')));
    end
end

function node = relinkNodeRelativePaths(node, pipelineRoot, bundleRoot)
    names = fieldnames(node);
    for i = 1:numel(names)
        name = names{i};
        if any(strcmp(name, {'params','origin','runState'}))
            continue;
        end
        value = node.(name);
        if ~(ischar(value) || (isstring(value) && isscalar(value)))
            continue;
        end
        text = char(string(value));
        if isempty(text) || isAbsolutePathLocal(text) || ~looksLikeBundlePathParam(name, text)
            continue;
        end
        node.(name) = resolveBundleRelativePath(text, pipelineRoot, bundleRoot, shouldCreatePathForParam(name));
    end
end

function params = relinkRelativePathParams(params, pipelineRoot, bundleRoot)
    names = fieldnames(params);
    for i = 1:numel(names)
        name = names{i};
        value = params.(name);
        if isstruct(value)
            params.(name) = relinkNestedRelativePathStruct(value, pipelineRoot, bundleRoot);
            continue;
        end
        if ~(ischar(value) || (isstring(value) && isscalar(value)))
            continue;
        end
        text = char(string(value));
        if isempty(text) || isAbsolutePathLocal(text) || ~looksLikeBundlePathParam(name, text)
            continue;
        end
        params.(name) = resolveBundleRelativePath(text, pipelineRoot, bundleRoot, shouldCreatePathForParam(name));
    end
end

function value = relinkNestedRelativePathStruct(value, pipelineRoot, bundleRoot)
    for k = 1:numel(value)
        names = fieldnames(value(k));
        for i = 1:numel(names)
            name = names{i};
            item = value(k).(name);
            if isstruct(item)
                value(k).(name) = relinkNestedRelativePathStruct(item, pipelineRoot, bundleRoot);
            elseif ischar(item) || (isstring(item) && isscalar(item))
                text = char(string(item));
                if ~isempty(text) && ~isAbsolutePathLocal(text) && looksLikeBundlePathParam(name, text)
                    value(k).(name) = resolveBundleRelativePath(text, pipelineRoot, bundleRoot, shouldCreatePathForParam(name));
                end
            end
        end
    end
end

function out = resolveBundleRelativePath(pathText, pipelineRoot, bundleRoot, createParent)
    out = char(string(pathText));
    candidates = {};
    if ~isempty(pipelineRoot)
        candidates{end+1} = fullfile(pipelineRoot, out); %#ok<AGROW>
    end
    if ~isempty(bundleRoot)
        candidates{end+1} = fullfile(bundleRoot, out); %#ok<AGROW>
    end
    for i = 1:numel(candidates)
        candidate = canonicalPathLocal(candidates{i});
        if exist(candidate, 'dir') == 7 || exist(candidate, 'file') == 2
            out = candidate;
            return;
        end
    end
    if isempty(candidates)
        return;
    end
    candidate = canonicalPathLocal(candidates{1});
    if createParent
        try
            if exist(candidate, 'dir') ~= 7
                mkdir(candidate);
            end
        catch
        end
    end
    out = candidate;
end

function tf = looksLikeBundlePathParam(name, value)
    key = lower(char(string(name)));
    value = char(string(value));
    tf = contains(value, '/') || contains(value, '\') || ...
        contains(key, 'path') || contains(key, 'dir') || contains(key, 'folder') || contains(key, 'root') || ...
        any(strcmp(key, {'patchfile','patchpreviewfile'}));
end

function tf = shouldCreatePathForParam(name)
    key = lower(char(string(name)));
    tf = contains(key, 'output') || contains(key, 'export') || contains(key, 'result') || ...
        contains(key, 'figure') || contains(key, 'report') || contains(key, 'workbook');
end

function out = canonicalPathLocal(pathText)
    out = char(string(pathText));
    try
        out = char(java.io.File(out).getCanonicalPath());
    catch
    end
end

function tf = isAbsolutePathLocal(p)
    tf = false;
    p = char(string(p));
    if isempty(p)
        return;
    end
    tf = startsWith(p, '/') || ~isempty(regexp(p, '^[A-Za-z]:[\\/]', 'once')) || startsWith(p, '\\');
end
