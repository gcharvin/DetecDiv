function result = formatDataset(classif,trainRois,valRois,outputDir,ctx,tp)
%CELLLATENTMODEL.FORMATDATASET Export ROI observations and reviewed lineage.
if nargin < 5 || isempty(ctx), ctx = struct(); end
if nargin < 6 || isempty(tp)
    tp = cellLatentModel.utils.defaultTrainingParam();
end
if isempty(trainRois) && isempty(valRois)
    error('cellLatentModel:NoFormattingROIs', ...
        'At least one ROI is required for formatting.');
end
if exist(outputDir,'dir') ~= 7, mkdir(outputDir); end
objective = trainingChoice(tp.trainingObjective,'relation_ensemble');
runId = formattingRunId(tp,ctx);
runRoot = fullfile(outputDir,'format_runs',runId);
datasetDir = fullfile(outputDir,'datasets',datasetDirectoryName( ...
    objective,runId));
manifestFile = fullfile(datasetDir,'manifest.json');
pointerFile = fullfile(outputDir,datasetPointerName(objective));
if isfolder(runRoot) || isfolder(datasetDir)
    error('cellLatentModel:ImmutableDatasetExists', ...
        ['Formatted dataset run "%s" already exists. Dataset versions ' ...
         'are immutable; start a new formatting run.'],runId);
end
mkdir(runRoot);
failureCleanup = onCleanup(@() cleanupFailedRun( ...
    runRoot,datasetDir,pointerFile,manifestFile)); %#ok<NASGU>
requestedFrames = [];
try requestedFrames = ctx.sel.frames; catch, end
stageRoot = fullfile(runRoot,'staging');
mkdir(stageRoot);

entries = [ ...
    splitEntries(trainRois,'train'); ...
    splitEntries(valRois,'validation')];
