function pipeObj = pipelineNew(varargin)
% pipelineNew  Create a new pipeline object and folder.
%   pipeObj = pipelineNew('path', PATH, 'filename', NAME, 'id', ID)

    path = pwd;
    filename = 'pipeline';
    id = 1;

    if nargin ~= 0
        for i = 1:numel(varargin)
            if strcmpi(varargin{i}, 'path')
                path = varargin{i+1};
            end
            if strcmpi(varargin{i}, 'filename')
                filename = varargin{i+1};
            end
            if strcmpi(varargin{i}, 'id')
                id = varargin{i+1};
            end
        end
    else
        [file, p] = uiputfile('pipeline.json', 'Select pipeline location', fullfile(path, 'pipeline.json'));
        if isequal(file, 0)
            disp('User selected Cancel');
            pipeObj = [];
            return;
        end
        path = p;
        filename = file;
    end

    if isempty(filename)
        filename = ['pipeline_' char(datetime('now','Format','yyyyMMdd_HHmmss'))];
    end

    if contains(filename, '.json')
        filename = replace(filename, '.json', '');
    end
    if contains(filename, '.mat')
        filename = replace(filename, '.mat', '');
    end

    % ensure pipeline root folder
    if ~isempty(path)
        [~, tail] = fileparts(path);
        if ~strcmpi(tail, 'pipeline')
            path = fullfile(path, 'pipeline');
        end
    end

    pipeObj = pipeline(path, filename, id);
    pipeObj.log('Pipeline creation', 'Creation');

    try
        pipelineSave(pipeObj);
    catch
    end
end
