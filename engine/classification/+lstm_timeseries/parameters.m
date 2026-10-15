function p = parameters(classif, overrides)
%PARAMETERS Normalize defaults and validate the reusable module contract.
p=lstm_timeseries.setparam();
if nargin>=1&&~isempty(classif)
    try,s=classif.trainingParam;catch,s=struct();end
    if isstruct(s),names=fieldnames(s);for k=1:numel(names),p.(names{k})=s.(names{k});end,end
end
% New classifiers keep data bindings separately from optimizer parameters.
% Read legacy trainingParam slots when no explicit binding set was saved.
try
    bindings=classif.dataset.inputBindings;
    if isstruct(bindings)&&~isempty(bindings)
        p.featureCount=numel(bindings);
        for k=1:numel(bindings)
            p.(sprintf('feature%d',k))=bindings(k).selector;
            p.(sprintf('featureColumn%d',k))=bindings(k).component;
        end
    end
catch
end
if nargin>=2&&isstruct(overrides)
    names=fieldnames(overrides);for k=1:numel(names),p.(names{k})=overrides.(names{k});end
end
for key={'outputMode','missingPolicy','executionEnvironment','classWeighting'}
    value=p.(key{1});if iscell(value),value=value{end};end
    p.(key{1})=char(string(value));
end
assert(ismember(p.outputMode,{'frame','window','video'}),'lstm_timeseries:Mode','Unknown output mode.');
assert(ismember(p.missingPolicy,{'error','training-median'}),'lstm_timeseries:MissingPolicy','Unknown missing-value policy.');
assert(ismember(p.executionEnvironment,{'auto','cpu','gpu','module_default'}),'lstm_timeseries:Device','Unknown execution environment.');
assert(ismember(p.classWeighting,{'none','inverse-frequency'}),'lstm_timeseries:ClassWeighting','Unknown class weighting policy.');
assert(isnumeric(p.l2Regularization)&&isscalar(p.l2Regularization)&&isfinite(p.l2Regularization)&&p.l2Regularization>=0, ...
    'lstm_timeseries:Parameter','l2Regularization must be finite and nonnegative.');
assert(isnumeric(p.validationPatience)&&isscalar(p.validationPatience)&&isfinite(p.validationPatience)&&p.validationPatience>=0&&p.validationPatience==fix(p.validationPatience), ...
    'lstm_timeseries:Parameter','validationPatience must be a nonnegative integer; 0 disables stopping.');
assert((islogical(p.returnBestValidation)||isnumeric(p.returnBestValidation))&&isscalar(p.returnBestValidation)&&ismember(p.returnBestValidation,[0 1]), ...
    'lstm_timeseries:Parameter','returnBestValidation must be true or false.');
p.returnBestValidation=logical(p.returnBestValidation);
for key={'featureCount','hiddenUnits','maxEpochs','miniBatchSize'}
    v=p.(key{1});assert(isnumeric(v)&&isscalar(v)&&isfinite(v)&&v>=1&&v==fix(v), ...
        'lstm_timeseries:Parameter','%s must be a positive integer.',key{1});
end
assert(p.featureCount<=128,'lstm_timeseries:Parameter','At most 128 input traces are supported.');
assert(isscalar(p.windowLength)&&isfinite(p.windowLength)&&p.windowLength>=0&&p.windowLength==fix(p.windowLength), ...
    'lstm_timeseries:Parameter','windowLength must be a nonnegative integer.');
assert(~strcmp(p.outputMode,'window')||p.windowLength>0,'lstm_timeseries:Parameter','Window mode requires windowLength > 0.');
assert(isscalar(p.dropout)&&isfinite(p.dropout)&&p.dropout>=0&&p.dropout<1,'lstm_timeseries:Parameter','dropout must be in [0,1).');
assert(isscalar(p.validationFraction)&&isfinite(p.validationFraction)&&p.validationFraction>=0&&p.validationFraction<1, ...
    'lstm_timeseries:Parameter','validationFraction must be in [0,1).');
assert(isscalar(p.initialLearnRate)&&isfinite(p.initialLearnRate)&&p.initialLearnRate>0,'lstm_timeseries:Parameter','Learning rate must be positive.');
assert(isscalar(p.seed)&&isfinite(p.seed)&&p.seed>=0&&p.seed==fix(p.seed),'lstm_timeseries:Parameter','seed must be a nonnegative integer.');
for k=1:p.featureCount
    key=sprintf('feature%d',k);col=sprintf('featureColumn%d',k);
    if ~isfield(p,key),p.(key)='';end
    if iscell(p.(key)),p.(key)=p.(key){end};end
    p.(key)=char(string(p.(key)));
    if ~isfield(p,col),p.(col)=1;end
    v=p.(col);assert(isnumeric(v)&&isscalar(v)&&isfinite(v)&&v>=1&&v==fix(v), ...
        'lstm_timeseries:FeatureColumn','%s must be a positive column index.',col);
end
end
