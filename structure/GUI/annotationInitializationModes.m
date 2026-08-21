function [labels, ids] = annotationInitializationModes(catalog, activeModel)
%ANNOTATIONINITIALIZATIONMODES Return safe, user-visible GT seed choices.

if nargin < 2 || isempty(activeModel), activeModel = struct(); end
labels = {};
ids = {};
if catalog.prediction.available
    labels{end+1} = 'Copy existing PRED objects as Draft GT'; %#ok<AGROW>
    ids{end+1} = 'prediction'; %#ok<AGROW>
end
if activeModelCanUseExistingInputs(activeModel)
    labels{end+1} = 'Apply active latent model to existing masks/tracks'; %#ok<AGROW>
    ids{end+1} = 'run_prediction'; %#ok<AGROW>
end
if catalog.supports.family && any([catalog.families.usable])
    labels{end+1} = 'Copy existing tracked objects as Draft GT'; %#ok<AGROW>
    ids{end+1} = 'family'; %#ok<AGROW>
end
if catalog.supports.mask && ~isempty(catalog.maskChannels)
    labels{end+1} = 'Copy existing segmentation mask as Draft GT'; %#ok<AGROW>
    ids{end+1} = 'mask'; %#ok<AGROW>
end
end

function tf = activeModelCanUseExistingInputs(info)
tf = fieldLogical(info, 'available') && ...
    fieldLogical(info, 'canRunOnExistingInputs');
end

function value = fieldLogical(item, name)
value = false;
try
    if isstruct(item) && isfield(item, name)
        value = logical(item.(name));
    end
catch
end
end
