function stats = normalizer(X)
%NORMALIZER Fit on training features only; reject entirely missing traces.
X=double(X);X(~isfinite(X))=NaN;
stats.median=median(X,2,'omitnan');
assert(all(isfinite(stats.median)),'lstm_timeseries:EmptyFeature','An input has no finite training values.');
for k=1:size(X,1),X(k,isnan(X(k,:)))=stats.median(k);end
stats.mean=mean(X,2);stats.scale=std(X,0,2);stats.scale(stats.scale<1e-12)=1;
end
