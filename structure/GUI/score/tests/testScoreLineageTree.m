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

        function refreshRestoresLaneNavigatorAndVerticalView(testCase)
            ids = uint64((1:70).');
            model.instances = table( ...
                repmat(uint32(1), 140, 1), repelem(ids, 2), ...
                repmat(uint32([1; 100]), 70, 1), ...
                'VariableNames', {'family_id','track_id','frame'});
            model.relations = table( ...
                zeros(0,1,'uint32'), zeros(0,1,'uint64'), ...
                zeros(0,1,'uint64'), ...
                'VariableNames', { ...
                'family_id','parent_track_id','child_track_id'});

            fig = score_lineageTreeDialog(model, 1, 'ViewKey', 'roi-a|1');
            cleanup = onCleanup(@() deleteIfValid(fig)); %#ok<NASGU>
            slider = findall(fig, 'Tag', 'ScoreLineageTreeLaneSlider');
            axesHandle = findall(fig, 'Tag', 'ScoreLineageTreeAxes');
            slider.ValueChangedFcn(slider, struct('Value', 12));
            axesHandle.YLim = [10 60];

            fig = score_lineageTreeDialog(model, 1, 'ViewKey', 'roi-a|1');
            slider = findall(fig, 'Tag', 'ScoreLineageTreeLaneSlider');
            axesHandle = findall(fig, 'Tag', 'ScoreLineageTreeAxes');
            testCase.verifyEqual(slider.Value, 12);
            testCase.verifyEqual(axesHandle.YLim, [10 60]);
        end

        function reviewIntervalDrawsTwoWhiteDashedBounds(testCase)
            model.instances = table( ...
                repmat(uint32(1), 4, 1), uint64([1; 1; 2; 2]), ...
                uint32([1; 100; 20; 80]), ...
                'VariableNames', {'family_id','track_id','frame'});
            model.relations = table( ...
                uint32(1), uint64(1), uint64(2), ...
                'VariableNames', { ...
                'family_id','parent_track_id','child_track_id'});

            fig = score_lineageTreeDialog(model, 1, ...
                'ViewKey', 'roi-review|1', 'ReviewBounds', [10 90]);
            cleanup = onCleanup(@() deleteIfValid(fig)); %#ok<NASGU>
            startLine = findall(fig, 'Tag', 'ScoreLineageReviewStart');
            endLine = findall(fig, 'Tag', 'ScoreLineageReviewEnd');
            testCase.verifyNumElements(startLine, 1);
            testCase.verifyNumElements(endLine, 1);
            testCase.verifyEqual(startLine.Value, 10);
            testCase.verifyEqual(endLine.Value, 90);
            testCase.verifyEqual(startLine.LineStyle, '--');
            testCase.verifyEqual(endLine.LineStyle, '--');
            testCase.verifyEqual(startLine.Color, [1 1 1]);
            testCase.verifyEqual(endLine.Color, [1 1 1]);
        end
    end
end

function deleteIfValid(handle)
try
    if ~isempty(handle) && isvalid(handle), delete(handle); end
catch
end
end
