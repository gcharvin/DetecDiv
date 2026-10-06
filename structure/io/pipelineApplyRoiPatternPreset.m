function params = pipelineApplyRoiPatternPreset(params, entry)
% Replace only the motif. Detection settings remain specific to this run.
if ~isstruct(params), params = struct(); end
params = pipelineInvalidateRoiPatternPreview(params);
stale = {'patternImage','patternRect','patternSourceFOV','patternSourceFrame','patternSourceChannel'};
stale = stale(isfield(params,stale));
if ~isempty(stale), params = rmfield(params,stale); end
params.pattern = entry.pattern;
params.patternList = struct([]);
params.activePatternIndex = 1;
params.patternPreset = struct('id',entry.id,'name',entry.name,'revision',entry.revision);
% Source channel/frame are only defaults when the run has no binding yet.
for key = {'channel','channelIndex','referenceFrame'}
    k = key{1};
    if (~isfield(params,k) || isempty(params.(k))) && isfield(entry.pattern,k)
        params.(k) = entry.pattern.(k);
    end
end
end
