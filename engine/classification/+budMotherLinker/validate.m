function out = validate(classif, rois, ctx)
%BUDMOTHERLINKER.VALIDATE Evaluate a trained model on independent ROI GT.

if nargin < 2 || isempty(rois)
    try rois = classif.dataset.split.test; catch, rois=[]; end
end
if nargin < 3 || isempty(ctx), ctx=struct(); end
if isempty(rois)
    error('budMotherLinker:NoValidationROIs', ...
        'Select independent test ROIs in classifierGUI.');
end
tp = budMotherLinker.utils.defaultTrainingParam();
if isstruct(classif.trainingParam)
    tp = budMotherLinker.utils.applyOverrides(tp,classif.trainingParam);
end
frames=[];
try frames=ctx.sel.frames; catch, end
dataset = budMotherLinker.datasetFromRois(classif,rois,'test',tp,frames);

p = budMotherLinker.utils.defaultExecutionParam();
p = budMotherLinker.utils.applyOverrides(p,classif.executionParam);
if isempty(p.trackChannelName)
    p.trackChannelName = tp.trackChannelName;
end
if isempty(p.trackChannelName)
    try
        names = cellstr(string(classif.channelName));
        names = names(strlength(string(names)) > 0);
        if ~isempty(names), p.trackChannelName = names{1}; end
    catch
    end
end
p = budMotherLinker.normalizeParam(p,ctx,classif);
scores = budMotherLinker.utils.scoreHGBExternal(dataset.X,p,ctx);
threshold = p.rankMarginThreshold;
if threshold < 0
    if strcmp(p.modelSource,'trained')
        payload=load(p.modelPath,'artifact');
        threshold=payload.artifact.rank_margin_threshold;
    else
        manifest=jsondecode(fileread(fullfile(fileparts(mfilename('fullpath')), ...
            'model','project47_v002','manifest.json')));
        threshold=manifest.deployment_calibration.rank_margin_threshold;
    end
end
metrics = budMotherLinker.evaluateScores( ...
    dataset,scores,true(size(dataset.y)),threshold);
out = budMotherLinker.utils.outInitSafe('budMotherLinker.validate');
out.metrics = metrics;
out.refs.rois = rois;
out.refs.gtFamilies = dataset.gt_family_by_roi;
out.status = "OK";
end
