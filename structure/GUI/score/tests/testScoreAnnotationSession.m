function tests = testScoreAnnotationSession
%TESTSCOREANNOTATIONSESSION Smoke-test the managed GT workflow in Score.
tests = functiontests(localfunctions);
end

function setupOnce(~)
repoRoot = fileparts(fileparts(fileparts(fileparts(fileparts( ...
    mfilename('fullpath'))))));
addpath(repoRoot);
startup;
end

function testPredictionBootstrapCreatesExplicitEditableGt(testCase)
folder = tempname;
mkdir(folder);
folderCleanup = onCleanup(@() removeFolder(folder)); %#ok<NASGU>

c = classi(folder, 'score_annotation', 1);
c.classifierPkg = 'cellposesam';
c.category = {'Pixel'};
c.classes = {'cell'};
c.executionParam = struct('outputName', 'prediction');

r = roi('R1', [1 1 4 4]);
r.path = c.path;
r.image = uint16(ones(4,4,1,3));
r.channelid = 1;
r.display.channel = {'raw'};
r.display.intensity = [1 1 1];
r.display.rgb = [1 1 1];
r.display.selectedchannel = true;
r.display.indexed = false;
r.display.alpha = 1;
r.display.contour = false;
r.display.width = 1;
prediction = zeros(4,4,1,3, 'uint16');
prediction(2:3,2:3,1,:) = 1;
r.addChannel(prediction, 'results_prediction_cell', [1 1 1], [0 0 0]);
r.display.displaylim = repmat([0.1; 0.9], 1, size(r.image, 3));
r.save([], false);
c.roi = r;

session = c.annotationSession(1);
gtName = [c.strid '_cell'];
verifyEmpty(testCase, r.findChannelID(gtName));

app = score(r, 'pixelAnnotation');
appCleanup = onCleanup(@() deleteScore(app)); %#ok<NASGU>
app.setAnnotationSession(session);

verifyEqual(testCase, char(app.AnnotationSessionPanel.Visible), 'on');
verifyTrue(testCase, contains(app.AnnotationStatusLabel.Text, 'MISSING'));
verifyEqual(testCase, char(app.CreateFromPredictionButton.Enable), 'on');
verifyEmpty(testCase, r.findChannelID(gtName), ...
    'Opening managed Score must not materialize GT implicitly.');
verifyNotEmpty(testCase, app.CreateFromPredictionButton.ButtonPushedFcn);

callback = app.CreateFromPredictionButton.ButtonPushedFcn;
callback(app.CreateFromPredictionButton, []);

verifyNotEmpty(testCase, r.findChannelID(gtName));
verifyEqual(testCase, session.summary().status, 'draft');
verifyTrue(testCase, contains(app.AnnotationStatusLabel.Text, 'DRAFT'));
verifyEqual(testCase, app.ChannelModeButtonGroup.SelectedObject, app.EditButton);
verifyEqual(testCase, char(app.ChannelModeButtonGroup.Enable), 'off');

app.notifyAnnotationChanged(gtName, 1);
summary = session.summary();
verifyEqual(testCase, summary.coverage.reviewed, 1);
verifyEqual(testCase, summary.coverage.total, 3);
end

function deleteScore(app)
try
    if ~isempty(app) && isvalid(app), delete(app); end
catch
end
try
    close(findall(0, 'Type', 'figure'));
catch
end
end

function removeFolder(folder)
if isfolder(folder), rmdir(folder, 's'); end
end
