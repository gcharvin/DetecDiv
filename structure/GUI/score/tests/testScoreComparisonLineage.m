function tests = testScoreComparisonLineage
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root = fileparts(fileparts(fileparts(fileparts(fileparts(mfilename('fullpath'))))));
addpath(root);
startup;
testCase.TestData.visibility = get(groot,'DefaultFigureVisible');
set(groot,'DefaultFigureVisible','off');
end

function teardownOnce(testCase)
set(groot,'DefaultFigureVisible',testCase.TestData.visibility);
end

function testEveryLegacyMaskHasItsOwnLinksInDisplayAndExports(testCase)
for mode = {'display','sequence','movie'}
    [r,opts] = fixture(mode{1},false);
    beforeDisplay = r.display;
    beforeData = r.data.userData;
    opts.name = [tempname '.pdf'];
    if strcmp(mode{1},'movie')
        opts.name = [tempname '.avi']; opts.movieProfile = 'Motion JPEG AVI';
    end
    cleanupFile = onCleanup(@() deleteIfPresent(opts.name)); %#ok<NASGU>
    dh = score_createDisplayHandles(opts);
    cleanup = onCleanup(@() close(dh.Figure)); %#ok<NASGU>
    gh = score_renderFinalFrame(dh,r,opts);
    frame = 1;
    if strcmp(mode{1},'movie'), frame = 2; end
    verifyLinks(testCase,gh,opts,frame,false);
    if strcmp(mode{1},'display')
        score_updateRender(gh,r,opts,dh,2);
        verifyLinks(testCase,gh,opts,2,false);
    end
    verifyEqual(testCase,r.display,beforeDisplay);
    verifyEqual(testCase,r.data.userData,beforeData);
end
end

function testCellModelFamiliesAreResolvedPerRow(testCase)
for overlay = [false true]
    [r,opts] = fixture('display',true);
    opts.overlay = overlay;
    before = r.cellModel;
    dh = score_createDisplayHandles(opts);
    cleanup = onCleanup(@() close(dh.Figure)); %#ok<NASGU>
    gh = score_renderFinalFrame(dh,r,opts);
    verifyLinks(testCase,gh,opts,1,true);
    score_updateRender(gh,r,opts,dh,2);
    verifyLinks(testCase,gh,opts,2,true);
    verifyEqual(testCase,r.cellModel,before);
    verifyEqual(testCase,r.display.lineage.modelFamilyId,1);
end
end

function testSecondMaskDoesNotRequireLinksOnTheFirst(testCase)
for useModel = [false true]
    [r,opts] = fixture('display',useModel);
    if useModel
        for field = reshape(fieldnames(r.cellModel.relations),1,[])
            r.cellModel.relations.(field{1}) = r.cellModel.relations.(field{1})(2,:);
        end
    else
        remove(r.data.userData.lineageSources.first.motherOf,int32(2));
    end
    r.display.lineage.enabled = false;
    dh = score_createDisplayHandles(opts);
    cleanup = onCleanup(@() close(dh.Figure)); %#ok<NASGU>
    gh = score_renderFinalFrame(dh,r,opts);
    for p = gh.comparisonPanels
        verifyEqual(testCase,isKey(gh.lineageHandles,p.tile),p.row == 2);
        if p.row == 2
            verifyNumElements(testCase,gh.lineageHandles(p.tile).geoms,1);
            verifyEqual(testCase,gh.lineageHandles(p.tile).geoms.daughterID,int32(20));
        end
    end
end
end

function testTogglesMissingSourcesAndPerChannelStyles(testCase)
[r,opts] = fixture('display',false);
score_setObjectDisplayConfig(r,'maskB',struct('genealogyLinkColor',[1 0 1], ...
    'budLinkColor',[0 1 0],'linkWidthPx',3));
dh = score_createDisplayHandles(opts);
cleanup = onCleanup(@() close(dh.Figure)); %#ok<NASGU>
gh = score_renderFinalFrame(dh,r,opts);
for p = gh.comparisonPanels
    if p.row == 2
        geometry = gh.lineageHandles(p.tile).geoms;
        verifyEqual(testCase,geometry.color,[1 0 1]);
        verifyEqual(testCase,geometry.lineWidth,3);
    end
end
opts.ShowLineageOverlay = false;
refreshLineageOverlays(gh,r,opts,dh,1);
verifyEqual(testCase,double(gh.lineageHandles.Count),0);
opts.ShowLineageOverlay = true;
score_setObjectDisplayConfig(r,'maskB',struct('lineageSource','<none>'));
refreshLineageOverlays(gh,r,opts,dh,1);
for p = gh.comparisonPanels
    verifyEqual(testCase,isKey(gh.lineageHandles,p.tile),p.row == 1);
