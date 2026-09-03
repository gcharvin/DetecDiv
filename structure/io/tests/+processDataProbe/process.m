function [params, data, image] = process(params, roiObj, ctx) %#ok<INUSD>
%PROCESSDATAPROBE Return a small dataseries without an image output.

groupId = 'process_probe';
try
    if isfield(ctx, 'outputName') && ~isempty(ctx.outputName)
        groupId = char(string(ctx.outputName));
    end
catch
end

nFrames = max(1, size(roiObj.image, 4));
data = dataseries(table((1:nFrames).', 'VariableNames', {'probe_value'}));
data.groupid = groupId;
data.parentid = roiObj.id;
image = [];
end
