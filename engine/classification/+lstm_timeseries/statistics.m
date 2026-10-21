function [score, fig] = statistics(classif, varargin)
%STATISTICS Compare reviewed GT and predictions at the classifier output unit.
% No inference, image load, model fitting or source-file writes occur here.
rois=[];explicitRois=false;silent=false;export='';show=false;plotRois=false;
i=1;
while i<=numel(varargin)
    key=lower(string(varargin{i}));
    switch key
        case 'rois'
            rois=varargin{i+1};explicitRois=true;i=i+1;
        case 'export'
            export=char(string(varargin{i+1}));i=i+1;
        case 'silent'
            silent=true;
        case {'confusion','classes','roi'}
            show=true;
            if key=="roi",plotRois=true;end
        case 'force'
            % Always derive statistics from the current prediction/GT data.
        otherwise
            error('lstm_timeseries:StatisticsOption','Unsupported statistics option "%s".',key);
    end
    i=i+1;
end
if ~explicitRois
    try,rois=classif.dataset.split.test;catch,end
end
rois=unique(double(rois(:).'),'stable');
assert(~isempty(rois)&&all(isfinite(rois)&rois==fix(rois)&rois>=1&rois<=numel(classif.roi)), ...
    'lstm_timeseries:NoTestRois','Select test ROIs before displaying statistics.');
p=lstm_timeseries.parameters(classif);names=cellstr(string(classif.classes(:).'));C=numel(names);
spec=annotationManager.specForClassifier(classif);
selection=annotationManager.reviewedFramesForClassifier(classif,rois);
predictionGroup=classif.strid;
try
    e=lstm_timeseries.executionSpec(classif);predictionGroup=char(string(e.defaults.outputName));
catch
end
samples=struct('roiIndex',{},'roiId',{},'firstFrame',{},'lastFrame',{},'truth',{},'prediction',{});
missingPredictionRois=[];
for k=rois
    r=classif.roi(k);selected=selection.(sprintf('roi%d',k));
    if isempty(selected),continue;end
    gtIndex=find(strcmp(string({r.data.groupid}),string(spec.components(1).groundTruth.groupId)),1);
    predIndex=find(strcmp(string({r.data.groupid}),string(predictionGroup)),1);
    if isempty(gtIndex),continue;end
    if isempty(predIndex)||~ismember('labels',r.data(predIndex).data.Properties.VariableNames)
        missingPredictionRois(end+1)=k;continue; %#ok<AGROW>
    end
    metadata=r.data(predIndex).userData;
    if isstruct(metadata)&&isfield(metadata,'outputMode')
        assert(strcmp(metadata.outputMode,p.outputMode)&&metadata.windowLength==p.windowLength, ...
            'lstm_timeseries:StalePredictions','ROI %s predictions use another output mode/window length. Run validation with the current model.',r.id);
    end
    n=annotationManager.frameCount(r);
    truth=alignedLabels(r.data(gtIndex).data,'labels_training',n,names);
    predicted=alignedLabels(r.data(predIndex).data,'labels',n,names);
    eligible=selected(truth(selected)>0);
    units=lstm_timeseries.sequences(classif,r,n,eligible,p);
    for j=1:numel(units)
        frames=units{j};
        if strcmp(p.outputMode,'frame')
            for frame=frames
                if predicted(frame)>0,appendSample(frame);end
            end
        else
            assert(numel(unique(truth(frames)))==1,'lstm_timeseries:ConflictingWindowGT', ...
                'ROI %s frames %d:%d contain conflicting GT labels.',r.id,frames(1),frames(end));
            if any(predicted(frames)==0),continue;end
            assert(numel(unique(predicted(frames)))==1,'lstm_timeseries:InconsistentPredictionUnit', ...
                'ROI %s has varying predictions inside one %s. Run validation again.',r.id,p.outputMode);
            appendSample(frames);
        end
    end
end
assert(isempty(missingPredictionRois),'lstm_timeseries:MissingPredictions', ...
    'Run Validate classifier on test ROI(s) %s before displaying statistics.',mat2str(missingPredictionRois));
assert(~isempty(samples),'lstm_timeseries:NoEvaluationSamples', ...
    'No complete reviewed %s with matching predictions. Validate the test ROIs and review complete annotation units.',p.outputMode);
truth=[samples.truth];predicted=[samples.prediction];
matrix=accumarray([truth(:) predicted(:)],1,[C C]);
support=sum(matrix,2);predictedCount=sum(matrix,1).';tp=diag(matrix);
precision=tp./max(1,predictedCount);recall=tp./max(1,support);
f1=2*precision.*recall./max(eps,precision+recall);recall(support==0)=NaN;f1(support==0)=NaN;
classScores=struct('name',{},'precision',{},'accuracy',{},'recall',{},'fscore',{},'support',{},'N',{});
for j=1:C
    classScores(j)=struct('name',names{j},'precision',precision(j),'accuracy',precision(j), ...
        'recall',recall(j),'fscore',f1(j),'support',support(j),'N',support(j));
end
score=struct('accuracy',sum(tp)/numel(samples),'precision',mean(precision(support>0)), ...
    'recall',mean(recall(support>0)),'fscore',mean(f1(support>0)), ...
    'N',numel(samples),'confusion',matrix,'confusionLbl',1:C,'classNames',{names}, ...
    'classes',classScores,'roiIndices',rois,'outputMode',p.outputMode, ...
    'windowLength',p.windowLength,'samples',struct2table(samples), ...
    'comments','Agreement with reviewed ground truth; one sample per output unit.');
roiScores=struct('roiIndex',{},'roiId',{},'N',{},'accuracy',{});
for k=rois
    used=[samples.roiIndex]==k;
    if ~any(used),continue;end
    first=find(used,1);
    roiScores(end+1)=struct('roiIndex',k,'roiId',samples(first).roiId, ...
        'N',nnz(used),'accuracy',mean(truth(used)==predicted(used))); %#ok<AGROW>
end
score.roi=roiScores;
classif.score=score;fig=[];
if show||~isempty(export)
    visibility='on';if silent,visibility='off';end
    fig=figure('Name','Numeric LSTM validation statistics','NumberTitle','off','Color','w','Visible',visibility);
    layout=tiledlayout(fig,1,2+double(plotRois));
    ax=nexttile(layout);imagesc(ax,matrix);axis(ax,'image');colorbar(ax);
    xticks(ax,1:C);yticks(ax,1:C);xticklabels(ax,names);yticklabels(ax,names);
    xlabel(ax,'Predicted');ylabel(ax,'Reviewed GT');title(ax,sprintf('%d %s samples; accuracy %.1f%%',score.N,p.outputMode,100*score.accuracy));
    for row=1:C,for col=1:C,text(ax,col,row,num2str(matrix(row,col)),'HorizontalAlignment','center','Color','k');end,end
    ax=nexttile(layout);bar(ax,[precision recall f1]);ylim(ax,[0 1]);xticks(ax,1:C);
    xticklabels(ax,compose('%s (n=%d)',string(names(:)),support));
    legend(ax,{'Precision','Recall','F1'},'Location','southoutside');title(ax,'Metrics per class');
    if plotRois
        ax=nexttile(layout);bar(ax,[roiScores.accuracy]);ylim(ax,[0 1]);
        xticks(ax,1:numel(roiScores));xticklabels(ax,string([roiScores.roiIndex]));
        xlabel(ax,'ROI index');ylabel(ax,'Accuracy');title(ax,'Metrics per ROI');
    end
end
if ~isempty(export)
    folder=fileparts(export);if ~isempty(folder)&&~isfolder(folder),mkdir(folder);end
    save([export '_scores.mat'],'score');
    writetable(score.samples,[export '_predictions.csv']);
    metrics=table(string(names(:)),support,precision,recall,f1,'VariableNames',{'Class','Support','Precision','Recall','F1'});
    writetable(metrics,[export '_classes.csv']);
    writematrix(matrix,[export '_confusion.csv']);
    writetable(struct2table(roiScores),[export '_rois.csv']);
    exportgraphics(fig,[export '_statistics.png']);
end

    function appendSample(frames)
        samples(end+1)=struct('roiIndex',k,'roiId',r.id,'firstFrame',frames(1), ...
            'lastFrame',frames(end),'truth',truth(frames(1)),'prediction',predicted(frames(1)));
    end
end

function ids=alignedLabels(tbl,field,n,names)
ids=zeros(1,n);if ~ismember(field,tbl.Properties.VariableNames),return;end
frames=(1:height(tbl)).';if ismember('frame',tbl.Properties.VariableNames),frames=double(tbl.frame);end
assert(isvector(frames)&&numel(frames)==height(tbl)&&all(isfinite(frames))&& ...
    all(frames==fix(frames)&frames>=1&frames<=n)&&numel(unique(frames))==numel(frames), ...
    'lstm_timeseries:FrameAlignment','Statistics require unique absolute frames inside the ROI.');
[~,values]=ismember(string(tbl.(field)),string(names));ids(frames)=values;
end