end
score_setObjectDisplayConfig(r,'maskB',struct('lineageSource','<family default>'));
r.data.userData.lineageSources = rmfield(r.data.userData.lineageSources,'second');
refreshLineageOverlays(gh,r,opts,dh,1);
for p = gh.comparisonPanels
    verifyEqual(testCase,isKey(gh.lineageHandles,p.tile),p.row == 1);
end
end

function testBudPairingUsesEachMaskSource(testCase)
for useModel = [false true]
    [r,opts] = fixture('sequence',useModel);
    if ~useModel
        r.data.userData.lineageSources.second = rmfield(r.data.userData.lineageSources.second,'motherOf');
    end
    opts.ShowLineageOverlay = false; opts.ShowBudPairingOverlay = true;
    dh = score_createDisplayHandles(opts);
    cleanup = onCleanup(@() close(dh.Figure)); %#ok<NASGU>
    gh = score_renderAnnotationComparison(dh,r,opts);
    verifyLinks(testCase,gh,opts,1,useModel);
    for key = gh.lineageHandles.keys
        verifyEqual(testCase,gh.lineageHandles(key{1}).geoms.mode,'bud');
    end
end
end

function testSingleMaskBindingRemainsCompatible(testCase)
for useModel = [false true]
    [r,opts] = fixture('display',useModel);
    preset = score_getObjectDisplayConfig(r,'maskB');
    key = score_configureLineageDisplay(r,'maskB',4,preset,false,true);
    expected = 'second';
    if useModel, expected = 'cell_model:2'; end
    verifyEqual(testCase,key,expected);
    opts.channel = opts.channel([1 2 4]); opts.levels = opts.levels([1 2 4]);
    opts.RGB = opts.RGB([1 2 4]);
    dh = score_createDisplayHandles(opts);
    cleanup = onCleanup(@() close(dh.Figure)); %#ok<NASGU>
    gh = score_renderFinalFrame(dh,r,opts);
    verifyFalse(testCase,isfield(gh,'comparisonPanels'));
    for tile = gh.lineageHandles.keys
        geometry = gh.lineageHandles(tile{1}).geoms;
        verifyNumElements(testCase,geometry,1);
        verifyEqual(testCase,geometry.sourceKey,expected);
        verifyEqual(testCase,[geometry.xd geometry.xm],[17.5 17.5]);
    end
end
end

function testExplicitFamilyAndMaskProviderAreRespected(testCase)
[r,opts] = fixture('display',true);
score_setObjectDisplayConfig(r,'maskB',struct('objectFamily','GT','maskProvider','maskA'));
opts.objectDisplay = [score_getObjectDisplayConfig(r,'maskA') score_getObjectDisplayConfig(r,'maskB')];
dh = score_createDisplayHandles(opts);
cleanup = onCleanup(@() close(dh.Figure)); %#ok<NASGU>
gh = score_renderFinalFrame(dh,r,opts);
for p = gh.comparisonPanels
    verifyTrue(testCase,isKey(gh.lineageHandles,p.tile));
    geometry = gh.lineageHandles(p.tile).geoms;
    verifyNumElements(testCase,geometry,1);
    verifyEqual(testCase,geometry.sourceKey,'cell_model:1');
    verifyEqual(testCase,[geometry.xd geometry.xm],[5.5 5.5]);
end
end

function testGuiExportUsesTheSelectedModeWhenFirstMaskHasNoRelations(testCase)
exerciseGuiExport(testCase,false);
end

function testGuiExportSurvivesQueuedInteractiveRefresh(testCase)
exerciseGuiExport(testCase,true);
end

function exerciseGuiExport(testCase,queueRefresh)
[r,~] = fixture('display',true);
for field = reshape(fieldnames(r.cellModel.relations),1,[])
    r.cellModel.relations.(field{1}) = r.cellModel.relations.(field{1})(2,:);
