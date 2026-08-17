function out = classify(roiobj,classif,ctx)
%CELLLATENTMODEL.CLASSIFY Infer and persist a multimodal lineage.
if nargin < 3 || isempty(ctx), ctx = struct(); end
cellLatentModel.ensureClassMetadata(classif);
out = cellLatentModel.utils.outInitSafe('cellLatentModel.classify');
p = cellLatentModel.utils.defaultExecutionParam();
try
    p = cellLatentModel.utils.applyOverrides(p,classif.executionParam);
catch
end
if isfield(ctx,'params') && isstruct(ctx.params)
    runtime = ctx.params;
    present = {'modelPath','modelSource','compositeManifestPath', ...
        'trackingCheckpointDir','stateRuntimeConfigPath', ...
        'adaptiveMarkerModelPath','adaptiveMarkerModelSource'};
    present = present(isfield(runtime,present));
    if ~isempty(present), runtime = rmfield(runtime,present); end
    p = cellLatentModel.utils.applyOverrides(p,runtime);
end
[resolved,data,image] = cellLatentModel.core(p,roiobj,ctx,classif);
out.data = data;
out.image = image;
out.refs.outputFamilyId = resolved.outputFamilyId;
out.refs.outputFamilyName = resolved.outputFamilyName;
if isfield(resolved,'trackChannelName')
    out.refs.outputTrackChannelName = resolved.trackChannelName;
end
out.artifacts.audit = resolved.auditFile;
out.artifacts.cellModel = resolved.cellModelFile;
if isfield(resolved,'biologicalStateFile') && ...
        ~isempty(resolved.biologicalStateFile)
    out.artifacts.biologicalState = resolved.biologicalStateFile;
end
out.metrics = resolved.summary;
if isfield(resolved,'prediction')
    out.prediction = resolved.prediction;
end
out.status = "OK";
end
