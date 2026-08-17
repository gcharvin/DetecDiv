function ensureClassMetadata(classif)
%CELLLATENTMODEL.ENSURECLASSMETADATA Keep classifierGUI metadata stable.
if isempty(classif), return; end
try
    userComment = '';
    previous = classif.description;
    if iscell(previous) && numel(previous) >= 2
        candidate = char(string(previous{2}));
        if ~contains(lower(candidate),'latent')
            userComment = candidate;
        end
    end
    if strcmp(strtrim(userComment),'-'), userComment = ''; end
    classif.classifierPkg = 'cellLatentModel';
    classif.trainingFun = 'cellLatentModel.train';
    classif.classifyFun = 'cellLatentModel.classify';
    classif.category = {'Tracking'};
    classif.classes = {'stable track','latent lineage link','cell state'};
    classif.description = { ...
        'Composite latent cell model',userComment, ...
        ['[INPUT] raw images plus frame-local masks. [TRAIN] selected ' ...
         'EDGE/APPEAR/END and mother/NULL heads. [PRED] stable tracks, ' ...
         'lineage and optional causal cell states. CellposeSAM and ' ...
         'Trackastra remain explicit upstream alternatives.']};
    classif.outputType = 'tracking_lineage_state';
    if isempty(classif.colormap)
        classif.colormap = shallowColormap(1);
    end
catch
end
end
