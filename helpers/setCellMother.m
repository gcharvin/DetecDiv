function setCellMother(roiobj, daughterID, motherID, varargin)
% Mutates the active cell_information lineage source in place.

p = inputParser;
p.addParameter('birthFrame', [], @(x) isempty(x) || (isscalar(x) && x>=1));
p.addParameter('nFrames',    [], @(x) isempty(x) || (isscalar(x) && x>=1));
p.parse(varargin{:});
birthFrame  = p.Results.birthFrame;
nFramesHint = p.Results.nFrames;

ensureCellInformationDataseries(roiobj, 'nFrames', nFramesHint);
idx = find(arrayfun(@(x) strcmp(x.groupid,'cell_information'), roiobj.data), 1, 'first');
ds  = roiobj.data(idx);

daughterID = int32(daughterID);
motherID   = double(motherID);

if daughterID == motherID
    warning('setCellMother: daughter and mother are identical; operation ignored.');
    return;
end

[M, key] = activeMotherMap(ds);
M(daughterID) = motherID;
syncMotherAlias(ds, M, key);

if ~isempty(birthFrame)
    if ~isfield(ds.userData,'birthOf') || ~isa(ds.userData.birthOf,'containers.Map')
        ds.userData.birthOf = containers.Map('KeyType','int32','ValueType','int32');
    end
    bf = int32(max(1, min(height(ds.data), birthFrame)));
    ds.userData.birthOf(daughterID) = bf;
end
end

function [M, key] = activeMotherMap(ds)
key = "";
if isfield(ds.userData,'lineageSources') && isstruct(ds.userData.lineageSources) && ...
        ~isempty(fieldnames(ds.userData.lineageSources))
    key = activeSourceKey(ds);
    src = ds.userData.lineageSources.(char(key));
    if ~isfield(src,'motherOf') || ~isa(src.motherOf,'containers.Map')
        src.motherOf = containers.Map('KeyType','int32','ValueType','double');
    end
    src.show = true;
    M = src.motherOf;
    ds.userData.lineageSources.(char(key)) = src;
    ds.userData.activeLineageSource = char(key);
else
    if ~isfield(ds.userData,'motherOf') || ~isa(ds.userData.motherOf,'containers.Map')
        ds.userData.motherOf = containers.Map('KeyType','int32','ValueType','double');
    end
    M = ds.userData.motherOf;
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

function syncMotherAlias(ds, M, key)
ds.userData.motherOf = M;
if strlength(key) > 0
    ds.userData.motherOfSourceKey = char(key);
end
end
