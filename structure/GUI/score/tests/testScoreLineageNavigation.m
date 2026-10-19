function tests = testScoreLineageNavigation
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root = fileparts(fileparts(fileparts(fileparts(fileparts(mfilename('fullpath'))))));
addpath(root);
startup;
testCase.TestData.visibility = get(groot,'DefaultFigureVisible');
set(groot,'DefaultFigureVisible','off');
testCase.TestData.hadDisplaySettings = evalin('base','exist(''DisplaySettings'',''var'') == 1');
if testCase.TestData.hadDisplaySettings
    testCase.TestData.displaySettings = evalin('base','DisplaySettings');
end
end

function teardownOnce(testCase)
set(groot,'DefaultFigureVisible',testCase.TestData.visibility);
% Score shares presets through the base workspace; do not leak the fixture's
% channel/movie settings into other GUI suites.
if testCase.TestData.hadDisplaySettings
    assignin('base','DisplaySettings',testCase.TestData.displaySettings);
else
    evalin('base','clear DisplaySettings');
end
end

function testTreeClicksSelectTheSameRowThatMouseEditingUses(testCase)
[app,r,cleanup] = fixture(); %#ok<ASGLU>
beforeImage = r.image;
beforeModel = r.cellModel;
for channel = {'gtMask','predMask'}
    selectMask(app,channel{1});
    r.display.frame = 1;
    score_display(app,'fast');
    [node,callback] = treeNode(app,2);
    callback(node,[]);
    verifyEqual(testCase,r.display.frame,2);
    verifyEqual(testCase,app.SelectedTrackIDCell,2);
    verifyEqual(testCase,string(app.SelectedObjectRectangle.Parent.UserData.annotationChannel),string(channel{1}));
    overlay = score_getObjectOverlay(app,channel{1});
    verifyEqual(testCase,app.SelectedObjectRectangle.Parent,overlay.Parent);
    verifyTrue(testCase,score_isEditMode(app));
    verifyNotEmpty(testCase,app.ImageFigure.WindowButtonDownFcn);
    verifyNotEmpty(testCase,app.ImageFigure.KeyPressFcn);
end
verifyEqual(testCase,r.image,beforeImage);
verifyEqual(testCase,r.cellModel,beforeModel);
verifyEmpty(testCase,app.ModifiedRoiIds);
end

function testClickOnCurrentFrameRestoresMouseCallbacksWithoutRebuilding(testCase)
[app,r,cleanup] = fixture(); %#ok<ASGLU>
selectMask(app,'gtMask');
[node,callback] = treeNode(app,2);
callback(node,[]);
beforeOverlay = score_getObjectOverlay(app,'gtMask');
% Reproduce a stale callback snapshot or a drag whose mouse-up was lost.
app.ImageFigure.WindowButtonDownFcn = [];
app.ImageFigure.WindowButtonMotionFcn = @(~,~) error('test:AbandonedDrag','stale drag');
app.ImageFigure.WindowButtonUpFcn = @(~,~) error('test:AbandonedDrag','stale drag');
callback(node,[]);
verifyEqual(testCase,r.display.frame,2);
verifyEqual(testCase,score_getObjectOverlay(app,'gtMask'),beforeOverlay);
verifyNotEmpty(testCase,app.ImageFigure.WindowButtonDownFcn);
verifyTrue(testCase,contains(func2str(app.ImageFigure.WindowButtonDownFcn),'score_paintOverlay'));
verifyEmpty(testCase,app.ImageFigure.WindowButtonMotionFcn);
verifyEmpty(testCase,app.ImageFigure.WindowButtonUpFcn);
verifyEqual(testCase,app.ImageFigure.Pointer,'arrow');
end

function testNavigationPreservesPanAndLeavingPanRestoresEditing(testCase)
[app,~,cleanup] = fixture(); %#ok<ASGLU>
selectMask(app,'gtMask');
[node,callback] = treeNode(app,2);
panCallback = app.PanButton.ValueChangedFcn;
app.PanButton.Value = true;
panCallback(app.PanButton,struct());
verifyFalse(testCase,score_restoreMaskInteraction(app));
verifyWarningFree(testCase,@() callback(node,[]));
verifyTrue(testCase,app.PanButton.Value);
app.PanButton.Value = false;
panCallback(app.PanButton,struct());
verifyEqual(testCase,char(get(pan(app.ImageFigure),'Enable')),'off');
verifyNotEmpty(testCase,app.ImageFigure.WindowButtonDownFcn);
verifyEqual(testCase,string(app.SelectedObjectRectangle.Parent.UserData.annotationChannel),"gtMask");
end

