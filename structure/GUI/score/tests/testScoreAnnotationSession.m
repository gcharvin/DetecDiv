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
gtName = cellposesam.annotationChannelName(c);
verifyEmpty(testCase, r.findChannelID(gtName));

app = score(r, 'pixelAnnotation');
appCleanup = onCleanup(@() deleteScore(app)); %#ok<NASGU>
app.setAnnotationSession(session);

verifyTrue(testCase, isvalid(app.LineageLinkWidthEditField));
verifyEqual(testCase, app.LineageLinkWidthEditField.Value, 1);
verifyEqual(testCase, char(app.AnnotationSessionPanel.Visible), 'on');
verifyEqual(testCase, app.ValidateAnnotationButton.Text, 'Validate GT');
verifyEqual(testCase, char(app.ApproveAnnotationButton.Visible), 'off', ...
    'Validation is the only user-facing finalization action.');
verifyEqual(testCase, app.TabGroup.SelectedTab, app.AnnotationsTab, ...
    'Managed annotation sessions must open on the Annotations tab.');
verifyTrue(testCase, contains(app.AnnotationStatusLabel.Text, 'MISSING'));
verifyTrue(testCase, contains(app.AnnotationStatusLabel.Text, 'Train: all'));
verifyEqual(testCase, numel(findall(app.AnnotationMenu, ...
    'Tag', 'ScoreTrainingBoundsMenu')), 1);
r.display.frame = 2;
app.updateTrainingFrameBounds('start');
verifyEqual(testCase, session.frameBounds(), [2 3]);
verifyTrue(testCase, contains(app.AnnotationStatusLabel.Text, 'Train: 2:3'));
verifyEqual(testCase,session.summary().coverage.total,2);
verifyEqual(testCase,app.nextIncompleteAnnotationFrame(),3, ...
    'Next incomplete must ignore frames outside the training bounds.');
app.updateTrainingFrameBounds('all');
verifyEmpty(testCase, session.frameBounds());
verifyTrue(testCase, contains(app.AnnotationStatusLabel.Text, 'Train: all'));
r.display.frame = 1;
verifyEqual(testCase, char(app.CreateFromPredictionButton.Enable), 'on');
verifyEmpty(testCase, r.findChannelID(gtName), ...
    'Opening managed Score must not materialize GT implicitly.');
verifyNotEmpty(testCase, app.CreateFromPredictionButton.ButtonPushedFcn);
verifyTrue(testCase, isvalid(app.MarkThroughCurrentButton));
verifyNotEmpty(testCase, app.MarkThroughCurrentButton.ButtonPushedFcn);
verifyTrue(testCase, isvalid(app.ReviewWhileNavigatingCheckBox));

callback = app.CreateFromPredictionButton.ButtonPushedFcn;
callback(app.CreateFromPredictionButton, []);

verifyNotEmpty(testCase, r.findChannelID(gtName));
verifyEqual(testCase, session.summary().status, 'draft');
verifyTrue(testCase, contains(app.AnnotationStatusLabel.Text, 'DRAFT'));
verifyTrue(testCase, contains(app.AnnotationCoverageLabel.Text, 'Segmentation'));
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

% Painting after the selected track disappears must create a free provider
% label and bind it back to the persistent track, rather than inventing a
% new trajectory or stealing a label already used by another track.
[paintLabel, paintTrack] = score_prepareSelectedTrackPaint( ...
    app, r, gtName, gtIdx, gtIdx, 2);
verifyEqual(testCase, paintTrack, 1);
verifyEqual(testCase, paintLabel, 2, ...
    'Provider label 1 is occupied by track 2 on this frame.');
r.image(1,1,gtIdx,2) = uint16(paintLabel);
score_syncCellModelFrame(r, gtName, 2, 'Save', false);
paintReport = score_applySelectedTrackPaint( ...
    app, r, gtName, 2, paintLabel, paintTrack);
verifyEqual(testCase, paintReport.status, 'propagated');
[paintedModel, status] = score_getCellModel(r);
verifyEqual(testCase, status, 'ok');
[~, familyId] = cellModel.familyIndex(paintedModel, 'reviewed tracks');
paintedInstance = cellModel.findInstance( ...
    paintedModel, familyId, 2, paintLabel);
