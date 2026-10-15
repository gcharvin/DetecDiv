function X = transform(X, stats, policy)
bad=~isfinite(X);
if any(bad,'all')
    assert(strcmp(policy,'training-median'),'lstm_timeseries:MissingValues', ...
        'Nonfinite or absent input frames; fix the bindings/bounds or choose training-median imputation.');
    for k=1:size(X,1),X(k,bad(k,:))=stats.median(k);end
end
X=single((double(X)-stats.mean)./stats.scale);
end
