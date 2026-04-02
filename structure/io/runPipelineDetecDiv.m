function [ctxOut, report] = runPipelineDetecDiv(pipeObj, ctx)
% runPipelineDetecDiv  Stable wrapper to the structured pipeline runner.
% This wrapper calls a uniquely named implementation to avoid collisions
% with engine/pipeline/runPipeline.m on the MATLAB path.

    [ctxOut, report] = runPipelineStructured(pipeObj, ctx);
end
