function out = deriveGrowth(objectMetrics, varargin)
%CELLMETRICS.DERIVEGROWTH Add track and mother-bud growth measurements.
% Growth is a local Theil-Sen slope, which is robust to isolated mask-size
% errors and requires no Statistics Toolbox.

p=inputParser;
p.addParameter('SizeVariable','Area_Cell',@(x)ischar(x)||isstring(x));
p.addParameter('FrameIntervalMinutes',1,@(x)isnumeric(x)&&isscalar(x)&&isfinite(x)&&x>0);
p.addParameter('Window',5,@(x)isnumeric(x)&&isscalar(x)&&isfinite(x)&&x>=2);
p.parse(varargin{:});
name=char(string(p.Results.SizeVariable));
if ~istable(objectMetrics) || ~ismember(name,objectMetrics.Properties.VariableNames)
    error('cellMetrics:MissingSizeVariable','Size variable "%s" was not found.',name);
end
required={'TrackId','Frame','ParentTrackId'};
if ~all(ismember(required,objectMetrics.Properties.VariableNames))
    error('cellMetrics:MissingIdentityColumns','Object metrics must contain TrackId, Frame and ParentTrackId.');
end
out=objectMetrics;
base=matlab.lang.makeValidName(name);
growth=[base 'GrowthPerMinute'];
specific=[base 'SpecificGrowthPerMinute'];
out.(growth)=localSlopes(out.TrackId,double(out.Frame),double(out.(name)), ...
    p.Results.FrameIntervalMinutes,round(p.Results.Window),false);
out.(specific)=localSlopes(out.TrackId,double(out.Frame),double(out.(name)), ...
    p.Results.FrameIntervalMinutes,round(p.Results.Window),true);

n=height(out);
out.MotherSize=nan(n,1);
for i=1:n
    if out.ParentTrackId(i)==0, continue; end
    hit=find(out.TrackId==out.ParentTrackId(i) & out.Frame==out.Frame(i),1,'first');
    if ~isempty(hit), out.MotherSize(i)=double(out.(name)(hit)); end
end
out.PairSize=double(out.(name))+out.MotherSize;
out.BudFraction=double(out.(name))./out.PairSize;
pairTrack=out.TrackId;
pairTrack(out.ParentTrackId==0)=uint64(0);
out.PairGrowthPerMinute=localSlopes(pairTrack,double(out.Frame),out.PairSize, ...
    p.Results.FrameIntervalMinutes,round(p.Results.Window),false);
out.BudGrowthAllocation=out.(growth)./out.PairGrowthPerMinute;
out.BudGrowthAllocation(~isfinite(out.BudGrowthAllocation))=NaN;
end

function slope=localSlopes(track,frame,value,dt,window,useLog)
slope=nan(size(value));
ids=unique(track(track>0));
half=floor(window/2);
for k=1:numel(ids)
    rows=find(track==ids(k));
    [~,ord]=sort(frame(rows)); rows=rows(ord);
    y=value(rows);
    if useLog
        y(y<=0)=NaN; y=log(y);
    end
    x=frame(rows)*dt;
    for j=1:numel(rows)
        lo=max(1,j-half); hi=min(numel(rows),j+half);
        xx=x(lo:hi); yy=y(lo:hi);
        valid=isfinite(xx)&isfinite(yy);
        xx=xx(valid); yy=yy(valid);
        pairSlopes=[];
        for a=1:numel(xx)-1
            dx=xx(a+1:end)-xx(a);
            keep=dx~=0;
            offsets=find(keep);
            pairSlopes=[pairSlopes; (yy(a+offsets)-yy(a))./dx(keep)]; %#ok<AGROW>
        end
        if ~isempty(pairSlopes), slope(rows(j))=median(pairSlopes,'omitnan'); end
    end
end
end
