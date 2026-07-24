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
    classif.classes = {'latent lineage link'};
    classif.description = { ...
        'Multimodal cell latent relation model',userComment, ...
        ['Trainable PyTorch ensemble consuming LYN16 geometry and optional ' ...
         'GFP nuclear observations; output is a lineage family.']};
    classif.outputType = 'lineage';
    if isempty(classif.colormap)
        classif.colormap = shallowColormap(1);
    end
catch
end
end
