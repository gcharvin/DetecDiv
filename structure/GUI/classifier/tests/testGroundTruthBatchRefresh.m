function tests = testGroundTruthBatchRefresh
tests = functiontests(localfunctions);
end

function setupOnce(~)
detecdiv_setup_path;
end

function testVisibleTableRefreshesAfterParameterInvalidation(testCase)
folder = tempname; mkdir(folder);
testCase.addTeardown(@()rmdir(folder,'s'));
shim = fullfile(folder,'shim'); mkdir(shim);
fid = fopen(fullfile(shim,'uiconfirm.m'),'w');
fprintf(fid,['function answer=uiconfirm(varargin)\n' ...
    'answer=''Confirm reviewed + validate'';\nend\n']);
fclose(fid);
c = classi(folder,'batch_refresh',1);
c.classifierPkg='cnn_lstm'; c.category={'LSTM'};
c.classes={'alpha','beta'}; c.channelName='raw';
c.description={'cnn_lstm','','cnn_lstm'};
c.trainingParam=cnn_lstm.utils.defaultTrainingParam();
for k=1:2
    r=roi(sprintf('R%d',k),[1 1 2 2]); r.path=c.path;
    r.image=ones(2,2,1,4,'uint16'); r.display.channel={'raw'};
    ds=dataseries; ds.groupid=c.strid; ds.class='classification';
    labels={'alpha';'beta';'alpha';'beta'}; ids=[1;2;1;2];
    if k==2, labels{2}=''; ids(2)=0; end
    ds.data=table(categorical(labels,c.classes),ids, ...
        'VariableNames',{'labels_training','id_training'});
    r.data=ds; c.roi(k)=r;
end
previousResults=findall(groot,'Type','figure','-regexp','Name','^GT validation:');
app=classifierGUI(c);
testCase.addTeardown(@()closeFixture(app,previousResults));
callback=app.SettrainingandvalidationsetROIsTab.ButtonDownFcn;
callback(app.SettrainingandvalidationsetROIsTab,[]);
verifyNotEmpty(testCase,app.UITableData.Data);
addpath(shim,'-begin'); clear uiconfirm;
testCase.addTeardown(@()removeShim(shim));
% Changing parameters invalidates the table flag without clearing its rows.
callback=app.TypeDropDown.ValueChangedFcn;
callback(app.TypeDropDown,[]);
menu=findall(app.ClassifierMenu,'Tag','GroundTruthValidationMenu');
action=findall(menu,'-depth',1,'Text','All ROIs...');
callback=action.MenuSelectedFcn;
callback(action,[]);
column=find(strcmp(app.UITableData.ColumnName,'Annotation status'),1);
verifyEqual(testCase,app.UITableData.Data{1,column},'Ready');
verifyEqual(testCase,app.UITableData.Data{2,column},'Invalid');
verifyEqual(testCase,char(menu.Enable),'on');
verifyFalse(testCase,app.Data.groundTruthValidationRunning);
verifyEqual(testCase,app.Data.groundTruthValidationReport.ready,1);
% A second invocation must be possible after completion.
callback(action,[]);
verifyEqual(testCase,app.Data.groundTruthValidationReport.ready,1);
verifyFalse(testCase,app.Data.groundTruthValidationRunning);
recovery=findall(menu,'Text','Recover annotation bounds + validate');
action=findall(recovery,'Text','All ROIs...');
callback=action.MenuSelectedFcn;
callback(action,[]);
verifyNotEmpty(testCase,app.Data.groundTruthValidationReport.boundsRecovery);
verifyEqual(testCase,trainingBounds.resolve(c,1),[1 4]);
verifyEqual(testCase,char(menu.Enable),'on');
end

function removeShim(folder)
rmpath(folder); clear uiconfirm;
end

function closeFixture(app,previousResults)
if isvalid(app),delete(app);end
results=findall(groot,'Type','figure','-regexp','Name','^GT validation:');
delete(results(~ismember(results,previousResults)));
end
