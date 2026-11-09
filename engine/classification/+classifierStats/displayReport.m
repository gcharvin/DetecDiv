function figures=displayReport(report,varargin)
%PLOT Render only a complete evaluated report; never create empty windows.
p=inputParser;p.addParameter('Visible',true);p.addParameter('Export','');p.parse(varargin{:});
figures=gobjects(0);
assert(isfield(report,'components')&&~isempty(report.components),'classifierStats:NoEvaluationSamples','No statistics to display.');
for component=report.components
    assert(~isempty(component.frameMetrics),'classifierStats:NoEvaluationSamples','No evaluated frames.');
    visible='off';if p.Results.Visible,visible='on';end
    h=figure('Color','w','Name',[report.classifierId ' - ' component.id], ...
        'Visible',visible,'Position',[100 100 1100 720]);
    try
        if component.instanceSegmentation,tiledlayout(h,2,2);else,tiledlayout(h,1,2);end
        nexttile;imagesc(component.confusion);colorbar;axis square;
        xticks(1:numel(component.classNames));yticks(1:numel(component.classNames));
        xticklabels(component.classNames);yticklabels(component.classNames);
        xlabel('Prediction');ylabel('Reviewed ground truth');title('Confusion counts');
        nexttile;v=component.pixel;
        bar([v.precision v.recall v.f1 v.iou]);ylim([0 1]);
        xticks(1:numel(component.classNames));xticklabels(component.classNames);
        legend({'Precision','Recall','F1 / Dice','IoU'},'Location','southoutside');title('Class agreement');
        if component.instanceSegmentation
            nexttile;s=component.instances;
            bar([s.precision s.recall s.f1 s.matchedIoU s.panopticQuality]);ylim([0 1]);
            xticks(1:5);xticklabels({'Precision','Recall','F1','Matched IoU','PQ'});
            title(sprintf('Instances: TP %d / FP %d / FN %d; IoU >= %.2f', ...
                s.truePositive,s.falsePositive,s.falseNegative,s.iouThreshold));
            nexttile;t=component.frameMetrics;
            plot(1:height(t),[t.groundTruthCount t.predictionCount],'-o');
            xticks(1:height(t));xticklabels(compose('ROI %d, f%d',t.roiIndex,t.frame));xtickangle(30);
            ylabel('Cell count');legend({'GT','Prediction'},'Location','best');title('Reviewed frames only');
        end
        sgtitle(sprintf('%s | %s | %d evaluated frame / sequence samples', ...
            report.classifierId,component.id,height(component.frameMetrics)),'Interpreter','none');
        if ~isempty(p.Results.Export)
            exportgraphics(h,[char(string(p.Results.Export)) '_' matlab.lang.makeValidName(component.id) '_statistics.png'],'Resolution',180);
        end
    catch ME
        close(h);rethrow(ME);
    end
    if p.Results.Visible,figures(end+1)=h;else,close(h);end %#ok<AGROW>
end
end
