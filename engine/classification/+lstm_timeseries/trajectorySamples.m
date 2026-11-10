function joined=trajectorySamples(samples)
%TRAJECTORYSAMPLES Retain frame inputs; endpoint loss sees one target/unit.
joined=samples([]);
for k=1:numel(samples)
    s=samples(k);s.Y=repmat(s.Y,1,numel(s.frames));
    if isempty(joined)||joined(end).roiIndex~=s.roiIndex|| ...
            ~strcmp(joined(end).split,s.split)||joined(end).frames(end)+1~=s.frames(1)
        joined(end+1)=s; %#ok<AGROW>
    else
        for key={'frames','inputFrames','X','Y'}
            joined(end).(key{1})=[joined(end).(key{1}) s.(key{1})];
        end
    end
end
end
