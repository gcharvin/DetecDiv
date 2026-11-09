function tests=testNumericBindingReview
% Review/configuration only: these tests never format or train a network.
tests=functiontests(localfunctions);
end
function setupOnce(~)
root=fileparts(fileparts(fileparts(fileparts(fileparts(mfilename('fullpath'))))));
addpath(root);detecdiv_setup_path(root,'Verbose',false);
end

function testTrainingContractSeparatesBindingsFromStaticSettings(tc)
[c,cleanup]=fixture(); %#ok<ASGLU>
spec=lstm_timeseries.executionSpec(c,'train');
verifyEqual(tc,spec.defaults.hiddenUnits,12);
verifyEqual(tc,spec.defaults.maxEpochs,77);
verifyEqual(tc,spec.defaults.dropout,0.35);
verifyEqual(tc,spec.defaults.featureColumn2,2);
verifyTrue(tc,all(ismember({'hiddenUnits','maxEpochs','dropout','outputMode'},spec.staticKeys)));
verifyEmpty(tc,intersect(spec.staticKeys,spec.inputKeys));
verifyEqual(tc,{spec.contract.resources.in.param},{'feature1','feature2'});
verifyEqual(tc,spec.contract.binding.selectorKeys,{'feature1','feature2'});
verifyFalse(tc,any(ismember({'hiddenUnits','maxEpochs'},lstm_timeseries.executionSpec(c).staticKeys)));
node=struct('type','classifier','pkg','lstm_timeseries','params',spec.defaults);
node.params.operation='train';contract=pipelineNodeContract(node);
verifyTrue(tc,ismember('hiddenUnits',contract.parameters.static));
verifyFalse(tc,any(startsWith(string(contract.parameters.static),'feature')));
verifyEqual(tc,contract.binding.selectorKeys,{'feature1','feature2'});
end

function testDisplayChoicesNeverChangeModelBindingSummary(tc)
[c,cleanup]=fixture(); %#ok<ASGLU>
fig=dataseriesLSTMAnnotation(c,1,[],'Visible','off');finish=onCleanup(@()delete(fig)); %#ok<NASGU>
before=c.dataset.inputBindings;
summary=findall(fig,'Tag','NumericModelBindings');
verifyEqual(tc,char(summary.Editable),'off');
verifyEqual(tc,summary.Value,lstm_timeseries.inputBindingSummary(c));
heading=findall(fig,'Tag','NumericModelBindingsTitle');
verifyTrue(tc,contains(heading.Text,'2 inputs, all ROIs'));
check=findall(fig,'Tag','VisibleTrace2');verifyTrue(tc,startsWith(check.Text,'Show '));
check.Value=false;check.ValueChangedFcn(check,[]);drawnow;
verifyEqual(tc,summary.Value,lstm_timeseries.inputBindingSummary(c));
verifyEqual(tc,c.dataset.inputBindings,before);
choice=findall(fig,'Tag','RoiSelector');choice.Value='2';choice.ValueChangedFcn(choice,[]);
verifyEqual(tc,summary.Value,lstm_timeseries.inputBindingSummary(c));
verifyEqual(tc,c.dataset.inputBindings,before);
if strcmp(getenv('DETECDIV_UI_PREVIEW'),'1')
    exportapp(fig,fullfile(tempdir,'detecdiv_numeric_bindings_roi.png'));
end
end

function testRoiOpensExistingBindingEditorAndRefreshesSummary(tc)
[c,cleanup]=fixture(); %#ok<ASGLU>
fig=dataseriesLSTMAnnotation(c,1,[],'Visible','off');finish=onCleanup(@()delete(fig)); %#ok<NASGU>
button=findall(fig,'Tag','ConfigureNumericModelBindings');button.ButtonPushedFcn(button,[]);
editor=findall(groot,'Type','figure','Name',['Input bindings - ' c.strid]);
assertNumElements(tc,editor,1);finishEditor=onCleanup(@()delete(editor)); %#ok<NASGU>
editor.Visible='off';
remove=findall(editor,'Tag','RemoveInput_feature1');assertNumElements(tc,remove,1);
remove.ButtonPushedFcn(remove,[]);drawnow;
apply=findall(editor,'Type','uibutton','Text','Apply inputs');assertNumElements(tc,apply,1);
apply.ButtonPushedFcn(apply,[]);drawnow;
verifyNumElements(tc,c.dataset.inputBindings,1);
verifyEqual(tc,c.dataset.inputBindings.selector,'input / b');
verifyEqual(tc,c.dataset.inputBindings.component,2);
summary=findall(fig,'Tag','NumericModelBindings');
verifyEqual(tc,summary.Value,{'1. input / b (component 2)'});
heading=findall(fig,'Tag','NumericModelBindingsTitle');verifyTrue(tc,contains(heading.Text,'1 inputs, all ROIs'));
end

