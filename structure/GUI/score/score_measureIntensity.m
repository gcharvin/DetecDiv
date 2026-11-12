function result = score_measureIntensity(plane,mode,geometry,source,channel)
%SCORE_MEASUREINTENSITY Shared Score profile sampling in source/physical units.
% Line geometry is [x1 y1; x2 y2]; Region geometry is a logical image mask.
if nargin<4, source=[]; end
if nargin<5, channel=0; end
validateattributes(plane,{'numeric','logical'},{'real','nonempty'});
assert(ismatrix(plane)||(ndims(plane)==3&&size(plane,3)==3), ...
    'score:MeasurementPlane','Select a single intensity or logical RGB channel.');
if ndims(plane)==3
    plane=.2989*double(plane(:,:,1))+.5870*double(plane(:,:,2))+.1140*double(plane(:,:,3));
else, plane=double(plane);
end
result=struct('values',[],'x',[],'counts',[],'centers',[],'edges',[], ...
    'count',0,'minimum',NaN,'maximum',NaN,'mean',NaN,'median',NaN,'std',NaN, ...
    'unit',score_channelDisplayUnit(source,channel));
switch mode
    case 'Line'
        validateattributes(geometry,{'numeric'},{'real','finite','size',[2 2]});
        length=hypot(diff(geometry(:,1)),diff(geometry(:,2)));
        assert(length>0,'score:MeasurementLine','Draw a line with distinct endpoints.');
        values=improfile(plane,geometry(:,1),geometry(:,2));
        result.x=linspace(0,length,numel(values))';
    case 'Region'
        validateattributes(geometry,{'logical'},{'size',size(plane)});
        values=plane(geometry);
    otherwise, error('score:MeasurementMode','Choose Line or Region.');
end
result.values=score_decodeChannelValues(source,channel,values(:));
finite=result.values(isfinite(result.values)); result.count=numel(finite);
if isempty(finite), return; end
result.minimum=min(finite); result.maximum=max(finite); result.mean=mean(finite);
result.median=median(finite); result.std=std(finite);
if strcmp(mode,'Region')
    lo=result.minimum; hi=result.maximum;
    binWidth=2*iqr(finite)/(numel(finite)^(1/3)); bins=10;
    if isfinite(binWidth)&&binWidth>0&&hi>lo, bins=max(10,min(4096,ceil((hi-lo)/binWidth))); end
    if hi<=lo
        span=max(1,abs(lo))*1e-6; hi=lo+span;
        if ~isfinite(hi), hi=lo; lo=lo-span; end
    end
    result.edges=linspace(lo,hi,bins+1);
    result.centers=(result.edges(1:end-1)+result.edges(2:end))/2;
    result.counts=histcounts(finite,result.edges);
end
end
