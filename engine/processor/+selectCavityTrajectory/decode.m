function result = decode(model,familyId,observations,param,imageSize,nFrames)
%SELECTCAVITYTRAJECTORY.DECODE Global TrackID/NULL dynamic program.
%
% observations is a row-aligned struct with frame, track_id, mask_label,
% centroid_x, centroid_y and area columns. Frames are 1-based.

param=selectCavityTrajectory.normalizeParam(param,struct());
required={'frame','track_id','mask_label','centroid_x','centroid_y','area'};
if ~isstruct(observations) || ~all(isfield(observations,required))
    error('selectCavityTrajectory:InvalidObservations', ...
        'Observations lack required instance geometry fields.');
end
if nargin < 6 || isempty(nFrames)
    nFrames=max([double(observations.frame(:));0]);
end
if nargin < 5 || numel(imageSize)<2
    error('selectCavityTrajectory:InvalidImageSize','imageSize must be [height width].');
end
nFrames=max(1,round(double(nFrames)));
imageHeight=max(1,double(imageSize(1))); imageWidth=max(1,double(imageSize(2)));

frame=double(observations.frame(:));
track=uint64(observations.track_id(:));
maskLabel=uint32(observations.mask_label(:));
x=double(observations.centroid_x(:)); y=double(observations.centroid_y(:));
area=double(observations.area(:));
valid=frame>=1 & frame<=nFrames & track>0 & isfinite(x) & isfinite(y) & area>0;
frame=frame(valid); track=track(valid); maskLabel=maskLabel(valid);
x=x(valid); y=y(valid); area=area(valid);
trackIds=unique(track,'stable'); nTracks=numel(trackIds); nStates=nTracks+1;

visible=false(nTracks,nFrames); allowed=false(nTracks,nFrames);
labels=zeros(nTracks,nFrames,'uint32'); xpos=nan(nTracks,nFrames);
ypos=nan(nTracks,nFrames); areas=nan(nTracks,nFrames);
for row=1:numel(frame)
    k=find(trackIds==track(row),1,'first'); t=frame(row);
    if visible(k,t)
        error('selectCavityTrajectory:DuplicateTrackFrame', ...
            'Track %u has more than one observation at frame %d.',track(row),t);
    end
    visible(k,t)=true; allowed(k,t)=true; labels(k,t)=maskLabel(row);
    xpos(k,t)=x(row); ypos(k,t)=y(row); areas(k,t)=area(row);
end
for k=1:nTracks
    frames=find(visible(k,:));
    for j=1:max(0,numel(frames)-1)
        gap=(frames(j)+1):(frames(j+1)-1);
        if ~isempty(gap) && numel(gap)<=param.maxVirtualGapFrames
            allowed(k,gap)=true;
        end
    end
end

axis=[param.trapAxisX param.trapAxisY]; axis=axis./norm(axis);
xn=(xpos-1)./max(imageWidth-1,1); yn=(ypos-1)./max(imageHeight-1,1);
tipScore=0.5+param.tipDirection.*(((xn-0.5).*axis(1)+(yn-0.5).*axis(2))./sqrt(2));
tipScore=max(0,min(1,tipScore));
emission=-inf(nStates,nFrames); emission(1,:)=param.abstainScore;
for t=1:nFrames
    frameAreas=areas(:,t); maxArea=max(frameAreas,[],'omitnan');
    if isempty(maxArea)||~isfinite(maxArea)||maxArea<=0, maxArea=1; end
    for k=1:nTracks
        if ~allowed(k,t), continue; end
        if visible(k,t)
            if strcmp(param.mode,'mother_resident')
                d=hypot(xn(k,t)-param.anchorXNormalized, ...
                    yn(k,t)-param.anchorYNormalized)/sqrt(2);
                position=max(0,1-d);
            else
                position=tipScore(k,t);
            end
            relativeArea=log1p(areas(k,t))/log1p(maxArea);
            emission(k+1,t)=param.positionWeight*position+ ...
                param.areaWeight*relativeArea;
        else
            emission(k+1,t)=-param.gapPenalty;
        end
    end
end