function testPipelineImportsTrainingSettingsAndKeepsModelBindingsReadOnly(tc)
[c,cleanup]=fixture(); %#ok<ASGLU>
app=classifierOpenTrainingPipeline(c,'ExecutionTarget','local');finish=onCleanup(@()delete(app)); %#ok<NASGU>
app.UIFigure.Visible='off';
heading=findall(app.UIFigure,'Tag','NumericModelBindingsHeading');
assertNumElements(tc,heading,1);verifyTrue(tc,contains(heading.Text,'2 model inputs'));
binding=findall(app.UIFigure,'Tag','NumericReadOnlyBinding_feature2');
verifyEqual(tc,char(binding.Editable),'off');verifyEqual(tc,binding.Value,{'input / b (component 2)'});
verifyEmpty(tc,findall(app.UIFigure,'Tag','NumericVariable_feature2'));
verifyEmpty(tc,findall(app.UIFigure,'Tag','NumericComponent_feature2'));
verifyEmpty(tc,findall(app.UIFigure,'Tag','AddNumericInput'));
verifyEmpty(tc,findall(app.UIFigure,'Tag','RemoveInput_feature1'));
button=findall(app.UIFigure,'Type','uibutton','Text','Training parameters...');assertNumElements(tc,button,1);
button.ButtonPushedFcn(button,[]);drawnow;
dialog=findall(groot,'Type','figure','Name',['Training parameters - ' c.strid]);assertNumElements(tc,dialog,1);
finishDialog=onCleanup(@()delete(dialog)); %#ok<NASGU>
dialog.Visible='off';
verifyEqual(tc,parameterControl(dialog,'hiddenUnits').Value,12);
verifyEqual(tc,parameterControl(dialog,'maxEpochs').Value,77);
verifyEqual(tc,parameterControl(dialog,'dropout').Value,0.35);
verifyEqual(tc,parameterControl(dialog,'outputMode').Value,'window');
verifyEqual(tc,parameterControl(dialog,'executionEnvironment').Value,'cpu');
for key={'featureCount','feature1','featureColumn2'}
    verifyEmpty(tc,parameterControl(dialog,key{1}));
end
if strcmp(getenv('DETECDIV_UI_PREVIEW'),'1')
    exportapp(dialog,fullfile(tempdir,'detecdiv_numeric_training_settings.png'));
    app.MainTabGroup.SelectedTab=app.BuildTab;drawnow;
    exportapp(app.UIFigure,fullfile(tempdir,'detecdiv_numeric_training_pipeline.png'));
end
end

function testClassifierTrainingTabShowsTheSameBindings(tc)
[c,cleanup]=fixture(); %#ok<ASGLU>
app=classifierGUI(c);finish=onCleanup(@()delete(app)); %#ok<NASGU>
app.ClassifierUIFigure.Visible='off';
app.SettrainingparametersTab.ButtonDownFcn(app.SettrainingparametersTab,[]);drawnow;
summary=findall(app.ClassifierUIFigure,'Tag','ClassifierModelInputBindings');
verifyEqual(tc,summary.Value,lstm_timeseries.inputBindingSummary(c));
scope=findall(app.ClassifierUIFigure,'Tag','ClassifierTrainingScope');assertNumElements(tc,scope,1);
verifyTrue(tc,any(contains(string(scope.Value),'MODEL INPUT BINDINGS (2')));
verifyTrue(tc,any(contains(string(scope.Value),'input / b (component 2)')));
verifyFalse(tc,any(startsWith(string(app.UITableParam.Data.Param),'feature')));
end

function testPrelaunchSummaryUsesEffectiveRunBindings(tc)
[c,cleanup]=fixture(); %#ok<ASGLU>
p=lstm_timeseries.executionSpec(c,'train').defaults;p.operation='train';
node=struct('id','numeric','type','classifier','pkg','lstm_timeseries','params',p,'enabled',true);
overrides=struct('id','numeric','params',struct('feature1','upstream / prob_small','featureColumn2',1));
lines=pipelineClassifierTrainingSummary(node,overrides,{'numeric'});
verifyTrue(tc,contains(lines{1},'2, all ROIs'));
verifyTrue(tc,any(strcmp(lines,'1. upstream / prob_small')));
verifyTrue(tc,any(strcmp(lines,'2. input / b')));
verifyEqual(tc,node.params.feature1,'input / a');
verifyEmpty(tc,pipelineClassifierTrainingSummary(node,overrides,{'other'}));
node.enabled=false;verifyEmpty(tc,pipelineClassifierTrainingSummary(node,overrides,{}));
node.enabled=true;node.params.operation='validate';
verifyEmpty(tc,pipelineClassifierTrainingSummary(node,struct(),{}));
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

function [c,cleanup]=fixture()
root=tempname;mkdir(root);cleanup=onCleanup(@()rmdir(root,'s'));
c=classi(root,'numeric_binding_review',1);lstm_timeseries.ensureClassMetadata(c);
c.classes={'budding','dead'};c.trainingParam=lstm_timeseries.setparam();
c.trainingParam.featureCount=2;c.trainingParam.feature1='input / a';
c.trainingParam.feature2='input / b';c.trainingParam.featureColumn2=2;
c.trainingParam.hiddenUnits=12;c.trainingParam.maxEpochs=77;c.trainingParam.dropout=0.35;
c.trainingParam.outputMode='window';c.trainingParam.windowLength=4;c.trainingParam.executionEnvironment='cpu';
c.channelName={};c.trainingset=1;c.dataset=struct('classes',{c.classes},'channels',{{}}, ...
    'split',struct('train',1,'val',[],'test',2));
lstm_timeseries.storeInputBindings(c,lstm_timeseries.parameters(c));
for k=1:2
    r=roi(sprintf('review%d',k),[]);r.path=c.path;r.parent=c;x=(1:8)'+k;
    input=dataseries(table((1:8)',x,[x 2*x],'VariableNames',{'frame','a','b'}));input.groupid='input';
    ids=[ones(4,1);2*ones(4,1)];gt=dataseries(table(categorical(ids,1:2,c.classes),ids,'VariableNames',{'labels_training','id_training'}));
    gt.groupid=c.strid;gt.class='classification';r.data=[input gt];c.roi(k)=r;
    session=c.annotationSession(k);session.markReviewed('Frames',1:8,'Save',false);
    r.save('data',false);
end
end
