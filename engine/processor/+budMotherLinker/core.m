function [paramout, dataout, imageout] = core(param, roiobj, ctx)
%BUDMOTHERLINKER.CORE Run HGB-16 inference and update the canonical cellModel.

if nargin < 3, ctx = struct(); end
paramout = budMotherLinker.normalizeParam(param, ctx);
ensureROIImage(roiobj);
[trackStack, trackPix] = trackedStack(roiobj, paramout.trackChannelName);

paths = resolveRuntimePaths(paramout);
runtimeDir = tempname;
mkdir(runtimeDir);
cleanup = onCleanup(@() cleanupRuntime(runtimeDir, paramout.keepRuntimeFiles));
inputFile = fullfile(runtimeDir, 'tracks.h5');
writeTrackStack(inputFile, trackStack);

auditFile = resolveAuditFile(roiobj, paramout.outputFamilyName, ctx);
if ~isfolder(fileparts(auditFile)), mkdir(fileparts(auditFile)); end
runtimeScript = fullfile(fileparts(mfilename('fullpath')), 'python', ...
    'bud_mother_linker_runtime.py');
command = buildCommand(paths, runtimeScript, inputFile, auditFile, roiobj, paramout);
if paramout.debug
    fprintf('[budMotherLinker] track channel: %s (pix %d)\n', ...
        paramout.trackChannelName, trackPix);
    fprintf('[budMotherLinker] model package: %s\n', paths.modelPackage);
    fprintf('[budMotherLinker] LYN repository: %s\n', paths.lynRepository);
    fprintf('[budMotherLinker] audit output: %s\n', auditFile);
end
[status, console] = system(command);
if status ~= 0
    error('budMotherLinker:BackendFailed', ...
        'Bud/mother backend failed (exit %d):\n%s', status, console);
end
if ~isfile(auditFile)
    error('budMotherLinker:MissingOutput', ...
        'Python backend did not create %s.', auditFile);
end
result = jsondecode(fileread(auditFile));

[model, loadReport] = roiobj.loadCellModel('MigrateLegacy', true);
[model, familyId, applyReport] = applyInference( ...
    model, trackStack, paramout.trackChannelName, paramout.inputFamily, ...
    paramout.outputFamilyName, result, paramout.overwriteOutputFamily);
model.provenance.last_processor = 'budMotherLinker';
model.provenance.last_audit_artifact = auditFile;
if isfield(result, 'tool_version')
    model.provenance.last_processor_version = char(string(result.tool_version));
end
if isfield(result, 'model_manifest_sha256')
    model.provenance.last_model_manifest_sha256 = ...
        char(string(result.model_manifest_sha256));
end
saveReport = roiobj.saveCellModel(model);

paramout.outputFamilyId = double(familyId);
paramout.auditFile = auditFile;
paramout.cellModelFile = char(saveReport.filename);
paramout.artifacts = {auditFile, char(saveReport.filename)};
paramout.summary = result.summary;
paramout.runtime = struct('pythonExecutable', paths.pythonExecutable, ...
    'modelPackage', paths.modelPackage, 'lynRepository', paths.lynRepository, ...
    'lynCheckpoint', paths.lynCheckpoint);
paramout.cellModelReport = struct('load', loadReport, 'apply', applyReport, ...
    'save', saveReport);
paramout.saveChannels = {};

dataout = roiobj.data;
imageout = roiobj.image;
if paramout.debug
    fprintf('[budMotherLinker] %d linked, %d review; family %u.\n', ...
        double(result.summary.linked), double(result.summary.review), familyId);
end
clear cleanup;
cleanupRuntime(runtimeDir, paramout.keepRuntimeFiles);
end

function ensureROIImage(roiobj)
if isempty(roiobj.image), roiobj.load; end
end

function [stack, pix] = trackedStack(roiobj, channelName)
try pix = roiobj.findChannelID(channelName, 'exact'); catch, pix = roiobj.findChannelID(channelName); end
if isempty(pix)
    try
        roiobj.load('Channel', channelName, 'Data', false, 'Silent');
        pix = roiobj.findChannelID(channelName, 'exact');
    catch
    end
