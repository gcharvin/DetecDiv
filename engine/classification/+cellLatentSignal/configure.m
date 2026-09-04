function classif = configure(classif, definition)
%CELLLATENTSIGNAL.CONFIGURE Bind a custom latent signal head to a classifier.
cellLatentModel.signal.annotationSpec(definition);
if ~isfield(definition,'mask_provider'), definition.mask_provider=''; end
resolvedProvider='';
if ~isempty(definition.family)
    try
        roiObj=classif.roi(1);
        [model,~]=roiObj.loadCellModel('MigrateLegacy',true);
        [familyIndex,~]=cellModel.familyIndex(model,definition.family);
        if ~isempty(familyIndex)
            resolvedProvider=char(string(model.families.mask_provider{familyIndex}));
        end
    catch
    end
end
if isempty(definition.mask_provider)
    definition.mask_provider=resolvedProvider;
elseif ~isempty(resolvedProvider) && ...
        ~strcmp(char(string(definition.mask_provider)),resolvedProvider)
    error('cellLatentSignal:MaskProviderMismatch', ...
        'Family "%s" uses mask provider "%s", not "%s".', ...
        char(string(definition.family)),resolvedProvider, ...
        char(string(definition.mask_provider)));
end
if isempty(definition.mask_provider)
    error('cellLatentSignal:MaskProviderRequired', ...
        'Set MaskProvider explicitly or attach a ROI whose target family can be resolved.');
end
classif.classifierPkg='cellLatentSignal';
classif.category={'Tracking'};
classif.classes=definition.classes;
if ~isstruct(classif.trainingParam), classif.trainingParam=struct(); end
if ~isstruct(classif.executionParam), classif.executionParam=struct(); end
classif.trainingParam.customSignalDefinition=definition;
classif.executionParam.customSignalDefinition=definition;
classif.channelName=definition.channels;
end
