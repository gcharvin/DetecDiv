function out = classify(roiobj,classif,ctx)
%CELLLATENTMODEL.CLASSIFY Infer and persist a multimodal lineage.
if nargin < 3 || isempty(ctx), ctx = struct(); end
cellLatentModel.ensureClassMetadata(classif);
out = cellLatentModel.utils.outInitSafe('cellLatentModel.classify');
% Normal pipeline execution resolves the classifier-owned deployment
% snapshot here.  Direct annotation inference instead supplies the exact
% already-resolved snapshot through an explicit, validated context, so a
% multi-ROI run cannot switch artifacts if the JSON changes mid-run.
p = cellLatentModel.resolveInferenceParam(classif,ctx);
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
