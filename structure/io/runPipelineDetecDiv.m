function [ctxOut, report] = runPipelineDetecDiv(pipeObj, ctx)
% runPipelineDetecDiv  Stable wrapper to the structured pipeline runner.
% This wrapper keeps a unique explicit entry point for callers that prefer
% to avoid relying on MATLAB path resolution of runPipeline.m.

    [ctxOut, report] = runPipelineStructured(pipeObj, ctx);
end
