function app = classifierOpenTrainingPipeline(classiObj, varargin)
% classifierOpenTrainingPipeline  Open a pipeline2 training run for a classifier.
%
% classifierGUI remains the source of truth for train/test ROI selection and
% training parameters. pipeline2 materializes the run. Execution-target and
% channel defaults are shared with validation by the common helper.

app = classifierOpenValidationPipeline(classiObj, 'Intent', 'train', varargin{:});
end
