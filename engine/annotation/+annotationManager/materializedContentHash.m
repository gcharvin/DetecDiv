function hash = materializedContentHash(roiObj, spec)
%ANNOTATIONMANAGER.MATERIALIZEDCONTENTHASH Hash a fresh disk-backed snapshot.
% Do not reuse the active ROI handle: it may contain unsaved Score edits.

diskRoi = roi(char(string(roiObj.id)), [1 1 1 1]);
diskRoi.path = char(string(roiObj.path));
hash = annotationManager.contentHash(diskRoi, spec);
end
