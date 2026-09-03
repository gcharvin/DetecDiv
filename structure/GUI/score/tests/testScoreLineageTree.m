classdef testScoreLineageTree < matlab.unittest.TestCase
    methods (Test)
        function asymmetricLayoutAvoidsVisibleCrossings(testCase)
            ids = uint64([1 2 3 4 5 6]);
            first = [1 10 30 20 40 50];
            last = [80 80 80 80 80 80];
            parent = uint64([1 1 1 2 4]);
            child = uint64([2 3 4 5 6]);
            [nodes, edges] = score_lineageTreeLayout( ...
                ids, first, last, parent, child);
            nodeIds = [nodes.track_id];
            for edge = edges(:).'
                lo = min(edge.parent_x, edge.child_x);
                hi = max(edge.parent_x, edge.child_x);
                for node = nodes(:).'
                    if any(node.track_id == [edge.parent_track_id edge.child_track_id])
                        continue;
                    end
                    crossesX = node.x > lo && node.x < hi;
                    visible = node.first_frame <= edge.event_frame && ...
                        node.last_frame >= edge.event_frame;
                    testCase.verifyFalse(crossesX && visible, ...
                        sprintf('Track %u crosses edge %u -> %u', ...
                        node.track_id, edge.parent_track_id, edge.child_track_id));
                end
            end
            testCase.verifyEqual(sort(nodeIds), sort(ids));
        end

        function malformedRelationsRemainDiagnostic(testCase)
            ids = uint64([1 2 3]);
            [~, edges, diagnostics] = score_lineageTreeLayout( ...
                ids, [1 2 3], [10 10 10], ...
                uint64([1 3 99]), uint64([2 2 1]));
            testCase.verifyEqual(numel(edges), 1);
            testCase.verifyEqual( ...
                size(diagnostics.ignored_duplicate_parent_relations, 1), 1);
            testCase.verifyEqual( ...
                size(diagnostics.ignored_missing_or_self_relations, 1), 1);
        end

        function colorMatchesSixteenEntryCycle(testCase)
            testCase.verifyEqual(score_trackColor(1), score_trackColor(17));
            testCase.verifyNotEqual(score_trackColor(1), score_trackColor(2));
        end
    end
end
