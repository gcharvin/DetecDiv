function out = normalizeParam(param, ctx)
%SELECTCAVITYTRAJECTORY.NORMALIZEPARAM Merge defaults and normalize choices.

if nargin < 2 || isempty(ctx), ctx = struct(); end
out = selectCavityTrajectory.setparam(ctx);
if nargin >= 1 && isstruct(param)
    names = fieldnames(param);
    for i = 1:numel(names), out.(names{i}) = param.(names{i}); end
end

out.inputFamily = choice(out.inputFamily,'<auto>');
out.mode = lower(choice(out.mode,'mother_resident'));
if ~any(strcmp(out.mode,{'mother_resident','daughter_tip'}))
    error('selectCavityTrajectory:InvalidMode', ...
        'Mode must be mother_resident or daughter_tip.');
end
out.outputName = strtrim(char(string(out.outputName)));
out.outputChannelBase = strtrim(char(string(out.outputChannelBase)));
if isempty(out.outputName), out.outputName = 'cavity_trajectory'; end
if isempty(out.outputChannelBase), out.outputChannelBase = 'cavity_target'; end

defaults = selectCavityTrajectory.setparam(ctx);
numericFields = {'trapAxisX','trapAxisY','tipDirection', ...
    'anchorXNormalized','anchorYNormalized','positionWeight','areaWeight', ...
    'stayBonus','appearancePenalty','gapPenalty','replacementPenalty', ...
    'lineageHandoverPenalty','handoverTipGainWeight', ...
    'minHandoverAgeFrames','minHandoverTipGain','maxVirtualGapFrames', ...
    'maxCompanionAgeFrames','abstainScore','confidenceTemperature'};
for i = 1:numel(numericFields)
    name = numericFields{i};
    out.(name) = scalarValue(out.(name),defaults.(name));
end
if hypot(out.trapAxisX,out.trapAxisY) <= eps
    error('selectCavityTrajectory:InvalidAxis', ...
        'The cavity axis must be a non-zero vector.');
end
out.tipDirection = sign(out.tipDirection);
if out.tipDirection == 0, out.tipDirection = 1; end
out.minHandoverAgeFrames = max(0,round(out.minHandoverAgeFrames));
out.maxVirtualGapFrames = max(0,round(out.maxVirtualGapFrames));
if isfinite(out.maxCompanionAgeFrames)
    out.maxCompanionAgeFrames = max(0,round(out.maxCompanionAgeFrames));
end
out.confidenceTemperature = max(eps,out.confidenceTemperature);
out.allowLineageHandover = logicalValue(out.allowLineageHandover,true);
out.allowUnrelatedReplacement = logicalValue(out.allowUnrelatedReplacement,true);
out.writeArtifact = logicalValue(out.writeArtifact,true);
out.debug = logicalValue(out.debug,false);
end

function value = choice(value, fallback)
if iscell(value)
    if isempty(value), value=fallback; else, value=value{end}; end
end
value = strtrim(char(string(value)));
if isempty(value), value=fallback; end
end

function value = scalarValue(value, fallback)
if iscell(value)
    if isempty(value), value=fallback; else, value=value{end}; end
end
if ischar(value) || isstring(value), value=str2double(char(string(value))); end
if ~isnumeric(value) || ~isscalar(value) || isnan(value), value=fallback; end
value=double(value);
end

function value = logicalValue(value, fallback)
if iscell(value)
    if isempty(value), value=fallback; else, value=value{end}; end
end
if ischar(value) || isstring(value)
    value=any(strcmpi(strtrim(char(string(value))),{'true','1','yes','on'}));
elseif isnumeric(value) || islogical(value)
    value=logical(value(1));
else
    value=fallback;
end
end
