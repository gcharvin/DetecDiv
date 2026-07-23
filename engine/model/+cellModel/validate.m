function report = validate(model, varargin)
%CELLMODEL.VALIDATE Validate model integrity and genealogy cardinality.

p=inputParser;
p.addParameter('Throw',false,@(x)islogical(x)&&isscalar(x));
p.parse(varargin{:});
model=cellModel.normalize(model);
errors=strings(0,1); warnings=strings(0,1);

if ~strcmp(model.format,'detecdiv_cell_model'), errors(end+1)="Invalid format"; end %#ok<AGROW>
if model.schema_version~=1, errors(end+1)="Unsupported schema version"; end %#ok<AGROW>

fid=model.families.family_id;
if any(fid==0), errors(end+1)="family_id must be positive"; end %#ok<AGROW>
if numel(unique(fid))~=numel(fid), errors(end+1)="family_id values must be unique"; end %#ok<AGROW>
if numel(unique(string(model.families.name)))~=numel(model.families.name)
    errors(end+1)="Family names must be unique"; %#ok<AGROW>
end

oid=model.instances.object_id;
if any(oid==0), errors(end+1)="object_id must be positive"; end %#ok<AGROW>
if numel(unique(oid))~=numel(oid), errors(end+1)="object_id values must be unique"; end %#ok<AGROW>
if any(model.instances.frame==0), errors(end+1)="Instance frames are 1-based and must be positive"; end %#ok<AGROW>
if any(model.instances.mask_label==0), errors(end+1)="mask_label 0 is reserved for background"; end %#ok<AGROW>
if any(~ismember(model.instances.family_id,fid)), errors(end+1)="Instances reference unknown families"; end %#ok<AGROW>
triples=[double(model.instances.family_id),double(model.instances.frame),double(model.instances.mask_label)];
if size(unique(triples,'rows'),1)~=size(triples,1)
    errors(end+1)="Each (family, frame, mask_label) reference must be unique"; %#ok<AGROW>
end
tracked=model.instances.track_id~=0;
trackFrameKeys=[double(model.instances.family_id(tracked)), ...
    double(model.instances.frame(tracked)),double(model.instances.track_id(tracked))];
if size(unique(trackFrameKeys,'rows'),1)~=size(trackFrameKeys,1)
    errors(end+1)="A track may reference only one mask label per family and frame"; %#ok<AGROW>
end

knownStates=model.states.state_id;
usedStates=unique(model.instances.state_id(model.instances.state_id~=0));
if any(~ismember(usedStates,knownStates)), errors(end+1)="Instances reference unknown states"; end %#ok<AGROW>

rel=model.relations;
if any(rel.relation_id==0), errors(end+1)="relation_id must be positive"; end %#ok<AGROW>
if numel(unique(rel.relation_id))~=numel(rel.relation_id), errors(end+1)="relation_id values must be unique"; end %#ok<AGROW>
if any(~ismember(rel.family_id,fid)), errors(end+1)="Relations reference unknown families"; end %#ok<AGROW>
if any(rel.parent_track_id==0 | rel.child_track_id==0), errors(end+1)="Relation track IDs must be positive"; end %#ok<AGROW>
if any(rel.parent_track_id==rel.child_track_id), errors(end+1)="A track cannot be its own parent"; end %#ok<AGROW>
knownTypes=uint8([model.relation_types.type_id]);
if any(~ismember(rel.type_id,knownTypes)), errors(end+1)="Relations reference unknown relation types"; end %#ok<AGROW>

% A mother may have several children, but one child cannot have two mothers
% inside one family for the same parent relation type.
parentRows=(rel.type_id==1);
childKeys=[double(rel.family_id(parentRows)),double(rel.child_track_id(parentRows))];
if size(unique(childKeys,'rows'),1)~=size(childKeys,1)
    errors(end+1)="A child track has more than one parent in the same family"; %#ok<AGROW>
end
knownTracks=unique(model.instances.track_id(model.instances.track_id~=0));
relationTracks=unique([rel.parent_track_id;rel.child_track_id]);
if any(~ismember(relationTracks,knownTracks))
    warnings(end+1)="Some relation tracks have no instance row"; %#ok<AGROW>
end

report=struct('ok',isempty(errors),'errors',{cellstr(errors)},'warnings',{cellstr(warnings)}, ...
    'counts',struct('families',numel(fid),'states',numel(knownStates), ...
    'instances',numel(oid),'relations',numel(rel.relation_id)));
if p.Results.Throw && ~report.ok
    error('cellModel:InvalidModel','Invalid cell model:\n%s',strjoin(report.errors,newline));
end
end
