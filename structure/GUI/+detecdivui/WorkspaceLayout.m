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
        function yes = isBelowImage(layout,id)
            image=detecdivui.WorkspaceLayout.tile(layout,'workspace_image');
            item=detecdivui.WorkspaceLayout.tile(layout,id); yes=false;
            if isempty(image)||isempty(item)||image==item||numel(layout.tileOccupancy(item).children)~=1, return; end
            [ir,ic]=find(layout.tileCoverage==image); [mr,mc]=find(layout.tileCoverage==item);
            if isempty(ir)||isempty(mr), return; end
            yes=max(ir)<min(mr)&&isequal(unique(ic),unique(mc));
        end
        function layout = tabWith(layout,anchorId,id)
            layout=detecdivui.WorkspaceLayout.geometry(layout);
            anchor=detecdivui.WorkspaceLayout.tile(layout,anchorId);
            assert(~isempty(anchor),'detecdivui:InspectorLayout','The target document group is unavailable.');
            previous=detecdivui.WorkspaceLayout.tile(layout,id);
            for k=1:numel(layout.tileOccupancy)
                children=layout.tileOccupancy(k).children;
                children=children(~strcmp({children.id},id)); layout.tileOccupancy(k).children=children;
                if strcmp(layout.tileOccupancy(k).showingChildId,id)
                    shown=''; if ~isempty(children), shown=children(1).id; end
                    layout.tileOccupancy(k).showingChildId=shown;
                end
            end
            if ~isempty(previous)&&previous~=anchor&&isempty(layout.tileOccupancy(previous).children)
                layout=detecdivui.WorkspaceLayout.closeEmptyTile(layout,previous);
                anchor=detecdivui.WorkspaceLayout.tile(layout,anchorId);
            end
            layout.tileOccupancy(anchor).children(end+1).id=char(id);
            layout.tileOccupancy(anchor).showingChildId=char(id);
        end
        function anchor = inspectorAnchor(layout)
            anchor='';
            for id={'workspace_display','workspace_pipeline','workspace_objects','workspace_image','workspace_projects'}
                tile=detecdivui.WorkspaceLayout.tile(layout,id{1});
                if ~isempty(tile)&&any(layout.tileCoverage(:)==tile), anchor=id{1}; return; end
            end
        end
    end
    methods (Static,Access=private)
        function layout = closeEmptyTile(layout,tile)
            coverage=layout.tileCoverage; [rows,columns]=find(coverage==tile);
            if ~isempty(rows)
                rr=min(rows):max(rows); cc=min(columns):max(columns);
                image=detecdivui.WorkspaceLayout.tile(layout,'workspace_image');
                ir=[]; ic=[];
                if ~isempty(image), [ir,ic]=find(coverage==image); end
                outside=setdiff(1:size(coverage,2),cc);
                collapse=~isempty(ir)&&isequal(unique(ic),unique(columns))&&max(ir)<min(rows);
                if collapse
                    same=coverage(rr,outside)==coverage(max(ir),outside);
                    collapse=all(same(:));
                end
                if collapse
                    % Return the former profile row to Image. The cells in
                    % other columns belong to the same spanning documents.
                    layout.rowWeights(max(ir))=layout.rowWeights(max(ir))+sum(layout.rowWeights(rr));
                    layout.rowWeights(rr)=[]; coverage(rr,:)=[];
                else
                    candidates=[];
                    if min(rr)>1, candidates=[candidates coverage(min(rr)-1,cc)]; end
                    if max(rr)<size(coverage,1), candidates=[candidates coverage(max(rr)+1,cc)]; end
                    if min(cc)>1, candidates=[candidates coverage(rr,min(cc)-1)']; end
                    if max(cc)<size(coverage,2), candidates=[candidates coverage(rr,max(cc)+1)']; end
                    replacement=[];
                    for candidate=unique(candidates,'stable')
                        [r,c]=find(coverage==candidate|coverage==tile);
                        block=coverage(min(r):max(r),min(c):max(c));
                        if all(block(:)==candidate|block(:)==tile), replacement=candidate; break; end
                    end
                    assert(~isempty(replacement),'detecdivui:InspectorLayout','Cannot collapse the former widget tile.');
                    coverage(coverage==tile)=replacement;
                end
            end
            layout.tileOccupancy(tile)=[]; coverage(coverage>tile)=coverage(coverage>tile)-1;
            layout.tileCoverage=coverage; layout.tileCount=numel(layout.tileOccupancy);
            layout.gridDimensions=struct('w',size(coverage,2),'h',size(coverage,1));
        end
    end
end
