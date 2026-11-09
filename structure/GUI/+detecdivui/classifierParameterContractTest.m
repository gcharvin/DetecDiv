function classifierParameterContractTest()
%CLASSIFIERPARAMETERCONTRACTTEST Preserve package resource/storage semantics.
folder=tempname; mkdir(folder); files=onCleanup(@()rmdir(folder,'s'));
c=classi(folder,'Contracts',1); c.category={'Pixel'};
packages={'cellposesam','trackastra','cellLatentModel','cellLatentTracker', ...
    'budMotherLinker','cnn','cnn_lstm','lstm_timeseries','deeplab_pixel_classification','sam31'};
for k=1:numel(packages)
    c.classifierPkg=packages{k}; c.trainingParam=struct(); c.executionParam=struct();
    for stage={'Training','Inference'}
        static=detecdivui.ClassifierParameters.describe(c,stage{1},false);
        links=detecdivui.ClassifierParameters.describe(c,stage{1},true,true);
        assert(isempty(intersect({static.records.key},{links.records.key})), ...
            'Static settings and resource bindings overlap for %s.',packages{k});
        if strcmp(stage{1},'Inference')
            spec=feval([packages{k} '.executionSpec'],c);
            if isfield(spec,'environmentKeys')
                assert(isempty(intersect({static.records.key},spec.environmentKeys)));
            end
        end
    end
end
c.classifierPkg='cnn'; c.trainingParam=cnn.utils.defaultTrainingParam();
view=detecdivui.ClassifierParameters.describe(c,'Training',false);
assert(nnz(~[view.records.advanced])>=6);
c.classifierPkg='cellLatentModel'; c.trainingParam=cellLatentModel.utils.defaultTrainingParam();
view=detecdivui.ClassifierParameters.describe(c,'Training',false);
record=view.records(strcmp({view.records.key},'architectureVersion'));
assert(strcmp(record.choiceLabels{1},'Composite causal model v1'));
choice=record.value; choice{end}='lineage_only_v1';
detecdivui.ClassifierParameters.apply(c,view,struct('architectureVersion',{choice}));
assert(iscell(c.trainingParam.architectureVersion{1}) && strcmp(c.trainingParam.architectureVersion{1}{end},'lineage_only_v1'));
c.classifierPkg='cellposesam'; c.executionParam=[];
view=detecdivui.ClassifierParameters.describe(c,'Inference',false);
detecdivui.ClassifierParameters.apply(c,view,struct('diameter',30));
assert(c.executionParam.diameter==30);
c.classifierPkg='trackastra'; c.executionParam=struct('instanceChannelName','@segment.masks');
view=detecdivui.ClassifierParameters.describe(c,'Inference',true,true);
record=view.records(strcmp({view.records.key},'instanceChannelName'));
assert(strcmp(record.value,'@segment.masks') && any(strcmp(record.choices,'@segment.masks')));
detecdivui.ClassifierParameters.apply(c,view,struct());
assert(strcmp(c.executionParam.instanceChannelName,'@segment.masks'));
% Normalize UI sentinel values through the same backend as training bindings.
binding=classifierBinding.newBinding('param','optionalInput','storage','executionParam','allowNone',true);
record=struct('key','optionalInput','label','Optional input','editable',true,'choices',{{'<none>','Phase'}},'binding',binding);
view.records=record; view.snapshot=detecdivui.ClassifierParameters.snapshot(c);
detecdivui.ClassifierParameters.apply(c,view,struct('optionalInput','<none>'));
assert(isempty(c.executionParam.optionalInput));
fprintf('Classifier parameter contracts passed for %d packages, symbolic bindings and sentinel normalization.\n',numel(packages));
end
