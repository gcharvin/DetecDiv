function tf = isCensored(model, family, trackId, frames, scope)
%CELLMODEL.ISCENSORED Query explicit censor intervals for a track.

if nargin < 5 || isempty(scope), scope = 'all'; end
model = cellModel.normalize(model);
[~, familyId] = cellModel.familyIndex(model, family);
if isempty(familyId)
    error('cellModel:UnknownFamily', 'Unknown family.');
end
trackId = uint64(trackId);
frames = round(double(frames));
scopeFlag = resolveScope(scope);
tf = false(size(frames));
rows = model.censoring.family_id == familyId & ...
    model.censoring.track_id == trackId & ...
    bitand(model.censoring.scope_flags, scopeFlag) ~= 0;
indices = find(rows);
for i = indices(:).'
    tf = tf | (frames >= double(model.censoring.frame_start(i)) & ...
        frames <= double(model.censoring.frame_end(i)));
end
end

function flag = resolveScope(scope)
if ischar(scope) || isstring(scope)
    flag = cellModel.censorScope(scope);
else
    flag = uint16(scope);
end
if ~isscalar(flag) || flag < 1 || bitand(flag, bitcmp(uint16(63))) ~= 0
    error('cellModel:BadCensorScope', 'Invalid censoring scope flags.');
end
end
