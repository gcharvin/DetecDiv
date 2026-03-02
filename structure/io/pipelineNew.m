function pipeObj = pipelineNew(varargin)
% pipelineNew  Create a new independent pipeline object and folder.
%   pipeObj = pipelineNew('path', PATH, 'name', NAME, 'id', ID, 'workspace', TF)
%   Backward-compatible aliases:
%     'filename' -> 'name'
%
% PATH is the parent directory. The pipeline folder is created as PATH/NAME.

    path = '';
    name = 'pipeline';
    id = 1;
    publishWs = false;

    i = 1;
    while i <= numel(varargin)
        key = varargin{i};
        if ~ischar(key) && ~isstring(key)
            i = i + 1;
            continue;
        end
        switch lower(char(string(key)))
            case 'path'
                path = varargin{i+1};
            case {'filename','name'}
                name = varargin{i+1};
            case 'id'
                id = varargin{i+1};
            case 'workspace'
                publishWs = logical(varargin{i+1});
        end
        i = i + 2;
    end

    if isempty(name)
        name = ['pipeline_' char(datetime('now','Format','yyyyMMdd_HHmmss'))];
    end

    name = char(string(name));
    name = strrep(name, '.json', '');
    name = strrep(name, '.mat', '');

    if isempty(path)
        path = uigetdir(pwd, 'Select parent folder where pipeline folder will be created');
        if isequal(path, 0)
            disp('User selected Cancel');
            pipeObj = [];
            return;
        end
    end

    pipeObj = pipeline(path, name, id);

    % Default template: dataloader only. ROI-producing and ROI-extraction
    % modules are added on demand when the user chooses a concrete workflow.
    n1 = struct();
    n1.id = 'dataloader_1';
    n1.name = 'dataloader_1';
    n1.type = 'dataLoader';
    n1.func = 'dataLoader.process';
    n1.gui = 'dataLoader.ui';
    n1.guiMode = 'replace';
    n1.paramRequired = {'path'};
    n1.pkg = '';
    try
        n1.params = dataLoader.setparam(struct());
    catch
        n1.params = struct();
    end
    n1.inputs = {};
    n1.outputs = {'images'};
    n1.enabled = true;
    n1.status = '';
    n1.layout = [10 10 20 10];

    pipeObj.nodes = n1;
    pipeObj.edges = struct('from',{},'to',{},'fromPort',{},'toPort',{},'condition',{});

    pipeObj.log('Pipeline creation', 'Creation');

    try
        pipelineSave(pipeObj);
    catch
    end

    if publishWs
        varName = matlab.lang.makeValidName(pipeObj.strid);
        assignin('base', varName, pipeObj);
    end
end
