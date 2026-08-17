function scope = trainingScopeSpec(classif)
%SAM31.TRAININGSCOPESPEC Dynamic SAM3.1 sub-module ownership contract.
tp=trainingParams(classif);
preset=lower(strrep(strrep(textValue(tp,'trainModules', ...
    'instance + video memory'),'_',' '),'-',' '));
allModules={'semantic segmentation head','instance segmentation head','video-memory tracking head'};
if strcmp(strtrim(preset),'all')
    trained=allModules;
else
    trained={};
    if contains(preset,'semantic'),trained{end+1}=allModules{1};end
    if contains(preset,'instance'),trained{end+1}=allModules{2};end
    if contains(preset,'video')||contains(preset,'memory'),trained{end+1}=allModules{3};end
end
if isempty(trained),trained={'No recognized SAM3.1 weight update selected'};end
frozen=setdiff(allModules,trained,'stable');
frozen=[frozen {'CellposeSAM','Trackastra','latent EDGE/APPEAR/END tracker','lineage heads'}];
scope=classifierBinding.newTrainingScope( ...
    'module','sam31', ...
    'displayName','SAM3.1 — segmentation and video memory', ...
    'objective',['Train the selected SAM3.1 preset: ' strtrim(preset) '.'], ...
    'trainedComponents',trained,'frozenComponents',frozen, ...
    'datasetUnit','Microscopy framebanks with reviewed tracked-instance masks.', ...
    'splitPolicy','Whole-ROI validation holdout; test ROIs are excluded from training and validation exports.', ...
    'outputParameter','outputName','outputQuality','pred', ...
    'outputSemantic','tracked-instance mask channel', ...
    'outputTemplate','results_<outputName>_cell', ...
    'canonicalOutput','results_pred_sam31_tracks_cell', ...
    'notes',{'Bud pairing at inference is post-processing and is not trained by SAM3.1 trainModules.'});
end

function tp=trainingParams(classif)
tp=sam31.utils.defaultTrainingParam();
try
    if isobject(classif)&&isprop(classif,'trainingParam')&&isstruct(classif.trainingParam)
        tp=classif.trainingParam;
    elseif isstruct(classif)&&isfield(classif,'trainingParam')&&isstruct(classif.trainingParam)
        tp=classif.trainingParam;
    end
catch
end
end
function value=textValue(tp,name,fallback)
value=fallback;
try raw=tp.(name);while iscell(raw),raw=raw{end};end,value=char(string(raw));catch,end
end
