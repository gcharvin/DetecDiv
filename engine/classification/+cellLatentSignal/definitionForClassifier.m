function definition = definitionForClassifier(classif)
%CELLLATENTSIGNAL.DEFINITIONFORCLASSIFIER Resolve the persisted head contract.
definition=[];
for container={'trainingParam','executionParam'}
    try, value=classif.(container{1}); catch, value=[]; end
    if isstruct(value)&&isfield(value,'customSignalDefinition')&& ...
            isstruct(value.customSignalDefinition)
        definition=value.customSignalDefinition;
        break;
    end
end
if isempty(definition)
    error('cellLatentSignal:MissingDefinition', ...
        'Configure the classifier with cellLatentSignal.configure first.');
end
% Upgrade definitions created before mask_provider became explicit.
if ~isfield(definition,'mask_provider'), definition.mask_provider=''; end
cellLatentModel.signal.annotationSpec(definition);
end