[parentIds,childIds,eventFrames,relationConfidence]=relationsForFamily(model,familyId);
delta=-inf(nStates,nFrames); back=zeros(nStates,nFrames,'uint32');
delta(:,1)=emission(:,1);
for t=2:nFrames
    for current=1:nStates
        if ~isfinite(emission(current,t)), continue; end
        best=-inf; bestPrevious=uint32(0);
        for previous=1:nStates
            if ~isfinite(delta(previous,t-1)), continue; end
            transition=transitionScore(previous,current,t);
            score=delta(previous,t-1)+transition;
            if score>best, best=score; bestPrevious=uint32(previous); end
        end
        delta(current,t)=best+emission(current,t);
        back(current,t)=bestPrevious;
    end
end
[~,state]=max(delta(:,end)); statePath=zeros(nFrames,1,'uint32');
statePath(end)=uint32(state);
for t=nFrames:-1:2
    previous=back(statePath(t),t);
    if previous==0, previous=uint32(1); end
    statePath(t-1)=previous;
end

selectedTrack=zeros(nFrames,1,'uint64'); selectedLabel=zeros(nFrames,1,'uint32');
selectedVisible=false(nFrames,1); confidence=zeros(nFrames,1,'single');
for t=1:nFrames
    s=double(statePath(t));
    if s>1
        selectedTrack(t)=trackIds(s-1); selectedLabel(t)=labels(s-1,t);
        selectedVisible(t)=visible(s-1,t);
    end
    competitors=delta(:,t); competitors(s)=-inf;
    alternative=max(competitors);
    margin=delta(s,t)-alternative;
    if ~isfinite(margin), margin=20; end
    confidence(t)=single(1/(1+exp(-margin/param.confidenceTemperature)));
end

