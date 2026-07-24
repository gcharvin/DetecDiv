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
    present = {'modelPath','modelSource'};
    present = present(isfield(runtime,present));
    if ~isempty(present), runtime = rmfield(runtime,present); end
    p = cellLatentModel.utils.applyOverrides(p,runtime);
end
[resolved,data,image] = cellLatentModel.core(p,roiobj,ctx,classif);
out.data = data;
out.image = image;
out.refs.outputFamilyId = resolved.outputFamilyId;
out.refs.outputFamilyName = resolved.outputFamilyName;
out.artifacts.audit = resolved.auditFile;
out.artifacts.cellModel = resolved.cellModelFile;
out.metrics = resolved.summary;
out.status = "OK";
end
