function modelPath = selectModelPath(classifierPath, id)
%SELECTMODELPATH Prefer the best trained epoch, retaining legacy fallbacks.
modelPath = 'sam';
if isempty(classifierPath) || isempty(id), return; end
candidate = fullfile(classifierPath,'models',id);
candidates = {fullfile(classifierPath,[id '_best.pth']), candidate, [candidate '.pth']};
for i = 1:numel(candidates)
    if isfile(candidates{i})
        modelPath = candidates{i};
        return;
    end
end
end