end
folder = tempname;
mkdir(folder);
cleanupFolder = onCleanup(@() rmdir(folder,'s')); %#ok<NASGU>
r.path = folder;
r.display.intensity = [1 1 1;1 1 1;0 0 0;0 0 0];
r.display.alpha = [1 1 0.5 0.5]; r.display.width = ones(1,4);
r.display.displaylim = repmat([0;1],1,4);
r.save([],false);
app = score(r);
cleanupApp = onCleanup(@() deleteApp(app)); %#ok<NASGU>
owner = app.ScoreAppUIFigure;
cleanupExports = onCleanup(@() closeExportFigures(owner)); %#ok<NASGU>
app.ImageFigure.Visible = 'off';
beforeModel = r.cellModel;
app.OverlayCheckBox.Value = false;
app.MovieoutputtypeDropDown.Value = 'Sequence';
app.MovieFramesEditField.Value = '1:2';
app.MovieROIArraysizeEditField.Value = '1 1';
app.MovieImagetodataratioEditField.Value = '1';
app.MovieoutputfilenameEditField.Value = fullfile(folder,'comparison.pdf');
% Programmatic Value assignments do not run the normal ValueChanged callbacks.
app.DisplaySettings.Movie.MovieoutputtypeDropDown = 'Sequence';
app.DisplaySettings.Movie.MovieFramesEditField = '1:2';
app.DisplaySettings.Movie.MovieROIArraysizeEditField = '1 1';
app.DisplaySettings.Movie.MovieoutputfilenameEditField = fullfile(folder,'comparison.pdf');
app.DisplaySettings.Movie.OverlayCheckBox = false;
app.MovieselectcurrentROIonlyCheckBox.Value = true;
app.LineageDisplayButtonGroup.SelectedObject = app.FullGenealogyRadioButton;
score_configureLineageDisplay(r,'maskA',3,score_getObjectDisplayConfig(r,'maskA'),false,true);
verifyFalse(testCase,r.display.lineage.showGenealogy);
callback = app.GrenerateMovieButton.ButtonPushedFcn;
setappdata(app.ScoreAppUIFigure,'TestExportRefreshCount',0);
if queueRefresh
    refreshTimer = timer('ExecutionMode','fixedSpacing','Period',0.05, ...
        'BusyMode','drop','TimerFcn',@(t,e) refreshDuringExport(t,e,app));
    cleanupTimer = onCleanup(@() deleteTimer(refreshTimer)); %#ok<NASGU>
    start(refreshTimer);
end
callback(app.GrenerateMovieButton,struct());
exportFigures = findExportFigures(owner);
assertNumElements(testCase,exportFigures,1);
exportFigure = exportFigures(1);
exportOptions = getappdata(exportFigure,'ScoreExportOptions');
verifyTrue(testCase,exportOptions.ShowLineageOverlay);
verifyFalse(testCase,exportOptions.ShowBudPairingOverlay);
verifyEqual(testCase,lower(exportOptions.mode),'sequence');
verifyEqual(testCase,exportOptions.frames,[1 2]);
verifyEqual(testCase,exportOptions.Nchannel,2);
verifyNotEqual(testCase,exportFigure,app.ImageFigure);
verifyEqual(testCase,lower(app.layoutOptions.mode),'display');
verifyTrue(testCase,isfile(fullfile(folder,'comparison.pdf')));
arrows = findall(exportFigure,'Type','quiver');
verifyNumElements(testCase,arrows,4);
for h = reshape(arrows,1,[])
    verifyEqual(testCase,h.XData,17.5);
end
if queueRefresh
    verifyEqual(testCase,getappdata(app.ScoreAppUIFigure,'TestExportRefreshCount'),1);
end
drawnow;
verifyNumElements(testCase,findall(exportFigure,'Type','quiver'),4);
verifyEqual(testCase,r.cellModel,beforeModel);
end

function refreshDuringExport(t,~,app)
if isempty(findall(groot,'Tag','ScoreSequenceChannelLabel')), return; end
stop(t);
setappdata(app.ScoreAppUIFigure,'TestExportRefreshCount',1);
score_display(app,'slow');
end

function deleteTimer(t)
if ~isvalid(t), return; end
stop(t); delete(t);
end

function figures = findExportFigures(owner)
figures = findall(groot,'Type','figure','Tag','ScoreExportFigure');
keep = arrayfun(@(f) isequal(getappdata(f,'ScoreExportOwner'),owner),figures);
figures = figures(keep);
end

function closeExportFigures(owner)
figures = findExportFigures(owner);
delete(figures);
end

function verifyLinks(testCase,gh,opts,frame,useModel)
for p = gh.comparisonPanels
    verifyTrue(testCase,isKey(gh.lineageHandles,p.tile));
    if ~isKey(gh.lineageHandles,p.tile), continue; end
    entry = gh.lineageHandles(p.tile);
    verifyNumElements(testCase,entry.geoms,1);
    if isempty(entry.geoms), continue; end
    geometry = entry.geoms;
    actualFrame = frame;
    if strcmp(opts.mode,'sequence'), actualFrame = opts.frames(p.frame); end
    if p.row == 1
        verifyEqual(testCase,geometry.daughterID,int32(2));
        verifyEqual(testCase,geometry.motherID,1);
        verifyEqual(testCase,[geometry.xd geometry.xm],[5.5 5.5]);
        expectedSource = 'first';
    else
        verifyEqual(testCase,geometry.daughterID,int32(20));
        verifyEqual(testCase,geometry.motherID,10);
        verifyEqual(testCase,[geometry.xd geometry.xm],[17.5 17.5]);
        expectedSource = 'second';
    end
    if useModel, expectedSource = sprintf('cell_model:%d',p.row); end
    verifyEqual(testCase,geometry.sourceKey,expectedSource);
    verifyEqual(testCase,[geometry.yd geometry.ym],[15.5 5.5]+actualFrame);
    if strcmp(opts.mode,'display')
        verifyTrue(testCase,isgraphics(entry.image));
        verifyTrue(testCase,any(entry.image.AlphaData(:) > 0));
    else
        verifyGreaterThan(testCase,double(entry.vectorGroups.Count),0);
    end
