function batchSpec = pipelineBatchSetPipeline(batchSpec, pipelineRef, pipelineTemplate)
% pipelineBatchSetPipeline  Attach a pipeline reference to a batch spec.

    if nargin < 1 || isempty(batchSpec) || ~isstruct(batchSpec)
        error('pipelineBatchSetPipeline:InvalidBatch', 'batchSpec must be a struct.');
    end
    if nargin < 2
        pipelineRef = struct();
    end
    if nargin < 3
        pipelineTemplate = struct();
    end

    batchSpec.pipelineRef = localNormalizePipelineRef(pipelineRef);
    batchSpec.pipelineTemplatePath = char(string(batchSpec.pipelineRef.path));
    if isempty(pipelineTemplate) || ~(isstruct(pipelineTemplate) || isobject(pipelineTemplate))
        batchSpec.pipelineTemplate = struct();
    else
        batchSpec.pipelineTemplate = pipelineTemplate;
    end
end

function ref = localNormalizePipelineRef(ref)
    defaults = struct('id', '', 'path', '', 'version', '');
    if isempty(ref) || ~isstruct(ref)
        ref = defaults;
        return;
    end
    fn = fieldnames(defaults);
    for i = 1:numel(fn)
        if ~isfield(ref, fn{i}) || isempty(ref.(fn{i}))
            ref.(fn{i}) = defaults.(fn{i});
        else
            ref.(fn{i}) = char(string(ref.(fn{i})));
        end
    end
end
