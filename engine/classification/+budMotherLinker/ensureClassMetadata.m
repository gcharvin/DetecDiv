function ensureClassMetadata(classif)
%BUDMOTHERLINKER.ENSURECLASSMETADATA Keep classifierGUI metadata stable.

if isempty(classif), return; end
try
    userComment = '';
    previous = classif.description;
    if iscell(previous) && numel(previous) >= 2
        candidate = char(string(previous{2}));
        if ~contains(lower(candidate), 'lyn') && ...
                ~contains(lower(candidate), 'mother-bud')
            userComment = candidate;
        end
    end
    if strcmp(strtrim(userComment), '-'), userComment = ''; end

    classif.classifierPkg = 'budMotherLinker';
    classif.trainingFun = 'budMotherLinker.train';
    classif.classifyFun = 'budMotherLinker.classify';
    classif.category = {'Tracking'};
    classif.classes = {'mother-bud link'};
    classif.description = { ...
        'Bud-mother lineage linker', userComment, ...
        ['[TRAIN] sklearn HistGradientBoosting mother ranker using the 16 ' ...
         'LYN-compatible descriptors. [GT] reviewed mother-bud links; ' ...
         '[PRED] mother-bud lineage family; inference is native MATLAB.']};
    classif.outputType = 'lineage';
    if isempty(classif.colormap)
        classif.colormap = shallowColormap(1);
    end
catch
end
end
