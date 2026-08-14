function value = text(bounds)
%TRAININGBOUNDS.TEXT Compact UI representation; unbounded is always "all".
if isempty(bounds)
    value = 'all';
    return;
end
try
    bounds = trainingBounds.parse(bounds);
catch
    bounds = [];
end
if isempty(bounds)
    value = 'all';
else
    value = sprintf('%d:%d', bounds(1), bounds(2));
end
end
