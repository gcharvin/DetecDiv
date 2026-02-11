function addPipeline(obj, varargin)
% addPipeline  Add a pipeline to an existing project.

    n = numel(obj.processing.pipeline);

    pth = fullfile(obj.io.path, obj.io.file);
    if ~exist(pth, 'dir')
        mkdir(pth);
    end

    if n == 0
        obj.processing.pipeline = pipeline.empty;
        mkdir(pth, 'pipeline');
    end

    name = [];
    for i = 1:numel(varargin)
        if strcmpi(varargin{i}, 'name')
            name = varargin{i+1};
        end
    end

    if isempty(name)
        prompt = 'Please enter the name of the pipeline (Default: pipeline): ';
        name = input(prompt, 's');
        if isempty(name)
            name = 'pipeline';
        end
    end

    pipeRoot = fullfile(pth, 'pipeline');
    if ~exist(pipeRoot, 'dir')
        mkdir(pipeRoot);
    end

    obj.processing.pipeline(n+1) = pipelineNew('path', pipeRoot, 'filename', name, 'id', n+1);
end
