function fig = plotTrajectory(input,varargin)
%CAVITYTRAJECTORYVIEW.PLOTTRAJECTORY Inspect one selected cavity trajectory.

p=inputParser;
p.addParameter('FocusTrackID',NaN,@(x)isnumeric(x)&&isscalar(x));
p.addParameter('Title','Cavity trajectory',@(x)ischar(x)||isstring(x));
p.addParameter('Parent',[],@(x)isempty(x)||isgraphics(x));
p.parse(varargin{:});
[assignments,events,~,metadata]=resolveInput(input);
if isempty(assignments)||height(assignments)==0
    error('cavityTrajectoryView:EmptyTrajectory','The trajectory contains no assignments.');
end

if isempty(p.Results.Parent)
    fig=figure('Name',char(string(p.Results.Title)),'Color','w', ...
        'Position',[100 100 1150 720]);
    layout=tiledlayout(fig,2,1,'TileSpacing','compact','Padding','compact');
else
    fig=ancestor(p.Results.Parent,'figure');
    layout=tiledlayout(p.Results.Parent,2,1,'TileSpacing','compact','Padding','compact');
end
ax=nexttile(layout,1); hold(ax,'on'); box(ax,'on');
trackIds=unique(assignments.TargetTrackID(assignments.TargetTrackID>0),'stable');
lane=nan(height(assignments),1);
for i=1:numel(trackIds), lane(assignments.TargetTrackID==trackIds(i))=i; end
colors=lines(max(1,numel(trackIds)));
episodes=unique(assignments.OccupancyEpisodeID(assignments.OccupancyEpisodeID>0));
for episode=episodes(:)'
    rows=find(assignments.OccupancyEpisodeID==episode & assignments.TargetTrackID>0);
    if isempty(rows), continue; end
    segments=splitConsecutive(rows);
    for s=1:numel(segments)
        rr=segments{s}; idx=find(trackIds==assignments.TargetTrackID(rr(1)),1);
        width=3;
        if isfinite(p.Results.FocusTrackID)&&uint64(p.Results.FocusTrackID)==trackIds(idx), width=7; end
        plot(ax,double(assignments.Frame(rr)),lane(rr),'-','LineWidth',width, ...
            'Color',colors(idx,:),'DisplayName',sprintf('Track %u',trackIds(idx)));
    end
end
gapRows=assignments.Abstained;
scatter(ax,double(assignments.Frame(gapRows)),zeros(sum(gapRows),1),18,[0.5 0.5 0.5],'x');
for i=1:height(events)
    x=double(events.EventFrame(i));
    xline(ax,x,'--','Color',eventColor(events.TransitionType(i)), ...
        'Label',char(events.TransitionType(i)),'LabelOrientation','horizontal', ...
        'HandleVisibility','off');
end
ax.YTick=0:numel(trackIds);
ax.YTickLabel=[{'gap'},arrayfun(@(x)sprintf('%u',x),trackIds,'UniformOutput',false)'];
ylabel(ax,'Selected biological TrackID'); xlabel(ax,'Frame');
title(ax,sprintf('%s | %s',char(string(p.Results.Title)),metadataText(metadata)), ...
    'Interpreter','none');
grid(ax,'on');

confidenceAx=nexttile(layout,2); hold(confidenceAx,'on'); box(confidenceAx,'on');
plot(confidenceAx,double(assignments.Frame),double(assignments.SelectionConfidence), ...
    'k-','LineWidth',1.5);
scatter(confidenceAx,double(assignments.Frame(assignments.Abstained)), ...
    double(assignments.SelectionConfidence(assignments.Abstained)),24,[0.75 0.1 0.1],'filled');
ylim(confidenceAx,[0 1]); xlabel(confidenceAx,'Frame');
ylabel(confidenceAx,'Path-margin score'); grid(confidenceAx,'on');
title(confidenceAx,'Uncalibrated selection confidence; red frames are abstained/gaps');
end

function parts=splitConsecutive(rows)
if isempty(rows), parts={}; return; end
cut=[0;find(diff(rows)>1);numel(rows)]; parts=cell(numel(cut)-1,1);
for i=1:numel(parts), parts{i}=rows((cut(i)+1):cut(i+1)); end
end

function color=eventColor(kind)
kind=string(kind);
if kind=="lineage_handover", color=[0.1 0.5 0.95];
elseif kind=="unrelated_replacement", color=[0.85 0.15 0.15];
else, color=[0.35 0.35 0.35]; end
end

function text=metadataText(metadata)
text='';
if isstruct(metadata)&&isfield(metadata,'mode'), text=char(string(metadata.mode)); end
if isstruct(metadata)&&isfield(metadata,'roi_id')
    if isempty(text), text=char(string(metadata.roi_id));
    else, text=[char(string(metadata.roi_id)) ' | ' text]; end
end
end

function [assignments,events,lifespans,metadata]=resolveInput(input)
[assignments,events,lifespans,metadata]=cavityTrajectoryView.resolveInput(input);
end
