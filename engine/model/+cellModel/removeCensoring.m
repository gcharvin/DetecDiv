function [model, report] = removeCensoring(model, family, trackId, varargin)
%CELLMODEL.REMOVECENSORING Remove explicit censor records from one track.

p = inputParser;
p.addParameter('CensorId', [], @isnumeric);
p.addParameter('Fast', false, @(x) islogical(x) && isscalar(x));
p.parse(varargin{:});
if ~p.Results.Fast, model = cellModel.normalize(model); end
[~, familyId] = cellModel.familyIndex(model, family);
if isempty(familyId), error('cellModel:UnknownFamily', 'Unknown family.'); end
trackId = uint64(trackId);
rows = model.censoring.family_id == familyId & ...
    model.censoring.track_id == trackId;
if ~isempty(p.Results.CensorId)
    rows = rows & ismember(model.censoring.censor_id, uint64(p.Results.CensorId));
end
removedIds = model.censoring.censor_id(rows);
model.censoring = keepRows(model.censoring, ~rows);
if ~p.Results.Fast
    model = cellModel.normalize(model);
    cellModel.validate(model, 'Throw', true);
end
report = struct('status', ternary(any(rows), 'removed', 'missing'), ...
    'family_id', familyId, 'track_id', trackId, ...
    'censor_ids', removedIds, 'records_removed', nnz(rows));
end

function out = keepRows(in, keep)
out = in;
names = fieldnames(in);
for i = 1:numel(names), out.(names{i}) = in.(names{i})(keep,:); end
end

function value = ternary(tf, yes, no)
if tf, value = yes; else, value = no; end
end
