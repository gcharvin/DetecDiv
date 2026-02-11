function addPipelineRun(obj, templateId, templatePath, varargin)
% addPipelineRun  Create a pipeline run associated with this project.

    if nargin < 2 || isempty(templateId)
        templateId = 'pipeline';
    end
    if nargin < 3
        templatePath = '';
    end

    pipelineRunNew(obj, templateId, templatePath, varargin{:});
end