specs = repmat(emptySpec(),0,1);
for i = 1:numel(entries)
    roiIndex = entries(i).index;
    roiobj = classif.roi(roiIndex);
    if isempty(roiobj.image), roiobj.load; end
    [trackName,gfpName,brightfieldName,nucleusName,budneckName] = ...
        resolveChannels(classif,tp,roiobj,objective);
    tracks = readStack(roiobj,trackName,true);
    selectedFrames = trainingBounds.frames(classif, roiIndex, ...
        size(tracks,3), requestedFrames, 'RoiPosition', i, ...
        'SplitName', entries(i).split);
    if isempty(selectedFrames)
        error('cellLatentModel:EmptyTrainingFrameSelection', ...
            'ROI %s has no selected training frame.', char(string(roiobj.id)));
    end
    if strcmp(objective,'continuous_lineage') && ...
            any(diff(selectedFrames) ~= 1)
        error('cellLatentModel:NonContiguousTrainingFrames', ...
            ['Continuous-lineage formatting requires a contiguous frame range. ' ...
             'Set one inclusive range for ROI %s.'], char(string(roiobj.id)));
    end
    gfp = [];
    brightfield = [];
    nucleus = [];
    budneck = [];
    if strcmp(objective,'relation_ensemble')
        if ~isempty(gfpName), gfp = readStack(roiobj,gfpName,false); end
    else
        if ~isempty(brightfieldName)
            brightfield = readStack(roiobj,brightfieldName,false);
        end
        if ~isempty(nucleusName)
            nucleus = readStack(roiobj,nucleusName,false);
        end
        if ~isempty(budneckName)
            budneck = readStack(roiobj,budneckName,false);
        end
    end
    trackMaskLabels = sliceStack(tracks,selectedFrames,trackName);
    if ~isempty(gfp), gfp = sliceStack(gfp,selectedFrames,gfpName); end
    if ~isempty(brightfield)
        brightfield = sliceStack(brightfield,selectedFrames,brightfieldName);
    end
    if ~isempty(nucleus)
        nucleus = sliceStack(nucleus,selectedFrames,nucleusName);
    end
    if ~isempty(budneck)
        budneck = sliceStack(budneck,selectedFrames,budneckName);
    end
    [model,~] = roiobj.loadCellModel('MigrateLegacy',true);
    % The indexed channel stores only frame-local mask labels. Reuse the
    % tracker contract to reconstruct persistent identities from the
    % reviewed cell model before any lineage observation is exported.
    [tracks,stableFamily] = cellLatentTracker.materializeStableTracks( ...
        trackMaskLabels,model,selectedFrames,trackName);
    [relations,familyName] = reviewedRelations( ...
        model,tp.groundTruthFamily,stableFamily,selectedFrames);
    relations = selectRelations(relations,selectedFrames);
    % A sequence without an explicit mother link is still valid continuous
    % supervision: each unlinked track appearance is formatted as NULL.
    assertRelationsMaterialized( ...
        relations,tracks,familyName,char(string(roiobj.id)));
    inputFile = fullfile(stageRoot,sprintf('roi_%03d.h5',roiIndex));
    writeStack(inputFile,'/tracks',tracks,'uint32');
    if ~isempty(gfp), writeStack(inputFile,'/gfp',gfp,'single'); end
    if ~isempty(brightfield)
        writeStack(inputFile,'/brightfield',brightfield,'single');
    end
    if ~isempty(nucleus)
        writeStack(inputFile,'/nucleus',nucleus,'single');
    end
    if ~isempty(budneck)
        writeStack(inputFile,'/budneck',budneck,'single');
    end
    spec = emptySpec();
    spec.roi_id = char(string(roiobj.id));
    spec.source_roi_path = normalizedPath(roiobj.path);
    spec.source_frames = selectedFrames;
    spec.input_path = normalizedPath(inputFile);
    spec.tracks_dataset = '/tracks';
    spec.tracks_representation = 'cell_model_track_id';
    spec.tracks_mask_provider = trackName;
    if ~isempty(gfp), spec.gfp_dataset = '/gfp'; end
    if ~isempty(brightfield), spec.brightfield_dataset = '/brightfield'; end
    if ~isempty(nucleus), spec.nucleus_dataset = '/nucleus'; end
    if ~isempty(budneck), spec.budneck_dataset = '/budneck'; end
    if strcmp(objective,'continuous_lineage')
        spec.frame_interval_minutes = positiveScalar( ...
            tp.frameIntervalMinutes,'frameIntervalMinutes');
    end
    spec.split = entries(i).split;
    spec.domain = char(string(tp.trainingDomain));
    spec.ground_truth_family = familyName;
    spec.ground_truth_relations = relations;
    specs(end+1,1) = spec; %#ok<AGROW>
    if exist('detecdiv_progress','file') == 2
        detecdiv_progress(ctx,i/numel(entries), ...
            sprintf('Prepared ROI %d/%d for latent training.', ...
            i,numel(entries)),'Scope','formatting');
    end
end

configFile = fullfile(runRoot,'format_config.json');
stdoutFile = fullfile(runRoot,'format_stdout.txt');
if strcmp(objective,'continuous_lineage')
    window = nonnegativeScalar(tp.temporalWindowMinutes, ...
        'temporalWindowMinutes');
    step = positiveScalar(tp.temporalSampleStepMinutes, ...
        'temporalSampleStepMinutes');
    sampleTimes = 0:step:window;
    if isempty(sampleTimes) || sampleTimes(end) < window
        sampleTimes(end+1) = window;
    end
    cfg = struct( ...
        'schema_version',1, ...
        'output_dir',normalizedPath(datasetDir), ...
        'rois',specs, ...
        'sample_times_minutes',sampleTimes, ...
        'maximum_candidates',positiveInteger( ...
            tp.continuousMaxCandidates,'continuousMaxCandidates'), ...
        'centroid_prefilter',positiveInteger( ...
            tp.continuousCentroidPrefilter, ...
            'continuousCentroidPrefilter'), ...
        'maximum_contour_distance_radii',positiveScalar( ...
            tp.continuousMaxContourDistanceRadii, ...
            'continuousMaxContourDistanceRadii'));
    command = 'format-detecdiv-continuous';
else
    cfg = struct( ...
        'schema_version',1, ...
        'output_dir',normalizedPath(datasetDir), ...
        'rois',specs, ...
        'linker_parameters',linkerParameters(tp));
    command = 'format-detecdiv';
