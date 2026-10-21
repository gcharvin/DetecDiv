function tests=testScoreFissionCorrection
tests=functiontests(localfunctions);
end
function setupOnce(testCase)
detecdiv_setup_path;
detecdiv_plugins_addpath;
assumeFalse(testCase,isempty(which('hoctModel.annotationSpec')), ...
    'Managed HOCT review requires its registered MATLAB adapter.');
end
function testGuidedSelectionCommitUndoAndCancel(testCase)
folder=tempname;mkdir(folder);clean=onCleanup(@()rmdir(folder,'s')); %#ok<NASGU>
r=roi('fission_ui',[1 1 16 16]);r.path=folder;
r.image=zeros(16,16,2,4,'uint16');r.image(:,:,1,:)=100;
r.image(4:12,5:12,2,1:2)=1;
r.image(4:7,5:12,2,3:4)=2;r.image(9:12,5:12,2,3:4)=3;
r.channelid=[1 2];r.display.channel={'BF','gt_tracks'};
r.display.intensity=[1 1 1;0 0 0];r.display.rgb=ones(2,3);
r.display.selectedchannel=[true true];r.display.indexed=[false true];
r.display.alpha=[1 .35];r.display.contour=[false true];r.display.width=[1 1.5];
r.display.displaylim=repmat([0;1],1,2);r.display.frame=2;
m=cellModel.create(r.id);
m.families=struct('family_id',uint32(1),'name',{{'GT'}},'mask_provider',{{'gt_tracks'}}, ...
    'lineage_source',{{'human_review'}},'color_rgb',uint8([99 214 255]));
m.provenance.family_division_modes=struct('family_id',1,'mode','binary_fission');
m.instances.object_id=uint64((1:6)');m.instances.family_id=ones(6,1,'uint32');
m.instances.frame=uint32([1;2;3;4;3;4]);m.instances.mask_label=uint32([1;1;2;2;3;3]);
m.instances.track_id=uint64([10;10;10;10;30;30]);m.instances.state_id=zeros(6,1,'uint16');
r.save([],false);r.saveCellModel(m);
score_setObjectDisplayConfig(r,'gt_tracks',struct('mode','multicolor','criterion','Track', ...
    'objectFamily','GT','maskProvider','gt_tracks','lineageMode','genealogy'));
app=score(r,'pixelAnnotation');close=onCleanup(@()closeScore(app)); %#ok<NASGU>
c=classi(folder,'fission_review_fixture',1,'InitTraining',false);
c.classifierPkg='hoctModel';c.category={'Tracking'};
c.trainingParam=struct('groundTruthFamily','GT','trackChannelName','gt_tracks');
c.executionParam=struct('divisionMode','binary_fission','brightfieldChannelName','BF');
c.roi=r;
session=c.annotationSession(1);app.setAnnotationSession(session);
rows=app.UIAnnotationTable.Data;target=find(strcmp(rows(:,2),'gt_tracks'),1);
if isempty(target),target=find(strcmp(rows(:,2),'gt'),1);end
assert(~isempty(target));app.UIAnnotationTable.Selection=[target 1];
app.SelectedObjectLabelCell=1;app.SelectedObjectRoiId=string(r.id);
before=r.cellModel;pixels=r.image;
score_fissionCorrection(app,'start');
verifyEqual(testCase,r.display.frame,3);
verifyTrue(testCase,score_fissionCorrection(app,'active'));
score_fissionCorrection(app,'pick',2);
score_fissionCorrection(app,'pick',2); % repeated click is not a second child
verifyEqual(testCase,r.cellModel,before);
verifyTrue(testCase,score_fissionCorrection(app,'active'));
score_fissionCorrection(app,'pick',3);
verifyFalse(testCase,score_fissionCorrection(app,'active'));
verifyEqual(testCase,r.image,pixels);
verifyTrue(testCase,annotationManager.validateParentage(r.cellModel,1).valid);
verifyEqual(testCase,numel(r.cellModel.relations.relation_id),2);
verifyTrue(testCase,any(app.ModifiedRoiIds==string(r.id)));
summary=session.summary();trackReview=summary.coverage.components(strcmp({summary.coverage.components.id},'tracking'));
verifyEqual(testCase,trackReview.reviewed,1,'Propagated future IDs must not be marked human-reviewed.');
r.saveCellModel(r.cellModel); % saving alone does not invalidate undo
score_fissionCorrection(app,'undo');verifyEqual(testCase,r.cellModel,before);
r.display.frame=2;app.SelectedObjectLabelCell=1;
score_fissionCorrection(app,'start');score_fissionCorrection(app,'pick',2);
callback=app.ScoreAppUIFigure.KeyPressFcn;
callback(app.ScoreAppUIFigure,struct('Key','escape','Modifier',{{}}));
verifyFalse(testCase,score_fissionCorrection(app,'active'));
verifyEqual(testCase,r.cellModel,before);
end
function closeScore(app)
if ~isvalid(app),return;end
fig=app.ImageFigure;
if isgraphics(fig),fig.KeyPressFcn=[];fig.WindowKeyPressFcn=[];end
delete(app);if isgraphics(fig),delete(fig);end
end
