function summary=cellFateSummary(classif,varargin)
%CELLFATESUMMARY Read-only ROI-level synthesis of saved predictions/reviewed GT.
% Summary policy is separate from all model parameters and input bindings.
p=inputParser;p.addParameter('Rois',[]);p.addParameter('MinEpisodeWindows',2);p.parse(varargin{:});
assert(lstm_timeseries.supportsCellFate(classif),'lstm_timeseries:FateUnsupported', ...
    'Cell fate requires window output and the classes budding, arrested and dead.');
minimum=p.Results.MinEpisodeWindows;lstm_timeseries.cellFateSequence([],[],[],minimum);
rois=p.Results.Rois;if isempty(rois),try,rois=classif.dataset.split.test;catch,end,end
rois=unique(double(rois(:).'),'stable');
assert(~isempty(rois)&&all(isfinite(rois)&rois==fix(rois)&rois>=1&rois<=numel(classif.roi)), ...
    'lstm_timeseries:NoTestRois','Select ROI(s) for cell fate synthesis.');
for k=rois,if isempty(classif.roi(k).data),classif.roi(k).load('Data','Silent');end,end
params=lstm_timeseries.parameters(classif);spec=annotationManager.specForClassifier(classif);
reviewed=annotationManager.reviewedFramesForClassifier(classif,rois);
execution=lstm_timeseries.executionSpec(classif);predictionGroup=char(string(execution.defaults.outputName));
rows=struct('roiIndex',{},'roiId',{},'firstFrame',{},'lastFrame',{},'availableLastFrame',{}, ...
    'nWindows',{},'predictionWindows',{},'reviewedGTWindows',{},'prediction',{},'truth',{}, ...
    'terminalPrediction',{},'terminalTruth',{},'ignoredShortArrests',{},'predictionNote',{},'truthNote',{});
records=cell(1,numel(rois));classes={'adapted','transient_arrest','persistent_arrest','dead'};
for j=1:numel(rois)
    k=rois(j);r=classif.roi(k);n=annotationManager.frameCount(r);
    base=trainingBounds.frames(classif,r,n,[]);units=lstm_timeseries.sequences(classif,r,n,base,params);
    first=cellfun(@(f)f(1),units);last=cellfun(@(f)f(end),units);
    gt=find(strcmp(string({r.data.groupid}),string(spec.components(1).groundTruth.groupId)),1);
    pred=find(strcmp(string({r.data.groupid}),string(predictionGroup)),1);
    truth=windowLabels(r,gt,'labels_training',units,reviewed.(sprintf('roi%d',k)),n);
    predicted=windowLabels(r,pred,'labels',units,base,n);
    if ~isempty(pred)
        meta=r.data(pred).userData;
        if isstruct(meta)&&isfield(meta,'outputMode')
            assert(strcmp(meta.outputMode,'window')&&meta.windowLength==params.windowLength, ...
                'lstm_timeseries:StalePredictions','ROI %s predictions use another window mode/length.',r.id);
        end
        scope='window';if isstruct(meta)&&isfield(meta,'sequenceScope'),scope=meta.sequenceScope;end
        assert(strcmp(scope,params.sequenceScope),'lstm_timeseries:StalePredictions','ROI %s predictions use another sequence scope.',r.id);
        if isstruct(meta)&&isfield(meta,'networkArchitecture')
            assert(strcmp(meta.networkArchitecture,params.networkArchitecture),'lstm_timeseries:StalePredictions','ROI %s predictions use another architecture.',r.id);
        end
    end
    a=lstm_timeseries.cellFateSequence(predicted,first,last,minimum);
    b=lstm_timeseries.cellFateSequence(truth,first,last,1); % reviewed GT is never smoothed
    if ~isempty(base)&&~isempty(last)&&last(end)~=base(end)
        a.population='unresolved';a.reason='Incomplete terminal window';
        b.population='unresolved';b.reason='Incomplete terminal window';
    end
    begin=NaN;finish=NaN;if ~isempty(first),begin=first(1);finish=last(end);end
    rows(end+1)=struct('roiIndex',k,'roiId',r.id,'firstFrame',begin,'lastFrame',finish,'availableLastFrame',n, ...
        'nWindows',numel(units),'predictionWindows',nnz(predicted~="undefined"),'reviewedGTWindows',nnz(truth~="undefined"), ...
        'prediction',a.population,'truth',b.population,'terminalPrediction',a.terminalState,'terminalTruth',b.terminalState, ...
        'ignoredShortArrests',a.ignoredShortArrestEpisodes,'predictionNote',a.reason,'truthNote',b.reason); %#ok<AGROW>
    records{j}=struct('roiIndex',k,'roiId',r.id,'firstFrames',first,'lastFrames',last, ...
        'predictedStates',predicted,'reviewedTruthStates',truth,'prediction',a,'truth',b);
end
tableRows=struct2table(rows,'AsArray',true);[knownTruth,t]=ismember(tableRows.truth,classes);[knownPrediction,q]=ismember(tableRows.prediction,classes);
paired=knownTruth&knownPrediction;matrix=zeros(4);if any(paired),matrix=accumarray([t(paired) q(paired)],1,[4 4]);end
counts=table(string(classes(:)),arrayfun(@(k)nnz(t==k),(1:4)'),arrayfun(@(k)nnz(q==k),(1:4)'), ...
    'VariableNames',{'Population','ReviewedGT','Predicted'});
support=sum(matrix,2);tp=diag(matrix);precision=tp./max(1,sum(matrix,1)');recall=tp./max(1,support);
f1=2*precision.*recall./max(eps,precision+recall);recall(support==0)=NaN;f1(support==0)=NaN;
accuracy=NaN;if any(paired),accuracy=sum(tp)/nnz(paired);end
summary=struct('schema','detecdiv.cell_fate_summary.v1','classifierId',classif.strid, ...
    'classNames',{classes},'windowLength',params.windowLength,'minEpisodeWindows',minimum, ...
    'confirmationFrames',minimum*params.windowLength,'roiIndices',rois,'N',numel(rois), ...
    'Npaired',nnz(paired),'unresolvedPredictions',nnz(~knownPrediction),'unresolvedTruth',nnz(~knownTruth), ...
    'counts',counts,'confusion',matrix,'accuracy',accuracy,'rois',tableRows,'records',{records}, ...
    'classes',table(string(classes(:)),support,precision,recall,f1,'VariableNames',{'Population','Support','Precision','Recall','F1'}), ...
    'comments','Observed fate within configured bounds, not proof of irreversible arrest or viability. GT is unchanged. Missing/gapped coverage stays unresolved. Prediction confirmation is a descriptive policy, not a newly trained or independently validated model.');
end
function labels=windowLabels(r,index,field,units,eligible,n)
labels=repmat("undefined",1,numel(units));if isempty(index),return;end
tbl=r.data(index).data;if ~ismember(field,tbl.Properties.VariableNames),return;end
frames=(1:height(tbl))';if ismember('frame',tbl.Properties.VariableNames),frames=double(tbl.frame);end
assert(isvector(frames)&&numel(frames)==height(tbl)&&all(isfinite(frames)&frames==fix(frames)&frames>=1&frames<=n)&&numel(unique(frames))==numel(frames), ...
    'lstm_timeseries:FrameAlignment','Fate labels require unique absolute ROI frames.');
aligned=repmat("undefined",1,n);values=string(tbl.(field));known=ismember(values,["budding","arrested","dead"]);aligned(frames(known))=values(known);
for k=1:numel(units)
    f=units{k};if ~all(ismember(f,eligible)),continue;end
    states=unique(aligned(f));if isscalar(states)&&states~="undefined",labels(k)=states;end
end
end
