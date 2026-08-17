function spec = specForClassifier(classif)
%ANNOTATIONMANAGER.SPECFORCLASSIFIER Resolve package or legacy annotation contract.

pkg = propertyText(classif, 'classifierPkg');
if ~isempty(pkg)
    hook = [pkg '.annotationSpec'];
    try
        if ~isempty(which(hook))
            spec = feval(hook, classif);
            spec = normalizeSpec(spec, classif, false);
            return;
        end
    catch ME
        warning('annotationManager:AnnotationSpecFailed', ...
            'Could not load %s: %s. Using the legacy fallback.', hook, ME.message);
    end
end

spec = legacySpec(classif);
spec = normalizeSpec(spec, classif, true);
end

function spec = legacySpec(classif)
spec = annotationManager.newSpec(classif);
category = lower(strtrim(string(spec.category)));
classes = spec.classes;
classifierId = spec.classifierId;

switch category
    case {"lstm", "timeseries"}
        predictionGroup = executionOutputName(classif, classifierId);
        gt = annotationManager.newAsset( ...
            'groupId', classifierId, 'valueField', 'labels_training', ...
            'idField', 'id_training','quality','gt', ...
            'producer','human_review','semantic','frame_class');
        pred = annotationManager.newAsset( ...
            'groupId', predictionGroup, 'valueField', 'labels', ...
            'idField', 'id','quality','pred', ...
            'producer',packageOrLegacy(classif),'semantic','frame_class');
        component = annotationManager.newComponent( ...
            'id', 'labels', 'kind', 'frame_labels', ...
            'storage', 'dataseries', 'coverageUnit', 'frame', ...
            'editor', 'class_palette', 'bootstrap', 'copy_fields', ...
            'classes', classes, 'groundTruth', gt, 'prediction', pred);
        spec.components = component;
        spec.defaultEditor = 'class_palette';

    case {"image", "image regression"}
        component = annotationManager.newComponent( ...
            'id', 'sequence_label', 'kind', 'sequence_label', ...
            'storage', 'dataseries', 'coverageUnit', 'roi', ...
            'editor', 'class_palette', 'classes', classes, ...
            'groundTruth', annotationManager.newAsset( ...
                'groupId', classifierId, 'valueField', 'labels_training', ...
                'idField', 'id_training','quality','gt', ...
                'producer','human_review','semantic','sequence_class'));
        spec.components = component;
        spec.defaultEditor = 'class_palette';

    otherwise
        gtName = annotationManager.annotationChannelName(classif);
        outputName = executionOutputName(classif, classifierId);
        prediction = ['results_' outputName];
        if ~isempty(classes) && any(category == ["pixel","object","delta","pedigree"])
            predictionWithClass = [prediction '_' classes{1}];
            candidates = {predictionWithClass, prediction};
        else
            candidates = {prediction};
        end
        component = annotationManager.newComponent( ...
            'id', 'mask', 'kind', 'instance_mask', ...
            'storage', 'channel', 'coverageUnit', 'frame', ...
            'editor', 'mask', 'bootstrap', 'copy_channel', ...
            'classes', classes, ...
            'groundTruth', annotationManager.newAsset('channel', gtName, ...
                'quality','gt','producer','human_review','semantic','mask'), ...
            'prediction', annotationManager.newAsset( ...
                'channel', candidates{1}, 'channelCandidates', candidates, ...
                'quality','pred','producer',packageOrLegacy(classif), ...
                'semantic','mask'));
        spec.components = component;
        spec.defaultEditor = 'mask';
end
spec.legacyFallback = true;
end

function name=packageOrLegacy(classif)
name=propertyText(classif,'classifierPkg');
if isempty(name),name='legacy_classifier';end
end

function spec = normalizeSpec(spec, classif, legacy)
base = annotationManager.newSpec(classif);
if isempty(spec) || ~isstruct(spec)
    spec = base;
end
fields = fieldnames(base);
for i = 1:numel(fields)
    if ~isfield(spec, fields{i}) || isempty(spec.(fields{i}))
        spec.(fields{i}) = base.(fields{i});
    end
end
if isempty(spec.id), spec.id = spec.classifierId; end
if isempty(spec.displayName), spec.displayName = spec.classifierId; end
if isempty(spec.components)
    spec.components = repmat(annotationManager.newComponent(), 0, 1);
else
    normalized = repmat(annotationManager.newComponent(), numel(spec.components), 1);
    template = annotationManager.newComponent();
    names = fieldnames(template);
    for c = 1:numel(spec.components)
        for i = 1:numel(names)
            if isfield(spec.components(c), names{i})
                normalized(c).(names{i}) = spec.components(c).(names{i});
            end
        end
    end
    spec.components = normalized;
end
spec.supportsBootstrap = any(~strcmp({spec.components.bootstrap}, 'none'));
spec.legacyFallback = logical(legacy || spec.legacyFallback);
end

function name = executionOutputName(classif, fallback)
name = fallback;
pkg = propertyText(classif, 'classifierPkg');
if ~isempty(pkg)
    hook = [pkg '.executionSpec'];
    try
        if ~isempty(which(hook))
            execution = feval(hook, classif);
            if isfield(execution, 'defaults') && ...
                    isfield(execution.defaults, 'outputName') && ...
                    ~isempty(execution.defaults.outputName)
                name = char(string(execution.defaults.outputName));
            end
        end
    catch
    end
end
executionParam = propertyValue(classif, 'executionParam', struct());
if isstruct(executionParam) && isfield(executionParam, 'outputName') && ...
        ~isempty(executionParam.outputName)
    name = char(string(executionParam.outputName));
end
end

function value = propertyText(obj, name)
value = propertyValue(obj, name, '');
try, value = char(string(value)); catch, value = ''; end
end

function value = propertyValue(obj, name, fallback)
value = fallback;
try
    if isobject(obj) && isprop(obj, name)
        value = obj.(name);
    elseif isstruct(obj) && isfield(obj, name)
        value = obj.(name);
    end
catch
    value = fallback;
end
end
