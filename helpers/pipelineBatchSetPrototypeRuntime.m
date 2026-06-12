function batchSpec = pipelineBatchSetPrototypeRuntime(batchSpec, runtimeConfig)
% pipelineBatchSetPrototypeRuntime  Attach prototype runtime config to a batch spec.

    if nargin < 1 || isempty(batchSpec) || ~isstruct(batchSpec)
        error('pipelineBatchSetPrototypeRuntime:InvalidBatch', 'batchSpec must be a struct.');
    end
    if nargin < 2 || isempty(runtimeConfig)
        runtimeConfig = struct();
    end
    batchSpec.prototypeRuntimeConfig = runtimeConfig;
end
