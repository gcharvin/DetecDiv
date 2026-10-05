function tests = testRoiPatternPreviewConsistency
tests = functiontests(localfunctions);
end

function setupOnce(~)
repoRoot = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
detecdiv_setup_path(repoRoot, 'Verbose', false);
end

function testJobPinsPatternDespiteLaterTemplateEdit(testCase)
p = params();
node = struct('id','pattern_1','type','roiPattern','params',p);
overrides.pattern_1 = struct('channel','phase','keepExisting',true);
saved = pipelineSnapshotRoiPatternOverrides(node, overrides);
node.params.pattern.image(:) = 999;
node.params.pattern.rect = [1 1 130 130];
verifyEqual(testCase, saved.pattern_1.pattern, p.pattern);
verifyEqual(testCase, saved.pattern_1.threshold, p.threshold);
verifyTrue(testCase, saved.pattern_1.keepExisting);
verifyFalse(testCase, isfield(saved.pattern_1,'previewRects'));
end

function testPreviewInvalidationKeepsPattern(testCase)
p = params();
p.previewRects = [1 1 130 130];
p.candidateRects = p.previewRects;
clean = pipelineInvalidateRoiPatternPreview(p);
verifyFalse(testCase, isfield(clean,'previewRects'));
verifyFalse(testCase, isfield(clean,'candidateRects'));
verifyEqual(testCase, clean.pattern, p.pattern);
end

function testChangingPatchPixelsInvalidatesConfigEvenWithSameRect(testCase)
p = params();
old = pipelineRoiPatternPreviewConfig(p);
p.pattern.image(1) = p.pattern.image(1) + 1;
verifyNotEqual(testCase, pipelineRoiPatternPreviewConfig(p), old);
end

function testNodePatternWinsOverStaleContextPattern(testCase)
[project, cleanup, images] = fixture(); %#ok<ASGLU>
p = params(); p.pattern.image = images{1}(20:31,20:31);
ctx = struct('shallow',project,'roiPattern',p,'pattern', ...
    struct('rect',[1 1 8 8],'image',ones(8)), ...
    'sel',struct('fovs',1),'testOnly',true,'resume',false,'saveProgress',false);
out = roiPattern.process(ctx);
verifyNotEmpty(testCase, out.patternDetection);
verifyEqual(testCase, out.patternList.image, p.pattern.image);
end

function testZeroDetectionsFailsWithoutProcessingOldPosition(testCase)
[project, cleanup] = fixture(); %#ok<ASGLU>
project.fov(1).roi = roi('source_old',[20 20 12 12]);
p = params(); p.threshold = 1; % No correlation can exceed this threshold.
ctx = struct('shallow',project,'roiPattern',p,'sel',struct('fovs',2), ...
    'resume',false,'saveProgress',false);
verifyError(testCase, @()roiPattern.process(ctx), 'roiPattern:NoDetections');
verifyEqual(testCase, project.fov(1).roi.id, 'source_old');
verifyEmpty(testCase, project.fov(2).roi.id);
end

function testBrowsingOtherFovDoesNotRecapturePatternOnProceed(testCase)
[project, cleanup] = fixture(); %#ok<ASGLU>
p = params();
app = workflow2(project,'FocusModule','roiPattern','Params',p);
appCleanup = onCleanup(@()delete(app)); %#ok<NASGU>
app.UIFigure.Visible = 'off';
app.UIFOVTable.SelectionChangedFcn(app.UIFOVTable,struct('Selection',2));
app.FrameEditField.Value = 2;
app.FrameEditField.ValueChangedFcn(app.FrameEditField,struct());
app.ProceedButton.ButtonPushedFcn(app.ProceedButton,struct());
verifyEqual(testCase, app.Result.pattern, p.pattern);
verifyEqual(testCase, app.Result.referenceFrame, p.referenceFrame);
verifyEqual(testCase, app.Result.channel, p.channel);
end

function testSuccessfulDetectionOnlyReturnsSelectedPosition(testCase)
[project, cleanup, images] = fixture(); %#ok<ASGLU>
project.fov(2).roi = roi('target_old',[20 20 12 12]);
p = params(); p.pattern.image = images{1}(20:31,20:31);
ctx = struct('shallow',project,'roiPattern',p,'sel',struct('fovs',1), ...
    'resume',false,'saveProgress',false);
