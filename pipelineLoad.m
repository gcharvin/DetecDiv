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

    if exist(inputPath, 'dir')
        jsonFile = fullfile(inputPath, 'pipeline.json');
    else
        jsonFile = inputPath;
        inputPath = fileparts(jsonFile);
    end

    if ~exist(jsonFile,'file')
        msg = ['Pipeline JSON not found: ' jsonFile];
        return;
    end

    txt = fileread(jsonFile);
    S = jsondecode(txt);

    pipe = pipeline('', '', 1);
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
