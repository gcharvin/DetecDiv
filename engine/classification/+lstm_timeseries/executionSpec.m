function spec = executionSpec(classif, intent)
if nargin<1,classif=[];end
p=lstm_timeseries.parameters(classif);
if nargin<2
    intent='';
    for key={'operation','intent'}
        if isfield(p,key{1})&&~isempty(p.(key{1})),intent=p.(key{1});break;end
    end
end
isTraining=any(strcmpi(string(intent),{'train','training','fit'}));
keys=arrayfun(@(k)sprintf('feature%d',k),1:p.featureCount,'UniformOutput',false);
cols=arrayfun(@(k)sprintf('featureColumn%d',k),1:p.featureCount,'UniformOutput',false);
defaults=struct('featureCount',p.featureCount,'outputName','pred_lstm_state','executionEnvironment','module_default');
staticKeys={'executionEnvironment'};
metadata=lstm_timeseries.trainingParameterSpec(classif);
if isTraining
    % Optimizer/format settings are static controls; feature selectors and
    % their components remain resource bindings in both execution intents.
    staticKeys={metadata.param};
    for k=1:numel(staticKeys),defaults.(staticKeys{k})=p.(staticKeys{k});end
end
try,if ~isempty(classif.strid),defaults.outputName=classif.strid;end,catch,end
for k=1:p.featureCount,defaults.(keys{k})=p.(keys{k});defaults.(cols{k})=p.(cols{k});end
try
    e=classif.executionParam;
    if ~isTraining
        for key={'outputName','executionEnvironment'},if isfield(e,key{1}),defaults.(key{1})=e.(key{1});end,end
    end
catch
end
resource=@(t,r,s,par,port,required,transfer)struct('type',t,'role',r,'symbol',s, ...
    'param',par,'port',port,'nameParam',par,'required',required,'transfer',transfer);
inputs=repmat(resource('dataSeriesVariable','numeric_trace','','','dataSeries',true,''),1,p.featureCount);
for k=1:p.featureCount,inputs(k).symbol=keys{k};inputs(k).param=keys{k};inputs(k).nameParam=keys{k};end
port=@(n,t)struct('name',n,'type',t,'required',true,'source','edge');
contract=struct('in',[port('roiList','roiList') port('dataSeries','dataSeriesSet')], ...
    'out',[port('roiList','roiList') port('dataSeries','dataSeriesSet')], ...
    'requirements',struct('roi',struct('required',true,'channelsMin',0,'masks',false,'dataSeries',true)), ...
    'capabilities',struct('preservesRoiList',true,'roiDataSeries',true,'outputsDataSeries',true), ...
    'binding',struct('scope','roi','outputScope','roi','mode','dataSeries','selectorKeys',{keys},'resolveAt','run','exactCount',[]), ...
    'selectors',struct('channelParam','','channelsParam','','outputNameParam','outputName'), ...
    'parameters',struct('static',{staticKeys}), ...
    'resources',struct('in',inputs,'out',resource('dataSeries','classification','state', ...
        'outputName','dataSeries',false,'roiDataSeries')));
spec=struct('category','LSTM','requiresRuntimeClassifier',false,'requiresRoiImages',false, ...
    'summary','Numeric state classification (LSTM or window TCN) from selected ROI dataseries, without image input.', ...
    'staticKeys',{staticKeys},'outputKeys',{{'outputName'}}, ...
    'inputKeys',{{'featureCount',keys{:},cols{:}}}, ...
    'defaultImportKeys',{{'featureCount',keys{:},cols{:},staticKeys{:}}}, ...
    'defaults',defaults,'contract',contract,'choices',struct('executionEnvironment',{{'module_default','cpu','gpu'}}), ...
    'labels',struct('featureCount','Number of input traces','outputName','[PRED] State output name', ...
        'executionEnvironment','Execution environment'), ...
    'outputProvenance',struct('quality','pred','producer','lstm_timeseries','semantic','temporal_state','template','<outputName>'));
for k=1:numel(metadata)
    spec.labels.(metadata(k).param)=metadata(k).label;
    spec.tips.(metadata(k).param)=metadata(k).tip;
end
% These choices are also needed when a training node is reconstructed from
% its pipeline parameters rather than from a live classifier handle.
spec.choices.outputMode={'frame','window','video'};
spec.choices.missingPolicy={'error','training-median'};
spec.choices.classWeighting={'none','inverse-frequency'};
spec.choices.networkArchitecture={'lstm','tcn'};
spec.choices.sequenceScope={'window','trajectory'};
if isTraining,spec.choices.executionEnvironment={'auto','cpu','gpu','module_default'};end
end
