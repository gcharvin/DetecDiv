function hash = contentHash(roiObj, spec)
%ANNOTATIONMANAGER.CONTENTHASH Hash the materialized GT components.

digest = java.security.MessageDigest.getInstance('SHA-256');
updateDigest(digest, uint8(char(string(spec.id))));
for i = 1:numel(spec.components)
    component = spec.components(i);
    updateDigest(digest, uint8(char(string(component.id))));
    value = componentValue(roiObj, component);
    try
        bytes = getByteStreamFromArray(value);
    catch
        bytes = uint8(jsonencode(value));
    end
    updateDigest(digest, bytes);
end
raw = typecast(digest.digest(), 'uint8');
hash = lower(reshape(dec2hex(raw, 2).', 1, []));
end

function value = componentValue(roiObj, component)
asset = component.groundTruth;
switch char(string(component.storage))
    case 'channel'
        [channel, exists] = annotationManager.resolveChannel(roiObj, asset);
        if ~exists, error('annotationManager:MissingGroundTruth', ...
                'GT channel "%s" does not exist.', asset.channel); end
        value = annotationManager.readChannel(roiObj, channel);
    case 'dataseries'
        ensureData(roiObj);
        idx = find(arrayfun(@(x) strcmp(char(string(x.groupid)), ...
            char(string(asset.groupId))), roiObj.data), 1);
        if isempty(idx) || ~ismember(asset.valueField, ...
                roiObj.data(idx).data.Properties.VariableNames)
            error('annotationManager:MissingGroundTruth', ...
                'GT dataseries field "%s.%s" does not exist.', ...
                asset.groupId, asset.valueField);
        end
        value = roiObj.data(idx).data.(asset.valueField);
        if ~isempty(asset.idField) && ismember(asset.idField, ...
                roiObj.data(idx).data.Properties.VariableNames)
            value = {value, roiObj.data(idx).data.(asset.idField)};
        end
    case 'cell_model_family'
        [model, ~] = roiObj.loadCellModel('MigrateLegacy', true);
        [idx, familyId] = cellModel.familyIndex(model, asset.family);
        if isempty(idx), error('annotationManager:MissingGroundTruth', ...
                'GT object family "%s" does not exist.', asset.family); end
        instanceRows = model.instances.family_id == familyId;
        relationRows = model.relations.family_id == familyId;
        value = struct( ...
            'family', struct('name', model.families.name{idx}, ...
                'mask_provider', model.families.mask_provider{idx}, ...
                'lineage_source', model.families.lineage_source{idx}), ...
            'instances', subsetRows(model.instances, instanceRows), ...
            'relations', subsetRows(model.relations, relationRows));
    otherwise
        value = [];
end
end

function ensureData(roiObj)
try
    if isempty(roiObj.data) || (numel(roiObj.data) == 1 && ...
            isempty(char(string(roiObj.data(1).groupid))))
        roiObj.load('Data', 'Silent');
    end
catch
end
end

function columns = subsetRows(columns, keep)
names = fieldnames(columns);
for i = 1:numel(names)
    columns.(names{i}) = columns.(names{i})(keep,:);
end
end

function updateDigest(digest, bytes)
bytes = uint8(bytes(:));
digest.update(bytes);
end
