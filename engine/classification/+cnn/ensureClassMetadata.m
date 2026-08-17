function ensureClassMetadata(classif)
%CNN.ENSURECLASSMETADATA Explain the legacy image classifier boundary.
if isempty(classif),return;end
try
    userComment=descriptionComment(classif);
    classif.classifierPkg='cnn';
    classif.trainingFun='cnn.train';
    classif.classifyFun='cnn.classify';
    if isempty(classif.category),classif.category={'Image'};end
    classif.description={'CNN image classifier',userComment, ...
        ['[TRAIN] CNN image backbone/classification head. [INPUT] microscopy ' ...
         'images; [GT] reviewed image/sequence classes; [PRED] class scores. ' ...
         'No segmentation, temporal, tracking, or lineage module is changed.']};
catch
end
end
function value=descriptionComment(classif)
value='';
try d=classif.description;if iscell(d)&&numel(d)>=2,value=char(string(d{2}));end,catch,end
end
