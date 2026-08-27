function tests = testAnnotationValidationDialog
%TESTANNOTATIONVALIDATIONDIALOG Persistent findings keep Score navigable.
tests = functiontests(localfunctions);
end

function testCensorSuggestionActionsRefreshAndStaySeparate(testCase)
parent = uifigure('Visible', 'off');
parentCleanup = onCleanup(@() deleteIfValid(parent)); %#ok<NASGU>
issue = annotationManager.newValidationIssue( ...
    'severity','warning','component','Censor suggestion', ...
    'summary','Possible truncation','message','Inspect Track 8.', ...
    'focus_frame',uint32(9),'focus_track_id',uint64(8), ...
    'suggested_censor',true, ...
    'suggested_scope_flags',cellModel.censorScope('segmentation'), ...
    'suggested_reason','truncated_at_roi_boundary', ...
    'suggested_frame_start',uint32(9), ...
    'suggested_frame_end',uint32(11));
ordinary = annotationManager.newValidationIssue( ...
    'severity','warning','component','Tracking', ...
    'summary','Ordinary warning','message','Still pending.');
report = struct('valid',true,'errors',strings(0,1), ...
    'warnings',strings(0,1),'issues',[issue; ordinary]);
updated = report;
updated.issues = ordinary;
setappdata(parent,'updated_after_decision',updated);

dialog = annotationValidationDialog(parent, report, ...
    'Persistent',true, ...
    'OnAcceptCensor',@(selected) recordDecision(parent,selected,'censored'), ...
    'OnKeepUsable',@(selected) recordDecision(parent,selected,'keep'));
dialogCleanup = onCleanup(@() deleteIfValid(dialog)); %#ok<NASGU>
accept = findall(dialog,'Text','Censor as suggested [C]');
keep = findall(dialog,'Text','Keep usable [K]');
verifyEqual(testCase,char(accept.Enable),'on');
verifyEqual(testCase,char(keep.Enable),'on');

keep.ButtonPushedFcn(keep,[]);
verifyTrue(testCase,isvalid(dialog));
verifyEqual(testCase,getappdata(parent,'decision'),'keep');
tableHandle = findobj(dialog,'Type','uitable');
verifyEqual(testCase,size(tableHandle.Data,1),1, ...
    'A decided suggestion must disappear after the callback refresh.');
verifyEqual(testCase,char(accept.Enable),'off', ...
    'Ordinary warnings must never expose a censor action.');
end

function report = recordDecision(parent, issue, decision)
setappdata(parent,'decision',decision);
setappdata(parent,'decision_track',double(issue.focus_track_id));
report = getappdata(parent,'updated_after_decision');
end

function setupOnce(~)
repoRoot = fileparts(fileparts(fileparts(fileparts(fileparts( ...
    mfilename('fullpath'))))));
addpath(genpath(repoRoot));
end

function testPersistentGoInvokesCallbackWithoutClosing(testCase)
parent = uifigure('Visible', 'off');
parentCleanup = onCleanup(@() deleteIfValid(parent)); %#ok<NASGU>
issue = annotationManager.newValidationIssue( ...
    'severity', 'warning', 'component', 'Prior review', ...
    'summary', 'Inspect child track', 'message', 'Inspect frame 4.', ...
    'focus_frame', uint32(4), 'focus_track_id', uint64(12));
report = struct('valid', true, 'errors', strings(0,1), ...
    'warnings', strings(0,1), 'issues', issue);
updatedIssue = issue;
updatedIssue.summary = 'Updated finding';
updatedIssue.focus_frame = uint32(6);
updatedReport = report;
updatedReport.issues = [issue; updatedIssue];
setappdata(parent, 'findings_stale', false);
setappdata(parent, 'updated_report', updatedReport);
setappdata(parent, 'refresh_count', 0);

dialog = annotationValidationDialog(parent, report, ...
    'Persistent', true, ...
    'OnGo', @(~,row) setappdata(parent, 'selected_frame', row.frame), ...
    'OnRefresh', @() refreshedReport(parent), ...
    'OnIsStale', @() getappdata(parent, 'findings_stale'));
dialogCleanup = onCleanup(@() deleteIfValid(dialog)); %#ok<NASGU>
verifyTrue(testCase, isvalid(dialog));
verifyEqual(testCase, char(dialog.WindowStyle), 'normal');

go = findall(dialog, 'Text', 'Go to selected');
verifyEqual(testCase, numel(go), 1);
go.ButtonPushedFcn(go, []);

verifyTrue(testCase, isvalid(dialog), ...
    'Go to selected must not close the persistent findings window.');
verifyEqual(testCase, getappdata(parent, 'selected_frame'), 4);

setappdata(parent, 'findings_stale', true);
dialog.WindowButtonDownFcn(dialog, []);
tableHandle = findobj(dialog, 'Type', 'uitable');
verifyEqual(testCase, size(tableHandle.Data, 1), 2, ...
    'Returning to a stale findings window must refresh its snapshot.');
verifyEqual(testCase, getappdata(parent, 'refresh_count'), 1);
verifyEqual(testCase, getappdata(parent, 'findings_stale'), false);
verifyEqual(testCase, numel(findall(dialog, 'Text', 'Refresh')), 1);
end

function testFindingNavigationUsesCachedModelAndNoReviewSideEffects(testCase)
repoRoot = fileparts(fileparts(fileparts(fileparts(fileparts( ...
    mfilename('fullpath'))))));
path = fullfile(repoRoot,'structure','GUI','score','private', ...
    'score_runtime_code.m');
source = fileread(path);
startAt = strfind(source,'function focusAnnotationValidationIssue');
stopAt = strfind(source,'function summary = removeAnnotationParentageIssues');
verifyNotEmpty(testCase,startAt);
verifyNotEmpty(testCase,stopAt);
block = source(startAt(1):stopAt(find(stopAt > startAt(1),1,'first'))-1);
verifyTrue(testCase,contains(block,'score_getCellModel(roi)'), ...
    'Go to selected must reuse the model loaded by the findings audit.');
verifyFalse(testCase,contains(block,'app.reviewFrameBeforeNavigation('), ...
    'Inspection jumps must not mark coverage or rebuild the audit.');
verifyFalse(testCase,contains(block,'UIAnnotationTableSelectionChanged'), ...
    'Finding navigation must not run the full annotation-selection callback.');
end

function report = refreshedReport(parent)
setappdata(parent, 'refresh_count', getappdata(parent, 'refresh_count') + 1);
setappdata(parent, 'findings_stale', false);
report = getappdata(parent, 'updated_report');
end

function deleteIfValid(handle)
try
    if ~isempty(handle) && isvalid(handle), delete(handle); end
catch
end
end
