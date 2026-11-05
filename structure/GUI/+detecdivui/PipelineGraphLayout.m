classdef PipelineGraphLayout
    % Geometry for declared links only. Never infers or changes a pipeline.
    methods (Static)
        function layout = build(nodes,edges)
            n = numel(nodes); bounds = zeros(n,4);
            for k = 1:n, bounds(k,:) = [.14 n-k+.13 .80 .74]; end
            routes = struct('edgeIndex',{},'fromIndex',{},'toIndex',{},'key',{}, ...
                'x',{},'y',{},'source',{},'target',{},'headX',{},'headY',{},'lane',{},'resource',{});
            issues = {}; ids = {};
            if n > 0, ids = cellstr(string({nodes.id})); end
            for k = 1:numel(edges)
                edge = edges(k); from = detecdivui.PipelineGraphLayout.text(edge,'from');
                to = detecdivui.PipelineGraphLayout.text(edge,'to');
                a = find(strcmp(ids,from)); b = find(strcmp(ids,to));
                if numel(a) ~= 1 || numel(b) ~= 1
                    issues{end+1} = ['Unresolved link: ' from ' → ' to]; %#ok<AGROW>
                    continue;
                end
                fields = {'from','to','fromPort','toPort','condition'}; identity = cell(size(fields));
                for j = 1:numel(fields), identity{j} = detecdivui.PipelineGraphLayout.text(edge,fields{j}); end
                resource = any(strcmpi(identity{5},{'resourceBinding','binding','symbolicBinding'}));
                routes(end+1) = struct('edgeIndex',k,'fromIndex',a,'toIndex',b,'key',jsonencode(identity), ...
                    'x',[],'y',[],'source',[],'target',[],'headX',[],'headY',[],'lane',0,'resource',resource); %#ok<AGROW>
            end
            direct = arrayfun(@(r)r.toIndex == r.fromIndex+1 && ~r.resource,routes);
            for k = find(direct)
                r = routes(k); a = bounds(r.fromIndex,:); b = bounds(r.toIndex,:);
                peers = find(direct & [routes.fromIndex] == r.fromIndex & [routes.toIndex] == r.toIndex);
                rank = find(peers == k); offset = (rank-(numel(peers)+1)/2)*min(.12,.6/numel(peers));
                x = a(1)+a(3)*(.5+offset); top = b(2)+b(4);
                routes(k).source = [x a(2)]; routes(k).target = [x top];
                routes(k).x = [x x]; routes(k).y = [a(2) top];
                routes(k).headX = [x x-.012 x+.012]; routes(k).headY = [top top+.10 top+.10];
            end
            side = find(~direct); spans = zeros(numel(side),2);
            for j = 1:numel(side)
                k = side(j); r = routes(k); a = bounds(r.fromIndex,:); b = bounds(r.toIndex,:);
                outgoing = side([routes(side).fromIndex] == r.fromIndex);
                incoming = side([routes(side).toIndex] == r.toIndex);
                y1 = a(2)+a(4)/2+detecdivui.PipelineGraphLayout.offset(find(outgoing == k),numel(outgoing));
                y2 = b(2)+b(4)/2+detecdivui.PipelineGraphLayout.offset(find(incoming == k),numel(incoming));
                if r.fromIndex == r.toIndex, y1 = a(2)+.16; y2 = a(2)+a(4)-.16; end
                routes(k).source = [a(1)+a(3) y1]; routes(k).target = [b(1)+b(3) y2];
                spans(j,:) = [min(y1,y2) max(y1,y2)];
            end
            lanes = {};
            [~,order] = sort(spans(:,2)-spans(:,1),'descend');
            for j = reshape(order,1,[])
                k = side(j); lane = 1;
                while lane <= numel(lanes)
                    occupied = lanes{lane};
                    if ~any(spans(j,1) <= occupied(:,2)+.12 & spans(j,2) >= occupied(:,1)-.12), break; end
                    lane = lane+1;
                end
                if lane > numel(lanes)
                    lanes{lane} = spans(j,:); %#ok<AGROW>
                else
                    lanes{lane}(end+1,:) = spans(j,:); %#ok<AGROW>
                end
                r = routes(k); x = .995+.05*(lane-1); target = r.target;
                routes(k).lane = lane;
                routes(k).x = [r.source(1) x x target(1)];
                routes(k).y = [r.source(2) r.source(2) target(2) target(2)];
                routes(k).headX = [target(1) target(1)+.025 target(1)+.025];
                routes(k).headY = [target(2) target(2)+.055 target(2)-.055];
            end
            layout = struct('bounds',bounds,'routes',routes,'issues',{issues}, ...
                'xlim',[0 max(1.01,1.02+.05*(numel(lanes)-1))],'ylim',[0 max(1,n)]);
        end
    end
    methods (Static, Access=private)
        function value = text(item,key)
            value = ''; if isfield(item,key) && ~isempty(item.(key)), value = char(string(item.(key))); end
        end
        function value = offset(rank,count)
            value = 0; if count > 1, value = -.20+.40*(rank-1)/(count-1); end
        end
    end
end
