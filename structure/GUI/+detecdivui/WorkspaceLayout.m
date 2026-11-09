classdef WorkspaceLayout
    % Split an existing document tile without resetting unrelated geometry.
    methods (Static)
        function result = geometry(layout)
            result = struct('gridDimensions',layout.gridDimensions,'tileCount',layout.tileCount, ...
                'columnWeights',reshape(layout.columnWeights,1,[]), ...
                'rowWeights',reshape(layout.rowWeights,1,[]),'tileCoverage',layout.tileCoverage, ...
                'tileOccupancy',repmat(struct('children',struct('id',''),'showingChildId',''),1,numel(layout.tileOccupancy)));
            for k = 1:numel(layout.tileOccupancy)
                children = layout.tileOccupancy(k).children;
                if isempty(children), result.tileOccupancy(k).children = struct('id',{});
                else
                    result.tileOccupancy(k).children = struct('id',{children.id});
                    if isfield(layout.tileOccupancy,'showingChildId') && ...
                            any(strcmp({children.id},layout.tileOccupancy(k).showingChildId))
                        result.tileOccupancy(k).showingChildId = layout.tileOccupancy(k).showingChildId;
                    end
                end
            end
        end
        function [layout,changed] = below(layout,anchorId,newId,topFraction)
            changed = false;
            if nargin < 4, topFraction = .70; end
            validateattributes(topFraction,{'numeric'},{'scalar','>',0,'<',1});
            anchor = detecdivui.WorkspaceLayout.tile(layout,anchorId);
            present=detecdivui.WorkspaceLayout.tile(layout,newId);
            if isempty(anchor) || (~isempty(present)&&present~=anchor), return; end
            if ~isempty(present)
                % Older layouts stacked this inspector with its anchor.
                layout=detecdivui.WorkspaceLayout.geometry(layout);
                children=layout.tileOccupancy(anchor).children;
                layout.tileOccupancy(anchor).children=children(~strcmp({children.id},newId));
                layout.tileOccupancy(anchor).showingChildId=char(anchorId);
            end
            coverage = layout.tileCoverage;
            [rows,columns] = find(coverage == anchor);
            if isempty(rows), return; end
            rowRange = min(rows):max(rows); columnRange = min(columns):max(columns);
            region = coverage(rowRange,columnRange);
            assert(all(region(:) == anchor),'detecdivui:InspectorLayout', ...
                'The selected document tile is not rectangular. Arrange it before opening the inspector.');
            weights = reshape(layout.rowWeights,1,[]); weights = weights/sum(weights);
            boundary = sum(weights(1:rowRange(1)-1)) + topFraction*sum(weights(rowRange));
            edges = cumsum(weights); [distance,index] = min(abs(edges-boundary));
            lastRow = rowRange(end);
            if distance < 1e-9
                firstBottom = index+1;
            else
                row = find(edges > boundary,1);
                first = boundary-sum(weights(1:row-1));
                weights = [weights(1:row-1) first weights(row)-first weights(row+1:end)];
                coverage = [coverage(1:row,:);coverage(row,:);coverage(row+1:end,:)];
                firstBottom = row+1; lastRow = lastRow+1;
            end
            newTile = numel(layout.tileOccupancy)+1;
            coverage(firstBottom:lastRow,columnRange) = newTile;
            selection = detecdivui.WorkspaceLayout.geometry(layout);
            occupancy = selection.tileOccupancy;
            occupancy(newTile) = struct('children',struct('id',char(newId)),'showingChildId',char(newId));
            % Native readback contains derived pixel caches. They
            % become inconsistent after a grid split and can silently undo
            % the requested layout. Keep only geometry, IDs and valid shown
            % child IDs, which are meaningful state for each tab group.
            layout = struct('gridDimensions',struct('w',size(coverage,2),'h',size(coverage,1)), ...
                'tileCount',newTile,'columnWeights',reshape(layout.columnWeights,1,[]), ...
                'rowWeights',weights,'tileCoverage',coverage,'tileOccupancy',occupancy);
            changed = true;
        end
        function index = tile(layout,id)
            index = [];
            if ~isstruct(layout) || ~isfield(layout,'tileOccupancy'), return; end
            for k = 1:numel(layout.tileOccupancy)
                children = layout.tileOccupancy(k).children;
                if isstruct(children) && isfield(children,'id') && any(strcmp({children.id},char(id)))
                    index = k; return;
                end
            end
        end
    end
end
