function tests = testReviewHints
%TESTREVIEWHINTS External review evidence remains advisory and navigable.
tests = functiontests(localfunctions);
end

function setupOnce(~)
repoRoot = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(genpath(repoRoot));
end

function testClassifierLocalHintsAreFilteredByRoiAndBounds(testCase)
folder = tempname;
mkdir(folder);
cleanup = onCleanup(@() removeFolder(folder)); %#ok<NASGU>

payload = struct( ...
    'schema_version', 'detecdiv_annotation_review_hints_v001', ...
    'classifier_id', 'review_demo', ...
    'source_id', 'python_review_v005', ...
    'items', [ ...
        hint('event_a','R1',4,12,3,'tracking_error'), ...
        hint('event_b','R1',7,15,0,'ambiguous'), ...
        hint('event_c','R2',4,18,2,'not_bud')]);
writeJson(fullfile(folder, 'review_hints.json'), payload);

classif = struct('path', folder, 'strid', 'review_demo', ...
    'classifierPkg', '', 'category', {{'Tracking'}}, ...
    'classes', {{'tracks'}}, 'executionParam', struct(), ...
    'trainingParam', struct(), 'channelName', {{'mask'}});
roiObj = struct('id', 'R1');

report = annotationManager.reviewHints( ...
    classif, roiObj, 'ReviewFrames', 1:5);
verifyTrue(testCase, report.valid);
verifyEqual(testCase, report.total, 1);
verifyEqual(testCase, report.sourceId, 'python_review_v005');
verifyEqual(testCase, report.issues.code, ...
    'external_review_tracking_error');
verifyEqual(testCase, report.issues.focus_frame, uint32(4));
verifyEqual(testCase, report.issues.focus_track_id, uint64(12));
verifyEqual(testCase, report.issues.severity, 'warning');
end

function value = hint(id, roiId, frame, child, parent, decision)
value = struct('hint_id', id, 'roi_id', roiId, 'frame', frame, ...
    'child_track_id', child, 'parent_track_id', parent, ...
    'decision', decision, 'note', 'prior reviewer note');
end

function writeJson(path, value)
fid = fopen(path, 'w');
assert(fid >= 0);
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fwrite(fid, jsonencode(value), 'char');
end

function removeFolder(folder)
if exist(folder, 'dir') == 7, rmdir(folder, 's'); end
end
