function records = materializeCensoring(model,family,selectedFrames)
%CELLMODEL.MATERIALIZECENSORING Export explicit intervals on local frames.
% Records retain their original inclusive 1-based frame bounds and add
% local inclusive bounds for the selected formatter sequence.  A
% non-contiguous selection splits an interval into contiguous local runs.

model = cellModel.normalize(model);
[~,familyId] = cellModel.familyIndex(model,family);
if isempty(familyId)
    error('cellModel:UnknownFamily','Unknown family.');
end
selectedFrames = round(double(selectedFrames(:).'));
if isempty(selectedFrames)
    records = emptyRecords();
    return;
end
if any(~isfinite(selectedFrames) | selectedFrames < 1) || ...
        numel(unique(selectedFrames)) ~= numel(selectedFrames)
    error('cellModel:BadCensorFrames', ...
        'Selected frames must be unique positive integers.');
end

records = emptyRecords();
rows = find(model.censoring.family_id == uint32(familyId));
for row = rows(:).'
    covered = find(selectedFrames >= double(model.censoring.frame_start(row)) & ...
        selectedFrames <= double(model.censoring.frame_end(row)));
    covered = covered(:).';
    if isempty(covered), continue; end
    breaks = [0 find(diff(covered) > 1) numel(covered)];
    for runIndex = 1:numel(breaks)-1
        run = covered(breaks(runIndex)+1:breaks(runIndex+1));
        records(end+1,1) = struct( ... %#ok<AGROW>
            'censor_id',double(model.censoring.censor_id(row)), ...
            'track_id',double(model.censoring.track_id(row)), ...
            'frame_start',double(run(1)), ...
            'frame_end',double(run(end)), ...
            'source_frame_start',double(selectedFrames(run(1))), ...
            'source_frame_end',double(selectedFrames(run(end))), ...
            'scope_flags',double(model.censoring.scope_flags(row)), ...
            'scopes',{scopeNames(model.censoring.scope_flags(row))}, ...
            'reason',namedValue(model.censor_reasons,'reason_id', ...
                model.censoring.reason_id(row)), ...
            'source',namedValue(model.censor_sources,'source_id', ...
                model.censoring.source_id(row)));
    end
end
end

function records = emptyRecords()
records = struct('censor_id',{},'track_id',{}, ...
    'frame_start',{},'frame_end',{}, ...
    'source_frame_start',{},'source_frame_end',{}, ...
    'scope_flags',{},'scopes',{},'reason',{},'source',{});
end

function names = scopeNames(flags)
scope = cellModel.censorScope();
ordered = {'segmentation','tracking','appearance','end','parentage','state'};
names = cell(0,1);
for index = 1:numel(ordered)
    if bitand(uint16(flags),scope.(ordered{index})) ~= 0
        names{end+1,1} = ordered{index}; %#ok<AGROW>
    end
end
end

function value = namedValue(rows,idField,id)
value = '';
if isempty(rows), return; end
hit = find(cast([rows.(idField)],class(id)) == id,1);
if ~isempty(hit), value = char(string(rows(hit).name)); end
end
