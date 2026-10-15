function app=openInputBindings(classif,afterApply)
%OPENINPUTBINDINGS Use Pipeline2's normal binding controls; do not submit a run.
if nargin<2,afterApply=[];end
spec=lstm_timeseries.executionSpec(classif);params=spec.defaults;
params.pkg='lstm_timeseries';params.modulePath=classif.path;params.moduleId=classif.strid;
params.classes=classif.classes;
node=struct('id',classif.strid,'name','Numeric LSTM inputs','type','classifier', ...
 'pkg','lstm_timeseries','func','lstm_timeseries.classify','params',params,'enabled',true);
pipe=pipelineConstruct(tempdir,'numeric_lstm_input_bindings',1);
pipe.nodes=pipelineNormalizeNodes(node,'persist');
app=pipeline2(pipe,'InputMode','classifier_rois','RoiObjects',classif.roi, ...
    'ExecutionTarget','local','Intent','train');
app.configureClassifierInputBindings(classif,afterApply);
end
