function tests = testClassiRestoreDiskRois
tests = functiontests(localfunctions);
end

function testRecoveryPreservesExistingAndIsIdempotent(t)
folder = tempname; mkdir(folder);
cleanup = onCleanup(@() rmdir(folder, 's')); %#ok<NASGU>
c = classi(folder, 'restore', 1);
existing = roi('kept', []); existing.path = c.path;
existing.image = uint16(99);
c.roi = existing;
r = roi('missing', []); r.path = c.path;
r.image = uint16(reshape(1:24, [3 4 1 2]));
r.data = dataseries; r.data.id = 'annotation'; r.data.groupid = 'labels';
r.data.data = table([1; 2], 'VariableNames', {'label'}); r.save([], false);
% A second legacy file for the same ID must not cause a duplicate.
roiobj = r; save(fullfile(c.path, 'im_missing.mat'), 'roiobj');
before = dir(fullfile(c.path, 'im_missing.h5'));
report = classiRestoreDiskRois(c);
verifyEqual(t, report.added, {'missing'});
verifyEmpty(t, report.failed);
verifyTrue(t, c.roi(1) == existing);
verifyEqual(t, c.roi(1).image, uint16(99));
verifyEmpty(t, c.roi(2).image);
verifyEqual(t, c.roi(2).data.id, 'annotation');
verifyEqual(t, string(c.roi(2).display.channel), string(r.display.channel));
after = dir(fullfile(c.path, 'im_missing.h5'));
verifyEqual(t, after.datenum, before.datenum);
report = classiRestoreDiskRois(c);
verifyEmpty(t, report.added);
verifyEqual(t, numel(c.roi), 2);
end

function testLegacyAndUnreadableFiles(t)
folder = tempname; mkdir(folder);
cleanup = onCleanup(@() rmdir(folder, 's')); %#ok<NASGU>
c = classi(folder, 'restore', 1);
roiobj = roi('legacy', []); roiobj.image = uint16(ones(2));
save(fullfile(c.path, 'im_legacy.mat'), 'roiobj');
fid = fopen(fullfile(c.path, 'im_broken.h5'), 'w'); fclose(fid);
report = classiRestoreDiskRois(c);
verifyEqual(t, report.added, {'legacy'});
verifyEqual(t, report.failed, {'broken'});
verifyEqual(t, {c.roi.id}, {'legacy'});
verifyEqual(t, c.roi.path, c.path);
end
