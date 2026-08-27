function model = create(roiId)
%CELLMODEL.CREATE Create an empty DetecDiv cellular object model (schema v1).

if nargin < 1, roiId = ''; end
nowText = char(datetime('now', 'Format', 'yyyy-MM-dd''T''HH:mm:ssXXX'));

model = struct();
model.format = 'detecdiv_cell_model';
model.schema_version = uint16(1);
model.index_base = uint8(1);
model.roi_id = char(string(roiId));

model.families = struct();
model.families.family_id = zeros(0,1,'uint32');
model.families.name = cell(0,1);
model.families.mask_provider = cell(0,1);
model.families.lineage_source = cell(0,1);
model.families.color_rgb = zeros(0,3,'uint8');

model.states = struct();
model.states.state_id = zeros(0,1,'uint16');
model.states.name = cell(0,1);
model.states.color_rgb = zeros(0,3,'uint8');

model.instances = struct();
model.instances.object_id = zeros(0,1,'uint64');
model.instances.family_id = zeros(0,1,'uint32');
model.instances.frame = zeros(0,1,'uint32');
model.instances.mask_label = zeros(0,1,'uint32');
model.instances.track_id = zeros(0,1,'uint64');
model.instances.state_id = zeros(0,1,'uint16');

% Optional, backward-compatible quality exclusions.  Censoring is an
% explicit human/model annotation, never inferred merely because a mask
% touches the ROI boundary.  scope_flags is a bit mask defined by
% cellModel.censorScope().
model.censoring = struct();
model.censoring.censor_id = zeros(0,1,'uint64');
model.censoring.family_id = zeros(0,1,'uint32');
model.censoring.track_id = zeros(0,1,'uint64');
model.censoring.frame_start = zeros(0,1,'uint32');
model.censoring.frame_end = zeros(0,1,'uint32');
model.censoring.scope_flags = zeros(0,1,'uint16');
model.censoring.reason_id = zeros(0,1,'uint16');
model.censoring.source_id = zeros(0,1,'uint8');

model.censor_reasons = defaultCensorReasons();
model.censor_sources = struct( ...
    'source_id', {uint8(1), uint8(2)}, ...
    'name', {'human_review', 'imported_review'});

model.relations = struct();
model.relations.relation_id = zeros(0,1,'uint64');
model.relations.family_id = zeros(0,1,'uint32');
model.relations.parent_track_id = zeros(0,1,'uint64');
model.relations.child_track_id = zeros(0,1,'uint64');
model.relations.event_frame = zeros(0,1,'uint32');
model.relations.type_id = zeros(0,1,'uint8');
model.relations.confidence = zeros(0,1,'single');

model.relation_types = struct('type_id', uint8(1), 'name', 'parent');
model.provenance = struct('created_at', nowText, 'updated_at', nowText, ...
    'source', 'detecdiv', 'source_version', '1');
end

function reasons = defaultCensorReasons()
reasons = struct( ...
    'reason_id', {uint16(1), uint16(2), uint16(3), uint16(4), uint16(5)}, ...
    'name', {'truncated_at_roi_boundary', 'ambiguous_identity', ...
        'ambiguous_parentage', 'unusable_segmentation', 'other'}, ...
    'description', { ...
        ['The cell or mask is visibly cut by the ROI boundary. Merely ' ...
         'touching the boundary is not sufficient.'], ...
        'The biological identity cannot be assigned reliably.', ...
        'The mother/NULL lineage decision cannot be assigned reliably.', ...
        'The segmentation is unusable for the selected evaluation units.', ...
        'Human-reviewed exclusion for another documented reason.'});
end
