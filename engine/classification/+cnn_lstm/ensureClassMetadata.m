function ensureClassMetadata(classif)
%CNN_LSTM.ENSURECLASSMETADATA Explain the temporal classifier boundary.
if isempty(classif),return;end
try
    userComment=descriptionComment(classif);
    classif.classifierPkg='cnn_lstm';
    classif.trainingFun='cnn_lstm.train';
    classif.classifyFun='cnn_lstm.classify';
    if isempty(classif.category),classif.category={'LSTM'};end
    classif.description={'CNN + LSTM temporal classifier',userComment, ...
        ['[TRAIN] Only stages selected by train_CNN_classifier and ' ...
         'train_LSTM_network. [INPUT] image sequences; [GT] reviewed ' ...
         'frame/sequence classes; [PRED] temporal class scores.']};
catch
end
end
function value=descriptionComment(classif)
value='';
try d=classif.description;if iscell(d)&&numel(d)>=2,value=char(string(d{2}));end,catch,end
end
