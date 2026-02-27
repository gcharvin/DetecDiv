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

    % Default template: dataloader -> ROI identification -> ROI extraction
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

    n2 = struct();
    n2.id = 'roiidentify_1';
    n2.name = 'roiidentify_1';
    n2.type = 'roiIdentify';
    n2.func = 'roiIdentify.process';
    n2.gui = 'roiIdentify.ui';
    n2.guiMode = 'replace';
    n2.paramRequired = {};
    n2.pkg = '';
    try
        n2.params = roiIdentify.setparam(struct());
    catch
        n2.params = struct();
    end
    n2.inputs = {'images'};
    n2.outputs = {'roiList'};
    n2.enabled = true;
    n2.status = '';
    n2.layout = [40 10 20 10];

    n3 = struct();
    n3.id = 'roiextract_1';
    n3.name = 'roiextract_1';
    n3.type = 'roiExtract';
    n3.func = 'roiExtract.process';
    n3.gui = '';
    n3.guiMode = 'replace';
    n3.paramRequired = {};
    n3.pkg = '';
    try
        n3.params = roiExtract.setparam(struct());
    catch
        n3.params = struct();
    end
    n3.inputs = {'roiList'};
    n3.outputs = {'channels'};
    n3.enabled = true;
    n3.status = '';
    n3.layout = [70 10 20 10];

    pipeObj.nodes = [n1 n2 n3];
    pipeObj.edges = struct( ...
        'from', {'dataloader_1','roiidentify_1'}, ...
        'to', {'roiidentify_1','roiextract_1'}, ...
        'fromPort', {'images','roiList'}, ...
        'toPort', {'images','roiList'}, ...
        'condition', {'',''});

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
