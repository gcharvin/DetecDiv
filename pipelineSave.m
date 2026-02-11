function pipelineSave(pipe)
% pipelineSave  Save pipeline to JSON in its folder.

    if nargin < 1 || isempty(pipe)
        return;
    end

    [path, file] = pipe.getPath;
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
