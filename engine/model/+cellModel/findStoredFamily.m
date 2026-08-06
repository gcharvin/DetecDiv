function [found, resolvedName, maskProvider] = findStoredFamily(roiObj, identifier)
%CELLMODEL.FINDSTOREDFAMILY Resolve one family without loading object rows.

found = false;
resolvedName = '';
maskProvider = '';
identifier = char(string(identifier));
if isempty(roiObj) || isempty(identifier), return; end

try
    if isstruct(roiObj.cellModel) && isfield(roiObj.cellModel, 'families') && ...
            isstruct(roiObj.cellModelInfo) && ...
            isfield(roiObj.cellModelInfo, 'loaded') && roiObj.cellModelInfo.loaded
        [idx, ~] = cellModel.familyIndex(roiObj.cellModel, identifier);
        if ~isempty(idx)
            found = true;
            resolvedName = char(string(roiObj.cellModel.families.name{idx}));
            maskProvider = char(string(roiObj.cellModel.families.mask_provider{idx}));
        end
        return;
    end
catch
end

filename = cellModel.pathForROI(roiObj);
if ~isempty(filename) && isfile(filename)
    metadata = cellModel.readMetadata(filename);
    if ~isfield(metadata, 'families') || ~isstruct(metadata.families)
        return;
    end
    rows = metadata.families;
    names = string({rows.name});
    providers = strings(size(names));
    if isfield(rows, 'mask_provider')
        providers = string({rows.mask_provider});
    end
    idx = find(names == string(identifier) | ...
        providers == string(identifier), 1, 'first');
    if ~isempty(idx)
        found = true;
        resolvedName = char(names(idx));
        maskProvider = char(providers(idx));
    end
    return;
end

% Only legacy ROIs without a sidecar require materialized migration.
[model, ~] = roiObj.loadCellModel('MigrateLegacy', true);
[idx, ~] = cellModel.familyIndex(model, identifier);
if ~isempty(idx)
    found = true;
    resolvedName = char(string(model.families.name{idx}));
    maskProvider = char(string(model.families.mask_provider{idx}));
end
end
