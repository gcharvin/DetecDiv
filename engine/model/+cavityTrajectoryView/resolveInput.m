function [assignments,events,lifespans,metadata] = resolveInput(input)
%CAVITYTRAJECTORYVIEW.RESOLVEINPUT Normalize result, dataseries, table or JSON.

events=table(); lifespans=table(); metadata=struct();
if isa(input,'dataseries')
    assignments=input.data;
    if isstruct(input.userData)
        metadata=input.userData;
        if isfield(input.userData,'events'), events=input.userData.events; end
        if isfield(input.userData,'lifespans'), lifespans=input.userData.lifespans; end
    end
elseif istable(input)
    assignments=input;
elseif isstruct(input)&&isfield(input,'assignments')
    assignments=toTable(input.assignments);
    if isfield(input,'events'), events=toTable(input.events); end
    if isfield(input,'lifespans'), lifespans=toTable(input.lifespans); end
    metadata=input;
elseif ischar(input)||isstring(input)
    payload=jsondecode(fileread(char(string(input))));
    [assignments,events,lifespans,metadata]=cavityTrajectoryView.resolveInput(payload);
    return;
else
    error('cavityTrajectoryView:InvalidInput', ...
        'Input must be a cavity result, dataseries, table, or JSON artifact.');
end
required={'Frame','OccupancyEpisodeID','TargetTrackID','SubjectID', ...
    'SelectionConfidence','Abstained'};
if ~istable(assignments)||~all(ismember(required,assignments.Properties.VariableNames))
    error('cavityTrajectoryView:InvalidAssignments', ...
        'Assignment table does not match cavity trajectory schema v1.');
end
if isempty(lifespans), lifespans=deriveLifespans(assignments); end
if isempty(events), events=emptyEvents(); end
end

function value=toTable(value)
if istable(value), return; end
if isempty(value), value=table();
elseif isstruct(value), value=struct2table(value);
else, error('cavityTrajectoryView:InvalidTable','Artifact table has invalid encoding.'); end
end

function out=deriveLifespans(assign)
ids=unique(assign.OccupancyEpisodeID(assign.OccupancyEpisodeID>0));
out=table();
for i=1:numel(ids)
    mask=assign.OccupancyEpisodeID==ids(i)&assign.TargetTrackID>0&~assign.Abstained;
    first=find(mask,1,'first'); last=find(mask,1,'last');
    row=table(uint32(ids(i)),uint32(assign.TrajectoryID(first)), ...
        uint64(assign.SubjectID(first)),uint64(assign.TargetTrackID(first)), ...
        uint32(assign.Frame(first)),uint32(assign.Frame(last)),uint32(sum(mask)), ...
        logical(first==1),logical(last==height(assign)), ...
        single(mean(assign.SelectionConfidence(mask),'omitnan')), ...
        'VariableNames',{'OccupancyEpisodeID','TrajectoryID','SubjectID', ...
        'InitialTrackID','StartFrame','EndFrame','ObservedFrames', ...
        'LeftCensored','RightCensored','MeanConfidence'});
    if isempty(out), out=row; else, out=[out;row]; end %#ok<AGROW>
end
end

function out=emptyEvents()
out=table(zeros(0,1,'uint32'),zeros(0,1,'uint32'),zeros(0,1,'uint64'), ...
    zeros(0,1,'uint64'),strings(0,1),zeros(0,1,'single'),strings(0,1), ...
    'VariableNames',{'EventFrame','DecisionFrame','FromTrackID','ToTrackID', ...
    'TransitionType','Confidence','EvidenceSources'});
end
