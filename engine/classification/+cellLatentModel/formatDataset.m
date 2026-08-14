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
requestedFrames = [];
try requestedFrames = ctx.sel.frames; catch, end
stageRoot = fullfile(outputDir,['staging_' ...
    char(datetime('now','Format','yyyyMMddHHmmssSSS'))]);
mkdir(stageRoot);
stageCleanup = onCleanup(@() removeFolder(stageRoot));

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
    tracks = sliceStack(tracks,selectedFrames,trackName);
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
    [model,~] = roiobj.loadCellModel('MigrateLegacy',true);
    [relations,familyName] = reviewedRelations( ...
        model,tp.groundTruthFamily,trackName);
    relations = selectRelations(relations,selectedFrames);
    if isempty(relations)
        error('cellLatentModel:EmptyGroundTruth', ...
            'ROI %s has no reviewed lineage relations in family "%s".', ...
            char(string(roiobj.id)),familyName);
    end
    spec = emptySpec();
    spec.roi_id = char(string(roiobj.id));
    spec.source_roi_path = normalizedPath(roiobj.path);
    spec.source_frames = selectedFrames;
    spec.input_path = normalizedPath(inputFile);
    spec.tracks_dataset = '/tracks';
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

if strcmp(objective,'continuous_lineage')
    datasetDir = fullfile(outputDir,'continuous_dataset');
else
    datasetDir = fullfile(outputDir,'relation_dataset');
end
configFile = fullfile(outputDir,'format_config.json');
stdoutFile = fullfile(outputDir,'format_stdout.txt');
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
manifestFile = fullfile(datasetDir,'manifest.json');
if ~isfile(manifestFile)
    error('cellLatentModel:MissingFormattedDataset', ...
        'External formatter produced no dataset manifest.');
end
result = struct( ...
    'datasetDir',datasetDir, ...
    'manifestFile',manifestFile, ...
    'manifest',jsondecode(fileread(manifestFile)), ...
    'configFile',configFile, ...
    'stdoutFile',stdoutFile, ...
    'runtime',runtime);
clear stageCleanup;
removeFolder(stageRoot);
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
    'gfp_dataset','', ...
    'brightfield_dataset','', ...
    'nucleus_dataset','', ...
    'budneck_dataset','', ...
    'frame_interval_minutes',[], ...
    'split','train', ...
    'domain','detecdiv', ...
    'ground_truth_family','', ...
    'ground_truth_relations',struct( ...
        'child_track_id',{},'parent_track_id',{},'event_frame',{}));
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

function [relations,familyName] = reviewedRelations(model,requested,trackName)
model = cellModel.normalize(model);
requested = strtrim(char(string(requested)));
[index,~] = cellModel.familyIndex(model,requested);
if isempty(index) || strcmpi(requested,'<auto>')
    counts = zeros(numel(model.families.family_id),1);
    for i = 1:numel(counts)
        counts(i) = nnz(model.relations.family_id == ...
            model.families.family_id(i));
        if strcmp(model.families.name{i},trackName), counts(i) = -1; end
    end
    [best,index] = max(counts);
    if isempty(index) || best <= 0
        error('cellLatentModel:GroundTruthFamilyNotFound', ...
            'No cell-model family contains reviewed lineage relations.');
    end
end
familyId = model.families.family_id(index);
familyName = model.families.name{index};
rows = find(model.relations.family_id == familyId & ...
    model.relations.type_id == uint8(1));
relations = repmat(struct( ...
    'child_track_id',0,'parent_track_id',0,'event_frame',0),numel(rows),1);
for i = 1:numel(rows)
    row = rows(i);
    relations(i).child_track_id = ...
        double(model.relations.child_track_id(row));
    relations(i).parent_track_id = ...
        double(model.relations.parent_track_id(row));
    relations(i).event_frame = double(model.relations.event_frame(row));
end
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

function removeFolder(folder)
if isfolder(folder)
    try rmdir(folder,'s'); catch, end
end
end

function value = normalizedPath(value)
value = strrep(char(string(value)),'\','/');
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
