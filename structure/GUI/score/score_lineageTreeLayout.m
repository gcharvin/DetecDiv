function [nodes, edges, diagnostics] = score_lineageTreeLayout( ...
    trackIds, firstFrames, lastFrames, parentIds, childIds)
%SCORE_LINEAGETREELAYOUT Crossing-free asymmetric lineage lane layout.
% Mothers occupy the leftmost lane of their recursively reserved subtree.
% Children are allocated from latest to earliest birth. Therefore, at an
% older child's birth, all later-born sibling subtrees crossed by its span
% do not exist yet; earlier siblings lie outside that span.

trackIds = uint64(trackIds(:));
firstFrames = double(firstFrames(:));
lastFrames = double(lastFrames(:));
parentIds = uint64(parentIds(:));
childIds = uint64(childIds(:));
if numel(trackIds) ~= numel(firstFrames) || numel(trackIds) ~= numel(lastFrames)
    error('score:LineageTreeInput', ...
        'Track IDs and frame extents must have the same length.');
end
[trackIds, order] = sort(trackIds);
firstFrames = firstFrames(order);
lastFrames = lastFrames(order);
if numel(unique(trackIds)) ~= numel(trackIds)
    error('score:LineageTreeDuplicateTrack', 'Track IDs must be unique.');
end

n = numel(trackIds);
parentIndex = zeros(n, 1);
ignoredMissing = zeros(0, 2, 'uint64');
ignoredDuplicate = zeros(0, 2, 'uint64');
ignoredCycle = zeros(0, 2, 'uint64');
for relation = 1:min(numel(parentIds), numel(childIds))
    p = find(trackIds == parentIds(relation), 1, 'first');
    c = find(trackIds == childIds(relation), 1, 'first');
    if isempty(p) || isempty(c) || p == c
        ignoredMissing(end+1,:) = [parentIds(relation), childIds(relation)]; %#ok<AGROW>
        continue;
    end
    if parentIndex(c) ~= 0
        ignoredDuplicate(end+1,:) = [parentIds(relation), childIds(relation)]; %#ok<AGROW>
        continue;
    end
    ancestor = p;
    createsCycle = false;
    while ancestor ~= 0
        if ancestor == c
            createsCycle = true;
            break;
        end
        ancestor = parentIndex(ancestor);
    end
    if createsCycle
        ignoredCycle(end+1,:) = [parentIds(relation), childIds(relation)]; %#ok<AGROW>
        continue;
    end
    parentIndex(c) = p;
end

children = cell(n, 1);
for child = 1:n
    if parentIndex(child) > 0
        children{parentIndex(child)}(end+1) = child;
    end
end
for parent = 1:n
    child = children{parent};
    if isempty(child), continue; end
    % Latest child first is the key asymmetric ordering invariant.
    [~, childOrder] = sortrows( ...
        [-firstFrames(child), -double(trackIds(child))], [1 2]);
    children{parent} = child(childOrder);
end

roots = find(parentIndex == 0);
[~, rootOrder] = sortrows([firstFrames(roots), double(trackIds(roots))], [1 2]);
roots = roots(rootOrder);
x = nan(n, 1);
nextLane = 1;
for root = roots(:).'
    assignSubtree(root);
    nextLane = nextLane + 1; % visible gap between independent trees
end
% Defensive fallback for malformed graphs that escaped relation filtering.
for index = find(isnan(x)).'
    assignSubtree(index);
    nextLane = nextLane + 1;
end

nodes = struct( ...
    'track_id', num2cell(trackIds), ...
    'x', num2cell(x), ...
    'first_frame', num2cell(firstFrames), ...
    'last_frame', num2cell(lastFrames), ...
    'parent_track_id', num2cell(parentTrackIds()));
edgeChildren = find(parentIndex > 0);
edges = repmat(struct('parent_track_id', uint64(0), ...
    'child_track_id', uint64(0), 'event_frame', 0, ...
    'parent_x', 0, 'child_x', 0), numel(edgeChildren), 1);
for row = 1:numel(edgeChildren)
    child = edgeChildren(row);
    parent = parentIndex(child);
    edges(row) = struct( ...
        'parent_track_id', trackIds(parent), ...
        'child_track_id', trackIds(child), ...
        'event_frame', firstFrames(child), ...
        'parent_x', x(parent), ...
        'child_x', x(child));
end
diagnostics = struct( ...
    'ignored_missing_or_self_relations', ignoredMissing, ...
    'ignored_duplicate_parent_relations', ignoredDuplicate, ...
    'ignored_cycle_relations', ignoredCycle, ...
    'root_count', numel(roots), ...
    'track_count', n, ...
    'edge_count', numel(edges));

    function assignSubtree(index)
        if ~isnan(x(index)), return; end
        x(index) = nextLane;
        nextLane = nextLane + 1;
        for nestedChild = children{index}
            assignSubtree(nestedChild);
        end
    end

    function values = parentTrackIds()
        values = zeros(n, 1, 'uint64');
        linked = parentIndex > 0;
        values(linked) = trackIds(parentIndex(linked));
    end
end