end
end

function [r,opts] = fixture(mode,useModel)
r = roi('lineage-comparison',[1 1 24 24]);
r.image = zeros(24,24,4,2,'uint16');
r.image(:,:,1,:) = 16000; r.image(:,:,2,:) = 32000;
for frame = 1:2
    r.image(4+frame:7+frame,4:7,3,frame) = 1;
    r.image(14+frame:17+frame,4:7,3,frame) = 2;
    r.image(4+frame:7+frame,16:19,4,frame) = 10;
    r.image(14+frame:17+frame,16:19,4,frame) = 20;
end
r.channelid = 1:4;
r.display.channel = {'raw','fluorescence','maskA','maskB'};
r.display.indexed = [false false true true];
r.display.rgb = [1 1 1;0 1 0;1 0 0;0 0 1];
r.display.selectedchannel = true(1,4);
r.display.contour = [false false true true];
r.display.lineage = struct('enabled',true,'channelName','maskA', ...
    'channelPix',3,'sourceKey','first','modelFamilyId',1, ...
    'showGenealogy',true,'showBudPairing',false);
ds = dataseries; ds.groupid = 'cell_information';
first = struct('channelName','maskA','channelPix',3,'show',true, ...
    'motherOf',containers.Map(int32(2),double(1)), ...
    'events',struct('childId',2,'motherId',1,'startFrame',1));
second = struct('channelName','maskB','channelPix',4,'show',false, ...
    'motherOf',containers.Map(int32(20),double(10)), ...
    'events',struct('childId',20,'motherId',10,'startFrame',1));
ds.userData = struct('lineageSources',struct('first',first,'second',second), ...
    'activeLineageSource','first','motherOf',first.motherOf, ...
    'motherOfSourceChannelName','maskA','lineageChannelName','maskA');
r.data = ds;
if useModel
    model = cellModel.create(r.id);
    model.families.family_id = uint32([1;2]);
    model.families.name = {'GT';'Prediction'};
    model.families.mask_provider = {'maskA';'maskB'};
    model.families.lineage_source = {'ground_truth';'prediction'};
    model.families.color_rgb = uint8([255 0 0;0 0 255]);
    model.instances.object_id = uint64((1:8)');
    model.instances.family_id = uint32([1;1;2;2;1;1;2;2]);
    model.instances.frame = uint32([1;1;1;1;2;2;2;2]);
    model.instances.mask_label = uint32([1;2;10;20;1;2;10;20]);
    model.instances.track_id = uint64([101;102;201;202;101;102;201;202]);
    model.instances.state_id = zeros(8,1,'uint16');
    model.relations.relation_id = uint64([1;2]);
    model.relations.family_id = uint32([1;2]);
    model.relations.parent_track_id = uint64([101;201]);
    model.relations.child_track_id = uint64([102;202]);
    model.relations.event_frame = uint32([1;1]);
    model.relations.type_id = uint8([1;1]);
    model.relations.confidence = single([1;1]);
    r.cellModel = cellModel.normalize(model); r.cellModelInfo.loaded = true;
    r.display.lineage.sourceKey = 'cell_model:1';
end
opts = score_collectDisplayOptions('mode',mode,'overlay',false, ...
    'frames',[1 2],'Nrow',1,'Ncol',1,'Nchannel',2,'hideStamp',true);
opts.channel = r.display.channel;
opts.levels = {[0 65535],[0 65535],{'-1','lines',0.5,true,1},{'-1','lines',0.5,true,1}};
opts.RGB = {[1 1 1],[0 1 0],[1 0 0],[0 0 1]};
opts.tileH = 120; opts.tileW = 120; opts.scale = [false false];
opts.ShowLineageOverlay = true; opts.ShowBudPairingOverlay = false;
if strcmp(mode,'display'), opts.LineageRenderMode = 'raster'; end
end

function deleteIfPresent(path)
if isfile(path), delete(path); end
end

function deleteApp(app)
if ~isvalid(app), return; end
imageFigure = app.ImageFigure;
if isgraphics(imageFigure)
    imageFigure.KeyPressFcn = []; imageFigure.WindowKeyPressFcn = [];
end
delete(app);
if isgraphics(imageFigure), delete(imageFigure); end
end
