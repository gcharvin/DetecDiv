function defaults = normalizeTrainingExecutionDefaults(classif,defaults)
%NORMALIZETRAININGEXECUTIONDEFAULTS Migrate composite runtime bindings.
if nargin < 2 || ~isstruct(defaults),defaults=struct();end
if ~isComposite(classif,defaults),return;end
gt=propertyFieldText(classif,'trainingParam','trackChannelName');
requested=fieldText(defaults,'instanceChannelName');
[resolved,resolution]=cellLatentModel.utils.resolveFrameLocalInstanceChannel( ...
    classif,requested,gt,struct());
% A legacy GT-as-input binding is not permission to choose arbitrarily
% among several generic segmentation channels.  Keep only the canonical
% CellposeSAM migration here; otherwise leave the binding empty so the
% per-ROI annotation planner can detect ambiguity and ask the user.
autoSelected=any(strcmp(resolution.source, ...
    {'indexed_segmentation_channel','cell_model_mask_provider'}));
if (resolution.migrated_from_ground_truth || autoSelected) && ...
        ~strcmpi(resolved,'results_cellposeSAM_cell')
    resolved='';
end
defaults.instanceChannelName=resolved;
% Composite inference creates stable identities itself.  Reviewed IDs stay
% exclusively in trainingParam.trackChannelName for dataset formatting.
defaults.trackChannelName='';
% Composite PRED assets are classifier-owned and deterministic.  Persisting
% these identities in the active-model snapshot keeps inference, annotation
% discovery and PRED-to-Draft cloning on one family even when the loaded MAT
% snapshot still contains legacy output names.
classifierId=safeClassifierId(classif);
defaults.outputTrackChannelName=['pred_' classifierId '_tracks'];
defaults.outputFamilyName=['pred_' classifierId '_lineage'];
end

function tf=isComposite(classif,defaults)
backend=fieldText(defaults,'backend');
architecture=propertyFieldText(classif,'trainingParam', ...
    'architectureVersion');
if ~isempty(backend)
    tf=strcmpi(backend,'causal_composite');
else
    tf=strcmpi(architecture,'detecdiv_composite_v1');
end
end

function value=propertyFieldText(obj,property,field)
value='';
try
    container=obj.(property);
    if isstruct(container)&&isfield(container,field)
        value=fieldText(container,field);
    end
catch
end
end

function value=fieldText(container,field)
value='';
try
    if isstruct(container)&&isfield(container,field)
        value=container.(field);
        while iscell(value)
            if isempty(value),value='';return;end
            value=value{end};
        end
        value=strtrim(char(string(value)));
    end
catch
end
end

function value=safeClassifierId(classif)
value='cell_latent_model';
try
    candidate=strtrim(char(string(classif.strid)));
    if ~isempty(candidate),value=candidate;end
catch
end
value=regexprep(value,'[^A-Za-z0-9_.-]','_');
if isempty(value),value='cell_latent_model';end
end
