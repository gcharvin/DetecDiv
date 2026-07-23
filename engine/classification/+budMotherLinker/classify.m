function out = classify(roiobj, classif, ctx)
%BUDMOTHERLINKER.CLASSIFY Predict mother-bud links for one tracked ROI.

if nargin < 3 || isempty(ctx), ctx = struct(); end
budMotherLinker.ensureClassMetadata(classif);
out = budMotherLinker.utils.outInitSafe('budMotherLinker.classify');

p = budMotherLinker.utils.defaultExecutionParam();
try
    if isstruct(classif.executionParam)
        p = budMotherLinker.utils.applyOverrides(p, classif.executionParam);
    end
catch
end
if isfield(ctx,'params') && isstruct(ctx.params)
    runtime = ctx.params;
    % Artifact location belongs to the linked classi, never to static
    % pipeline parameters.
    runtime = removeFields(runtime, {'modelPath','modelSource'});
    p = budMotherLinker.utils.applyOverrides(p, runtime);
end
if isempty(p.trackChannelName)
    p.trackChannelName = classifierInputChannel(classif, ctx);
end

[resolved, data, image] = budMotherLinker.core(p, roiobj, ctx, classif);
out.data = data;
out.image = image;
out.refs.outputFamilyId = resolved.outputFamilyId;
out.refs.outputFamilyName = resolved.outputFamilyName;
out.artifacts.audit = resolved.auditFile;
out.artifacts.cellModel = resolved.cellModelFile;
out.metrics = resolved.summary;
out.status = "OK";
end

function value = classifierInputChannel(classif, ctx)
value = '';
try
    names = cellstr(string(classif.channelName));
    names = names(strlength(string(names)) > 0);
    if ~isempty(names), value = names{1}; end
catch
end
if ~isempty(value), return; end
sources = {};
try sources{end+1} = ctx.io.requiredChannels; catch, end
try sources{end+1} = ctx.params.channels; catch, end
try sources{end+1} = ctx.params.channel; catch, end
for i = 1:numel(sources)
    names = cellstr(string(sources{i}));
    names = names(strlength(string(names)) > 0);
    if ~isempty(names), value = names{end}; return; end
end
end

function value = removeFields(value, names)
present = names(isfield(value,names));
if ~isempty(present), value = rmfield(value,present); end
end
