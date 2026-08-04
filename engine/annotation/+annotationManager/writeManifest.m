function storeIndex = writeManifest(roiObj, manifest, varargin)
%ANNOTATIONMANAGER.WRITEMANIFEST Persist ROI annotation metadata in data_<roi>.mat.

p = inputParser;
p.addParameter('Save', true, @(x) islogical(x) && isscalar(x));
p.parse(varargin{:});

[~, storeIndex] = annotationManager.readManifest(roiObj);
if isempty(storeIndex)
    ds = dataseries;
    ds.groupid = 'detecdiv_annotation_manifest';
    ds.parentid = char(string(roiObj.id));
    ds.class = "other";
    ds.type = "other";
    ds.description = 'DetecDiv annotation lifecycle metadata';
    ds.userData = struct('annotationManifest', manifest);
    ds.show = false;
    data = roiObj.data;
    if isempty(data) || (numel(data) == 1 && isempty(char(string(data(1).groupid))))
        roiObj.data = ds;
        storeIndex = 1;
    else
        roiObj.data(end+1) = ds;
        storeIndex = numel(roiObj.data);
    end
else
    ds = roiObj.data(storeIndex);
    ud = ds.userData;
    if ~isstruct(ud), ud = struct(); end
    ud.annotationManifest = manifest;
    ds.userData = ud;
    roiObj.data(storeIndex) = ds;
end

if p.Results.Save
    roiObj.save('data', false);
end
end
