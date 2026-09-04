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
    package = fieldText(activeModel, 'package');
    if strcmpi(package, 'cellposesam')
        if contains(lower(fieldText(activeModel, 'modelLabel')), 'default')
            label = 'Run default CellposeSAM model and initialize Draft GT';
        else
            label = 'Run active CellposeSAM model and initialize Draft GT';
        end
    else
        releaseId = fieldText(activeModel, 'releaseId');
        if isempty(releaseId)
            label = 'Apply active latent model to existing masks/tracks';
        else
            label = sprintf('Apply latent model %s to existing masks/tracks', ...
                releaseId);
        end
    end
    labels{end+1} = label; %#ok<AGROW>
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

function value = fieldText(item, name)
value = '';
try
    if isstruct(item) && isfield(item, name)
        value = strtrim(char(string(item.(name))));
    end
catch
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