verifyEqual(testCase, paintedInstance.track_id, uint64(1));
verifyEqual(testCase, app.SelectedTrackIDCell, 1);
verifyEqual(testCase, app.SelectedObjectLabelCell, paintLabel);

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
app.ReviewWhileNavigatingCheckBox.Value = true;
keyCallback = app.ImageFigure.KeyPressFcn;
keyCallback(app.ImageFigure, struct('Key', 'rightarrow'));
verifyEqual(testCase, r.display.frame, frameBefore + 1);
verifyGreaterThan(testCase, app.graphicsHandles.overlayHandles.Count, 0);
verifyEqual(testCase, session.summary().coverage.reviewed, 2, ...
    'Leaving a frame in review-on-navigation mode must review it once.');

% A deliberately empty channel selection should still leave a live black
% canvas rather than an orphaned figure with no overlay handle.
r.display.selectedchannel(:) = false;
score_display(app, 'slow');
verifyGreaterThan(testCase, app.graphicsHandles.overlayHandles.Count, 0);

app.notifyAnnotationChanged(gtName, 1);
summary = session.summary();
verifyEqual(testCase, summary.coverage.reviewed, 2);
verifyEqual(testCase, summary.coverage.total, 3);

% External painting/lineage callbacks must use the public bridge rather
% than calling Score's private display-binding method directly.
verifyWarningFree(testCase, @() app.syncLineageDisplayAfterEdit());

% A visible ROI preset may be copied to a ROI with fewer/reordered channels.
% RGB/intensity use channel rows, whereas displaylim uses channel columns.
source = roi('presetSource', [1 1 4 4]);
source.image = uint16(ones(4,4,4,3));
source.channelid = 1:4;
source.display.channel = {'raw','sourceOnly','other','extraB'};
source.display.intensity = [1 2 3; 4 5 6; 7 8 9; 10 11 12];
source.display.rgb = [0.1 0.2 0.3; 0.4 0.5 0.6; ...
    0.7 0.8 0.9; 1.0 0.9 0.8];
source.display.displaylim = [0.01 0.02 0.03 0.04; 0.91 0.92 0.93 0.94];
source.display.selectedchannel = [true false true true];
source.display.indexed = [false false true true];
source.display.alpha = [1 0.8 0.5 0.35];
source.display.contour = [false false true true];
source.display.width = [0 0 1 1.5];
source.display.log = false(1,4);
source.display.scale = false(1,4);
source.display.colorMode = {'rgb','rgb','rgb','rgb'};
source.display.colormapName = {'','','',''};

target = roi('R2', [1 1 4 4]);
target.path = folder;
target.image = uint16(ones(4,4,3,3));
target.channelid = 1:3;
target.display.channel = {'extraB','raw','targetOnly'};
target.display.intensity = -ones(3,3);
target.display.rgb = -ones(3,3);
target.display.displaylim = repmat([0.2;0.8], 1, 3);
target.display.selectedchannel = true(1,3);
target.display.indexed = false(1,3);
target.display.alpha = ones(1,3);
target.display.contour = false(1,3);
target.display.width = ones(1,3);
target.display.log = false(1,3);
target.display.scale = false(1,3);
target.display.colorMode = {'rgb','rgb','rgb'};
target.display.colormapName = {'','',''};
copyReport = score_copyROIChannelPreset(source, target);

verifyEqual(testCase, copyReport.matched, {'raw','extraB'});
verifySize(testCase, target.display.intensity, [3 3]);
verifyEqual(testCase, target.display.intensity(1,:), [10 11 12]);
verifyEqual(testCase, target.display.intensity(2,:), [1 2 3]);
verifyEqual(testCase, target.display.intensity(3,:), [-1 -1 -1]);
verifyEqual(testCase, target.display.rgb(1,:), [1.0 0.9 0.8]);
verifyEqual(testCase, target.display.displaylim(:,1), [0.04;0.94]);
verifyEqual(testCase, target.display.displaylim(:,2), [0.01;0.91]);
verifyEqual(testCase, target.display.displaylim(:,3), [0.2;0.8]);
end

