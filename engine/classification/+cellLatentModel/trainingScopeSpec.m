function scope = trainingScopeSpec(classif)
%CELLLATENTMODEL.TRAININGSCOPESPEC Dynamic composite ownership contract.
tp=cellLatentModel.utils.defaultTrainingParam();
try
    if isstruct(classif.trainingParam)
        tp=cellLatentModel.utils.applyOverrides(tp,classif.trainingParam);
    end
catch
end
architecture=textValue(tp.architectureVersion);
composite=strcmpi(architecture,'detecdiv_composite_v1');
trained={}; frozen={'CellposeSAM','Trackastra'};
if composite && logical(tp.trainTrackingActions)
    trained=[trained {'EDGE association head','APPEAR new-track head','END termination head'}]; %#ok<AGROW>
else
    frozen=[frozen {'EDGE/APPEAR/END tracking head'}]; %#ok<AGROW>
end
if logical(tp.trainMotherNull)
    trained=[trained {'Physical-time mother/NULL lineage head'}]; %#ok<AGROW>
else
    frozen=[frozen {'mother/NULL lineage head'}]; %#ok<AGROW>
end
stateMode=textValue(tp.stateUpdateMode);
if strcmpi(stateMode,'promoted_frozen_bf')
    frozen=[frozen {'promoted BF/geometry biological-state student'}]; %#ok<AGROW>
else
    frozen=[frozen {'biological-state head (disabled)'}]; %#ok<AGROW>
end
if isempty(trained),trained={'No trainable latent component selected'};end
scope=classifierBinding.newTrainingScope( ...
    'module','cellLatentModel', ...
    'displayName','Composite latent cell model — tracking, lineage and states', ...
    'objective','Track instances, classify new trajectories as mother-linked or NULL, then update causal cell state.', ...
    'trainedComponents',trained, ...
    'frozenComponents',frozen, ...
    'datasetUnit','Frame-local instances, reviewed stable identities, reviewed mother/NULL lineage and typed raw images.', ...
    'splitPolicy','Whole-ROI validation held out from selected train ROIs; test ROIs are untouched.', ...
    'outputParameter','outputFamilyName','outputQuality','pred', ...
    'outputSemantic','stable tracks + mother/NULL lineage + optional biological state', ...
    'outputTemplate','<outputFamilyName>', ...
    'canonicalOutput','pred_cell_latent_composite', ...
    'notes',{['Architecture=' architecture '; state=' stateMode '.'], ...
        'cellLatentTracker remains a backward-compatible adapter to the same tracking backend.'});
end

function value=textValue(value)
while iscell(value),if isempty(value),value='';return;else,value=value{end};end,end
value=strtrim(char(string(value)));
end
