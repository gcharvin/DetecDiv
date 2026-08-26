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

dialog = annotationValidationDialog(parent, report, ...
    'Persistent', true, ...
    'OnGo', @(~,row) setappdata(parent, 'selected_frame', row.frame));
dialogCleanup = onCleanup(@() deleteIfValid(dialog)); %#ok<NASGU>
verifyTrue(testCase, isvalid(dialog));
verifyEqual(testCase, char(dialog.WindowStyle), 'normal');

go = findall(dialog, 'Text', 'Go to selected');
verifyEqual(testCase, numel(go), 1);
go.ButtonPushedFcn(go, []);

verifyTrue(testCase, isvalid(dialog), ...
    'Go to selected must not close the persistent findings window.');
verifyEqual(testCase, getappdata(parent, 'selected_frame'), 4);
end

function deleteIfValid(handle)
try
    if ~isempty(handle) && isvalid(handle), delete(handle); end
catch
end
end