function testConfiguredBrightfieldWinsWithPartialRoiCache(testCase)
folder = tempname;
mkdir(folder);
folderCleanup = onCleanup(@() removeFolder(folder)); %#ok<NASGU>

c = classi(folder, 'score_background', 1);
c.classifierPkg = 'cellposesam';
c.category = {'Pixel'};
c.classes = {'cell'};
c.executionParam = struct('outputName', 'prediction');
c.trainingParam = struct('brightfieldChannelName', 'Channel1_z2');

r = roi('R1', [1 1 4 4]);
r.path = c.path;
brightfield = reshape(uint16(1:48), [4 4 1 3]);
r.image = brightfield;
r.channelid = 1;
r.display.channel = {'Channel1_z2'};
r.display.intensity = [1 1 1];
r.display.rgb = [1 1 1];
r.display.selectedchannel = true;
r.display.indexed = false;
r.display.alpha = 1;
r.display.contour = false;
r.display.width = 1;
r.display.displaylim = [0.1; 0.9];
r.display.log = false;
r.display.scale = false;
r.display.colorMode = {'rgb'};
r.display.colormapName = {''};

combined = repmat(brightfield, 1, 1, 3, 1);
r.addChannel(combined, 'CombinedChannel', [1 1 1], [1 1 1]);
prediction = zeros(4,4,1,3, 'uint16');
prediction(2:3,2:3,1,:) = 1;
r.addChannel(prediction, 'results_prediction_cell', [1 1 1], [0 0 0]);
r.display.displaylim = repmat([0.1; 0.9], 1, size(r.image, 3));
r.save([], false);
c.roi = r;

session = c.annotationSession(1);
session.bootstrap();
context = session.uiContext();
verifyEqual(testCase, context.displayPreset.backgroundChannels, ...
    {'Channel1_z2'}, ...
    'The annotation preset must expose the configured BF observation.');

r = session.Roi;
gtName = cellposesam.annotationChannelName(c);
h5File = fullfile(r.path, ['im_' char(string(r.id)) '.h5']);
verifyEqual(testCase, h5read(h5File, '/Channel1_z2'), brightfield);

% Reproduce Score's partial cache: only the composite and GT are resident,
% while the configured BF pixels remain available in HDF5.
r.image = [];
r.channelid = [];
r.load('Channel', {'CombinedChannel', gtName}, 'Data', false, 'Silent');
verifyEmpty(testCase, r.findChannelID('Channel1_z2', 'exact'));
bfRow = find(strcmpi(r.display.channel, 'Channel1_z2'), 1, 'first');
combinedRow = find(strcmpi(r.display.channel, 'CombinedChannel'), 1, 'first');
gtRow = find(strcmpi(r.display.channel, gtName), 1, 'first');
r.display.selectedchannel(:) = false;
r.display.indexed(:) = true;
r.display.indexed(combinedRow) = false;
r.display.selectedchannel(combinedRow) = true;
r.display.selectedchannel(gtRow) = true;

app = score(r, 'pixelAnnotation');
appCleanup = onCleanup(@() deleteScore(app)); %#ok<NASGU>
app.setAnnotationSession(session);

bfPixels = r.findChannelID('Channel1_z2', 'exact');
verifyNotEmpty(testCase, bfPixels, ...
    'Applying the preset must load an HDF5-only BF channel.');
verifyLessThanOrEqual(testCase, max(bfPixels), size(r.image, 3));
verifyTrue(testCase, logical(r.display.selectedchannel(bfRow)));
verifyFalse(testCase, logical(r.display.indexed(bfRow)));
verifyTrue(testCase, any(logical(r.display.intensity(bfRow,:))));
verifyFalse(testCase, logical(r.display.selectedchannel(combinedRow)), ...
    'CombinedChannel must not supersede the configured BF observation.');
verifyEqual(testCase, h5read(h5File, '/Channel1_z2'), brightfield, ...
    'Selecting a background must not rewrite the stored source pixels.');
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
