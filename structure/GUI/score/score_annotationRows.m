function [count, indices, imageRows] = score_annotationRows(opts)
% One comparison row per selected indexed channel. Sequence keeps time in
% columns and stacks the intensity channels inside each annotation group.
indices = [];
if isfield(opts, 'levels') && iscell(opts.levels)
    indices = find(cellfun(@iscell, opts.levels));
end
count = max(1, numel(indices));
imageRows = count * opts.Nbrick;
if strcmpi(opts.mode, 'sequence') && ~opts.overlay
    imageRows = imageRows * opts.Nchannel;
end
end
