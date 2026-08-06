function report = normalizeClassifier(classif)
%CLASSIFIERBINDING.NORMALIZECLASSIFIER Repair legacy UI representations.

report = struct('flattenedParameters', {{}}, 'migratedChannels', false);
try
    tp = classif.trainingParam;
    if isstruct(tp)
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
end

function tf = isTextChoiceList(value)
tf = iscell(value) && ~isempty(value) && all(cellfun(@(x) ...
    ischar(x) || (isstring(x) && isscalar(x)), value));
end
