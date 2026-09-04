function [fig,pool] = plotLifespanPool(inputs,varargin)
%CAVITYTRAJECTORYVIEW.PLOTLIFESPANPOOL Pool occupancy lifespans across cells.

p=inputParser;
p.addParameter('FrameInterval',1,@(x)isnumeric(x)&&isscalar(x)&&x>0);
p.addParameter('TimeUnit','frames',@(x)ischar(x)||isstring(x));
p.addParameter('Title','Pooled cavity lifespans',@(x)ischar(x)||isstring(x));
p.parse(varargin{:});
if ~iscell(inputs), inputs={inputs}; end
pool=table();
for source=1:numel(inputs)
    [~,~,lifespans,metadata]=cavityTrajectoryView.resolveInput(inputs{source});
    if isempty(lifespans), continue; end
    item=lifespans;
    item.SourceIndex=repmat(uint32(source),height(item),1);
    item.SourceLabel=repmat(string(sourceLabel(metadata,source)),height(item),1);
    if isempty(pool), pool=item; else, pool=[pool;item]; end %#ok<AGROW>
end
if isempty(pool)
    error('cavityTrajectoryView:EmptyPool','No lifespan episodes were found.');
end
duration=double(pool.EndFrame-pool.StartFrame+1)*double(p.Results.FrameInterval);
[duration,order]=sort(duration,'descend'); pool=pool(order,:);

fig=figure('Name',char(string(p.Results.Title)),'Color','w', ...
    'Position',[120 120 1180 680]);
layout=tiledlayout(fig,1,2,'TileSpacing','compact','Padding','compact');
ax=nexttile(layout,1); hold(ax,'on'); box(ax,'on');
confidence=double(pool.MeanConfidence); confidence(~isfinite(confidence))=0;
map=turbo(256);
for i=1:height(pool)
    color=map(1+round(255*max(0,min(1,confidence(i)))),:);
    plot(ax,[0 duration(i)],[i i],'-','LineWidth',6,'Color',color);
    if pool.LeftCensored(i), plot(ax,0,i,'<','MarkerFaceColor',color,'Color',color); end
    if pool.RightCensored(i), plot(ax,duration(i),i,'>','MarkerFaceColor',color,'Color',color); end
end
set(ax,'YDir','reverse'); xlabel(ax,char(string(p.Results.TimeUnit)));
ylabel(ax,'Occupancy episode'); title(ax,char(string(p.Results.Title)));
grid(ax,'on'); colormap(ax,map); clim(ax,[0 1]);
cb=colorbar(ax); cb.Label.String='Mean path-margin score';

histAx=nexttile(layout,2);
histogram(histAx,duration,'BinMethod','fd','FaceColor',[0.2 0.5 0.8]);
xlabel(histAx,char(string(p.Results.TimeUnit))); ylabel(histAx,'Episodes');
title(histAx,sprintf('%d episodes from %d input(s)',height(pool),numel(inputs)));
grid(histAx,'on');
pool.Duration=duration;
end

function value=sourceLabel(metadata,index)
value=sprintf('source_%d',index);
if isstruct(metadata)&&isfield(metadata,'roi_id')&&~isempty(metadata.roi_id)
    value=char(string(metadata.roi_id));
end
end
