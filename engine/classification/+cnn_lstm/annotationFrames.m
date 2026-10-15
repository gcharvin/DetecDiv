function [frames, isWindow] = annotationFrames(classif, roiObj, currentFrame, frameCount)
%ANNOTATIONFRAMES Match the nonoverlapping windows used by format/classify.
frames = currentFrame;
isWindow = false;
if isempty(classif) || ~isa(classif, 'classi'), return; end
tp = classif.trainingParam;
if ~isstruct(tp) || ~isfield(tp, 'classifier_output'), return; end
mode = tp.classifier_output;
if iscell(mode), mode = mode{end}; end
if ~strcmpi(string(mode), 'sequence-to-one'), return; end
isWindow = true;
available = trainingBounds.frames(classif, roiObj, frameCount, []);
index = find(available == currentFrame, 1);
frames = [];
if isempty(index), return; end
lengthFrames = 0;
if isfield(tp, 'LSTM_sequence_length'), lengthFrames = tp.LSTM_sequence_length; end
if iscell(lengthFrames), lengthFrames = lengthFrames{end}; end
if isempty(lengthFrames) || ~isscalar(lengthFrames) || ~isfinite(lengthFrames)
    lengthFrames = 0;
end
lengthFrames = round(lengthFrames);
if lengthFrames <= 0
    frames = available;
else
    first = 1 + floor((index - 1) / lengthFrames) * lengthFrames;
    frames = available(first:min(numel(available), first + lengthFrames - 1));
end
end
