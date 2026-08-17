function ensureClassMetadata(classif)
%CELLLATENTTRACKER.ENSURECLASSMETADATA Stable classifierGUI metadata.
if isempty(classif), return; end
try
    userComment = '';
    previous = classif.description;
    if iscell(previous) && numel(previous) >= 2
        userComment = char(string(previous{2}));
    end
    if strcmp(strtrim(userComment),'-'), userComment = ''; end
    classif.classifierPkg = 'cellLatentTracker';
    classif.trainingFun = 'cellLatentTracker.train';
    classif.classifyFun = 'cellLatentTracker.classify';
    classif.category = {'Pixel'};
    classif.classes = {'tracklet'};
    classif.description = { ...
        'Latent tracker (stable IDs)',userComment, ...
        ['[TRAIN] latent EDGE/APPEAR/END actions. [INPUT] frame-local ' ...
         'instances; [GT] reviewed stable tracks; [PRED] stable track IDs. It does not train ' ...
         'CellposeSAM, Trackastra, or the mother/NULL lineage linker.']};
    classif.outputType = 'segmentation';
    if isempty(classif.colormap) || size(classif.colormap,1) < 2
        classif.colormap = shallowColormap(1);
    end
catch
end
end
