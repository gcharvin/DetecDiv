function pipelineSave(pipe)
% pipelineSave  Save pipeline to JSON in its folder and sync module artifacts.

    if nargin < 1 || isempty(pipe)
        return;
    end

    [path, ~] = pipe.getPath;
    if isempty(path)
        error('pipelineSave:NoPath','Pipeline path is empty.');
    end
    if ~exist(path,'dir')
        mkdir(path);
    end

    jsonFile = fullfile(path, 'pipeline.json');

    S = pipelineToStruct(pipe);

    try
        txt = jsonencode(S, 'PrettyPrint', true);
    catch
        txt = jsonencode(S);
    end

    fid = fopen(jsonFile, 'w');
    if fid < 0
        error('pipelineSave:IO','Unable to write %s', jsonFile);
    end
    fwrite(fid, txt, 'char');
    fclose(fid);

    % Keep one folder per node with a lightweight manifest/params.
    try
        syncModuleArtifacts(path, pipe.nodes);
    catch ME
        warning('pipelineSave:Artifacts','Could not sync module artifacts: %s', ME.message);
    end

    pipe.log(['Pipeline saved to ' jsonFile], 'Save');
    fprintf('Pipeline saved: %s\n', jsonFile);
end

function S = pipelineToStruct(pipe)
    S = struct();
    S.name = pipe.strid;
    S.id = pipe.id;
    S.version = pipe.version;
    S.description = pipe.description;

    S.nodes = pipe.nodes;
    S.edges = pipe.edges;
    if ~isempty(pipe.branches)
        S.branches = pipe.branches;
    end

    S.runState = pipe.runState;
    S.runProfiles = pipe.runProfiles;

    S.createdAt = '';
    S.updatedAt = char(datetime('now'));
end

function syncModuleArtifacts(pipePath, nodes)
    modulesRoot = fullfile(pipePath, 'modules');
    if ~exist(modulesRoot, 'dir')
        mkdir(modulesRoot);
    end

    if isempty(nodes)
        return;
    end

    keepDirs = strings(0,1);
    for i = 1:numel(nodes)
        node = nodes(i);
        nodeId = getNodeId(node, i);
        dirName = sanitizeName(nodeId);
        nodeDir = fullfile(modulesRoot, dirName);
        keepDirs(end+1,1) = string(dirName); %#ok<AGROW>

        if ~exist(nodeDir, 'dir')
            mkdir(nodeDir);
        end

        M = struct();
        M.id = nodeId;
        M.type = getField(node,'type','');
        M.pkg = getField(node,'pkg','');
        M.func = getField(node,'func','');
        M.params = sanitizeForJson(getField(node,'params',struct()));
        M.inputs = getField(node,'inputs',{});
        M.outputs = getField(node,'outputs',{});
        M.updatedAt = char(datetime('now'));

        writeJson(fullfile(nodeDir,'module.json'), M);

        t = lower(char(string(M.type)));
        if strcmp(t,'classifier')
            helperDir = fullfile(nodeDir,'helpers');
            if ~exist(helperDir,'dir')
                mkdir(helperDir);
            end
        end

        if strcmp(t,'processor')
            save(fullfile(nodeDir,'params.mat'), 'M');
        end
    end

    % Cleanup stale module directories
    d = dir(modulesRoot);
    d = d([d.isdir]);
    names = string({d.name});
    names = names(~ismember(names, [".",".."]));
    stale = setdiff(names, keepDirs);
    for i = 1:numel(stale)
        try
            rmdir(fullfile(modulesRoot, char(stale(i))), 's');
        catch
        end
    end
end

function id = getNodeId(node, idx)
    id = getField(node,'id','');
    if isempty(id)
        id = ['node_' num2str(idx)];
    end
    id = char(string(id));
end

function v = getField(S, name, default)
    if isstruct(S) && isfield(S, name)
        v = S.(name);
    else
        v = default;
    end
end

function out = sanitizeForJson(in)
    if isempty(in)
        out = in;
        return;
    end

    if isstruct(in)
        out = in;
        fn = fieldnames(in);
        for k = 1:numel(in)
            for i = 1:numel(fn)
                out(k).(fn{i}) = sanitizeForJson(in(k).(fn{i}));
            end
        end
        return;
    end

    if iscell(in)
        out = cell(size(in));
        for i = 1:numel(in)
            out{i} = sanitizeForJson(in{i});
        end
        return;
    end

    if isnumeric(in) || islogical(in) || ischar(in)
        out = in;
        return;
    end

    if isstring(in)
        out = cellstr(in);
        return;
    end

    if isa(in,'handle')
        out = struct('className', class(in), 'note', 'handle omitted for JSON');
        return;
    end

    try
        jsonencode(in);
        out = in;
    catch
        out = struct('className', class(in), 'note', 'value omitted for JSON');
    end
end

function writeJson(filename, S)
    try
        txt = jsonencode(S, 'PrettyPrint', true);
    catch
        txt = jsonencode(S);
    end
    fid = fopen(filename, 'w');
    if fid < 0
        error('pipelineSave:IO','Unable to write %s', filename);
    end
    fwrite(fid, txt, 'char');
    fclose(fid);
end

function out = sanitizeName(nameIn)
    out = regexprep(char(string(nameIn)), '[^a-zA-Z0-9_\-]', '_');
    if isempty(out)
        out = 'module';
    end
end
