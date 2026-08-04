function report = publishLegacyLineage(roiobj,model,familyId,outputName,channelName,auditFile)
%CELLLATENTMODEL.PUBLISHLEGACYLINEAGE Project cell-model relations to roi.data.
%
% The compact objects_<roi>.h5 model remains canonical.  This projection
% keeps Score and legacy DetecDiv consumers able to discover the inferred
% lineage through cell_information.userData.lineageSources.

if nargin < 6, auditFile = ''; end
model = cellModel.normalize(model);
familyRows = model.relations.family_id == uint32(familyId) & ...
    model.relations.type_id == uint8(1);
relationRows = find(familyRows);

motherOf = containers.Map('KeyType','int32','ValueType','double');
events = repmat(struct( ...
    'childId',0,'motherId',0,'startFrame',0, ...
    'confidence',NaN,'status','linked'),numel(relationRows),1);
for i = 1:numel(relationRows)
    row = relationRows(i);
    child = int32(model.relations.child_track_id(row));
    parent = double(model.relations.parent_track_id(row));
    motherOf(child) = parent;
    events(i).childId = double(child);
    events(i).motherId = parent;
    events(i).startFrame = double(model.relations.event_frame(row));
    events(i).confidence = double(model.relations.confidence(row));
end

nFrames = 0;
instanceRows = model.instances.family_id == uint32(familyId);
if any(instanceRows)
    nFrames = double(max(model.instances.frame(instanceRows)));
end
[ds,dsIndex] = ensureCellInformation(roiobj,nFrames);
if ~isstruct(ds.userData), ds.userData = struct(); end
if ~isfield(ds.userData,'lineageSources') || ...
        ~isstruct(ds.userData.lineageSources)
    ds.userData.lineageSources = struct();
end

sourceKey = matlab.lang.makeValidName(char(string(outputName)));
if isempty(sourceKey), sourceKey = 'cellLatentModel'; end
source = struct( ...
    'motherOf',motherOf, ...
    'events',events, ...
    'channelName',char(string(channelName)), ...
    'outputName',char(string(outputName)), ...
    'displayName',char(string(outputName)), ...
    'show',true, ...
    'version',1, ...
    'mode','cell_model_schema_v1_projection', ...
    'familyId',double(familyId), ...
    'auditFile',char(string(auditFile)), ...
    'createdAt',char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')));
ds.userData.lineageSources.(sourceKey) = source;
ds.userData.activeLineageSource = sourceKey;
ds.userData.motherOf = motherOf;
ds.userData.motherOfSource = 'cellLatentModel';
ds.userData.motherOfSourceKey = sourceKey;
ds.userData.motherOfSourceOutputName = char(string(outputName));
ds.userData.motherOfSourceChannelName = char(string(channelName));
roiobj.data(dsIndex) = ds;

report = struct( ...
    'changed',true, ...
    'dataseriesGroupid','cell_information', ...
    'sourceKey',sourceKey, ...
    'relations',motherOf.Count);
end

function [ds,index] = ensureCellInformation(roiobj,nFrames)
index = [];
try
    index = find(arrayfun(@(x) isprop(x,'groupid') && ...
        strcmp(char(string(x.groupid)),'cell_information'), ...
        roiobj.data),1,'first');
catch
end
if isempty(index)
    if isempty(roiobj.data) || ...
            (isscalar(roiobj.data) && emptyDataseries(roiobj.data(1)))
        index = 1;
    else
        index = numel(roiobj.data) + 1;
    end
    roiobj.data(index) = dataseries;
end
ds = roiobj.data(index);
ds.groupid = 'cell_information';
ds.class = "other";
ds.type = "temporal";
try
    ds.parentid = roiobj.id;
catch
end
if isempty(ds.data) || ~istable(ds.data) || ...
        ~ismember('lineage',ds.data.Properties.VariableNames)
    ds.data = table(cell(nFrames,1),'VariableNames',{'lineage'});
    ds.data.lineage(:) = {nan};
elseif height(ds.data) < nFrames
    extra = table(cell(nFrames-height(ds.data),1), ...
        'VariableNames',{'lineage'});
    extra.lineage(:) = {nan};
    ds.data = [ds.data; extra];
end
if isempty(ds.plotGroup)
    ds.plotGroup = {[] [] [] [] [] {'lineage'}};
end
if isempty(ds.groupProperties)
    ds.groupProperties = {'lineage','Plot','auto','auto'};
end
if ~isstruct(ds.userData), ds.userData = struct(); end
ds.userData.version = 1;
ds.userData.note = ...
    "lineage stored in userData.motherOf and userData.lineageSources";
end

function tf = emptyDataseries(ds)
tf = false;
try
    tf = isempty(ds.groupid) && istable(ds.data) && height(ds.data) == 0;
catch
end
end
