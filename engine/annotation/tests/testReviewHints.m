function tests = testReviewHints
%TESTREVIEWHINTS External review evidence remains advisory and navigable.
tests = functiontests(localfunctions);
end

function testCensorSuggestionDecisionLedgerIsDurableAndSeparate(testCase)
folder = tempname;
mkdir(folder);
cleanup = onCleanup(@() removeFolder(folder)); %#ok<NASGU>
classif = struct('path',folder,'strid','review_demo');
roiObj = struct('id','R1');
issue = annotationManager.newValidationIssue( ...
    'code','possible_roi_boundary_truncation', ...
    'focus_track_id',uint64(12),'focus_frame',uint32(4), ...
    'suggested_censor',true, ...
    'suggested_scope_flags',cellModel.censorScope('segmentation'), ...
    'suggested_reason','truncated_at_roi_boundary', ...
    'suggested_frame_start',uint32(4), ...
    'suggested_frame_end',uint32(6));
[ledger,record] = annotationManager.censorSuggestionLedger( ...
    classif,roiObj,'Issue',issue,'Decision','keep');
verifyEqual(testCase,record.decision,'keep');
verifyEqual(testCase,numel(ledger.items),1);
verifyEqual(testCase,record.suggestion_id, ...
    annotationManager.censorSuggestionId(roiObj,issue));
verifyEqual(testCase,exist(fullfile(folder, ...
    'censor_suggestion_decisions.json'),'file'),2);
[reloaded,~] = annotationManager.censorSuggestionLedger(classif,roiObj);
verifyEqual(testCase,reloaded.items.suggestion_id,record.suggestion_id);
verifyEqual(testCase,reloaded.items.roi_id,'R1');
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

fastReport = annotationManager.reviewHints( ...
    classif, roiObj, 'ReviewFrames', 1:5, 'ResolveFamily', false);
verifyEqual(testCase, fastReport.total, report.total);
verifyEqual(testCase, fastReport.issues.family_id, uint32(0), ...
    'The lightweight UI count must not load or resolve a cell-model family.');
end

function testLatentHintsLoadBesidePriorReviewAndPreserveConfidence(testCase)
folder = tempname;
mkdir(folder);
cleanup = onCleanup(@() removeFolder(folder)); %#ok<NASGU>
writeJson(fullfile(folder, 'review_hints.json'), struct( ...
    'classifier_id','review_demo','source_id','prior', ...
    'items',hint('prior_1','R1',2,8,0,'not_bud')));
latent = hint('latent_1','R1',3,12,4,'latent_parent');
latent.suggestion_confidence = 0.75;
writeJson(fullfile(folder, 'review_hints_latent_v4.json'), struct( ...
    'classifier_id','review_demo','source_id','latent_v4', ...
    'items',latent));

classif = struct('path',folder,'strid','review_demo', ...
    'classifierPkg','','category',{{'Tracking'}},'classes',{{'tracks'}}, ...
    'executionParam',struct(),'trainingParam',struct(),'channelName',{{'mask'}});
roiObj = struct('id','R1');
report = annotationManager.reviewHints(classif,roiObj, ...
    'ResolveFamily',false);
verifyEqual(testCase,report.total,2);
verifyTrue(testCase,contains(report.sourceId,'prior'));
verifyTrue(testCase,contains(report.sourceId,'latent_v4'));
verifyEqual(testCase,report.issues(2).component,'Latent v4 suggestion');
verifyEqual(testCase,report.issues(2).focus_track_id,uint64(12));
verifyEqual(testCase,report.issues(2).parent_track_id,uint64(4));
verifyEqual(testCase,report.issues(2).suggestion_confidence,0.75);
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
