function params = pipelineInvalidateRoiPatternPreview(params)
% Detection rectangles are invalid once their pattern/settings change.
keys = intersect(fieldnames(params), {'candidateRects','previewRects'});
if ~isempty(keys)
    params = rmfield(params, keys);
end
end
