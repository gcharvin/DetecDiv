function tests=testInferenceTableResize
tests=functiontests(localfunctions);
end

function testResume144To220PreservesAnnotationsAndMetadata(testCase)
ids=uint16(mod((1:144)',3));
labels=categorical(repmat("small",144,1),["small","large"], ...
    'Ordinal',true);
notes=repmat({''},144,1);notes{17}='reviewed manually';
t=table(ids,labels,notes,(1:144)',false(144,1), ...
    'VariableNames',{'id_training','labels_training','notes','id','reviewed'});
t.Properties.RowNames=cellstr("Frame"+(1:144)');
t.Properties.VariableUnits={'class','','','',''};
t.Properties.UserData=struct('reviewer','Abi','version',2);
ds=dataseries(t,t.Properties.VariableNames,'groupid','div_1');
ds.userData=struct('annotation_source','manual');
ds=cnn_lstm.resetInferenceOutputs(ds,["small","large"],true, ...
    ["undefined","small","large","unclassified"],220);
verifyEqual(testCase,height(ds.data),220);
verifyEqual(testCase,ds.data(1:144,{'id_training','labels_training','notes','reviewed'}), ...
    t(:,{'id_training','labels_training','notes','reviewed'}));
verifyEqual(testCase,ds.data.Properties.UserData,t.Properties.UserData);
verifyEqual(testCase,ds.data.Properties.VariableUnits{1},'class');
verifyEqual(testCase,ds.userData.annotation_source,'manual');
verifyClass(testCase,ds.data.id_training,'uint16');
verifyTrue(testCase,isordinal(ds.data.labels_training));
verifyEqual(testCase,categories(ds.data.labels_training),categories(labels));
verifyEqual(testCase,ds.data.id_training(145:end),zeros(76,1,'uint16'));
verifyTrue(testCase,all(isundefined(ds.data.labels_training(145:end))));
verifyFalse(testCase,any(ds.data.reviewed(145:end)));
verifyEqual(testCase,ds.data.id,zeros(220,1));
verifyEqual(testCase,ds.data.idCNN,zeros(220,1));
verifyEqual(testCase,ds.data.prob_small,zeros(220,1));
verifyEqual(testCase,ds.data.probCNN_large,zeros(220,1));
end

function testAnnotationOnlyTableAndMulticolumnValues(testCase)
t=table(ones(132,2,'single'),repmat("checked",132,1), ...
    'VariableNames',{'manual_measurement','annotation'});
ds=dataseries(t,t.Properties.VariableNames,'groupid','div_1');
ds=cnn_lstm.resetInferenceOutputs(ds,"cell",false,["undefined","cell"],220);
verifyEqual(testCase,ds.data.manual_measurement(1:132,:),t.manual_measurement);
verifySize(testCase,ds.data.manual_measurement,[220 2]);
verifyEqual(testCase,ds.data.annotation(1:132),t.annotation);
verifyTrue(testCase,all(ismissing(ds.data.annotation(133:end)) | ds.data.annotation(133:end)==""));
verifyFalse(testCase,ismember('idCNN',ds.data.Properties.VariableNames));
end

function testFreshEmptyTableAndIdempotentReset(testCase)
ds=dataseries();
ds=cnn_lstm.resetInferenceOutputs(ds,"cell",false,["undefined","cell"],4);
verifyEqual(testCase,height(ds.data),4);
ds.data.id(:)=1;
ds=cnn_lstm.resetInferenceOutputs(ds,"cell",false,["undefined","cell"],4);
verifyEqual(testCase,ds.data.id,zeros(4,1));
end

function testRefusesToDiscardTrailingAnnotations(testCase)
t=table(zeros(220,1),'VariableNames',{'id_training'});t.id_training(200)=2;
ds=dataseries(t,t.Properties.VariableNames,'groupid','div_1');
verifyError(testCase,@()cnn_lstm.resetInferenceOutputs(ds,"cell",false, ...
    ["undefined","cell"],144),'cnn_lstm:InferenceTableWouldTruncate');
verifyEqual(testCase,ds.data,t);
end

function testTableWithAllInferenceColumnsPrunedKeepsRowAlignment(testCase)
t=table(zeros(144,1),'VariableNames',{'id'});t=removevars(t,'id');
ds=dataseries();ds.data=t;
ds=cnn_lstm.resetInferenceOutputs(ds,"cell",false,["undefined","cell"],220);
verifyEqual(testCase,height(ds.data),220);
verifyEqual(testCase,ds.data.id,zeros(220,1));
end

function testExistingInferenceClassListDoesNotEraseManualCategories(testCase)
labels=categorical(["reviewed";"uncertain"],["reviewed","uncertain"],'Ordinal',true);
t=table(labels,'VariableNames',{'labels_training'});
ds=dataseries();ds.data=t;ds.userData=struct('classes',{{'cell','unclassified'}});
ds=cnn_lstm.resetInferenceOutputs(ds,"cell",false,["undefined","cell"],4);
verifyEqual(testCase,ds.data.labels_training(1:2),labels);
verifyEqual(testCase,categories(ds.data.labels_training),categories(labels));
verifyTrue(testCase,isordinal(ds.data.labels_training));
end

function testStringTrainingAnnotationsRemainUnchanged(testCase)
t=table(["manually reviewed";"uncertain"],'VariableNames',{'labels_training'});
ds=dataseries();ds.data=t;ds.userData=struct('classes',{{'cell','unclassified'}});
ds=cnn_lstm.resetInferenceOutputs(ds,"cell",false,["undefined","cell"],4);
verifyClass(testCase,ds.data.labels_training,'string');
verifyEqual(testCase,ds.data.labels_training(1:2),t.labels_training);
end