out = roiPattern.process(ctx);
verifyNotEmpty(testCase, out.roiList);
verifyTrue(testCase, all(startsWith({out.roiList.id},'source_')));
verifyEqual(testCase, project.fov(2).roi.id, 'target_old');
end

function testEmptySelectionWithSkipPolicyStillFails(testCase)
[project, cleanup] = fixture(); %#ok<ASGLU>
p = params(); p.threshold = 1;
ctx = struct('shallow',project,'roiPattern',p,'sel',struct('fovs',2), ...
    'io',struct('existingPolicy','skip'),'resume',false,'saveProgress',false);
verifyError(testCase, @()roiPattern.process(ctx), 'roiPattern:NoDetections');
end

function testEditingRectDiscardsLoadedPreviewAndCapturesNewPixels(testCase)
[project, cleanup, images] = fixture(); %#ok<ASGLU>
p = params(); p.previewRects = [1 1 130 130]; p.candidateRects = p.previewRects;
app = workflow2(project,'FocusModule','roiPattern','Params',p);
appCleanup = onCleanup(@()delete(app)); %#ok<NASGU>
app.UIFigure.Visible = 'off';
app.CurrentROIsizeEditField.Value = '30, 30, 12, 12';
app.CurrentROIsizeEditField.ValueChangedFcn(app.CurrentROIsizeEditField,struct());
verifyEmpty(testCase, app.UIROICandidateTable.Data);
app.ProceedButton.ButtonPushedFcn(app.ProceedButton,struct());
verifyEqual(testCase, app.Result.pattern.rect, [30 30 12 12]);
verifyEqual(testCase, app.Result.pattern.image, images{1}(30:41,30:41));
verifyFalse(testCase, isfield(app.Result,'previewRects'));
verifyFalse(testCase, isfield(app.Result,'candidateRects'));
end

function testDedicatedEditorReplacesLegacySinglePattern(testCase)
[project, cleanup] = fixture(); %#ok<ASGLU>
p = params(); selected = p.pattern; selected.rect = [30 30 12 12];
p.patternList = selected; p.activePatternIndex = 1;
p.previewRects = [1 1 130 130];
app = roiIdentifyGUI(project,p);
appCleanup = onCleanup(@()delete(app)); %#ok<NASGU>
app.UIFigure.Visible = 'off';
app.SaveButton.ButtonPushedFcn(app.SaveButton,struct());
verifyEqual(testCase, app.Result.pattern.rect, selected.rect);
verifyFalse(testCase, isfield(app.Result,'previewRects'));
end

function p = params()
p = struct('referenceFrame',1,'threshold',0.5,'channel','phase', ...
    'channelIndex',1,'keepExisting',false,'fovIndex',1, ...
    'pattern',struct('rect',[20 20 12 12],'crop',[20 20 12 12], ...
    'fovId','source','fovIndex',1,'referenceFrame',1, ...
    'channel','phase','channelIndex',1,'image',uint16(reshape(1:144,12,12))));
end

function [project, cleanup, images] = fixture()
root = tempname;
assert(startsWith(root, tempdir, 'IgnoreCase', true));
mkdir(root);
cleanup = onCleanup(@()rmdir(root,'s'));
project = shallow(); project.io.path = root; project.io.file = 'test_project';
stream = RandStream('mt19937ar','Seed',42);
images = {uint16(rand(stream,96)*60000), uint16(ones(96)*100)};
for i = 1:2
    folder = fullfile(root,sprintf('pos%d',i)); mkdir(folder);
    imwrite(images{i},fullfile(folder,'frame1.tif'));
    imwrite(images{i}+10,fullfile(folder,'frame2.tif'));
    f = fov(); f.roi = roi(); f.id = 'source';
    if i == 2, f.id = 'target'; end
    f.number = i; f.srcpath = {folder}; f.srclist = {dir(fullfile(folder,'frame*.tif'))};
    f.channel = {'phase'}; f.frames = 2; f.interval = 1; f.parent = project;
    project.fov(i) = f;
end
end
