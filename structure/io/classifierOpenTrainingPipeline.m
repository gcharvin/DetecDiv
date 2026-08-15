function app = classifierOpenTrainingPipeline(classiObj, varargin)
% classifierOpenTrainingPipeline  Open a pipeline2 training run for a classifier.
%
% classifierGUI remains the source of truth for train/test ROI selection and
% training parameters. pipeline2 materializes the run. A classifier on a
% server-visible or mapped path defaults to Hub execution; a local-only
% classifier defaults to Local MATLAB so the generated run is runnable.

if ~hasNameValue(varargin, {'ExecutionTarget','RunTarget','Target'})
    target = classifierDefaultExecutionTarget(classiObj.path);
    varargin = [varargin {'ExecutionTarget',target}];
end

app = classifierOpenValidationPipeline(classiObj, 'Intent', 'train', varargin{:});
end

function tf = hasNameValue(args, names)
tf = false;
if isempty(args)
    return;
end
names = strrep(cellstr(string(names)), '_', '');
for i = 1:2:numel(args)
    key = args{i};
    if ~(ischar(key) || isstring(key))
        continue;
    end
    key = strrep(char(string(key)), '_', '');
    if any(strcmpi(key, names))
        tf = true;
        return;
    end
end
end
