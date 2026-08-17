function scope = logTrainingScope(classif)
%CLASSIFIERBINDING.LOGTRAININGSCOPE Emit auditable training ownership/data.
scope=classifierBinding.trainingScopeSpec(classif);
fprintf('[TRAIN SCOPE] module=%s objective=%s\n',scope.module,scope.objective);
fprintf('[TRAIN SCOPE] changes=%s\n',joinOrNone(scope.trainedComponents));
fprintf('[TRAIN SCOPE] frozen=%s\n',joinOrNone(scope.frozenComponents));
bindings=classifierBinding.trainingSpec(classif);
for i=1:numel(bindings)
    value='';
    try value=valueText(classifierBinding.value(classif,bindings(i)));catch,end
    if isempty(value),value='<not configured>';end
    fprintf('[TRAIN DATA] quality=%s semantic=%s param=%s value=%s\n', ...
        upper(bindings(i).quality),bindings(i).semantic, ...
        bindings(i).param,value);
end
actual=resolvedOutput(classif,scope);
fprintf(['[TRAIN OUTPUT] quality=%s producer=%s semantic=%s configured=%s ' ...
    'canonical=%s\n'],upper(scope.outputQuality),scope.module, ...
    scope.outputSemantic,actual,scope.canonicalOutput);
fprintf('[TRAIN SPLIT] %s\n',scope.splitPolicy);
end

function output=resolvedOutput(classif,scope)
output=scope.canonicalOutput;
if isempty(scope.outputParameter),return;end
value='';
try
    execution=feval([scope.module '.executionSpec'],classif);
    value=valueText(execution.defaults.(scope.outputParameter));
catch
end
if isempty(value),return;end
if isempty(scope.outputTemplate),output=value;return;end
output=scope.outputTemplate;
output=strrep(output,['<' scope.outputParameter '>'],value);
output=strrep(output,'<outputName>',value);
output=strrep(output,'<outputFamilyName>',value);
end

function value=joinOrNone(values),if isempty(values),value='<none>';else,value=strjoin(values,', ');end,end
function value=valueText(value)
while iscell(value),if isempty(value),value='';return;end,value=value{end};end
if isnumeric(value)||islogical(value),value=mat2str(value);else,value=char(string(value));end
end
