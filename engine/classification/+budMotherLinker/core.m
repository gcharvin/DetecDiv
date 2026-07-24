function [paramout, dataout, imageout] = core(param, roiobj, ctx, classif)
%BUDMOTHERLINKER.CORE Run HGB-16 inference and update the canonical cellModel.

if nargin < 3, ctx = struct(); end
if nargin < 4, classif = []; end
paramout = budMotherLinker.normalizeParam(param, ctx, classif);
ensureROIImage(roiobj);
[trackStack, trackPix] = trackedStack(roiobj, paramout.trackChannelName);

auditFile = resolveAuditFile(roiobj, paramout.outputFamilyName, ctx);
if ~isfolder(fileparts(auditFile)), mkdir(fileparts(auditFile)); end
if paramout.debug
    fprintf('[budMotherLinker] track channel: %s (pix %d)\n', ...
        paramout.trackChannelName, trackPix);
    fprintf('[budMotherLinker] runtime: external cell_lineage_linker\n');
    fprintf('[budMotherLinker] audit output: %s\n', auditFile);
end
if exist('detecdiv_progress', 'file') == 2
    detecdiv_progress(ctx, 0, 'Preparing bud/mother candidates...', ...
        'Scope', 'event', 'Indeterminate', true);
end
result = budMotherLinker.infer(trackStack, paramout, ...
    char(string(roiobj.id)), ctx);
if exist('detecdiv_progress', 'file') == 2
    detecdiv_progress(ctx, 0.82, ...
        'Writing bud/mother audit data...', 'Scope', 'integration');
end
writeAuditFile(auditFile, result);

if exist('detecdiv_progress', 'file') == 2
    detecdiv_progress(ctx, 0.86, ...
        'Updating the ROI cell model...', 'Scope', 'integration');
end
[model, loadReport] = roiobj.loadCellModel('MigrateLegacy', true);
[model, familyId, applyReport] = applyInference( ...
    model, trackStack, paramout.trackChannelName, paramout.inputFamily, ...
    paramout.outputFamilyName, result, paramout.overwriteOutputFamily);
model.provenance.last_classifier = 'budMotherLinker';
model.provenance.last_audit_artifact = auditFile;
if isfield(result, 'tool_version')
    model.provenance.last_processor_version = char(string(result.tool_version));
end
if isfield(result, 'model_manifest_sha256')
    model.provenance.last_model_manifest_sha256 = ...
        char(string(result.model_manifest_sha256));
end
if exist('detecdiv_progress', 'file') == 2
    detecdiv_progress(ctx, 0.96, ...
        'Saving the ROI cell model...', 'Scope', 'integration');
end
saveReport = roiobj.saveCellModel(model);
if exist('detecdiv_progress', 'file') == 2
    detecdiv_progress(ctx, 1, ...
        'Bud/mother links saved.', 'Scope', 'integration');
end

paramout.outputFamilyId = double(familyId);
paramout.auditFile = auditFile;
paramout.cellModelFile = char(saveReport.filename);
paramout.artifacts = {auditFile, char(saveReport.filename)};
paramout.summary = result.summary;
paramout.runtime = struct('backend', 'Python', ...
    'package', 'cell_lineage_linker', ...
    'model_source', paramout.modelSource, 'model', paramout.modelPath);
paramout.cellModelReport = struct('load', loadReport, 'apply', applyReport, ...
    'save', saveReport);
paramout.saveChannels = {};

dataout = roiobj.data;
% The tracked masks are read-only input. Returning the ROI image here makes
% classifier orchestration interpret every loaded channel as image output
% and rewrite the complete HDF5 stack during the deferred final save.
imageout = [];
if paramout.debug
    fprintf('[budMotherLinker] %d linked, %d review; family %u.\n', ...
        double(result.summary.linked), double(result.summary.review), familyId);
end
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

function writeAuditFile(filename, result)
temporary = [filename '.tmp'];
fid = fopen(temporary, 'w');
if fid < 0
    error('budMotherLinker:AuditWriteFailed', ...
        'Cannot create audit artifact: %s', temporary);
end
cleanup = onCleanup(@() fclose(fid));
text = jsonencode(result, 'PrettyPrint', true);
fwrite(fid, text, 'char');
clear cleanup;
[ok, message] = movefile(temporary, filename, 'f');
if ~ok
    error('budMotherLinker:AuditWriteFailed', ...
        'Cannot finalize audit artifact %s: %s', filename, message);
end
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
