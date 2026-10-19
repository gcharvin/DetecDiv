function tests = testScoreCellModelCache
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

function testExternalFamilyAndLineageReloadWithoutChangingDisplay(testCase)
[r,cleanup] = fixture(); %#ok<ASGLU>
r.display.lineage = struct('channelName','prediction','enabled',false, ...
    'showBudPairing',false,'showGenealogy',true);
before = r.display;
writeExternal(r,modelFixture(r.id,true));
[changed,checked] = score_refreshCellModelCache(r);
verifyTrue(testCase,changed);
verifyTrue(testCase,checked);
verifyEqual(testCase,r.cellModel.families.name,{'GT';'HOCT prediction'});
verifyTrue(testCase,r.display.lineage.enabled);
verifyEqual(testCase,r.display.lineage.modelFamilyId,2);
verifyEqual(testCase,r.display.selectedchannel,before.selectedchannel);
verifyEqual(testCase,r.display.objectDisplay,before.objectDisplay);
verifyEqual(testCase,r.cellModel.relations.family_id,uint32([1;2]));
end

function testUnchangedSidecarRetainsMemoryAndThrottlesChecks(testCase)
[r,cleanup] = fixture(); %#ok<ASGLU>
r.cellModel.provenance.source = 'in-memory editing';
[changed,checked] = score_refreshCellModelCache(r);
verifyFalse(testCase,changed);
verifyTrue(testCase,checked);
clock = r.cellModelInfo.scoreCheckClock;
for i = 1:20
    [changed,checked] = score_refreshCellModelCache(r);
    verifyFalse(testCase,changed);
    verifyFalse(testCase,checked);
    score_getCellModel(r);
end
verifyEqual(testCase,r.cellModelInfo.scoreCheckClock,clock);
verifyEqual(testCase,r.cellModel.provenance.source,'in-memory editing');
end

function testNextCheckFindsAnExternalWrite(testCase)
[r,cleanup] = fixture(); %#ok<ASGLU>
score_refreshCellModelCache(r);
writeExternal(r,modelFixture(r.id,true));
% Expire the polling interval without waiting during the test.
r.cellModelInfo.scoreCheckClock = uint64(1);
[changed,checked] = score_refreshCellModelCache(r);
verifyTrue(testCase,changed);
verifyTrue(testCase,checked);
verifyNumElements(testCase,r.cellModel.families.family_id,2);
end

function testFirstSidecarCanAppearAfterOpeningAnEmptyROI(testCase)
[r,cleanup] = fixture(); %#ok<ASGLU>
delete(cellModel.pathForROI(r));
r.cellModel = cellModel.create(r.id);
r.cellModelInfo = struct('loaded',true,'filename',cellModel.pathForROI(r),'datenum',NaN);
score_refreshCellModelCache(r);
writeExternal(r,modelFixture(r.id,true));
verifyTrue(testCase,score_refreshCellModelCache(r,[],true));
verifyNumElements(testCase,r.cellModel.families.family_id,2);
end

function testMissingOrUnreadableSidecarPreservesCachedModel(testCase)
[r,cleanup] = fixture(); %#ok<ASGLU>
before = r.cellModel;
filename = cellModel.pathForROI(r);
delete(filename);
verifyFalse(testCase,score_refreshCellModelCache(r,[],true));
verifyEqual(testCase,r.cellModel,before);
fid = fopen(filename,'w'); fprintf(fid,'incomplete external write'); fclose(fid);
verifyWarning(testCase,@() score_refreshCellModelCache(r,[],true), ...
    'score:CellModelRefresh');
verifyEqual(testCase,r.cellModel,before);
writeExternal(r,modelFixture(r.id,true));
verifyTrue(testCase,score_refreshCellModelCache(r,[],true));
end

function testUnsavedRoiEditsAreNotOverwritten(testCase)
[r,cleanup] = fixture(); %#ok<ASGLU>
r.cellModel.provenance.source = 'unsaved tracking edits';
before = r.cellModel;
writeExternal(r,modelFixture(r.id,true));
app = struct('ModifiedRoiIds',string(r.id));
[changed,checked] = score_refreshCellModelCache(r,app,true);
verifyFalse(testCase,changed);
verifyFalse(testCase,checked);
verifyEqual(testCase,r.cellModel,before);
% A dirty *other* ROI does not block this one.
app.ModifiedRoiIds = "another-roi";
verifyTrue(testCase,score_refreshCellModelCache(r,app,true));
end

function testSameTimestampWithDifferentSizeAlsoInvalidates(testCase)
[r,cleanup] = fixture(); %#ok<ASGLU>
score_refreshCellModelCache(r);
filename = cellModel.pathForROI(r);
file = java.io.File(filename);
stamp = file.lastModified();
model = modelFixture(r.id,true);
model.provenance.source = repmat('external metadata ',1,1000);
cellModel.writeH5(filename,model,'KeepBackup',false);
verifyTrue(testCase,file.setLastModified(stamp));
verifyTrue(testCase,score_refreshCellModelCache(r,[],true));
verifyNumElements(testCase,r.cellModel.families.family_id,2);
end

