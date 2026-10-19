function rowOpts = score_annotationRowOptions(opts, row)
% Retain all intensity settings and the original paint-channel identity.
[~, indices] = score_annotationRows(opts);
rowOpts = opts;
if ~isempty(indices)
    rowOpts.annotationChannel = string(opts.channel{indices(row)});
end
end
