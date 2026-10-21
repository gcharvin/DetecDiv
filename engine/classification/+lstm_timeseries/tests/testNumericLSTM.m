function tests=testNumericLSTM
tests=functiontests(localfunctions);
end
function setupOnce(~)
addpath(fileparts(fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))))));detecdiv_setup_path;
end
function testFeaturesAlignAbsoluteFramesAndSelectMatrixColumn(testCase)
[c,cleanup]=fixture(); %#ok<ASGLU>
[X,schema]=lstm_timeseries.features(c,c.roi(1));
verifySize(testCase,X,[2 8]);verifyEqual(testCase,X(2,:),2*(1:8)+2);
verifyEqual(testCase,schema(2).column,2);
c.roi(1).data(1).groupid="input";
verifyEqual(testCase,lstm_timeseries.features(c,c.roi(1)),X);
c.roi(1).data(1).data.frame=(2:9)';
X=lstm_timeseries.features(c,c.roi(1));verifyTrue(testCase,all(isnan(X(:,1))));verifySize(testCase,X,[2 9]);
end
function testRejectGroundTruthAndAmbiguousFrames(testCase)
[c,cleanup]=fixture(); %#ok<ASGLU>
c.trainingParam.feature1=[c.strid ' / id_training'];
verifyError(testCase,@()lstm_timeseries.features(c,c.roi(1)),'lstm_timeseries:GroundTruthInput');
c.trainingParam.feature1='input / a';c.roi(1).data(1).data.frame(3)=2;
verifyError(testCase,@()lstm_timeseries.features(c,c.roi(1)),'lstm_timeseries:FrameAlignment');
end
function testScalarCellMetricsAreSelectableAndPreserveMissingFrames(testCase)
[c,cleanup]=fixture(); %#ok<ASGLU>
ds=c.roi(1).data(1);ds.data.a=num2cell((1:8)');ds.data.a{3}=[];
rows=classifierBinding.numericSeries(c.roi(1));
verifyTrue(testCase,any(strcmp({rows.name},'input / a')));
X=lstm_timeseries.features(c,c.roi(1));
verifyEqual(testCase,X(1,[1 2 4:8]),[1 2 4:8]);verifyTrue(testCase,isnan(X(1,3)));
verifyEmpty(testCase,ds.data.a{3}); % never mutate source storage
ds.data.a{4}=[1 2];rows=classifierBinding.numericSeries(c.roi(1));
verifyFalse(testCase,any(strcmp({rows.name},'input / a')));
verifyError(testCase,@()lstm_timeseries.features(c,c.roi(1)),'lstm_timeseries:NonNumericFeature');
end
function testColdNumericRoiRetainsFrameCountAndReviewedTrainingScope(testCase)
[c,cleanup]=fixture(); %#ok<ASGLU>
r=c.roi(1);r.save('Data',false);r.clear();
verifyEqual(testCase,annotationManager.frameCount(r),8);
r.clear();[selection,hasFrames]=annotationManager.reviewedFramesForClassifier(c,1);
verifyTrue(testCase,hasFrames);verifyEqual(testCase,selection.roi1,1:8);
end
function testAnnotationModesAndClearReview(testCase)
[c,cleanup]=fixture(); %#ok<ASGLU>
c.trainingParam.outputMode='window';c.trainingParam.windowLength=4;
f=lstm_timeseries.assignLabel(c,1,'dead',6,'Save',false);verifyEqual(testCase,f,5:8);
verifyEqual(testCase,c.roi(1).data(2).data.id_training(5:8),2*ones(4,1));
c.trainingParam.outputMode='video';
f=lstm_timeseries.assignLabel(c,1,'budding',6,'Save',false);verifyEqual(testCase,f,1:8);
f=lstm_timeseries.assignLabel(c,1,'undefined',6,'Save',false);
verifyEqual(testCase,c.roi(1).data(2).data.id_training,zeros(8,1));
session=c.annotationSession(1);[entry,~]=annotationManager.entryForSpec(c.roi(1),session.Spec);
verifyFalse(testCase,any(entry.review(1).frames));
end
function testWindowsDoNotJoinGapsOrTrainOnPartialUnits(testCase)
[c,cleanup]=fixture(); %#ok<ASGLU>
p=lstm_timeseries.parameters(c);p.outputMode='window';p.windowLength=4;
w=lstm_timeseries.sequences(c,c.roi(1),8,[1:3 5:8],p);verifyEqual(testCase,w,{5:8});
p.outputMode='frame';w=lstm_timeseries.sequences(c,c.roi(1),8,[1:3 5:8],p);verifyEqual(testCase,w,{1:3,5:8});
p.outputMode='video';verifyEmpty(testCase,lstm_timeseries.sequences(c,c.roi(1),8,1:7,p));
end
function testTrainOnlyNormalizationAndMissingPolicy(testCase)
s=lstm_timeseries.normalizer([1 3 NaN;2 2 2]);
verifyEqual(testCase,s.median,[2;2]);verifyEqual(testCase,s.mean,[2;2]);verifyEqual(testCase,s.scale(2),1);
verifyError(testCase,@()lstm_timeseries.transform([NaN;2],s,'error'),'lstm_timeseries:MissingValues');
verifyEqual(testCase,lstm_timeseries.transform([NaN;2],s,'training-median'),single([0;0]));
end
function testTrainingOnlyBalancedClassWeights(testCase)
[w,n]=lstm_timeseries.classWeights(["budding" "budding" "budding" "arrested" "dead" "dead"], ...
    {'budding','arrested','dead'},'inverse-frequency');
verifyEqual(testCase,n,[3 1 2]);verifyEqual(testCase,w,[2/3 2 1],'AbsTol',1e-12);
verifyEqual(testCase,lstm_timeseries.classWeights(["dead" "budding"],{'budding','dead'},'none'),[1 1]);
verifyError(testCase,@()lstm_timeseries.classWeights("budding",{'budding','dead'},'inverse-frequency'),'lstm_timeseries:MissingTrainingClass');
end
function testRegularizedTrainingReturnsBestValidationCheckpoint(testCase)
[c,cleanup]=fixture(); %#ok<ASGLU>
c.trainingParam.outputMode='window';c.trainingParam.windowLength=4;c.trainingParam.maxEpochs=8;
c.trainingParam.hiddenUnits=4;c.trainingParam.dropout=0.4;c.trainingParam.l2Regularization=0.01;
c.trainingParam.validationPatience=2;c.trainingParam.returnBestValidation=true;c.trainingParam.classWeighting='inverse-frequency';
c.formatDataForTraining();lstm_timeseries.train(c,struct());
s=load(fullfile(c.path,[c.strid '.mat']));
verifyEqual(testCase,s.model.trainingClassCounts,[2 2]);verifyEqual(testCase,s.model.classWeights,[1 1]);
verifyEqual(testCase,s.model.checkpointPolicy,'best-validation-loss');
valid=find(isfinite(s.info.ValidationLoss));[~,j]=min(s.info.ValidationLoss(valid));
verifyEqual(testCase,s.info.OutputNetworkIteration,valid(j));
% The returned native network retains the training-only loss weights.
verifyEqual(testCase,s.classifier.Layers(end).ClassWeights(:)',[1 1]);
end
function testWithoutValidationReturnsFinalIteration(testCase)
[c,cleanup]=fixture(); %#ok<ASGLU>
c.dataset.split.val=[];c.trainingParam.outputMode='window';c.trainingParam.windowLength=4;
c.trainingParam.maxEpochs=2;c.trainingParam.returnBestValidation=true;c.trainingParam.validationPatience=1;
c.formatDataForTraining();lstm_timeseries.train(c,struct());
s=load(fullfile(c.path,[c.strid '.mat']));verifyEqual(testCase,s.model.checkpointPolicy,'last-iteration');
verifyEqual(testCase,s.info.OutputNetworkIteration,numel(s.info.TrainingLoss));
end
function testUncomputedPredictionFramesAreMissing(testCase)
[c,cleanup]=fixture(); %#ok<ASGLU>
ds=c.roi(1).data(1);ds.class='classification';ds.data.id=ones(8,1);ds.data.id(4)=0;
ds.data.prob_small=0.5*ones(8,1);c.trainingParam.feature1='input / prob_small';
X=lstm_timeseries.features(c,c.roi(1));verifyTrue(testCase,isnan(X(1,4)));verifyEqual(testCase,X(1,3),0.5);
end
function testFormatAndTrainFrameWithoutImages(testCase)
exerciseTraining(testCase,'frame');
end
function testFormatAndTrainWindowWithoutImages(testCase)
exerciseTraining(testCase,'window');
end
function testFormatAndTrainVideoWithoutImages(testCase)
exerciseTraining(testCase,'video');
end
function exerciseTraining(testCase,mode)
[c,cleanup]=fixture(); %#ok<ASGLU>
c.trainingParam.outputMode=mode;c.trainingParam.windowLength=4;
if strcmp(mode,'video')
    for k=1:4
        value=1+mod(k,2);t=c.roi(k).data(2).data;
        t.id_training(:)=value;t.labels_training(:)=categorical(c.classes(value),c.classes,c.classes);c.roi(k).data(2).data=t;
    end
end
out=c.formatDataForTraining();d=load(out.artifacts.dataset);d=d.dataset;
verifyEqual(testCase,out.metrics.outputCount,numel(d.samples));
verifyEqual(testCase,out.metrics.outputUnit,'sequences');
verifyTrue(testCase,isempty(intersect(d.trainRoiIndices,d.validationRoiIndices)));
verifyFalse(testCase,any([d.samples.roiIndex]==4));
out=lstm_timeseries.train(c,struct());verifyTrue(testCase,isfile(out.artifacts.model));
[~,model]=lstm_timeseries.loadModel(c);
verifyLessThan(testCase,max(model.normalization.mean),50);
old=c.roi(4).data(2).data;
result=lstm_timeseries.classify(c.roi(4),c,struct('exec',struct('gpu',0)));
pred=result.patch.roi.dataseries.upsert{1}.dataseries.data;
verifyEqual(testCase,pred.id_training,old.id_training);
verifyEqual(testCase,pred.labels_training,old.labels_training);
verifyEqual(testCase,sum(pred{:,{'prob_budding','prob_dead'}},2),ones(8,1),'AbsTol',1e-5);
verifyEmpty(testCase,c.roi(4).image);
if ~strcmp(mode,'frame')
    for a=1:4:8,verifyNumElements(testCase,unique(pred.id(a:a+3)),1);end
end
% Exercise the classi dispatcher, persistence patch, and image-free guard.
c.classifyData(c.roi(4),'Ctx',struct('io',struct('saveMode','defer')));
verifyNotEmpty(testCase,c.roi(4).data(2).data.id);
verifyEqual(testCase,c.roi(4).data(2).data.id_training,old.id_training);
c.stats('Rois',4,'Force','Silent');
expected=8;if strcmp(mode,'window'),expected=2;elseif strcmp(mode,'video'),expected=1;end
verifyEqual(testCase,c.score.N,expected);
verifyEqual(testCase,sum(c.score.confusion,'all'),expected);
if strcmp(mode,'frame')
    app=classifierOpenValidationPipeline(c,'Rois',4,'ExecutionTarget','local');
    closeApp=onCleanup(@()delete(app)); %#ok<NASGU>
    verifyTrue(testCase,isvalid(app.UIFigure));
    buttons=findall(app.UIFigure,'Type','uibutton');
    button=buttons(strcmp({buttons.Text},'Execution parameters...'));verifyNumElements(testCase,button,1);
    callback=button.ButtonPushedFcn;callback(button,[]);drawnow;
    dialogs=findall(0,'Type','figure');dialog=[];
    for i=1:numel(dialogs)
        if isstruct(dialogs(i).UserData)&&isfield(dialogs(i).UserData,'bodyPanel'),dialog=dialogs(i);break;end
    end
    verifyNotEmpty(testCase,dialog);closeDialog=onCleanup(@()delete(dialog)); %#ok<NASGU>
    verifyEmpty(testCase,parameterControl(dialog,'featureCount'));
    verifyEmpty(testCase,parameterControl(dialog,'featureColumn2'));
end
end

function testStatisticsUseReviewedOutputUnitsAndExport(testCase)
[c,cleanup]=fixture(); %#ok<ASGLU>
c.trainingParam.outputMode='window';c.trainingParam.windowLength=4;
ds=c.roi(4).data(2);ds.data.labels=categorical(ones(8,1),1:2,c.classes);c.roi(4).data(2)=ds;
[s,fig]=lstm_timeseries.statistics(c,'Rois',4,'Confusion','Classes','Silent','Export',fullfile(c.path,'test_validation'));
closeFig=onCleanup(@()delete(fig)); %#ok<NASGU>
verifyEqual(testCase,s.N,2);verifyEqual(testCase,s.accuracy,0.5);
verifyEqual(testCase,s.confusion,[1 0;1 0]);verifyEqual(testCase,s.classes(2).support,1);
verifyEqual(testCase,s.classes(2).recall,0);verifyEqual(testCase,s.classes(2).fscore,0);
verifyTrue(testCase,isfile(fullfile(c.path,'test_validation_statistics.png')));
verifyEqual(testCase,height(readtable(fullfile(c.path,'test_validation_predictions.csv'))),2);
session=c.annotationSession(4);session.markUnreviewed('Frames',8,'Save',false);
s=lstm_timeseries.statistics(c,'Rois',4,'Silent');verifyEqual(testCase,s.N,1);
c.trainingParam.outputMode='frame';s=lstm_timeseries.statistics(c,'Rois',4,'Silent');verifyEqual(testCase,s.N,7);
session.markReviewed('Frames',8,'Save',false);
c.trainingParam.outputMode='video';ds=c.roi(4).data(2);ds.data.labels_training(:)=categorical({'dead'},c.classes);
c.roi(4).data(2)=ds;s=lstm_timeseries.statistics(c,'Rois',4,'Silent');verifyEqual(testCase,s.N,1);verifyEqual(testCase,s.accuracy,0);
end

function testStatisticsRequirePredictionsAndReviewedTestUnits(testCase)
[c,cleanup]=fixture(); %#ok<ASGLU>
verifyError(testCase,@()lstm_timeseries.statistics(c,'Rois',4),'lstm_timeseries:MissingPredictions');
ds=c.roi(4).data(2);ds.data.labels=ds.data.labels_training;c.roi(4).data(2)=ds;
session=c.annotationSession(4);session.markUnreviewed('Frames',1:8,'Save',false);
verifyError(testCase,@()lstm_timeseries.statistics(c,'Rois',4),'lstm_timeseries:NoEvaluationSamples');
end

function testClassifierGUIStatisticsUseFilteredRoiIdentities(testCase)
[c,cleanup]=fixture(); %#ok<ASGLU>
ds=c.roi(4).data(2);ds.data.labels=ds.data.labels_training;c.roi(4).data(2)=ds;
app=classifierGUI(c);closeApp=onCleanup(@()delete(app)); %#ok<NASGU>
closePlots=onCleanup(@()close(findall(0,'Type','figure','Name','Numeric LSTM validation statistics'))); %#ok<NASGU>
cb=app.SettrainingandvalidationsetROIsTab.ButtonDownFcn;cb(app.SettrainingandvalidationsetROIsTab,[]);
rows=app.UITableData.Data;row=find(cellfun(@(v)isequal(v,4),rows(:,3)),1);
app.UITableData.Data=rows(row,:);
cb=app.DisplayclassifierstatisticsButton.ButtonPushedFcn;cb(app.DisplayclassifierstatisticsButton,[]);
verifyEqual(testCase,c.score.roiIndices,4);verifyEqual(testCase,c.score.N,8);
end
function control=parameterControl(fig,key)
control=[];objects=findall(fig);
for i=1:numel(objects)
    if ~isprop(objects(i),'ValueChangedFcn')||~isa(objects(i).ValueChangedFcn,'function_handle'),continue;end
    info=functions(objects(i).ValueChangedFcn);
    if ~isfield(info,'workspace'),continue;end
    for j=1:numel(info.workspace)
        w=info.workspace{j};
        if isstruct(w)&&isfield(w,'key')&&strcmp(w.key,key),control=objects(i);return;end
    end
end
end
function testBindingsAndDynamicPipelineContract(testCase)
[c,cleanup]=fixture(); %#ok<ASGLU>
c.trainingParam.featureCount=5;
b=classifierBinding.trainingSpec(c);verifyNumElements(testCase,b,6);
cat=classifierBinding.catalog(c);choices=classifierBinding.choices(b(1),cat,'');
verifyTrue(testCase,ismember('input / a',choices.values));
verifyFalse(testCase,any(contains(string(choices.values),'id_training')));
node=struct('type','classifier','pkg','lstm_timeseries','params',struct('featureCount',5));
contract=pipelineNodeContract(node);verifyNumElements(testCase,contract.resources.in,5);
verifyEqual(testCase,contract.requirements.roi.channelsMin,0);verifyTrue(testCase,contract.requirements.roi.dataSeries);
verifyFalse(testCase,any(ismember({'featureCount','featureColumn5'},contract.parameters.static)));
verifyTrue(testCase,ismember('executionEnvironment',contract.parameters.static));
node.contract=pipelineNodeContract(struct('type','classifier','pkg','lstm_timeseries','params',struct('featureCount',2)));
contract=pipelineNodeContract(node);verifyNumElements(testCase,contract.resources.in,5);
end
function testImageLengthRemainsAuthoritative(testCase)
[c,cleanup]=fixture(); %#ok<ASGLU>
c.roi(1).image=ones(2,2,1,8,'uint16');
long=dataseries(table(ones(100,1),'VariableNames',{'objects'}));long.groupid='long';
c.roi(1).data(end+1)=long;
verifyEqual(testCase,annotationManager.frameCount(c.roi(1)),8);
X=lstm_timeseries.features(c,c.roi(1));verifySize(testCase,X,[2 8]);
end
function testPipelineResolvesUpstreamNumericTrace(testCase)
source=struct('id','division','type','classifier','pkg','cnn_lstm','func','cnn_lstm.classify', ...
    'params',struct('pkg','cnn_lstm','channels',{{'BF'}},'outputName','div_prediction'));
target=struct('id','state','type','classifier','pkg','lstm_timeseries','func','lstm_timeseries.classify', ...
    'params',struct('pkg','lstm_timeseries','featureCount',1, ...
        'feature1','@resource:classification:division / prob_small','outputName','state_prediction'));
pipe=struct('nodes',[source target],'edges',struct('from','division','to','state'), 'branches',struct([]));
[resolved,report]=pipelineResolveBindings(pipe,struct('roiList',1,'channels',{{'BF'}},'dataSeries',1),struct('allowGui',false));
verifyEqual(testCase,resolved.nodes(2).params.feature1,'div_prediction / prob_small');
verifyTrue(testCase,any(strcmp({report.applied.param},'feature1')));
end
function testConflictingWindowLabelsFail(testCase)
[c,cleanup]=fixture(); %#ok<ASGLU>
c.trainingParam.outputMode='window';c.trainingParam.windowLength=8;
verifyError(testCase,@()c.formatDataForTraining(),'lstm_timeseries:ConflictingWindowGT');
end
function testNativeModelBundleExcludesTrainingDataByDefault(testCase)
[c,cleanup]=fixture(); %#ok<ASGLU>
classiObj=c;save(fullfile(c.path,[c.strid '_classification.mat']),'classiObj');
classifier=struct('transportSentinel',1);model=struct('normalization',struct('mean',1,'scale',2));
save(fullfile(c.path,[c.strid '.mat']),'classifier','model');
mkdir(fullfile(c.path,'trainingdataset'));dataset=struct('sentinel',2);
save(fullfile(c.path,'trainingdataset','lstm_timeseries_dataset.mat'),'dataset');
node=struct('id','numeric','type','classifier','pkg','lstm_timeseries','func','lstm_timeseries.classify', ...
    'params',struct('pkg','lstm_timeseries','modulePath',c.path,'moduleId',c.strid,'outputName',c.strid));
pipe=struct('name','numeric_transport','nodes',node,'edges',struct([]),'branches',struct([]));
bundle=fullfile(fileparts(c.path),'bundle');
pipelineExport(pipe,bundle,'includePlugins',false,'includeTrainingData',false);
files=dir(fullfile(bundle,'**',[c.strid '.mat']));verifyNumElements(testCase,files,1);
copy=load(fullfile(files(1).folder,files(1).name));verifyEqual(testCase,copy.model,model);
verifyEmpty(testCase,dir(fullfile(bundle,'**','lstm_timeseries_dataset.mat')));
end
function testNumericAnnotationUI(testCase)
[c,cleanup]=fixture(); %#ok<ASGLU>
c.trainingParam.outputMode='window';c.trainingParam.windowLength=4;
fig=dataseriesLSTMAnnotation(c,1,[],'Visible','off');finish=onCleanup(@()delete(fig)); %#ok<NASGU>
axes=findall(fig,'Type','axes');verifyTrue(testCase,all(arrayfun(@(a)a.XLim(2)>=8,axes)));
handles=fig.UserData;handles.Frame.Value=6;cb=handles.Frame.ValueChangedFcn;cb(handles.Frame,[]);
handles.Label.Value='dead';cb=handles.AssignButton.ButtonPushedFcn;cb(handles.AssignButton,[]);
verifyEqual(testCase,c.roi(1).data(2).data.id_training(5:8),2*ones(4,1));
end
function testAnnotationNavigationRespectsBoundsAndCompleteUnits(testCase)
[c,cleanup]=fixture(); %#ok<ASGLU>
c.bounds.Type='Auto';c.bounds.Values=[2 8];
c.trainingParam.outputMode='window';c.trainingParam.windowLength=3;r=c.roi(1);
verifyEqual(testCase,lstm_timeseries.adjacentAnnotationFrame(c,r,3,1,8),5);
verifyEqual(testCase,lstm_timeseries.adjacentAnnotationFrame(c,r,5,1,8),5);
verifyEqual(testCase,lstm_timeseries.adjacentAnnotationFrame(c,r,5,-1,8),2);
verifyEqual(testCase,lstm_timeseries.adjacentAnnotationFrame(c,r,2,-1,8),2);
verifyEqual(testCase,lstm_timeseries.adjacentAnnotationFrame(c,r,8,-1,8),5);
verifyEqual(testCase,lstm_timeseries.adjacentAnnotationFrame(c,r,1,1,8),2);
c.trainingParam.outputMode='frame';verifyEqual(testCase,lstm_timeseries.adjacentAnnotationFrame(c,r,3,1,8),4);
c.trainingParam.outputMode='video';verifyEqual(testCase,lstm_timeseries.adjacentAnnotationFrame(c,r,6,1,8),2);
c.trainingParam.outputMode='window';c.trainingParam.windowLength=10;
verifyEqual(testCase,lstm_timeseries.adjacentAnnotationFrame(c,r,3,1,8),3);
end
function testNumericAnnotationHotkeysShadingAndTraceVisibility(testCase)
[c,cleanup]=fixture(); %#ok<ASGLU>
c.trainingParam.outputMode='window';c.trainingParam.windowLength=4;
fig=dataseriesLSTMAnnotation(c,1,[],'Visible','off');finish=onCleanup(@()delete(fig)); %#ok<NASGU>
key=fig.WindowKeyPressFcn;key(fig,struct('Key','rightarrow','Modifier',{{}}));
verifyEqual(testCase,fig.UserData.Frame.Value,5);
bands=findall(fig,'Tag','CurrentAnnotationInterval');verifyNumElements(testCase,bands,3);
for k=1:numel(bands),verifyEqual(testCase,bands(k).XData(:)',[4.5 8.5 8.5 4.5]);end
[keys,~]=detecdiv_prefs_get_shortcuts();
key(fig,struct('Key',keys{1},'Modifier',{{'control'}}));
verifyEqual(testCase,c.roi(1).data(2).data.id_training(5:8),2*ones(4,1));
key(fig,struct('Key',keys{1},'Modifier',{{}}));
verifyEqual(testCase,c.roi(1).data(2).data.id_training(1:8),ones(8,1));
checkbox=findall(fig,'Tag','VisibleTrace1');checkbox.Value=false;
cb=checkbox.ValueChangedFcn;cb(checkbox,[]);drawnow;
visibleAxes=findall(fig,'Type','axes','Visible','on');verifyNumElements(testCase,visibleAxes,2);
key(fig,struct('Key','leftarrow','Modifier',{{}}));verifyEqual(testCase,fig.UserData.Frame.Value,1);
key(fig,struct('Key',keys{2},'Modifier',{{}}));
verifyEqual(testCase,c.roi(1).data(2).data.id_training(1:4),2*ones(4,1));
checkbox=findall(fig,'Tag','VisibleTrace1');verifyFalse(testCase,checkbox.Value);
sourceData=c.roi(1).data(1).data;
roiChoice=findall(fig,'Tag','RoiSelector');roiChoice.Value='2';cb=roiChoice.ValueChangedFcn;cb(roiChoice,[]);
checkbox=findall(fig,'Tag','VisibleTrace1');verifyFalse(testCase,checkbox.Value);
verifyEqual(testCase,c.roi(1).data(1).data,sourceData);
button=findall(fig,'Tag','HideAllTraces');cb=button.ButtonPushedFcn;cb(button,[]);
verifyNumElements(testCase,findall(fig,'Type','axes','Visible','on'),1);
button=findall(fig,'Tag','ShowAllTraces');cb=button.ButtonPushedFcn;cb(button,[]);
verifyNumElements(testCase,findall(fig,'Type','axes','Visible','on'),3);
ax=findall(fig,'Tag','NumericStateLabels');ax.YLim=[-2 5];drawnow;
band=findall(ax,'Tag','CurrentAnnotationInterval');verifyEqual(testCase,band.YData(:)',[-2 -2 5 5]);
end
function testSixScoreClassKeysAssignWholeWindows(testCase)
[c,cleanup]=fixture(); %#ok<ASGLU>
c.classes={'budding','arrested','dead','state4','state5','state6'};
c.trainingParam.outputMode='window';c.trainingParam.windowLength=4;
t=c.roi(1).data(2).data;t.id_training(:)=1;
t.labels_training=categorical(repmat("budding",8,1),c.classes,c.classes);c.roi(1).data(2).data=t;
fig=dataseriesLSTMAnnotation(c,1,[],'Visible','off');finish=onCleanup(@()delete(fig)); %#ok<NASGU>
[keys,~]=detecdiv_prefs_get_shortcuts();key=fig.WindowKeyPressFcn;
for index=1:6
    key(fig,struct('Key',keys{index},'Modifier',{{}}));
    t=c.roi(1).data(2).data;
    verifyEqual(testCase,t.id_training(1:4),index*ones(4,1));
    verifyEqual(testCase,string(t.labels_training(1:4)),repmat(string(c.classes{index}),4,1));
    verifyEqual(testCase,t.id_training(5:8),ones(4,1));
end
end
function testClassifierGUIDynamicFeatureBindings(testCase)
[c,cleanup]=fixture(); %#ok<ASGLU>
% Deferred Pipeline2 inventories reopen ROI data from the classifier's
% persisted snapshot, just as they do for imported production ROI.
for k=1:numel(c.roi),c.roi(k).save('data',false);end
app=classifierGUI(c);finish=onCleanup(@()delete(app)); %#ok<NASGU>
cb=app.SettrainingparametersTab.ButtonDownFcn;cb(app.SettrainingparametersTab,[]);drawnow;
t=app.UITableParam.Data;verifyFalse(testCase,any(startsWith(string(t.Param),'feature')));
verifyTrue(testCase,any(contains(string(app.TypeDropDown.Items),'lstm_timeseries')));
buttons=findall(app.ClassifierUIFigure,'Type','uibutton');
verifyTrue(testCase,any(strcmp({buttons.Text},'Configure inputs in Pipeline2...')));
editor=lstm_timeseries.openInputBindings(c);closeEditor=onCleanup(@()delete(editor)); %#ok<NASGU>
% Pipeline2 discovers the ROI schema only when a selector is opened. The
% initial controls retain saved components until that inventory is known.
component=findall(editor.UIFigure,'Tag','NumericComponent_feature2');
verifyNotEmpty(testCase,component);verifyEqual(testCase,component(1).Value,2);
cb=component(1).DropDownOpeningFcn;cb(component(1),[]);drawnow;
verifyEqual(testCase,component(1).ItemsData,1:2);
verifyFalse(testCase,contains(string(editor.PipelineandRuncheckreportLabel.Text),'Missing inputs'));
variable=findall(editor.UIFigure,'Tag','NumericVariable_feature2');variable=variable(1);
variable.Value='a';cb=variable.ValueChangedFcn;cb(variable,[]);drawnow;
verifyEmpty(testCase,findall(editor.UIFigure,'Tag','NumericComponent_feature1'));
verifyEmpty(testCase,findall(editor.UIFigure,'Tag','NumericComponent_feature2'));
variable=findall(editor.UIFigure,'Tag','NumericVariable_feature2');variable=variable(1);
variable.Value='b';cb=variable.ValueChangedFcn;cb(variable,[]);drawnow;
component=findall(editor.UIFigure,'Tag','NumericComponent_feature2');component=component(1);
component.Value=2;cb=component.ValueChangedFcn;cb(component,[]);drawnow;
remove=findall(editor.UIFigure,'Tag','RemoveInput_feature1');
assertNotEmpty(testCase,remove);cb=remove(1).ButtonPushedFcn;cb(remove(1),[]);drawnow;
component=findall(editor.UIFigure,'Tag','NumericComponent_feature1');verifyNotEmpty(testCase,component);
cb=editor.NewRunButton.ButtonPushedFcn;cb(editor.NewRunButton,[]);drawnow;
verifyEqual(testCase,numel(c.dataset.inputBindings),1);
verifyEqual(testCase,c.dataset.inputBindings.selector,'input / b');
verifyEqual(testCase,c.dataset.inputBindings.component,2);
verifyFalse(testCase,isfield(c.trainingParam,'featureCount'));
X=lstm_timeseries.features(c,c.roi(1));verifySize(testCase,X,[1 8]);
verifyEqual(testCase,X,2*((1:8)+1));
end
function testSeparateBindingsPreserveFeaturesLabelsAndOptimizer(testCase)
[c,cleanup]=fixture(); %#ok<ASGLU>
before=lstm_timeseries.features(c,c.roi(1));labels=c.roi(1).data(2).data;
p=lstm_timeseries.parameters(c);lstm_timeseries.storeInputBindings(c,p);
verifyEqual(testCase,lstm_timeseries.features(c,c.roi(1)),before);
verifyEqual(testCase,c.roi(1).data(2).data,labels);
verifyEqual(testCase,c.trainingParam.hiddenUnits,4);
verifyFalse(testCase,any(startsWith(string(fieldnames(c.trainingParam)),'feature')));
verifyNumElements(testCase,lstm_timeseries.inputBindingSummary(c),2);
end
function [c,cleanup]=fixture()
root=tempname;mkdir(root);cleanup=onCleanup(@()rmdir(root,'s'));
c=classi(root,'numeric_fixture',1);
if ~isfolder(c.path),mkdir(c.path);end
lstm_timeseries.ensureClassMetadata(c);c.classes={'budding','dead'};c.colormap=shallowColormap(2);
c.trainingParam=lstm_timeseries.setparam();c.trainingParam.featureCount=2;
c.trainingParam.feature1='input / a';c.trainingParam.feature2='input / b';c.trainingParam.featureColumn2=2;
c.trainingParam.hiddenUnits=4;c.trainingParam.maxEpochs=1;c.trainingParam.miniBatchSize=2;
c.trainingParam.validationFraction=0;c.trainingParam.executionEnvironment='cpu';
c.channelName={};c.dataset=struct('classes',{c.classes},'channels',{{}}, ...
    'split',struct('train',[1 2],'val',3,'test',4));c.trainingset=[1 2];
for k=1:4
    r=roi(sprintf('N%d',k),[]);r.path=c.path;r.parent=c;x=(1:8)'+k;
    if k>=3,x=x*1000;end
    input=dataseries(table((1:8)',x,[x 2*x],'VariableNames',{'frame','a','b'}));input.groupid='input';
    ids=[ones(4,1);2*ones(4,1)];gt=dataseries(table(categorical(ids,1:2,c.classes),ids,'VariableNames',{'labels_training','id_training'}));
    gt.groupid=c.strid;gt.class='classification';r.data=[input gt];c.roi(k)=r;
end
for k=1:4,session=c.annotationSession(k);session.markReviewed('Frames',1:8,'Save',false);end
end