end
writeJson(configFile,cfg);
detecdiv_check_cancel(ctx,'cellLatentModel before dataset formatting');
runtime = cellLatentModel.utils.runPythonModule( ...
    command,configFile,ctx,stdoutFile);
detecdiv_check_cancel(ctx,'cellLatentModel after dataset formatting');
if ~isfile(manifestFile)
    error('cellLatentModel:MissingFormattedDataset', ...
        'External formatter produced no dataset manifest.');
end
% Preserve the exact materialized formatter inputs inside the immutable
% dataset. Deleting them left format_config.json and lineage provenance
% pointing to missing staging files, so the published dataset could be
% trained but not audited or replayed.
sourceArchive = fullfile(datasetDir,'materialized_sources');
[ok,message] = movefile(stageRoot,sourceArchive);
if ~ok
    error('cellLatentModel:SourceArchiveFailed', ...
        'Cannot preserve materialized formatter inputs: %s',message);
end
cellLatentModel.utils.relocateTextArtifacts( ...
    datasetDir,stageRoot,sourceArchive);
cellLatentModel.utils.relocateTextArtifacts( ...
    runRoot,stageRoot,sourceArchive);
% Parse the immutable record before publishing it. A formatter that exits
% successfully but leaves a truncated/invalid manifest must never replace
% the last completed dataset pointer.
manifest = jsondecode(fileread(manifestFile));
materializedSources = materializedSourceRecords( ...
    specs,stageRoot,sourceArchive);
cellLatentModel.utils.appendJsonField( ...
    manifestFile,'materialized_sources',materializedSources);
manifest = jsondecode(fileread(manifestFile));
pointerPayload = struct( ...
    'schema_version',1, ...
    'objective',objective, ...
    'run_id',runId, ...
    'model_name',safeName(tp.modelName), ...
    'manifest',normalizedPath(manifestFile), ...
    'manifest_sha256',fileSha256(manifestFile), ...
    'config',normalizedPath(configFile), ...
    'config_sha256',fileSha256(configFile), ...
    'created_at',cellLatentModel.utils.utcIso8601());
writeJsonAtomic(pointerFile,pointerPayload);
result = struct( ...
    'datasetDir',datasetDir, ...
    'manifestFile',manifestFile, ...
    'manifest',manifest, ...
    'configFile',configFile, ...
    'stdoutFile',stdoutFile, ...
    'pointerFile',pointerFile, ...
    'runDir',runRoot, ...
    'runId',runId, ...
    'runtime',runtime);
end

function records = materializedSourceRecords(specs,sourceRoot,targetRoot)
records = repmat(struct('roi_id','','split','','path','', ...
    'sha256','','bytes',0),numel(specs),1);
for index = 1:numel(specs)
    [pathValue,audit] = cellLatentModel.utils.relocatePathTree( ...
        specs(index).input_path,sourceRoot,targetRoot);
    if audit.relocated_path_count ~= 1 || ~isfile(pathValue)
        error('cellLatentModel:SourceArchiveIncomplete', ...
            'Materialized source for ROI %s was not archived.', ...
            specs(index).roi_id);
    end
    info = dir(pathValue);
    records(index) = struct( ...
        'roi_id',specs(index).roi_id, ...
        'split',specs(index).split, ...
        'path',normalizedPath(pathValue), ...
        'sha256',fileSha256(pathValue), ...
        'bytes',double(info.bytes));
end
end

function entries = splitEntries(indices,name)
indices = double(indices(:));
entries = repmat(struct('index',0,'split',''),numel(indices),1);
for i = 1:numel(indices)
    entries(i).index = indices(i);
    entries(i).split = name;
end
end

function spec = emptySpec()
spec = struct( ...
    'roi_id','', ...
    'source_roi_path','', ...
    'source_frames',[], ...
    'input_path','', ...
    'tracks_dataset','/tracks', ...
    'tracks_representation','cell_model_track_id', ...
    'tracks_mask_provider','', ...
    'gfp_dataset','', ...
    'brightfield_dataset','', ...
    'nucleus_dataset','', ...
    'budneck_dataset','', ...
    'frame_interval_minutes',[], ...
    'split','train', ...
    'domain','detecdiv', ...
    'ground_truth_family','', ...
    'ground_truth_relations',struct( ...
        'relation_id',{},'child_track_id',{},'parent_track_id',{}, ...
        'event_frame',{},'evidence_mode',{}, ...
        'temporal_parentage_eligible',{}, ...
        'static_parentage_eligible',{},'exclusion_reason',{}));
