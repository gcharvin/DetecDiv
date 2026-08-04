function entry = setEntry(roiObj, spec, entry, varargin)
%ANNOTATIONMANAGER.SETENTRY Upsert one bundle entry in the ROI manifest.

p = inputParser;
p.addParameter('Save', true, @(x) islogical(x) && isscalar(x));
p.parse(varargin{:});

[manifest, ~] = annotationManager.readManifest(roiObj);
entry.annotation_id = char(string(spec.id));
entry.classifier_id = char(string(spec.classifierId));
entry.updated_at = nowText();

if isempty(manifest.entries)
    manifest.entries = entry;
else
    idx = find(strcmp(string({manifest.entries.annotation_id}), string(spec.id)), 1, 'first');
    if isempty(idx)
        manifest.entries(end+1,1) = entry;
    else
        manifest.entries(idx) = entry;
    end
end
annotationManager.writeManifest(roiObj, manifest, 'Save', p.Results.Save);
end

function value = nowText()
value = char(datetime('now', 'Format', 'yyyy-MM-dd''T''HH:mm:ssXXX'));
end
