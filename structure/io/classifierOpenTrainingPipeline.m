function app = classifierOpenTrainingPipeline(classiObj, varargin)
% classifierOpenTrainingPipeline  Open a pipeline2 training run for a classifier.
%
% classifierGUI remains the source of truth for train/test ROI selection and
% training parameters. pipeline2 materializes the run and defaults to the Hub
% execution target so training is picked up by detecdiv-worker instances.

if ~hasNameValue(varargin, {'ExecutionTarget','RunTarget','Target'})
    varargin = [varargin {'ExecutionTarget','hub'}]; %#ok<AGROW>
end

app = classifierOpenValidationPipeline(classiObj, 'Intent', 'train', varargin{:});
end

function tf = hasNameValue(args, names)
tf = false;
if isempty(args)
    return;
end
names = lower(strrep(cellstr(string(names)), '_', ''));
for i = 1:2:numel(args)
    key = args{i};
    if ~(ischar(key) || isstring(key))
        continue;
    end
    key = lower(strrep(char(string(key)), '_', ''));
    if any(strcmp(key, names))
        tf = true;
        return;
    end
end
end
