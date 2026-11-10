function fig=displayCellFateSummary(summary,varargin)
%DISPLAYCELLFATESUMMARY Native GUI view; all synthesis is in the backend.
p=inputParser;p.addParameter('Visible','on');p.parse(varargin{:});
fig=uifigure('Name',['Cell fate summary — ' summary.classifierId],'Tag','ClassifierCellFateStatistics', ...
    'Position',[70 70 1370 900],'Visible',p.Results.Visible);fig.UserData=summary;
grid=uigridlayout(fig,[4 2]);grid.RowHeight={76,'1x',280,35};grid.ColumnWidth={'1x','1x'};
description=sprintf(['%d ROI(s); %d fully paired with reviewed GT. Prediction confirmation: %d consecutive windows (%d frames) for arrest and terminal recovery.\n' ...
    'GT is unchanged. Arrested at observation end does not establish irreversible arrest or viability. Bounds may end before the experiment.\n' ...
    '%d prediction(s) and %d GT trajectory/trajectories unresolved. This synthesis policy has not been independently validated.'], ...
    summary.N,summary.Npaired,summary.minEpisodeWindows,summary.confirmationFrames,summary.unresolvedPredictions,summary.unresolvedTruth);
label=uilabel(grid,'Text',description,'WordWrap','on');label.Layout.Row=1;label.Layout.Column=[1 2];
short={'Adapted','Transient arrest','Arrested at end','Dead'};
ax=uiaxes(grid);ax.Layout.Row=2;ax.Layout.Column=1;imagesc(ax,summary.confusion);axis(ax,'image');colorbar(ax);
xticks(ax,1:4);yticks(ax,1:4);xticklabels(ax,short);yticklabels(ax,short);xtickangle(ax,15);xlabel(ax,'Predicted fate');ylabel(ax,'Reviewed GT fate');
title(ax,sprintf('Cell fate agreement: %d paired ROI(s)',summary.Npaired));
for row=1:4,for col=1:4,text(ax,col,row,num2str(summary.confusion(row,col)),'HorizontalAlignment','center','Color','k');end,end
ax=uiaxes(grid);ax.Layout.Row=2;ax.Layout.Column=2;bar(ax,[summary.counts.ReviewedGT summary.counts.Predicted]);
xticks(ax,1:4);xticklabels(ax,short);xtickangle(ax,15);ylabel(ax,'ROI count');title(ax,'Four subpopulations — known trajectories');legend(ax,{'Reviewed GT','Predicted'},'Location','northoutside','Orientation','horizontal');
t=summary.rois;labels={'Adapted / budding','Transient arrest + recovery','Arrested at observation end','Dead'};
for key={'prediction','truth'}
    values=string(t.(key{1}));[known,index]=ismember(values,string(summary.classNames));values(known)=string(labels(index(known)));values(~known)="To review";t.(key{1})=values;
end
fields={'roiIndex','roiId','prediction','truth','firstFrame','lastFrame','availableLastFrame','predictionWindows','reviewedGTWindows','ignoredShortArrests','predictionNote','truthNote'};
tableUI=uitable(grid,'Data',t(:,fields),'Tag','CellFateRoiTable','ColumnEditable',false, ...
    'ColumnName',{'ROI','ROI reference','Predicted fate','Reviewed GT fate','First frame','Last evaluated','Last available','Pred windows','GT windows','Short arrests ignored','Prediction status','GT status'});
tableUI.Layout.Row=3;tableUI.Layout.Column=[1 2];tableUI.ColumnWidth={45,280,180,180,75,85,85,75,75,100,240,240};
note=uilabel(grid,'Text','Counts exclude unresolved cases; the confusion matrix uses only fully paired ROI(s).','WordWrap','on');note.Layout.Row=4;note.Layout.Column=1;
button=uibutton(grid,'Text','Export cell fate tables…','Tag','ExportCellFateSummary','ButtonPushedFcn',@(~,~)exportTables(summary));button.Layout.Row=4;button.Layout.Column=2;
end
function exportTables(summary)
[file,folder]=uiputfile('*.csv','Export cell fate tables',[summary.classifierId '_cell_fate.csv']);if isequal(file,0),return;end
[~,name]=fileparts(file);lstm_timeseries.exportCellFateSummary(summary,fullfile(folder,name));
end
