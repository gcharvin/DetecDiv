function spec = annotationSpec(classif)
% The shared annotation lifecycle owns labels and review coverage.
spec=cnn_lstm.annotationSpec(classif);
spec.displayName='Numeric sequence state labels';spec.trainingFramePolicy='disjoint';
spec.allowPartialApproval=true;
end
