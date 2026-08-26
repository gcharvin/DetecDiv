function tests = testAnnotationValidationDialog
%TESTANNOTATIONVALIDATIONDIALOG Persistent findings keep Score navigable.
tests = functiontests(localfunctions);
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
