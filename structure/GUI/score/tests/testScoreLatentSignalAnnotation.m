function tests = testScoreLatentSignalAnnotation
%TESTSCORELATENTSIGNALANNOTATION Managed object-signal editor smoke tests.
tests=functiontests(localfunctions);
end

function setupOnce(~)
repoRoot=fileparts(fileparts(fileparts(fileparts(fileparts( ...
    mfilename('fullpath'))))));
addpath(repoRoot);
startup;
end

function testClassificationControlWritesObjectGtWithoutChangingMask(testCase)
folder=tempname; mkdir(folder);
cleanup=onCleanup(@()removeFolder(folder)); %#ok<NASGU>
c=classi(folder,'htb2_signal_ui',1);
r=fixtureRoi(folder);
c.roi=r;
def=cellLatentModel.signal.definition('HTB2 phase','classification', ...
    'Channels','ch2-HTB2','Family','cells','MaskProvider','tracked_cells', ...
    'Classes',{'low','high'});
cellLatentSignal.configure(c,def);
session=c.annotationSession(1);
session.startBlank('Save',false);

app=score(r,'pixelAnnotation');
appCleanup=onCleanup(@()deleteScore(app)); %#ok<NASGU>
app.setAnnotationSession(session);
verifyEqual(testCase,char(app.StartBlankGTButton.Visible),'on');
verifyEqual(testCase,char(app.CreateFromPredictionButton.Visible),'off');
verifyEqual(testCase,char(app.SelectedObjectIDEditField.Visible),'on');
verifyEqual(testCase,app.SelectedCellStateDropDownLabel.Text,'Signal class:');

maskIndex=r.findChannelID('tracked_cells','exact');
before=r.image(:,:,maskIndex,:);
app.SelectedObjectLabelCell=uint32(1);
app.SelectedObjectRoiId=string(r.id);
score_updateSelectedObjectFields(app);
verifyEqual(testCase,app.SelectedObjectIDEditField.Value,'11');
verifyEqual(testCase,app.SelectedCellStateDropDown.Items, ...
    {'<undefined>','low','high'});
app.SelectedCellStateDropDown.Value=2;
score_setSelectedSignalGroundTruth(app);
[tbl,~]=cellLatentModel.signal.readGroundTruth(r,def);
verifyEqual(testCase,string(tbl.Label(1)),"high");
verifyEqual(testCase,r.image(:,:,maskIndex,:),before, ...
    'Object-signal annotation must not mutate the tracking mask.');
end

function testRegressionControlUsesNumericObjectTarget(testCase)
folder=tempname; mkdir(folder);
cleanup=onCleanup(@()removeFolder(folder)); %#ok<NASGU>
c=classi(folder,'redox_signal_ui',1);
r=fixtureRoi(folder); c.roi=r;
def=cellLatentModel.signal.definition('redox','regression', ...
    'Channels','ch2-HTB2','Family','cells','MaskProvider','tracked_cells', ...
    'ValueRange',[0 2]);
cellLatentSignal.configure(c,def);
session=c.annotationSession(1); session.startBlank('Save',false);
app=score(r,'pixelAnnotation');
appCleanup=onCleanup(@()deleteScore(app)); %#ok<NASGU>
app.setAnnotationSession(session);
r.display.frame=2;
app.SelectedObjectLabelCell=uint32(2);
app.SelectedObjectRoiId=string(r.id);
score_updateSelectedObjectFields(app);
verifyEqual(testCase,char(app.MasklabelEditField.Visible),'on');
verifyEqual(testCase,app.MasklabelEditFieldLabel.Text,'Signal value:');
app.MasklabelEditField.Value=0.75;
score_setSelectedSignalGroundTruth(app);
tbl=cellLatentModel.signal.readGroundTruth(r,def);
verifyEqual(testCase,tbl.Value(2),0.75,'AbsTol',1e-12);
end

function testPaintHandlerGuardsSignalMaskBeforePainting(testCase)
source=fileread(fullfile(fileparts(fileparts(mfilename('fullpath'))), ...
    'score_paintOverlay.m'));