function testOverlayLookupRespectsThePhysicalColumnAndRejectsOtherRows(testCase)
[app,~,cleanup] = fixture(); %#ok<ASGLU>
for panel = app.graphicsHandles.comparisonPanels
    base = app.graphicsHandles.imgHandles(panel.tile);
    expected = app.graphicsHandles.overlayHandles(panel.tile);
    channel = expected.UserData.annotationChannel;
    verifyEqual(testCase,score_getObjectOverlay(app,channel,base.Parent),expected);
    verifyEqual(testCase,score_getObjectOverlay(app,channel,expected.Parent),expected);
    other = 'gtMask';
    if strcmp(channel,other), other = 'predMask'; end
    selected = score_getObjectOverlay(app,other,expected.Parent);
    verifyEqual(testCase,string(selected.UserData.annotationChannel),string(other));
end
verifyEmpty(testCase,score_getObjectOverlay(app,'absentMask'));
end

function testSingleMaskTreeNavigationRemainsInteractive(testCase)
[app,r,cleanup] = fixture(); %#ok<ASGLU>
selectMask(app,'gtMask');
r.display.selectedchannel(4) = false;
app.UIAnnotationTable.Data{2,1} = false;
score_display(app,'slow');
verifyFalse(testCase,isfield(app.graphicsHandles,'comparisonPanels'));
[node,callback] = treeNode(app,2);
callback(node,[]);
overlay = score_getObjectOverlay(app,'gtMask');
verifyEqual(testCase,app.SelectedObjectRectangle.Parent,overlay.Parent);
verifyEqual(testCase,r.display.frame,2);
verifyNotEmpty(testCase,app.ImageFigure.WindowButtonDownFcn);
end

function [app,r,cleanup] = fixture()
folder = tempname;
mkdir(folder);
r = roi('lineage-navigation',[1 1 24 24]);
r.path = folder;
r.image = zeros(24,24,4,3,'uint16');
r.image(:,:,1:2,:) = 20000;
r.image(4:8,4:8,3,:) = 1;
r.image(14:18,4:8,3,2:3) = 2;
r.image(4:8,16:20,4,:) = 1;
r.image(14:18,16:20,4,2:3) = 2;
r.channelid = 1:4;
r.display.channel = {'raw','fluorescence','gtMask','predMask'};
r.display.indexed = [false false true true];
r.display.selectedchannel = true(1,4);
r.display.intensity = [1 1 1;1 1 1;0 0 0;0 0 0];
r.display.rgb = [1 1 1;0 1 0;1 0 0;0 0 1];
r.display.alpha = [1 1 .5 .5];
r.display.contour = [false false true true];
r.display.width = ones(1,4);
r.display.displaylim = repmat([0;1],1,4);
model = cellModel.create(r.id);
model.families.family_id = uint32([1;2]);
model.families.name = {'GT';'Prediction'};
model.families.mask_provider = {'gtMask';'predMask'};
model.families.lineage_source = {'gt';'prediction'};
model.families.color_rgb = uint8([255 0 0;0 0 255]);
for family = 1:2
    for frame = 1:3
        model = cellModel.syncFrame(model,family,frame,r.image(:,:,family+2,frame), ...
            'TrackPolicy','preserve_or_label');
    end
    model = cellModel.setParent(model,family,2,2,1);
end
r.saveCellModel(model,'KeepBackup',false);
r.save([],false);
app = score(r);
cleanup = onCleanup(@() deleteFixture(app,folder));
app.OverlayCheckBox.Value = false;
score_display(app,'slow');
end

function selectMask(app,channel)
row = find(strcmp(string(app.UIAnnotationTable.Data(:,2)),string(channel)),1);
app.UIAnnotationTable.Selection = [row 1];
score_refreshObjectDisplayUI(app);
score_setEditMode(app,true);
callback = app.ChannelModeButtonGroup.SelectionChangedFcn;
callback(app.ChannelModeButtonGroup,struct());
end

function [node,callback] = treeNode(app,trackId)
open = app.LineageTreeButton.ButtonPushedFcn;
open(app.LineageTreeButton,struct());
fig = findall(groot,'Tag','ScoreAsymmetricLineageTree');
node = findall(fig,'Type','text','String',sprintf('%u',trackId));
node = node(1);
callback = node.ButtonDownFcn;
end

function deleteFixture(app,folder)
if isvalid(app)
    app.ModifiedRoiIds = strings(0,1);
    app.AnnotationReviewDirty = false;
    if isgraphics(app.ImageFigure), delete(app.ImageFigure); end
    delete(app);
end
if isfolder(folder), rmdir(folder,'s'); end
end