end

function stack = sliceStack(stack,frames,name)
if size(stack,3) < max(frames)
    error('cellLatentModel:TrainingChannelFrameMismatch', ...
        'Channel "%s" contains %d frames but frame %d was requested.', ...
        name,size(stack,3),max(frames));
end
stack = stack(:,:,frames);
end

function relations = selectRelations(relations,frames)
if isempty(relations), return; end
eventFrames = double([relations.event_frame]);
[keep,localFrames] = ismember(eventFrames,frames);
relations = relations(keep);
localFrames = localFrames(keep);
for i = 1:numel(relations)
    relations(i).event_frame = double(localFrames(i));
end
end

function [trackName,gfpName,brightfieldName,nucleusName,budneckName] = ...
        resolveChannels(classif,tp,roiobj,objective)
names = {};
try names = cellstr(string(classif.channelName)); catch, end
try
    names = [names(:); cellstr(string(classif.channelName2))];
catch
end
try
    roiNames = cellstr(string(roiobj.display.channel));
    names = [names(:); roiNames(:)];
catch
end
names = unique(names(strlength(string(names)) > 0),'stable');
trackName = strtrim(char(string(tp.trackChannelName)));
gfpName = strtrim(char(string(tp.gfpChannelName)));
brightfieldName = strtrim(char(string(tp.brightfieldChannelName)));
nucleusName = strtrim(char(string(tp.nucleusChannelName)));
budneckName = strtrim(char(string(tp.budneckChannelName)));
if isempty(trackName)
    hit = find(contains(lower(string(names)),'trackastra') | ...
        contains(lower(string(names)),'track'),1,'last');
    if isempty(hit)
        error('cellLatentModel:MissingTrainingTrackChannel', ...
            'Set trainingParam.trackChannelName for ROI formatting.');
    end
    trackName = names{hit};
end
if strcmp(objective,'relation_ensemble') && isempty(gfpName)
    hit = find(contains(lower(string(names)),'gfp'),1,'first');
    if ~isempty(hit), gfpName = names{hit}; end
end
if strcmp(objective,'continuous_lineage') && isempty(brightfieldName)
    hit = find(contains(lower(string(names)),'brightfield') | ...
        contains(lower(string(names)),'phase') | ...
        contains(lower(string(names)),'-ph'),1,'first');
    if ~isempty(hit), brightfieldName = names{hit}; end
end
if strcmp(objective,'continuous_lineage'), gfpName = ''; end
end

function stack = readStack(roiobj,name,isLabels)
try pix = roiobj.findChannelID(name,'exact');
catch, pix = roiobj.findChannelID(name);
end
if isempty(pix)
    error('cellLatentModel:TrainingChannelNotFound', ...
        'ROI %s does not contain channel "%s".', ...
        char(string(roiobj.id)),name);
end
stack = squeeze(roiobj.image(:,:,pix(1),:));
if ismatrix(stack)
    stack = reshape(stack,size(stack,1),size(stack,2),1);
end
if isLabels, stack = uint32(stack); else, stack = single(stack); end
end

function [relations,familyName] = reviewedRelations( ...
        model,requested,stableFamily,selectedFrames)
model = cellModel.normalize(model);
[model,~] = cellModel.canonicalizeParentageEvents(model);
requested = strtrim(char(string(requested)));
stableFamilyId = uint32(stableFamily.family_id);
[index,~] = cellModel.familyIndex(model,stableFamilyId);
if isempty(index)
    error('cellLatentModel:GroundTruthFamilyNotFound', ...
        'The stable-track GT family no longer exists in the cell model.');