end
if isempty(pix), error('budMotherLinker:ChannelNotFound', 'Channel "%s" not found.', channelName); end
pix = pix(1);
stack = squeeze(roiobj.image(:,:,pix,:));
if ismatrix(stack), stack = reshape(stack, size(stack,1), size(stack,2), 1); end
if any(~isfinite(double(stack(:)))) || any(double(stack(:)) < 0) || ...
        any(mod(double(stack(:)),1) ~= 0)
    error('budMotherLinker:InvalidLabels', ...
        'Track channel must contain finite non-negative integer labels.');
end
stack = uint32(stack);
end

function writeTrackStack(filename, stack)
shape = size(stack); if numel(shape) < 3, shape(3) = 1; end
h5create(filename, '/tracks', shape, 'Datatype', 'uint32', ...
    'ChunkSize', [shape(1), shape(2), 1], 'Deflate', 4);
h5write(filename, '/tracks', stack);
h5writeatt(filename, '/tracks', 'producer', 'MATLAB');
h5writeatt(filename, '/tracks', 'logical_axes', 'YXT');
h5writeatt(filename, '/tracks', 'height', uint32(shape(1)));
h5writeatt(filename, '/tracks', 'width', uint32(shape(2)));
h5writeatt(filename, '/tracks', 'frames', uint32(shape(3)));
end

