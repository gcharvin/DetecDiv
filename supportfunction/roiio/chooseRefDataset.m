function ref = chooseRefDataset(info)
ref = [];
for i = 1:numel(info.Datasets)
    if startsWith(info.Datasets(i).Name,'Channel'), ref = info.Datasets(i); return; end
end
if ~isempty(info.Datasets), ref = info.Datasets(1); return; end
for gi = 1:numel(info.Groups)
    g = info.Groups(gi);
    if ~isempty(g.Datasets), ref = g.Datasets(1); return; end
end
end
