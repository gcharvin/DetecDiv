function app = classifierOpenTrainingPipeline(classiObj, varargin)
% classifierOpenTrainingPipeline  Open a pipeline2 training run for a classifier.
%
% classifierGUI remains the source of truth for train/test ROI selection and
% training parameters. pipeline2 only materializes the run and lets the user
% choose the execution target.

app = classifierOpenValidationPipeline(classiObj, 'Intent', 'train', varargin{:});
end
