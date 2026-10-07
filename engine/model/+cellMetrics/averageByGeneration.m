function [out, report] = averageByGeneration(model, metrics, varargin)
%CELLMETRICS.AVERAGEBYGENERATION Average track metrics between bud emergences.
% Each track is processed independently inside its family. This operation
% neither chooses a lineage nor infers mother->daughter switches.
% Boundaries use canonical child_birth_v2 events with temporal evidence.
% Intervals are [StartFrame, EndFrameExclusive); the final observed frame is
% included in the last interval. Edge intervals remain explicitly partial.
% Generation is a local interval index, not biological age or tree depth.
% Missing/censored frames are never filled. Each metric has its own count.

p=inputParser;
p.addParameter('ExcludeCensored',true,@(x)islogical(x)&&isscalar(x));
p.parse(varargin{:});
model=cellModel.normalize(model);
cellModel.validate(model,'Throw',true);
required={'FamilyId','ObjectId','TrackId','Frame'};
if ~istable(metrics) || ~all(ismember(required,metrics.Properties.VariableNames))
    error('cellMetrics:MissingIdentityColumns', ...
        'Generation averages require FamilyId, ObjectId, TrackId and Frame.');
end
for i=1:numel(required)
    values=metrics.(required{i});
    if ~isnumeric(values)||~isreal(values)||size(values,2)~=1 || ...
            any(~isfinite(values)|values<0|values~=fix(values))
        error('cellMetrics:InvalidMetricIdentity','Identity columns must contain nonnegative scalar integers.');
    end
end
[found,instanceRows]=ismember(metrics.ObjectId,model.instances.object_id);
if any(~found) || numel(unique(metrics.ObjectId))~=height(metrics)
    error('cellMetrics:MetricIdentityMismatch','Metric ObjectIds must be unique and present in the model.');
end
instances=model.instances;
if any(metrics.FamilyId~=instances.family_id(instanceRows)) || ...
        any(metrics.TrackId~=instances.track_id(instanceRows)) || ...
        any(metrics.Frame~=instances.frame(instanceRows))
    error('cellMetrics:MetricIdentityMismatch','Metric family, track and frame must match each ObjectId.');
end

identity=[required {'MaskLabel','StateId','ParentTrackId'}];
metricNames=setdiff(metrics.Properties.VariableNames,identity,'stable');
keep=false(size(metricNames));
for i=1:numel(metricNames)
    values=metrics.(metricNames{i});
    keep(i)=isnumeric(values)&&isreal(values)&&size(values,2)==1;
end
metricNames=metricNames(keep);
out=table(zeros(0,1,'uint32'),zeros(0,1,'uint64'),zeros(0,1,'uint32'), ...
    zeros(0,1),zeros(0,1),zeros(0,1),false(0,1),false(0,1),false(0,1), ...
    false(0,1),zeros(0,1),zeros(0,1),zeros(0,1),zeros(0,1), ...
    false(0,1),false(0,1),'VariableNames', ...
    {'FamilyId','TrackId','Generation','StartFrame','EndFrame','EndFrameExclusive', ...
    'StartObserved','EndObserved','CompleteCycle','HasExcludedEvents', ...
    'DurationFrames','ObservedFrames','ValidFrames','Coverage', ...
    'CompleteSampling','ParentageCensored'});
if any(ismember(metricNames,out.Properties.VariableNames))
    error('cellMetrics:ReservedGenerationVariable','Metric names collide with generation metadata.');
end
countNames=matlab.lang.makeUniqueStrings( ...
    matlab.lang.makeValidName(strcat('ValidCount_',metricNames)), ...
    [out.Properties.VariableNames metricNames],namelengthmax);
for i=1:numel(metricNames)
    out.(metricNames{i})=zeros(0,1); out.(countNames{i})=zeros(0,1);
end
report=struct('roi_id',model.roi_id,'event_convention','child_birth_v2', ...
    'interval_convention','[StartFrame, EndFrameExclusive)', ...
    'generation_semantics','Local per-track interval index; not biological age or genealogical depth.', ...
    'exclude_censored',p.Results.ExcludeCensored, ...
    'metric_variables',{metricNames},'count_variables',{countNames}, ...
    'untracked_rows',nnz(metrics.TrackId==0),'diagnostics',strings(0,1));
