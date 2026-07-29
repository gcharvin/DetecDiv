function report = persistBiologicalState( ...
        roiobj,familyId,familyName,trackChannelName,result,auditFile)
%CELLLATENTMODEL.PERSISTBIOLOGICALSTATE Save continuous per-cell/frame states.
%
% The canonical cell-model schema v1 has only one discrete state_id per
% instance. Continuous probabilities therefore live in a versioned JSON
% sidecar keyed by (family_id, track_id, frame), referenced from provenance.

if ~isstruct(result) || ~isfield(result,'biological_state') || ...
        ~isstruct(result.biological_state)
    error('cellLatentModel:MissingBiologicalState', ...
        'continuous_cell_state returned no biological_state contract.');
end
state = result.biological_state;
if isfield(state,'records')
    records = state.records;
else
    records = struct([]);
end
recordCount = validateRecords(records);

modelPath = cellModel.pathForROI(roiobj);
root = fileparts(modelPath);
if isempty(root)
    error('cellLatentModel:BiologicalStatePath', ...
        'ROI path/id is required to persist continuous biological state.');
end
if ~isfolder(root), mkdir(root); end
safeRoi = safeName(char(string(roiobj.id)));
safeFamily = safeName(char(string(familyName)));
filename = fullfile(root,sprintf( ...
    'continuous_states_%s_%s.json',safeRoi,safeFamily));

metadata = state;
if isfield(metadata,'records'), metadata = rmfield(metadata,'records'); end
payload = struct();
payload.format = 'detecdiv_continuous_cell_state';
payload.schema_version = 1;
payload.index_base = 1;
payload.roi_id = char(string(roiobj.id));
payload.family_id = double(familyId);
payload.family_name = char(string(familyName));
payload.track_channel_name = char(string(trackChannelName));
payload.backend = 'continuous_cell_state';
payload.created_at = createdAt(result);
payload.audit_artifact = char(string(auditFile));
if isfield(result,'frame_interval_minutes')
    payload.frame_interval_minutes = ...
        double(result.frame_interval_minutes);
end
if isfield(result,'checkpoint')
    payload.checkpoint = result.checkpoint;
end
payload.biological_state = metadata;
payload.records = records;
writeJsonAtomic(filename,payload);

report = struct( ...
    'filename',string(filename), ...
    'records',recordCount, ...
    'schema_version',1, ...
    'status','ok');
end

function count = validateRecords(records)
if isempty(records)
    count = 0;
    return;
end
if ~isstruct(records)
    error('cellLatentModel:InvalidBiologicalState', ...
        'biological_state.records must be a struct array.');
end
required = {'track_id','frame'};
for i = 1:numel(required)
    if ~isfield(records,required{i})
        error('cellLatentModel:InvalidBiologicalState', ...
            'Biological-state records lack field "%s".',required{i});
    end
end
trackIds = zeros(numel(records),1,'uint64');
frames = zeros(numel(records),1,'uint32');
for i = 1:numel(records)
    track = double(records(i).track_id);
    frame = double(records(i).frame);
    if ~isscalar(track) || ~isfinite(track) || track <= 0 || ...
            mod(track,1) ~= 0
        error('cellLatentModel:InvalidBiologicalState', ...
            'Biological-state track_id values must be positive integers.');
    end
    if ~isscalar(frame) || ~isfinite(frame) || frame <= 0 || ...
            mod(frame,1) ~= 0
        error('cellLatentModel:InvalidBiologicalState', ...
            'Biological-state frame values must be 1-based integers.');
    end
    trackIds(i) = uint64(track);
    frames(i) = uint32(frame);
end
keys = string(trackIds) + ":" + string(frames);
if numel(unique(keys)) ~= numel(keys)
    error('cellLatentModel:DuplicateBiologicalState', ...
        'Biological-state records must be unique by (track_id, frame).');
end
count = numel(records);
end

function value = createdAt(result)
if isfield(result,'created_at') && ~isempty(result.created_at)
    value = char(string(result.created_at));
else
    value = char(datetime('now', ...
        'Format','yyyy-MM-dd''T''HH:mm:ssXXX'));
end
end

function value = safeName(value)
value = regexprep(value,'[^A-Za-z0-9_.-]+','_');
if isempty(value), value = 'unnamed'; end
end

function writeJsonAtomic(filename,value)
temporary = [filename '.tmp.' char(java.util.UUID.randomUUID)];
cleanup = onCleanup(@() deleteIfPresent(temporary));
fid = fopen(temporary,'w');
if fid < 0
    error('cellLatentModel:BiologicalStateWriteFailed', ...
        'Cannot create %s.',temporary);
end
closeFile = onCleanup(@() fclose(fid));
fwrite(fid,jsonencode(value,'PrettyPrint',true),'char');
clear closeFile;
[ok,message] = movefile(temporary,filename,'f');
if ~ok
    error('cellLatentModel:BiologicalStateWriteFailed', ...
        'Cannot finalize %s: %s',filename,message);
end
clear cleanup;
end

function deleteIfPresent(filename)
try
    if isfile(filename), delete(filename); end
catch
end
end