[assignments,events,lifespans]=materializeTables();
result=struct('format','detecdiv_cavity_trajectory','schema_version',1, ...
    'family_id',double(familyId),'mode',param.mode, ...
    'confidence_semantics','uncalibrated_viterbi_path_margin', ...
    'assignments',assignments,'events',events,'lifespans',lifespans, ...
    'diagnostics',struct('tracks',nTracks,'frames',nFrames, ...
        'abstained_frames',sum(assignments.Abstained), ...
        'occupancy_episodes',height(lifespans),'events',height(events)));

    function value=transitionScore(previous,current,t)
        if previous==1 && current==1, value=0; return; end
        if previous==1 && current>1, value=-param.appearancePenalty; return; end
        if previous>1 && current==1, value=-param.gapPenalty; return; end
        previousTrack=trackIds(previous-1); currentTrack=trackIds(current-1);
        if previousTrack==currentTrack, value=param.stayBonus; return; end
        relation=find(parentIds==previousTrack & childIds==currentTrack,1,'first');
        if ~isempty(relation) && strcmp(param.mode,'daughter_tip') && ...
                param.allowLineageHandover
            age=t-double(eventFrames(relation));
            if age<param.minHandoverAgeFrames, value=-inf; return; end
            currentTip=tipScore(current-1,t);
            previousTip=tipScore(previous-1,t);
            if ~isfinite(previousTip), previousTip=0; end
            gain=currentTip-previousTip;
            if ~isfinite(currentTip)||gain<param.minHandoverTipGain
                value=-inf; return;
            end
            p=double(relationConfidence(relation));
            if ~isfinite(p)||p<=0||p>1, p=0.5; end
            value=param.stayBonus-param.lineageHandoverPenalty+log(max(p,eps))+ ...
                param.handoverTipGainWeight*gain;
        elseif param.allowUnrelatedReplacement
            value=-param.replacementPenalty;
        else
            value=-inf;
        end
    end

    function [assign,eventTable,lifespanTable]=materializeTables()
        frames=uint32((1:nFrames)'); trajectory=ones(nFrames,1,'uint32');
        subject=selectedTrack; episode=zeros(nFrames,1,'uint32');
        companion=zeros(nFrames,1,'uint64'); role=strings(nFrames,1);
        transition=strings(nFrames,1); qc=strings(nFrames,1);
        eventRows=cell(0,7); episodeId=uint32(0); lastNonzero=uint64(0);
        for tt=1:nFrames
            current=selectedTrack(tt);
            previousFrame=uint64(0);
            if tt>1, previousFrame=selectedTrack(tt-1); end
            if current==0 || ~selectedVisible(tt)
                role(tt)="gap"; qc(tt)="no_visible_target";
                previousWasVisible=tt>1 && selectedVisible(tt-1) && previousFrame>0;
                if previousWasVisible
                    transition(tt)="gap_start";
                    eventRows(end+1,:)={uint32(tt),uint32(tt),previousFrame,uint64(0), ...
                        transition(tt),confidence(tt),"visibility"}; %#ok<AGROW>
                else
                    transition(tt)="gap";
                end
                if episodeId>0, episode(tt)=episodeId; end
                if current>0, lastNonzero=current; end
                continue;
            end
            if strcmp(param.mode,'mother_resident'), role(tt)="resident";
            else, role(tt)="tip"; end
            if episodeId==0
                episodeId=uint32(1); transition(tt)="episode_start";
            elseif tt>1 && ~selectedVisible(tt-1)
                if lastNonzero==current
                    transition(tt)="gap_close";
                else
                    episodeId=episodeId+1;
                    transition(tt)=switchType(lastNonzero,current);
                end
            elseif previousFrame==current
                transition(tt)="continuation";
            else
                episodeId=episodeId+1;
                transition(tt)=switchType(previousFrame,current);
            end
            episode(tt)=episodeId; lastNonzero=current;
            companion(tt)=companionFor(current,tt);
            if selectedVisible(tt), qc(tt)="ok"; else, qc(tt)="virtual_gap"; end
            if transition(tt)~="continuation"
                from=previousFrame;
                if from==0, from=lastTrackBefore(tt); end
                eventRows(end+1,:)={uint32(tt),uint32(tt),from,current, ...
                    transition(tt),confidence(tt),evidenceFor(transition(tt))}; %#ok<AGROW>
            end
        end
        abstained=selectedTrack==0 | ~selectedVisible;
        assign=table(frames,trajectory,episode,selectedTrack,subject,companion, ...
            selectedLabel,role,transition,confidence,abstained,qc, ...
            'VariableNames',{'Frame','TrajectoryID','OccupancyEpisodeID', ...
            'TargetTrackID','SubjectID','CompanionBudTrackID','MaskLabel', ...
            'Role','TransitionType','SelectionConfidence','Abstained','QCFlags'});
        if isempty(eventRows)
            eventTable=table(zeros(0,1,'uint32'),zeros(0,1,'uint32'), ...
                zeros(0,1,'uint64'),zeros(0,1,'uint64'),strings(0,1), ...
                zeros(0,1,'single'),strings(0,1),'VariableNames', ...
                {'EventFrame','DecisionFrame','FromTrackID','ToTrackID', ...
                'TransitionType','Confidence','EvidenceSources'});
        else
            eventTable=cell2table(eventRows,'VariableNames', ...
                {'EventFrame','DecisionFrame','FromTrackID','ToTrackID', ...
                'TransitionType','Confidence','EvidenceSources'});
            eventTable.EventFrame=uint32(cell2mat(eventRows(:,1)));
            eventTable.DecisionFrame=uint32(cell2mat(eventRows(:,2)));
            eventTable.FromTrackID=uint64(cell2mat(eventRows(:,3)));
            eventTable.ToTrackID=uint64(cell2mat(eventRows(:,4)));
            eventTable.TransitionType=string(eventRows(:,5));
            eventTable.Confidence=single(cell2mat(eventRows(:,6)));
            eventTable.EvidenceSources=string(eventRows(:,7));
        end
        lifespanTable=buildLifespans(assign,nFrames);
    end

    function kind=switchType(from,to)
        if any(parentIds==from & childIds==to) && strcmp(param.mode,'daughter_tip')
            kind="lineage_handover";
        else
            kind="unrelated_replacement";
        end
    end

    function value=lastTrackBefore(t)
        value=uint64(0);
        if t<=1, return; end
        row=find(selectedTrack(1:t-1)>0,1,'last');
        if ~isempty(row), value=selectedTrack(row); end
    end

    function value=evidenceFor(kind)
        if kind=="lineage_handover", value="geometry+parentage";
        elseif kind=="unrelated_replacement", value="geometry+appearance_end";
        elseif kind=="gap_close", value="stable_track_identity";
        else, value="geometry"; end
    end

    function child=companionFor(parent,t)
        child=uint64(0); rows=find(parentIds==parent);
        if isempty(rows), return; end
        candidates=zeros(0,4);
        for rr=rows(:)'
            age=t-double(eventFrames(rr));
            if age<0 || age>param.maxCompanionAgeFrames, continue; end
            k=find(trackIds==childIds(rr),1,'first');
            p=find(trackIds==parent,1,'first');
            if isempty(k)||isempty(p)||~visible(k,t), continue; end
            distance=hypot(xpos(k,t)-xpos(p,t),ypos(k,t)-ypos(p,t));
            candidates(end+1,:)=[double(childIds(rr)) age distance double(eventFrames(rr))]; %#ok<AGROW>
        end
        if isempty(candidates), return; end
        [~,order]=sortrows([-candidates(:,4),candidates(:,3)],[1 2]);
        child=uint64(candidates(order(1),1));
    end
end

function [parent,child,eventFrame,confidence]=relationsForFamily(model,familyId)
parent=zeros(0,1,'uint64'); child=zeros(0,1,'uint64');
eventFrame=zeros(0,1,'uint32'); confidence=zeros(0,1,'single');
if ~isstruct(model)||~isfield(model,'relations'), return; end
r=model.relations; rows=r.family_id==uint32(familyId) & r.type_id==uint8(1);
parent=uint64(r.parent_track_id(rows)); child=uint64(r.child_track_id(rows));
eventFrame=uint32(r.event_frame(rows)); confidence=single(r.confidence(rows));
end

function out=buildLifespans(assign,nFrames)
ids=unique(assign.OccupancyEpisodeID(assign.OccupancyEpisodeID>0));
rows=cell(numel(ids),10);
for i=1:numel(ids)
    mask=assign.OccupancyEpisodeID==ids(i) & assign.TargetTrackID>0 & ~assign.Abstained;
    first=find(mask,1,'first'); last=find(mask,1,'last');
    rows(i,:)={ids(i),assign.TrajectoryID(first),assign.SubjectID(first), ...
        assign.TargetTrackID(first),assign.Frame(first),assign.Frame(last), ...
        uint32(sum(mask)),assign.Frame(first)==1,assign.Frame(last)==nFrames, ...
        single(mean(assign.SelectionConfidence(mask),'omitnan'))};
end
if isempty(rows)
    out=table(zeros(0,1,'uint32'),zeros(0,1,'uint32'),zeros(0,1,'uint64'), ...
        zeros(0,1,'uint64'),zeros(0,1,'uint32'),zeros(0,1,'uint32'), ...
        zeros(0,1,'uint32'),false(0,1),false(0,1),zeros(0,1,'single'), ...
        'VariableNames',{'OccupancyEpisodeID','TrajectoryID','SubjectID', ...
        'InitialTrackID','StartFrame','EndFrame','ObservedFrames', ...
        'LeftCensored','RightCensored','MeanConfidence'});
else
    out=cell2table(rows,'VariableNames',{'OccupancyEpisodeID','TrajectoryID', ...
        'SubjectID','InitialTrackID','StartFrame','EndFrame','ObservedFrames', ...
        'LeftCensored','RightCensored','MeanConfidence'});
    out.OccupancyEpisodeID=uint32(cell2mat(rows(:,1)));
    out.TrajectoryID=uint32(cell2mat(rows(:,2)));
    out.SubjectID=uint64(cell2mat(rows(:,3)));
    out.InitialTrackID=uint64(cell2mat(rows(:,4)));
    out.StartFrame=uint32(cell2mat(rows(:,5)));
    out.EndFrame=uint32(cell2mat(rows(:,6)));
    out.ObservedFrames=uint32(cell2mat(rows(:,7)));
    out.LeftCensored=logical(cell2mat(rows(:,8)));
    out.RightCensored=logical(cell2mat(rows(:,9)));
    out.MeanConfidence=single(cell2mat(rows(:,10)));
end
end