scopes=cellModel.censorScope();
metricFlags=bitor(scopes.segmentation,scopes.tracking);
eventFlags=bitor(scopes.parentage,scopes.tracking);

familyIds=unique(metrics.FamilyId(metrics.TrackId>0),'stable');
for familyId=familyIds(:).'
    [evidence,~]=cellModel.parentageEvidence(model,familyId);
    tracks=unique(metrics.TrackId(metrics.FamilyId==familyId & metrics.TrackId>0));
    for trackId=tracks(:).'
        trackRows=find(metrics.FamilyId==familyId & metrics.TrackId==trackId);
        trackFrames=double(metrics.Frame(trackRows));
        allFrames=double(instances.frame(instances.family_id==familyId & instances.track_id==trackId));
        first=min(allFrames); stop=max(allFrames)+1;
        events=zeros(0,1); excluded=zeros(0,1);
        for e=1:numel(evidence)
            link=evidence(e);
            if link.parent_track_id~=trackId, continue; end
            birth=double(link.event_frame);
            usable=link.temporal_parentage_eligible;
            if p.Results.ExcludeCensored
                usable=usable && ~any(censored(model,familyId,trackId,[birth-1 birth],eventFlags)) && ...
                    ~censored(model,familyId,link.child_track_id,birth,eventFlags);
            end
            if usable
                events(end+1,1)=birth; %#ok<AGROW>
            else
                excluded(end+1,1)=birth; %#ok<AGROW>
                report.diagnostics(end+1,1)=sprintf( ...
                    'Family %u track %u: ignored child %u boundary at frame %d (%s or explicit censoring).', ...
                    familyId,trackId,link.child_track_id,birth,link.evidence_mode); %#ok<AGROW>
            end
        end
        events=unique(events(events>=first & events<stop));
        boundaries=unique([first; events; stop]);
        valid=true(size(trackFrames));
        if p.Results.ExcludeCensored
            valid=~censored(model,familyId,trackId,trackFrames,metricFlags);
        end
        for g=1:numel(boundaries)-1
            start=boundaries(g); finish=boundaries(g+1);
            selected=trackFrames>=start & trackFrames<finish;
            if ~any(selected), continue; end
            usableRows=trackRows(selected & valid);
            nObserved=nnz(selected); nValid=numel(usableRows); duration=finish-start;
            startObserved=ismember(start,events); endObserved=ismember(finish,events);
            hasExcluded=any(excluded>=start & excluded<=finish);
            parentageCensored=false;
            if p.Results.ExcludeCensored
                parentageCensored=intervalCensored(model,familyId,trackId,start,finish-1,eventFlags);
            end
            row=table(uint32(familyId),uint64(trackId),uint32(g),start,finish-1,finish, ...
                startObserved,endObserved,startObserved&&endObserved&&~hasExcluded&&~parentageCensored, ...
                hasExcluded,duration,nObserved,nValid,nValid/duration,nValid==duration,parentageCensored, ...
                'VariableNames',out.Properties.VariableNames(1:16));
            for v=1:numel(metricNames)
                values=double(metrics.(metricNames{v})(usableRows));
                values=values(isfinite(values));
                value=NaN;
                if ~isempty(values), value=mean(values); end
                row.(metricNames{v})=value;
                row.(countNames{v})=numel(values);
            end
            out=[out; row]; %#ok<AGROW>
        end
    end
end
report.interval_count=height(out);
report.complete_cycle_count=nnz(out.CompleteCycle);
end

function tf=censored(model,familyId,trackId,frames,flags)
tf=false(size(frames)); c=model.censoring;
rows=find(c.family_id==familyId & c.track_id==trackId & bitand(c.scope_flags,flags)~=0);
for r=rows(:).'
    tf=tf | (frames>=double(c.frame_start(r)) & frames<=double(c.frame_end(r)));
end
end

function tf=intervalCensored(model,familyId,trackId,start,finish,flags)
c=model.censoring;
tf=any(c.family_id==familyId & c.track_id==trackId & bitand(c.scope_flags,flags)~=0 & ...
    double(c.frame_start)<=finish & double(c.frame_end)>=start);
end