function paths = resolveRuntimePaths(param)
packageDir = fileparts(mfilename('fullpath'));
repoRoot = fileparts(fileparts(fileparts(packageDir)));
paths.modelPackage = resolveModelPackage(param.modelPackage, repoRoot);
paths.lynRepository = resolveLynRepository(param.lynRepository, paths.modelPackage, repoRoot);
paths.lynCheckpoint = resolveLynCheckpoint(param.lynCheckpoint, paths.lynRepository);
paths.pythonExecutable = resolvePython(param.pythonExecutable);
required = {paths.modelPackage, paths.lynRepository, paths.lynCheckpoint, paths.pythonExecutable};
labels = {'model package','LYN repository','LYN checkpoint','Python executable'};
for i = 1:numel(required)
    commandOnly = i == 4 && ~contains(required{i}, filesep) && ...
        ~contains(required{i}, '/') && ~contains(required{i}, '\');
    if (i <= 2 && ~isfolder(required{i})) || ...
            (i > 2 && ~commandOnly && ~isfile(required{i}))
        error('budMotherLinker:MissingRuntime', 'Missing %s: %s', labels{i}, required{i});
    end
end
if ~isfile(fullfile(paths.modelPackage, 'manifest.json')) || ...
        ~isfile(fullfile(paths.modelPackage, 'hgb_lyn16.joblib'))
    error('budMotherLinker:InvalidModelPackage', ...
        'Model package lacks manifest.json or hgb_lyn16.joblib: %s', paths.modelPackage);
end
end

function path = resolveModelPackage(value, repoRoot)
path = explicitOrEnvironment(value, 'DETECDIV_BUD_MOTHER_MODEL');
if ~isempty(path), return; end
candidates = { ...
    fullfile(repoRoot, 'models', 'bud_mother_linker', 'project47_v002'), ...
    fullfile(fileparts(repoRoot), 'SAM31_yeast_sandbox', 'data', 'models', ...
        'project47_bud_mother_linker_v002')};
path = firstExisting(candidates, true);
end

function path = resolveLynRepository(value, modelPackage, repoRoot)
path = explicitOrEnvironment(value, 'DETECDIV_LYN_TRACE_REPO');
if ~isempty(path), return; end
manifestPath = fullfile(modelPackage, 'manifest.json');
try
    manifest = jsondecode(fileread(manifestPath));
    if isfield(manifest, 'lyn_repository') && isfolder(manifest.lyn_repository)
        path = char(string(manifest.lyn_repository)); return;
    end
catch
end
candidates = {fullfile(fileparts(repoRoot), 'LYN-trace'), ...
    fullfile(tempdir, 'codex_lyn_trace_20260722')};
path = firstExisting(candidates, true);
end

function path = resolveLynCheckpoint(value, lynRepository)
path = explicitOrEnvironment(value, 'DETECDIV_LYN_TRACE_CHECKPOINT');
if ~isempty(path), return; end
path = fullfile(lynRepository, 'src', 'bread', 'algo', 'lineage', ...
    'saved_models', 'best_model_with_fake_candid_thresh12_frame_num8_normalized_True.pth');
end

function path = resolvePython(value)
path = explicitOrEnvironment(value, 'DETECDIV_PYTHON');
if isempty(path), path = getenv('PROJECT47_GT_PYTHON'); end
if ~isempty(path), path = char(string(path)); return; end
try
    env = pyenv;
    if strlength(string(env.Executable)) > 0, path = char(env.Executable); return; end
catch
end
candidate = fullfile(getenv('USERPROFILE'), '.conda', 'envs', ...
    'detecdiv_python', 'python.exe');
if isfile(candidate), path = candidate; else, path = 'python'; end
end

function path = explicitOrEnvironment(value, environmentName)
path = '';
value = char(string(value));
if ~isempty(value) && ~strcmpi(value, 'auto'), path = value; return; end
envValue = getenv(environmentName);
if ~isempty(envValue), path = envValue; end
end

function path = firstExisting(candidates, directory)
path = '';
for i = 1:numel(candidates)
    if (directory && isfolder(candidates{i})) || (~directory && isfile(candidates{i}))
        path = candidates{i}; return;
    end
end
end

function command = buildCommand(paths, runtimeScript, inputFile, outputFile, roiobj, param)
args = {paths.pythonExecutable, runtimeScript, '--input-h5', inputFile, ...
    '--dataset', '/tracks', '--model-dir', paths.modelPackage, ...
    '--lyn-repo', paths.lynRepository, '--lyn-model', paths.lynCheckpoint, ...
    '--output-json', outputFile, '--roi-id', char(string(roiobj.id)), ...
    '--frame-end', num2str(param.frameEnd, '%.0f'), ...
    '--min-lifetime', num2str(param.minLifetime, '%.0f'), ...
    '--max-birth-area', num2str(param.maxBirthArea, '%.17g'), ...
    '--min-parent-age', num2str(param.minParentAge, '%.0f'), ...
    '--max-parent-centroid-distance', num2str(param.maxParentCentroidDistance, '%.17g'), ...
    '--max-parent-contour-distance', num2str(param.maxParentContourDistance, '%.17g'), ...
    '--max-candidates', num2str(param.maxCandidates, '%.0f')};
quoted = cellfun(@quoteArgument, args, 'UniformOutput', false);
command = strjoin(quoted, ' ');
end

function value = quoteArgument(value)
value = char(string(value));
value = strrep(value, '"', '""');
value = ['"' value '"'];
end

function auditFile = resolveAuditFile(roiobj, outputFamily, ctx)
root = '';
try
    if isfield(ctx, 'store') && isstruct(ctx.store) && isfield(ctx.store, 'workDir')
        root = char(string(ctx.store.workDir));
    end
catch
end
if isempty(root)
    sidecar = cellModel.pathForROI(roiobj);
    root = fullfile(fileparts(sidecar), 'artifacts', 'budMotherLinker');
end
stamp = char(datetime('now', 'Format', 'yyyyMMdd''T''HHmmssSSS'));
safeFamily = regexprep(outputFamily, '[^A-Za-z0-9_-]+', '_');
safeRoi = regexprep(char(string(roiobj.id)), '[^A-Za-z0-9_-]+', '_');
auditFile = fullfile(root, sprintf('bud_mother_%s_%s_%s.json', ...
    safeRoi, safeFamily, stamp));
end

function [model, familyId, report] = applyInference( ...
        model, stack, channelName, inputFamily, outputFamily, result, overwrite)
model = cellModel.normalize(model);
[sourceIndex, ~] = cellModel.familyIndex(model, inputFamily);
if isempty(sourceIndex), [sourceIndex, ~] = cellModel.familyIndex(model, channelName); end

[outputIndex, familyId] = cellModel.familyIndex(model, outputFamily);
if ~isempty(outputIndex) && outputIndex == sourceIndex
    error('budMotherLinker:SourceOutputCollision', ...
        ['The output family must be distinct from the tracking/source family. ' ...
         'This preserves the source genealogy and latent cell states.']);
end
if ~isempty(outputIndex) && ~overwrite
    error('budMotherLinker:OutputExists', ...
        'Cell-model family "%s" already exists.', outputFamily);
end
if isempty(outputIndex)
    familyId = max([model.families.family_id; uint32(0)]) + uint32(1);
    outputIndex = numel(model.families.family_id) + 1;
    model.families.family_id(outputIndex,1) = familyId;
    model.families.name{outputIndex,1} = outputFamily;
    model.families.mask_provider{outputIndex,1} = channelName;
    model.families.lineage_source{outputIndex,1} = 'budMotherLinker';
    if isempty(sourceIndex)
        model.families.color_rgb(outputIndex,:) = uint8([255 214 64]);
    else
        model.families.color_rgb(outputIndex,:) = model.families.color_rgb(sourceIndex,:);
    end
else
    keepInstances = model.instances.family_id ~= familyId;
    model.instances = subsetRows(model.instances, keepInstances);
    keepRelations = model.relations.family_id ~= familyId;
    model.relations = subsetRows(model.relations, keepRelations);
    model.families.mask_provider{outputIndex} = channelName;
    model.families.lineage_source{outputIndex} = 'budMotherLinker';
end

nextObject = max([model.instances.object_id; uint64(0)]) + uint64(1);
for frame = 1:size(stack,3)
    labels = unique(stack(:,:,frame)); labels = labels(labels > 0);
    n = numel(labels); if n == 0, continue; end
    rows = (numel(model.instances.object_id)+1):(numel(model.instances.object_id)+n);
    model.instances.object_id(rows,1) = nextObject + uint64((0:n-1)');
    nextObject = nextObject + uint64(n);
    model.instances.family_id(rows,1) = familyId;
    model.instances.frame(rows,1) = uint32(frame);
    model.instances.mask_label(rows,1) = uint32(labels);
    model.instances.track_id(rows,1) = uint64(labels);
    model.instances.state_id(rows,1) = sourceStates( ...
        model, sourceIndex, frame, labels);
end

edges = result.edges;
if isempty(edges), edges = struct([]); end
nextRelation = max([model.relations.relation_id; uint64(0)]) + uint64(1);
linked = 0; skipped = 0;
knownTracks = unique(model.instances.track_id(model.instances.family_id == familyId));
for i = 1:numel(edges)
    edge = edges(i);
    if ~isfield(edge, 'status') || ~strcmp(char(string(edge.status)), 'linked')
        continue;
    end
    parent = uint64(edge.pred_parent_id); child = uint64(edge.child_track_id);
    if parent == 0 || child == 0 || parent == child || ...
            ~ismember(parent, knownTracks) || ~ismember(child, knownTracks)
        skipped = skipped + 1; continue;
    end
    row = numel(model.relations.relation_id) + 1;
    model.relations.relation_id(row,1) = nextRelation; nextRelation = nextRelation + 1;
    model.relations.family_id(row,1) = familyId;
    model.relations.parent_track_id(row,1) = parent;
    model.relations.child_track_id(row,1) = child;
    model.relations.event_frame(row,1) = uint32(edge.bud_appearance_frame);
    model.relations.type_id(row,1) = uint8(1);
    confidence = NaN;
    if isfield(edge, 'top_score') && ~isempty(edge.top_score), confidence = edge.top_score; end
    model.relations.confidence(row,1) = single(confidence);
    linked = linked + 1;
end
model = cellModel.normalize(model);
validation = cellModel.validate(model, 'Throw', true);
report = struct('family_id', familyId, 'family_name', outputFamily, ...
    'linked_relations', linked, 'skipped_invalid_relations', skipped, ...
    'validation', validation);
end

function states = sourceStates(model, sourceIndex, frame, labels)
states = zeros(numel(labels),1,'uint16');
if isempty(sourceIndex), return; end
sourceFamilyId = model.families.family_id(sourceIndex);
rows = find(model.instances.family_id == sourceFamilyId & ...
    model.instances.frame == uint32(frame));
for i = 1:numel(labels)
    hit = rows(find(model.instances.mask_label(rows) == uint32(labels(i)), 1, 'first'));
    if ~isempty(hit), states(i) = model.instances.state_id(hit); end
end
end

function columns = subsetRows(columns, keep)
names = fieldnames(columns);
for i = 1:numel(names), columns.(names{i}) = columns.(names{i})(keep,:); end
end

function cleanupRuntime(path, keep)
if keep || ~isfolder(path), return; end
try rmdir(path, 's'); catch, end
end
