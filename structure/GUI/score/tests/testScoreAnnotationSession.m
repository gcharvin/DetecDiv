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

verifyTrue(testCase, isvalid(app.LineageLinkWidthEditField));
verifyEqual(testCase, app.LineageLinkWidthEditField.Value, 1);
verifyEqual(testCase, char(app.AnnotationSessionPanel.Visible), 'on');
verifyEqual(testCase, app.TabGroup.SelectedTab, app.AnnotationsTab, ...
    'Managed annotation sessions must open on the Annotations tab.');
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
verifyEqual(testCase, char(app.MasklabelEditField.Visible), 'off');
verifyEqual(testCase, char(app.SelectedObjectIDEditField.Visible), 'off');
verifyEqual(testCase, app.DisplayCriterionDropDown.Value, 'Track');
rawIdx = r.findChannelID('raw', 'exact');
gtIdx = r.findChannelID(gtName, 'exact');
verifyTrue(testCase, logical(r.display.selectedchannel(rawIdx)), ...
    'Managed annotation must retain an intensity background.');

% Selection follows track identity, not a coincidentally reused mask label.
model = cellModel.create(r.id);
model.families.family_id = uint32(1);
model.families.name = {'reviewed tracks'};
model.families.mask_provider = {gtName};
model.families.lineage_source = {''};
model.families.color_rgb = uint8([255 0 0]);
for frame = 1:3
    [model, ~] = cellModel.syncFrame(model, 1, frame, ...
        r.image(:,:,gtIdx,frame), 'TrackPolicy', 'preserve_or_label');
end
[model, ~] = cellModel.reassignTrack(model, 1, 2, 1, 2, 'to-last');
r.saveCellModel(model);
r.display.frame = 1;
score_display(app, 'fast');
[~, ~, overlay1] = score_makeComposite(r, 1, app.layoutOptions);
r.display.frame = 2;
score_display(app, 'fast');
[~, ~, overlay2] = score_makeComposite(r, 1, app.layoutOptions);
verifyNotEqual(testCase, squeeze(overlay1(2,2,:)), ...
    squeeze(overlay2(2,2,:)), ...
    'Edit mode with Color by Track must not color reused mask labels alike.');
app.SelectedObjectChannelIdx = gtIdx;
app.SelectedObjectRoiId = string(r.id);
app.SelectedObjectLabelCell = 1;
app.SelectedObjectLabel = 1;
app.SelectedTrackIDCell = 1;
r.display.frame = 2;
verifyEmpty(testCase, score_resolveSelectedTrackForFrame(app, r), ...
    'The same mask label on another track must not remain selected.');
verifyTrue(testCase, isnan(app.SelectedObjectLabelCell));
verifyEqual(testCase, app.SelectedTrackIDCell, 1);
r.display.frame = 1;
instance = score_resolveSelectedTrackForFrame(app, r);
verifyEqual(testCase, instance.track_id, uint64(1));
verifyEqual(testCase, app.SelectedObjectLabelCell, 1);

% Reviewing an unchanged frame is a one-click operation and immediately
% advances to the next incomplete frame.
reviewCallback = app.MarkFrameReviewedButton.ButtonPushedFcn;
reviewCallback(app.MarkFrameReviewedButton, []);
verifyEqual(testCase, session.summary().coverage.reviewed, 1);
verifyEqual(testCase, r.display.frame, 2);

% Indexed-only display must still own a valid image/overlay tile and the
% ImageFigure arrow callback must continue navigating between frames.
r.display.selectedchannel(:) = false;
r.display.selectedchannel(gtIdx) = true;
app.OverlayCheckBox.Value = true;
score_display(app, 'slow');
verifyNotEmpty(testCase, app.graphicsHandles.overlayHandles);
verifyGreaterThan(testCase, app.graphicsHandles.overlayHandles.Count, 0);
frameBefore = r.display.frame;
keyCallback = app.ImageFigure.KeyPressFcn;
keyCallback(app.ImageFigure, struct('Key', 'rightarrow'));
verifyEqual(testCase, r.display.frame, frameBefore + 1);
verifyGreaterThan(testCase, app.graphicsHandles.overlayHandles.Count, 0);

% A deliberately empty channel selection should still leave a live black
% canvas rather than an orphaned figure with no overlay handle.
r.display.selectedchannel(:) = false;
score_display(app, 'slow');
verifyGreaterThan(testCase, app.graphicsHandles.overlayHandles.Count, 0);

app.notifyAnnotationChanged(gtName, 1);
summary = session.summary();
verifyEqual(testCase, summary.coverage.reviewed, 1);
verifyEqual(testCase, summary.coverage.total, 3);

% External painting/lineage callbacks must use the public bridge rather
% than calling Score's private display-binding method directly.
verifyWarningFree(testCase, @() app.syncLineageDisplayAfterEdit());
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