end
if ~isempty(requested) && ~strcmpi(requested,'<auto>')
    [requestedIndex,requestedId] = cellModel.familyIndex(model,requested);
    if isempty(requestedIndex)
        error('cellLatentModel:GroundTruthFamilyNotFound', ...
            'Cell-model GT family "%s" was not found.',requested);
    end
    if requestedId ~= stableFamilyId
        error('cellLatentModel:GroundTruthFamilyMismatch', ...
            ['Requested lineage GT family "%s" is not the reviewed family ' ...
             'that maps mask provider "%s" to stable track IDs ("%s").'], ...
            model.families.name{requestedIndex},stableFamily.mask_provider, ...
            stableFamily.name);
    end
end
familyId = stableFamilyId;
familyName = model.families.name{index};
parentage = annotationManager.validateParentage( ...
    model,familyId,'Frames',selectedFrames);
if ~parentage.valid
    error('cellLatentModel:InvalidGroundTruthRelations', ...
        'Invalid reviewed lineage in family "%s": %s',familyName, ...
        strjoin(cellstr(parentage.errors),' '));
end
[evidence,model] = cellModel.parentageEvidence( ...
    model,familyId,'Frames',selectedFrames);
rows = find(model.relations.family_id == familyId & ...
    model.relations.type_id == uint8(1));
relations = repmat(struct( ...
    'relation_id',0,'child_track_id',0,'parent_track_id',0, ...
    'event_frame',0,'evidence_mode','', ...
    'temporal_parentage_eligible',false, ...
    'static_parentage_eligible',false,'exclusion_reason',''),numel(rows),1);
for i = 1:numel(rows)
    row = rows(i);
    relations(i).relation_id = double(model.relations.relation_id(row));
    relations(i).child_track_id = ...
        double(model.relations.child_track_id(row));
    relations(i).parent_track_id = ...
        double(model.relations.parent_track_id(row));
    relations(i).event_frame = double(model.relations.event_frame(row));
    evidenceIndex = find([evidence.relation_id] == ...
        model.relations.relation_id(row),1);
    if isempty(evidenceIndex), continue; end
    relations(i).evidence_mode = evidence(evidenceIndex).evidence_mode;
    relations(i).temporal_parentage_eligible = ...
        evidence(evidenceIndex).temporal_parentage_eligible;
    relations(i).static_parentage_eligible = ...
        evidence(evidenceIndex).static_parentage_eligible;
    relations(i).exclusion_reason = evidence(evidenceIndex).exclusion_reason;
end
end

