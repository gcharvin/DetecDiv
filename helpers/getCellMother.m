function motherID = getCellMother(roiobj, daughterID, varargin)
% Returns motherID from the active lineage source; NaN means unknown.

p = inputParser;
p.addParameter('nFrames', [], @(x) isempty(x) || (isscalar(x) && x>=1));
p.parse(varargin{:});
nFramesHint = p.Results.nFrames;

ensureCellInformationDataseries(roiobj, 'nFrames', nFramesHint);
idx = find(arrayfun(@(x) strcmp(x.groupid,'cell_information'), roiobj.data), 1, 'first');
ds  = roiobj.data(idx);

daughterID = int32(daughterID);
M = activeMotherMap(ds);
if isKey(M, daughterID)
    motherID = M(daughterID);
else
    motherID = NaN;
end
end

function M = activeMotherMap(ds)
if isfield(ds.userData,'lineageSources') && isstruct(ds.userData.lineageSources) && ...
        ~isempty(fieldnames(ds.userData.lineageSources))
    key = activeSourceKey(ds);
    src = ds.userData.lineageSources.(char(key));
    if isfield(src,'motherOf') && isa(src.motherOf,'containers.Map')
        M = src.motherOf;
        return;
    end
end

if isfield(ds.userData,'motherOf') && isa(ds.userData.motherOf,'containers.Map')
    M = ds.userData.motherOf;
else
    M = containers.Map('KeyType','int32','ValueType','double');
end
end

function key = activeSourceKey(ds)
fields = fieldnames(ds.userData.lineageSources);
key = "";
if isfield(ds.userData,'activeLineageSource') && ~isempty(ds.userData.activeLineageSource)
    candidate = char(string(ds.userData.activeLineageSource));
    if isfield(ds.userData.lineageSources, candidate)
        key = string(candidate);
        return;
    end
end
for i = 1:numel(fields)
    src = ds.userData.lineageSources.(fields{i});
    if isfield(src,'show') && logical(src.show)
        key = string(fields{i});
        return;
    end
end
key = string(fields{1});
end
