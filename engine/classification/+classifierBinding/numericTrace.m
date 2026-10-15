function [values, valid] = numericTrace(value)
%NUMERICTRACE Normalize numeric matrices or unambiguous scalar-cell traces.
% computeMetrics stores one numeric vector per frame. A single measured
% object is scalar; empty frames are missing. Multiple objects require an
% explicit upstream selection/aggregation, never an implicit first object.
valid=(isnumeric(value)||islogical(value))&&isreal(value)&&ismatrix(value);
values=[];
if valid,values=double(value);return;end
if ~iscell(value)||~ismatrix(value)||size(value,2)~=1,return;end
good=cellfun(@(x)(isnumeric(x)||islogical(x))&&isreal(x)&&(isempty(x)||isscalar(x)),value);
if ~all(good),return;end
values=nan(size(value));
present=~cellfun(@isempty,value);
values(present)=cellfun(@double,value(present));
valid=true;
end