guard=strfind(source,'if score_isLatentSignalObjectSession(app)');
paint=strfind(source,'%% --- Peinture (left / middle / right');
verifyNumElements(testCase,guard,1);
verifyNumElements(testCase,paint,1);
verifyLessThan(testCase,guard,paint);
end

function testAdapterContractsAndMaskProviderConsistency(testCase)
folder=tempname; mkdir(folder);
cleanup=onCleanup(@()removeFolder(folder)); %#ok<NASGU>
c=classi(folder,'signal_contract',1);
r=fixtureRoi(folder); c.roi=r;
classification=cellLatentModel.signal.definition('HTB2 state','classification', ...
    'Channels','ch2-HTB2','Family','cells','MaskProvider','tracked_cells', ...
    'Classes',{'G1','S-G2-M'});
cellLatentSignal.configure(c,classification);
spec=cellLatentSignal.annotationSpec(c);
verifyEqual(testCase,spec.package,'cellLatentSignal');
verifyEqual(testCase,spec.components.kind,'object_classification');
verifyEqual(testCase,spec.components.groundTruth.maskProvider,'tracked_cells');

wrong=classification; wrong.mask_provider='another_mask';
verifyError(testCase,@()cellLatentSignal.configure(c,wrong), ...
    'cellLatentSignal:MaskProviderMismatch');

session=c.annotationSession(1);
session.startBlank('Save',false);
validation=annotationManager.validate(r,session.Spec,'RequireReviewed',false);
verifyTrue(testCase,validation.valid);
group=classification.ground_truth_group;
idx=find(arrayfun(@(x)strcmp(char(string(x.groupid)),group),r.data),1);
r.data(idx).data(end,:)=[];
validation=annotationManager.validate(r,session.Spec,'RequireReviewed',false);
verifyFalse(testCase,validation.valid);
verifyTrue(testCase,contains(validation.errors(1),'every object'));

segmentation=cellLatentModel.signal.definition('mitochondria','segmentation', ...
    'Channels','ch2-HTB2','Family','cells','MaskProvider','tracked_cells', ...
    'Classes',{'network','fragment'});
cellLatentSignal.configure(c,segmentation);
segSpec=cellLatentSignal.annotationSpec(c);
verifyEqual(testCase,segSpec.components.kind,'semantic_mask');
verifyEqual(testCase,segSpec.components.storage,'channel');
end

function r=fixtureRoi(folder)
r=roi('signal_roi',[1 1 6 5]); r.path=folder;
r.image=zeros(5,6,2,2,'uint16');
r.image(:,:,1,:)=uint16(100);
r.image(2:3,2:3,2,1)=uint16(1);
r.image(3:4,3:4,2,2)=uint16(2);
r.channelid=[1 2]; r.display.channel={'ch2-HTB2','tracked_cells'};
r.display.indexed=[false true]; r.display.intensity=[1 1 1;0 0 0];
r.display.rgb=[1 1 1;0 1 0]; r.display.selectedchannel=[true true];
r.display.alpha=[1 0.35]; r.display.contour=[false true]; r.display.width=[1 1];
r.display.displaylim=repmat([0;1],1,2);
model=cellModel.create(r.id);
model.families.family_id=uint32(1); model.families.name={'cells'};
model.families.mask_provider={'tracked_cells'}; model.families.lineage_source={'latent'};
model.families.color_rgb=uint8([1 2 3]);
model.instances.object_id=uint64([11;12]); model.instances.family_id=uint32([1;1]);
model.instances.frame=uint32([1;2]); model.instances.mask_label=uint32([1;2]);
model.instances.track_id=uint64([7;7]); model.instances.state_id=uint16([0;0]);
r.cellModel=model;
r.saveCellModel(model,'KeepBackup',false);
end

function deleteScore(app)
try, delete(app); catch, end
try, close all force; catch, end
end
function removeFolder(folder)
if exist(folder,'dir')==7, rmdir(folder,'s'); end
end
