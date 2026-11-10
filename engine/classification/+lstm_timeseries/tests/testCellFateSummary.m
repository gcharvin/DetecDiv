function tests=testCellFateSummary
tests=functiontests(localfunctions);
end
function setupOnce(~)
addpath(fileparts(fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))))));detecdiv_setup_path;
end
function testIsolatedArrestCannotInventRecovery(testCase)
r=summarize(["budding","arrested","budding","budding","arrested","budding","budding"]);
verifyEqual(testCase,r.population,'adapted');verifyFalse(testCase,r.terminalRecovery);verifyEqual(testCase,r.ignoredShortArrestEpisodes,2);
% A real, reviewed short episode remains present in GT, which is not filtered.
gt=summarize(["budding","arrested","budding","budding"],1);
verifyEqual(testCase,gt.population,'transient_arrest');
end
function testRecoveryRequiresConfirmedArrestAndTerminalBudding(testCase)
r=summarize(["budding","arrested","arrested","budding","budding"]);
verifyEqual(testCase,r.population,'transient_arrest');verifyTrue(testCase,r.terminalRecovery);
r=summarize(["budding","arrested","arrested","budding"]);
verifyEqual(testCase,r.population,'unresolved');verifyEqual(testCase,r.reason,'Terminal recovery not confirmed');
end
function testBuddingExcursionBeforeDeathIsNotTerminalRecovery(testCase)
r=summarize(["arrested","arrested","budding","budding","dead"]);
verifyEqual(testCase,r.population,'dead');verifyFalse(testCase,r.terminalRecovery);
end
function testTerminalArrestAndContradictoryDeathStayExplicit(testCase)
r=summarize(["budding","budding","arrested","arrested"]);verifyEqual(testCase,r.population,'persistent_arrest');
r=summarize(["budding","budding","arrested"]);verifyEqual(testCase,r.population,'unresolved');
r=summarize(["dead","budding","budding"]);verifyEqual(testCase,r.population,'unresolved');
end
function testMissingStatesAndFrameGapsDoNotJoinEpisodes(testCase)
r=summarize(["arrested","undefined","arrested","budding","budding"]);verifyEqual(testCase,r.population,'unresolved');
r=lstm_timeseries.cellFateSequence(["arrested","arrested","budding","budding"],[1 15 22 29],[7 21 28 35],2);
verifyEqual(testCase,r.population,'unresolved');verifyEqual(testCase,r.reason,'Gap between windows');
verifyError(testCase,@()summarize("budding",0),'lstm_timeseries:FatePolicy');
end
function testBackendSeparatesPolicyFromReviewedGTAndModel(testCase)
[c,cleanup]=fixture(); %#ok<ASGLU>
before=c.trainingParam;labels=c.roi(1).data(1).data;
s=lstm_timeseries.cellFateSummary(c,'Rois',[1 2 3 4]);
verifyEqual(testCase,s.N,4);verifyEqual(testCase,s.Npaired,4);
verifyEqual(testCase,s.rois.prediction,{'adapted';'transient_arrest';'persistent_arrest';'dead'});
verifyEqual(testCase,s.rois.truth,{'transient_arrest';'transient_arrest';'persistent_arrest';'dead'});
verifyEqual(testCase,s.confusion,[0 0 0 0;1 1 0 0;0 0 1 0;0 0 0 1]);
verifyEqual(testCase,c.trainingParam,before);verifyEqual(testCase,c.roi(1).data(1).data,labels);
verifyEqual(testCase,s.confirmationFrames,14);verifyEqual(testCase,s.rois.lastFrame,42*ones(4,1));
end
function testPredictionsWithoutReviewedGTAreStillSummarized(testCase)
[c,cleanup]=fixture(); %#ok<ASGLU>
session=c.annotationSession(1);session.markUnreviewed('Frames',1:42,'Save',false);
s=lstm_timeseries.cellFateSummary(c,'Rois',1);
verifyEqual(testCase,s.rois.prediction,{'adapted'});verifyEqual(testCase,s.rois.truth,{'unresolved'});
verifyEqual(testCase,s.Npaired,0);verifyTrue(testCase,isnan(s.accuracy));verifyEqual(testCase,s.confusion,zeros(4));
end
function testIncompletePredictionAndPartialTerminalUnitNeedReview(testCase)
[c,cleanup]=fixture(); %#ok<ASGLU>
c.roi(1).data(1).data.labels(8:14)=categorical(missing,c.classes);
s=lstm_timeseries.cellFateSummary(c,'Rois',1);verifyEqual(testCase,s.rois.prediction,{'unresolved'});
% Extending the configured bounds leaves an incomplete last seven-frame unit.
t=c.roi(2).data(1).data;t(43,:)=t(42,:);t.frame(43)=43;c.roi(2).data(1).data=t;c.bounds.Values=[1 43];
s=lstm_timeseries.cellFateSummary(c,'Rois',2);verifyEqual(testCase,s.rois.predictionNote,{'Incomplete terminal window'});
end
function testClassOrderUsesNamesAndIndependentOutputGroup(testCase)
[c,cleanup]=fixture(); %#ok<ASGLU>
c.classes={'dead','budding','arrested'};c.executionParam.outputName='custom_prediction';
copy=c.roi(4).data(1);p=dataseries(copy.data);p.groupid='custom_prediction';c.roi(4).data(end+1)=p;
s=lstm_timeseries.cellFateSummary(c,'Rois',4);verifyEqual(testCase,s.rois.prediction,{'dead'});verifyEqual(testCase,s.rois.truth,{'dead'});
end
function testStalePredictionWindowRejected(testCase)
[c,cleanup]=fixture(); %#ok<ASGLU>
c.roi(1).data(1).userData=struct('outputMode','window','windowLength',14);
verifyError(testCase,@()lstm_timeseries.cellFateSummary(c,'Rois',1),'lstm_timeseries:StalePredictions');
end
function testStatisticsExportIncludesFatesWithoutChangingWindowScore(testCase)
[c,cleanup]=fixture(); %#ok<ASGLU>
prefix=fullfile(c.path,'fates');[score,fig]=lstm_timeseries.statistics(c,'Rois',[1 2 3 4],'Silent','Export',prefix);
closePlot=onCleanup(@()delete(fig)); %#ok<NASGU>
verifyEqual(testCase,score.N,24);verifyEqual(testCase,score.cellFate.N,4);verifyTrue(testCase,isfile([prefix '_fate_rois.csv']));
verifyTrue(testCase,isfile([prefix '_fate_summary.mat']));
end
function testClassifierGUIUsesSelectedTestRoiIdentitiesAndNativeSummary(testCase)
[c,cleanup]=fixture(); %#ok<ASGLU>
app=classifierGUI(c);closeApp=onCleanup(@()delete(app)); %#ok<NASGU>
closePlots=onCleanup(@()delete(findall(groot,'Tag','ClassifierCellFateStatistics'))); %#ok<NASGU>
cb=app.SettrainingandvalidationsetROIsTab.ButtonDownFcn;cb(app.SettrainingandvalidationsetROIsTab,[]);
rows=app.UITableData.Data;row=find(cellfun(@(v)isequal(v,2),rows(:,3)),1);app.UITableData.Data=rows(row,:);
menu=findall(app.ClassifierUIFigure,'Tag','ClassifierCellFateSummaryMenu');verifyNumElements(testCase,menu,1);
cb=menu.MenuSelectedFcn;cb(menu,[]);drawnow;
fig=findall(groot,'Tag','ClassifierCellFateStatistics');verifyNumElements(testCase,fig,1);
verifyEqual(testCase,fig.UserData.roiIndices,2);verifyEqual(testCase,fig.UserData.rois.prediction,{'transient_arrest'});
verifyNotEmpty(testCase,findall(fig,'Tag','CellFateRoiTable'));
end
function result=summarize(states,minimum)
if nargin<2,minimum=2;end
first=1:7:7*numel(states);result=lstm_timeseries.cellFateSequence(states,first,first+6,minimum);
end
function [c,cleanup]=fixture()
root=tempname;mkdir(root);cleanup=onCleanup(@()rmdir(root,'s'));
c=classi(root,'fate_fixture',1);if ~isfolder(c.path),mkdir(c.path);end;lstm_timeseries.ensureClassMetadata(c);
c.classes={'budding','arrested','dead'};c.colormap=shallowColormap(3);
c.trainingParam=lstm_timeseries.setparam();c.trainingParam.outputMode='window';c.trainingParam.windowLength=7;
c.bounds.Type='Auto';c.bounds.Values=[1 42];c.dataset=struct('classes',{c.classes},'split',struct('train',[],'val',[],'test',1:4));
states={ ["budding","arrested","budding","budding","budding","budding"], ...
    ["budding","arrested","arrested","budding","budding","budding"], ...
    ["budding","budding","arrested","arrested","arrested","arrested"], ...
    ["arrested","arrested","budding","budding","dead","dead"]};
for k=1:4
 r=roi(sprintf('F%d',k),[]);r.path=c.path;r.parent=c;labels=categorical(repelem(states{k},7)',c.classes);
 ds=dataseries(table((1:42)',labels,labels,'VariableNames',{'frame','labels','labels_training'}));ds.groupid=c.strid;ds.class='classification';r.data=ds;c.roi(k)=r;
 session=c.annotationSession(k);session.markReviewed('Frames',1:42,'Save',false);
end
end
