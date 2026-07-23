function metrics = evaluateScores(dataset, scores, rows, threshold)
%BUDMOTHERLINKER.EVALUATESCORES Event-level ranking and auto-link metrics.

if nargin < 4, threshold = -Inf; end
rows = logical(rows(:));
groups = unique(dataset.event_id(rows),'stable');
correct = false(numel(groups),1);
margins = nan(numel(groups),1);
topScores = nan(numel(groups),1);
for i = 1:numel(groups)
    idx = find(rows & dataset.event_id == groups(i));
    [ordered,order] = sort(scores(idx),'descend');
    top = idx(order(1));
    correct(i) = logical(dataset.y(top));
    topScores(i) = ordered(1);
    if numel(ordered) > 1, margins(i) = ordered(1)-ordered(2);
    else, margins(i) = ordered(1); end
end
selected = margins >= threshold;
if any(selected), precision = mean(correct(selected)); else, precision = NaN; end
metrics = struct( ...
    'events',numel(groups), ...
    'top1_correct',nnz(correct), ...
    'top1_accuracy',mean(correct), ...
    'selected',nnz(selected), ...
    'coverage',mean(selected), ...
    'auto_precision',precision, ...
    'event_correct',correct, ...
    'event_margins',margins, ...
    'event_top_scores',topScores);
end