function testAnnotationPanelRefreshDiscoversNewFamily(testCase)
[r,cleanup] = fixture(); %#ok<ASGLU>
r.save([],false);
app = score(r);
cleanupApp = onCleanup(@() deleteApp(app)); %#ok<NASGU>
selectPrediction(app);
score_refreshObjectDisplayUI(app);
verifyFalse(testCase,any(strcmp(app.ObjectFamilyDropDown.Items,'HOCT prediction')));
writeExternal(r,modelFixture(r.id,true));
r.cellModelInfo.scoreCheckClock = uint64(1);
score_refreshObjectDisplayUI(app);
verifyTrue(testCase,any(strcmp(app.ObjectFamilyDropDown.Items,'HOCT prediction')));
verifyEqual(testCase,app.ObjectFamilyDropDown.Value,'HOCT prediction');
verifyEqual(testCase,app.CellModelStatusLabel.Text,'Cell model v1: 2 families');
end

function testFrameDisplayRefreshesPanelAndLineage(testCase)
[r,cleanup] = fixture(); %#ok<ASGLU>
r.save([],false);
app = score(r);
cleanupApp = onCleanup(@() deleteApp(app)); %#ok<NASGU>
selectPrediction(app);
score_refreshObjectDisplayUI(app);
app.LineageDisplayButtonGroup.SelectedObject = app.FullGenealogyRadioButton;
score_configureLineageDisplay(r,'prediction',3, ...
    score_getObjectDisplayConfig(r,'prediction'),false,true);
writeExternal(r,modelFixture(r.id,true));
r.cellModelInfo.scoreCheckClock = uint64(1);
score_display(app,'fast');
verifyEqual(testCase,app.ObjectFamilyDropDown.Value,'HOCT prediction');
verifyEqual(testCase,app.CellModelStatusLabel.Text,'Cell model v1: 2 families');
verifyTrue(testCase,r.display.lineage.enabled);
verifyEqual(testCase,r.display.lineage.modelFamilyId,2);
verifyEqual(testCase,double(app.graphicsHandles.lineageHandles.Count),2);
end

function [r,cleanup] = fixture()
folder = tempname;
mkdir(folder);
cleanup = onCleanup(@() rmdir(folder,'s'));
r = roi('cache-refresh',[1 1 24 24]);
r.path = folder;
r.image = zeros(24,24,3,2,'uint16');
r.image(:,:,1,:) = 16000;
r.image(3:7,4:8,2:3,:) = 1;
r.image(14:18,4:8,2:3,:) = 2;
r.channelid = 1:3;
r.display.channel = {'raw','gt','prediction'};
r.display.indexed = [false true true];
r.display.selectedchannel = true(1,3);
r.display.rgb = [1 1 1;1 0 0;0 0 1];
r.display.intensity = [1 1 1;0 0 0;0 0 0];
r.display.alpha = [1 0.5 0.5];
r.display.contour = [false true true];
r.display.width = ones(1,3);
r.display.displaylim = repmat([0;1],1,3);
score_setObjectDisplayConfig(r,'prediction',struct('lineageMode','genealogy'));
r.saveCellModel(modelFixture(r.id,false),'KeepBackup',false);
end

function model = modelFixture(id,includePrediction)
model = cellModel.create(id);
model.families.family_id = uint32([1;2]);
model.families.name = {'GT';'HOCT prediction'};
model.families.mask_provider = {'gt';'prediction'};
model.families.lineage_source = {'ground_truth';'hoct'};
model.families.color_rgb = uint8([255 0 0;0 0 255]);
for family = 1:(1 + includePrediction)
    for frame = 1:2
        mask = uint16([1 1 0;0 2 2]);
        model = cellModel.syncFrame(model,family,frame,mask,'TrackPolicy','preserve_or_label');
    end
    model = cellModel.setParent(model,family,1,2,1);
end
if ~includePrediction
    for field = reshape(fieldnames(model.families),1,[])
        model.families.(field{1}) = model.families.(field{1})(1,:);
    end
end
model = cellModel.normalize(model);
end

function writeExternal(r,model)
filename = cellModel.pathForROI(r);
file = java.io.File(filename);
before = file.lastModified();
cellModel.writeH5(filename,model,'KeepBackup',false);
% Guarantee a changed timestamp even on filesystems with coarse resolution.
file.setLastModified(max(file.lastModified(),before + 2000));
end

function selectPrediction(app)
data = app.UIAnnotationTable.Data;
row = find(strcmp(string(data(:,2)),"prediction"),1);
app.UIAnnotationTable.Selection = [row 2];
end

function deleteApp(app)
if ~isvalid(app), return; end
if ~isempty(app.ImageFigure) && isgraphics(app.ImageFigure), delete(app.ImageFigure); end
delete(app);
end
