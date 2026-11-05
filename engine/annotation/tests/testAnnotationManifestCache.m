function tests = testAnnotationManifestCache
tests = functiontests(localfunctions);
end

function setupOnce(~)
detecdiv_setup_path;
end

function testLegacyAbsenceIsReadOnceAndExternalSaveIsDiscovered(testCase)
folder = tempname; mkdir(folder);
cleanup = onCleanup(@()rmdir(folder,'s')); %#ok<NASGU>
r = roi('legacy', []); r.path = folder;
data = dataseries(table((1:3)', 'VariableNames', {'value'}));
data.groupid = 'legacy_labels';
file = fullfile(folder, 'data_legacy.mat');
save(file, 'data');
r.data = dataseries(table(99, 'VariableNames', {'unsaved'}));
r.data.groupid = 'local_edits';

% A second inspection may stat the MAT file, but must not deserialize it.
profile clear; profile on;
profileCleanup = onCleanup(@()profile('off')); %#ok<NASGU>
first = annotationManager.readManifest(r);
second = annotationManager.readManifest(r);
profile off;
info = profile('info');
names = string({info.FunctionTable.FunctionName});
rows = endsWith(names, 'readManifest>manifestFromData');
verifyEqual(testCase, sum([info.FunctionTable(rows).NumCalls]), 3, ...
    'Two memory inspections and one disk inspection; no second disk load.');
verifyEmpty(testCase, first.entries);
verifyEqual(testCase, second, first);
verifyEqual(testCase, numel(r.data), 1);

% An independently saved lifecycle manifest invalidates the cached absence.
manifest = struct('schema_version',uint16(3), ...
    'entries',annotationManager.newEntry([],3));
data(2) = dataseries;
data(2).groupid = 'detecdiv_annotation_manifest';
data(2).userData = struct('annotationManifest',manifest);
save(file, 'data');
[updated,index] = annotationManager.readManifest(r);
verifyNotEmpty(testCase, updated.entries);
verifyEqual(testCase, index, 2);
verifyEqual(testCase, r.data(1).data.unsaved, 99);
end
