function plan = recoverAnnotated(classif, indices)
%RECOVERANNOTATED Recover historical scopes, falling back to labelled extent.
% Explicit current bounds take precedence. Undefined interior frames are kept
% in scope so ordinary validation still reports them.
template=struct('roiIndex',0,'bounds',[],'source','','message','');
plan=repmat(template,numel(indices),1);
for k=1:numel(indices)
    i=indices(k); r=classif.roi(i); plan(k).roiIndex=i;
    try
        [current,info]=trainingBounds.resolve(classif,i);
        if ~isempty(current) && ~startsWith(info.source,'legacy')
            plan(k).bounds=current; plan(k).source='current'; continue;
        end
        annotationManager.readManifest(r); % load data only when needed
        di=find(strcmp({r.data.groupid},classif.strid),1);
        if isempty(di)||~ismember('labels_training',r.data(di).data.Properties.VariableNames)
            error('trainingBounds:MissingLabels','No frame-label ground truth.');
        end
        values=r.data(di).data.labels_training;
        names=lower(strtrim(string(values)));
        defined=~ismissing(names)&names~=""&names~="undefined"&names~="<undefined>";
        if isnumeric(values)||islogical(values)
            defined=isfinite(double(values))&double(values)>0;
        end
        if ~any(defined)
            error('trainingBounds:EmptyLabels','No defined label; no annotated interval can be recovered.');
        end
        count=annotationManager.frameCount(r);
        ud=r.data(di).userData; legacy=[];
        for field={'userbounds','bounds'}
            candidate=[];
            if isstruct(ud)&&isfield(ud,field{1}),candidate=ud.(field{1});end
            if isa(ud,'containers.Map')&&isKey(ud,field{1}),candidate=ud(field{1});end
            if isempty(candidate)||isequal(candidate,[0 0]),continue;end
            if isnumeric(candidate)&&numel(candidate)==2&&candidate(1)==0&&candidate(2)>0
                candidate(1)=1; % historical zero start means from the beginning
            end
            legacy=trainingBounds.parse(candidate,'FrameCount',count);
            if ~isempty(legacy),break;end
        end
        if ~isempty(legacy)
            plan(k).bounds=legacy; plan(k).source='historical';
        else
            frames=find(defined);
            plan(k).bounds=trainingBounds.parse([frames(1) frames(end)],'FrameCount',count);
            plan(k).source='annotated';
        end
    catch ME
        plan(k).source='unavailable'; plan(k).message=ME.message;
    end
end
usable=~strcmp({plan.source},'unavailable');
if ~any(usable),return;end
% Switching to Manual must preserve every unselected ROI's effective scope,
% including Auto/all, rather than accidentally activating its legacy bounds.
previous=cell(1,numel(classif.roi));
for i=1:numel(classif.roi)
    previous{i}=trainingBounds.resolve(classif,i);
    if isempty(previous{i}),previous{i}=[1 annotationManager.frameCount(classif.roi(i))];end
end
for i=1:numel(previous)
    if previous{i}(end)>=1,trainingBounds.setRoi(classif,i,previous{i});end
end
for k=find(usable(:).')
    trainingBounds.setRoi(classif,plan(k).roiIndex,plan(k).bounds);
end
end
