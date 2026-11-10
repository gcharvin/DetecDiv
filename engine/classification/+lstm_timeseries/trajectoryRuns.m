function runs=trajectoryRuns(windows)
%TRAJECTORYRUNS Join complete adjacent units, never crossing frame gaps.
runs={};
for k=1:numel(windows)
    f=windows{k};
    if isempty(runs)||runs{end}(end)+1~=f(1),runs{end+1}=f; %#ok<AGROW>
    else,runs{end}=[runs{end} f];end
end
end
