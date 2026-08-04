function entry = markReviewed(roiObj, spec, varargin)
%ANNOTATIONMANAGER.MARKREVIEWED Mark frames or ROI-level components reviewed.

p = inputParser;
p.addParameter('Frames', [], @isnumeric);
p.addParameter('Components', {}, @(x) ischar(x) || isstring(x) || iscell(x));
p.addParameter('Save', true, @(x) islogical(x) && isscalar(x));
p.parse(varargin{:});

[entry, ~] = annotationManager.entryForSpec(roiObj, spec);
componentIds = normalizeIds(p.Results.Components, spec);
frames = normalizeFrames(p.Results.Frames, annotationManager.frameCount(roiObj));
for i = 1:numel(entry.review)
    if ~any(strcmp(componentIds, entry.review(i).component_id)), continue; end
    if strcmp(entry.review(i).unit, 'roi')
        entry.review(i).complete = true;
    else
        if isempty(frames), frames = 1:numel(entry.review(i).frames); end
        entry.review(i).frames(frames) = true;
        entry.review(i).complete = all(entry.review(i).frames);
    end
end
if strcmp(entry.status, 'approved')
    entry.approved_at = '';
    entry.approved_hash = '';
end
entry.status = 'draft';
entry.revision = uint32(double(entry.revision) + 1);
entry = annotationManager.setEntry(roiObj, spec, entry, 'Save', p.Results.Save);
end

function ids = normalizeIds(value, spec)
if isempty(value)
    ids = {spec.components.id};
elseif ischar(value) || isstring(value)
    ids = cellstr(string(value));
else
    ids = cellfun(@(x) char(string(x)), value, 'UniformOutput', false);
end
end

function frames = normalizeFrames(value, total)
if isempty(value), frames = []; return; end
frames = unique(round(double(value(:)')), 'stable');
frames = frames(isfinite(frames) & frames >= 1 & frames <= total);
end
