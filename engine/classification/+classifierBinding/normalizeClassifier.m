function report = normalizeClassifier(classif)
%CLASSIFIERBINDING.NORMALIZECLASSIFIER Repair legacy UI representations.

report = struct('flattenedParameters', {{}}, ...
    'addedParameters', {{}}, 'migratedChannels', false, ...
    'packageMigration', struct());
try
    tp = classif.trainingParam;
    if isstruct(tp)
        [tp,report.addedParameters] = mergePackageDefaults(classif,tp);
        keys = fieldnames(tp);
        for i = 1:numel(keys)
            key = keys{i};
            if strcmp(key, 'tip'), continue; end
            before = tp.(key);
            candidate = before;
            while iscell(candidate) && numel(candidate) == 1 && iscell(candidate{1})
                candidate = candidate{1};
            end
            after = before;
            if isTextChoiceList(candidate), after = candidate; end
            if ~isequal(before, after)
                tp.(key) = after;
                report.flattenedParameters{end+1} = key; %#ok<AGROW>
            end
        end
        classif.trainingParam = tp;
    end
catch
end

% Materialize pre-channelName numeric selections only for packages whose
% typed contract uses the legacy classifier input storage.
try
    spec = classifierBinding.trainingSpec(classif);
    usesInputs = any(strcmpi({spec.storage}, 'classifierInputChannels'));
    if usesInputs
        probe = spec(find(strcmpi({spec.storage}, 'classifierInputChannels'), 1));
        current = classifierBinding.value(classif, probe);
        hasStoredNames = false;
        try, hasStoredNames = ~isempty(classif.channelName); catch, end
        try
            hasStoredNames = hasStoredNames || ...
                (isstruct(classif.dataset) && isfield(classif.dataset, 'channels') && ...
                 ~isempty(classif.dataset.channels));
        catch
        end
        if ~hasStoredNames && ~isempty(current)
            classifierBinding.applyValue(classif, probe, current);
            report.migratedChannels = true;
        end
    end
catch
end

% Packages may migrate semantic bindings that generic storage code cannot
% safely interpret (for example, separating an inference mask from its GT).
try
    pkg=strtrim(char(string(classif.classifierPkg)));
    hook=[pkg '.migrateClassifierBindings'];
    if ~isempty(pkg)&&~isempty(which(hook))
        report.packageMigration=feval(hook,classif);
    end
catch ME
    warning('classifierBinding:PackageBindingMigrationFailed', ...
        'Could not migrate %s classifier bindings: %s',pkg,ME.message);
end
end

function [merged,added] = mergePackageDefaults(classif,current)
% Add newly introduced package parameters without resetting saved values.
merged=current;
added={};
pkg='';
try pkg=strtrim(char(string(classif.classifierPkg))); catch, end
if isempty(pkg),return;end
factory=[pkg '.utils.defaultTrainingParam'];
if isempty(which(factory)),return;end
try defaults=feval(factory);catch,return;end
if ~isstruct(defaults)||~isscalar(defaults),return;end

currentKeys=fieldnames(current);
currentKeys=currentKeys(~strcmp(currentKeys,'tip'));
defaultKeys=fieldnames(defaults);
defaultKeys=defaultKeys(~strcmp(defaultKeys,'tip'));
currentTips=parameterTips(current,numel(currentKeys));
defaultTips=parameterTips(defaults,numel(defaultKeys));

% Rebuild in package-default order so scope controls stay visible at the
% top of classifierGUI. Existing values always win over new defaults.
merged=struct();
mergedTips={};
for i=1:numel(defaultKeys)
    key=defaultKeys{i};
    if isfield(current,key)
        merged.(key)=current.(key);
    else
        merged.(key)=defaults.(key);
        added{end+1}=key; %#ok<AGROW>
    end
    mergedTips{end+1}=defaultTips{i}; %#ok<AGROW>
end
extra=currentKeys(~ismember(currentKeys,defaultKeys));
for i=1:numel(extra)
    key=extra{i};
    merged.(key)=current.(key);
    index=find(strcmp(currentKeys,key),1);
    mergedTips{end+1}=currentTips{index}; %#ok<AGROW>
end
merged.tip={mergedTips};
end

function tips=parameterTips(parameters,count)
tips=cell(1,count);
tips(:)={''};
try
    raw=parameters.tip;
    while iscell(raw)&&isscalar(raw)&&iscell(raw{1}),raw=raw{1};end
    if iscell(raw)
        for i=1:min(count,numel(raw))
            try tips{i}=char(string(raw{i}));catch,end
        end
    end
catch
end
end

function tf = isTextChoiceList(value)
tf = iscell(value) && ~isempty(value) && all(cellfun(@(x) ...
    ischar(x) || (isstring(x) && isscalar(x)), value));
end