function assertRelationsMaterialized(relations,tracks,familyName,roiId)
materializedIds = unique(uint64(tracks(tracks > 0)));
parentIds = uint64([relations.parent_track_id]);
childIds = uint64([relations.child_track_id]);
missingIds = setdiff(unique([parentIds(:);childIds(:)]),materializedIds);
if isempty(missingIds), return; end
error('cellLatentModel:InvalidGroundTruthRelations', ...
    ['ROI %s lineage family "%s" references stable track ID(s) %s in ' ...
     'the selected relations, but those IDs are absent from the selected ' ...
     'materialized GT frames.'],roiId,familyName, ...
    char(strjoin(string(double(missingIds(:).')),',')));
end

function parameters = linkerParameters(p)
parameters = struct( ...
    'min_lifetime',double(p.minLifetime), ...
    'max_birth_area',double(p.maxBirthArea), ...
    'min_parent_age',double(p.minParentAge), ...
    'max_parent_centroid_distance',double(p.maxParentCentroidDistance), ...
    'max_parent_contour_distance',double(p.maxParentContourDistance), ...
    'max_candidates',double(p.maxCandidates));
end

function writeStack(filename,dataset,stack,datatype)
stored = permute(stack,[2 1 3]);
storedSize = [size(stack,2),size(stack,1),size(stack,3)];
chunk = [min(storedSize(1),256),min(storedSize(2),256),1];
h5create(filename,dataset,storedSize,'Datatype',datatype, ...
    'ChunkSize',chunk,'Deflate',1);
h5write(filename,dataset,stored);
h5writeatt(filename,dataset,'axis_order','time,y,x');
end

function writeJson(filename,value)
fid = fopen(filename,'w');
if fid < 0
    error('cellLatentModel:ConfigWriteFailed','Cannot write %s.',filename);
end
cleanup = onCleanup(@() fclose(fid));
fwrite(fid,jsonencode(value,'PrettyPrint',true),'char');
end

function writeJsonAtomic(filename,value)
tmp = [filename '.tmp_' char(java.util.UUID.randomUUID)];
tmpCleanup = onCleanup(@() deleteIfPresent(tmp));
writeJson(tmp,value);
[ok,message] = movefile(tmp,filename,'f');
if ~ok
    error('cellLatentModel:PointerPublishFailed', ...
        'Cannot publish dataset pointer %s: %s',filename,message);
end
clear tmpCleanup;
end

function deleteIfPresent(filename)
if isfile(filename)
    try delete(filename); catch, end
end
end

function cleanupFailedRun(runRoot,datasetDir,pointerFile,manifestFile)
% These are freshly generated, run-scoped targets. Removing them cannot
% affect a previously completed immutable dataset.
if pointerTargets(pointerFile,manifestFile), return; end
removeFolder(datasetDir);
removeFolder(runRoot);
end

function tf = pointerTargets(pointerFile,manifestFile)
tf = false;
if ~isfile(pointerFile) || ~isfile(manifestFile), return; end
try
    pointer = jsondecode(fileread(pointerFile));
    tf = strcmpi(normalizedPath(pointer.manifest), ...
        normalizedPath(manifestFile));
catch
    tf = false;
end
end

function removeFolder(folder)
if isfolder(folder)
    try rmdir(folder,'s'); catch, end
end
end

function value = normalizedPath(value)
value = strrep(char(string(value)),'\','/');
end

function value = fileSha256(filename)
fid = fopen(filename,'r');
if fid < 0
    error('cellLatentModel:ManifestReadFailed','Cannot read %s.',filename);
end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
bytes = fread(fid,Inf,'*uint8');
digest = java.security.MessageDigest.getInstance('SHA-256');
hash = typecast(digest.digest(bytes),'uint8');
value = lower(reshape(dec2hex(hash,2).',1,[]));
end

function value = formattingRunId(tp,ctx)
value = '';
try value = safeName(ctx.formatRunId); catch, end
if ~isempty(value), return; end
stamp = char(datetime('now','Format','yyyyMMdd''T''HHmmssSSS'));
uuid = regexprep(char(java.util.UUID.randomUUID),'-','');
value = sprintf('%s_%s_%s',safeName(tp.modelName),stamp,uuid(1:8));
end

function value = datasetDirectoryName(objective,runId)
if strcmp(objective,'continuous_lineage')
    prefix = 'continuous_lineage';
else
    prefix = 'relation_ensemble';
end
value = [prefix '_' runId];
end

function value = datasetPointerName(objective)
if strcmp(objective,'continuous_lineage')
    value = 'latest_cell_latent_continuous_dataset.json';
else
    value = 'latest_cell_latent_relation_dataset.json';
end
end

function value = safeName(value)
while iscell(value)
    if isempty(value), value=''; break; else, value=value{end}; end
end
value = regexprep(strtrim(char(string(value))), ...
    '[^A-Za-z0-9_.-]','_');
if isempty(value), value = 'cell_latent_dataset'; end
end

function value = trainingChoice(raw,fallback)
while iscell(raw)
    if isempty(raw), raw = fallback; else, raw = raw{end}; end
end
value = lower(strtrim(char(string(raw))));
if isempty(value), value = fallback; end
if ~any(strcmp(value,{'relation_ensemble','continuous_lineage'}))
    error('cellLatentModel:InvalidTrainingObjective', ...
        'trainingObjective must be relation_ensemble or continuous_lineage.');
end
end

function value = positiveScalar(raw,name)
value = double(raw);
if ~isscalar(value) || ~isfinite(value) || value <= 0
    error('cellLatentModel:InvalidTrainingParameter', ...
        '%s must be positive.',name);
end
end

function value = nonnegativeScalar(raw,name)
value = double(raw);
if ~isscalar(value) || ~isfinite(value) || value < 0
    error('cellLatentModel:InvalidTrainingParameter', ...
        '%s must be non-negative.',name);
end
end

function value = positiveInteger(raw,name)
value = round(positiveScalar(raw,name));
end
