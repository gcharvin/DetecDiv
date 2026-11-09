function metrics = interpolateMetrics(metrics, ids, frames, plan)
% Linear interpolation of each label inside a continuous presence segment.
missing=ismember(frames,plan.missing_frames);
if ~any(missing), return; end
fields=fieldnames(metrics);
labels=unique([ids{:}]);
for label=labels(:)'
    slots=cellfun(@(x)find(x==label,1),ids,'UniformOutput',false);
    present=~cellfun(@isempty,slots);
    starts=find(present & [true; ~present(1:end-1)]);
    stops=find(present & [~present(2:end); true]);
    for f=1:numel(fields)
        values=metrics.(fields{f});
        for s=1:numel(starts)
            segment=starts(s):stops(s);
            measured=segment(~missing(segment));
            for t=segment(missing(segment))
                values{t}(slots{t})=NaN;
            end
            if numel(measured)<2, continue; end
            y=arrayfun(@(t)values{t}(slots{t}),measured);
            % NaNs remain barriers rather than being bridged as acquisitions.
            target=segment(missing(segment) & frames(segment)>=frames(measured(1)) ...
                & frames(segment)<=frames(measured(end)));
            estimates=interp1(frames(measured),y,frames(target),'linear');
            for j=1:numel(target)
                t=target(j); values{t}(slots{t})=estimates(j);
            end
        end
        metrics.(fields{f})=values;
    end
end
end
