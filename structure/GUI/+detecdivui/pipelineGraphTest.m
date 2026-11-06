function pipelineGraphTest(previewPath)
%PIPELINEGRAPHTEST Actual arrow endpoints, branching lanes and stale clicks.
if nargin < 1, previewPath = ''; end
nodes = repmat(struct('id','','name','','type','processor'),1,7);
for k = 1:7, nodes(k).id = sprintf('step_%d',k); nodes(k).name = nodes(k).id; end
nodes(1).type = 'dataLoader'; nodes(2).type = 'roiPattern'; nodes(3).type = 'roiExtract'; nodes(4).type = 'classifier';
nodes(1).name = 'Load raw microscopy image data and metadata';
edges = repmat(struct('from','','to','','fromPort','roiList','toPort','roiList','condition',''),1,6);
for k = 1:6, edges(k).from = nodes(k).id; edges(k).to = nodes(k+1).id; end
original = edges;
figure = uifigure('Visible','off','Name','Pipeline connections','Position',[200 100 720 630]);
cleanup = onCleanup(@()delete(figure));
grid = uigridlayout(figure,[2 1]); grid.RowHeight = {'1x',26}; grid.Padding = [8 8 8 8];
panel = uipanel(grid,'BorderType','none'); status = uilabel(grid,'Text','Ready','Interpreter','none');
graph = detecdivui.PipelineGraph(panel,'test-pipeline-graph');
graph.OnStatus = @(message)set(status,'Text',message);
graph.OnSelect = @(index)set(status,'UserData',index);
graph.OnToggle = @(index)set(status,'UserData',-index);
% Shuffled edge storage must not change the actual module connections.
order = [5 1 6 3 2 4]; edges = edges(order); graph.show(nodes,edges,1);
figure.Visible = 'on'; drawnow;
started = tic;
while graph.Axes.Parent.InnerPosition(3)<650
    assert(toc(started)<12,'The initial graph layout did not settle.'); pause(.05); drawnow;
end
labels = findall(graph.Axes,'Tag','pipeline-graph-name');
label = labels(arrayfun(@(h)strcmp(h.UserData,nodes(1).name),labels));
assert(strcmp(label.String,nodes(1).name),'A wide card unnecessarily truncates its module name.');
lines = findall(graph.Axes,'Tag','pipeline-graph-edge'); assert(numel(lines)==6);
blocks = findall(graph.Axes,'Tag','pipeline-graph-node');
for line = reshape(lines,1,[])
    source = blocks([blocks.UserData] == find(strcmp({nodes.id},line.UserData.from)));
    target = blocks([blocks.UserData] == find(strcmp({nodes.id},line.UserData.to)));
    a = source.Position; b = target.Position;
    assert(isequal(line.XData,[a(1)+a(3)/2 b(1)+b(3)/2]));
    assert(isequal(line.YData,[a(2) b(2)+b(4)]));
    head = findall(graph.Axes,'Tag','pipeline-graph-arrow');
    head = head(arrayfun(@(h)h.UserData.edgeIndex==line.UserData.edgeIndex,head));
    assert(head.XData(1)==line.XData(end) && head.YData(1)==line.YData(end));
    assert(all(head.YData(2:3)>head.YData(1)),'The arrow points away from its target.');
end
assert(isequal(edges,original(order)));
% Several overlapping skip links, a back link, fan-in and a parallel resource
% binding all remain separate. Nothing is connected from node order alone.
extra = repmat(edges(1),1,6);
pairs = [1 4;1 6;2 6;6 2;3 3;3 4];
for k = 1:6, extra(k).from = nodes(pairs(k,1)).id; extra(k).to = nodes(pairs(k,2)).id; end
extra(6).condition = 'resourceBinding'; extra(6).fromPort = 'mask'; extra(6).toPort = 'mask';
edges = [edges extra]; graph.show(nodes,edges,1); routes = graph.Model.routes;
assert(numel(routes)==numel(edges));
for a = 1:numel(routes)
    for b = a+1:numel(routes)
        if routes(a).lane==0 || routes(b).lane==0, continue; end
        x = sort([routes(a).source(2) routes(a).target(2)]);
        y = sort([routes(b).source(2) routes(b).target(2)]);
        if max(x(1),y(1)) <= min(x(2),y(2))+.12
            assert(routes(a).lane~=routes(b).lane,'Overlapping links share a trunk.');
        end
    end
end
lines = findall(graph.Axes,'Tag','pipeline-graph-edge');
resource = lines(arrayfun(@(h)h.UserData.edgeIndex==numel(edges),lines)); assert(strcmp(resource.LineStyle,'--'));
% Clicking a link inspects its real ports and highlights just that link.
stale = resource.ButtonDownFcn; stale(resource,[]);
assert(strcmp(status.Text,'Binding: step_3.mask → step_4.mask'));
lines = findall(graph.Axes,'Tag','pipeline-graph-edge'); assert(nnz([lines.LineWidth]>2)==1);
graph.show(nodes,edges,1); status.Text = 'Unchanged'; stale([],[]); assert(strcmp(status.Text,'Unchanged'));
if ~isempty(previewPath)
    lines = findall(graph.Axes,'Tag','pipeline-graph-edge');
    resource = lines(arrayfun(@(h)h.UserData.edgeIndex==numel(edges),lines));
    resource.ButtonDownFcn(resource,[]);
    figure.Visible = 'on'; drawnow; pause(.4); exportapp(figure,previewPath);
end
% Resizing alone must keep the plot and connectors inside a narrow widget;
% no show()/redraw call is allowed to repair the axes after this resize.
figure.Visible = 'on'; figure.Position(3) = 240;
started = tic;
while graph.Axes.Parent.InnerPosition(3)>260 || ...
        abs(graph.Axes.InnerPosition(3)-graph.Axes.Parent.InnerPosition(3))>2
    assert(toc(started)<12,'Graph did not fit its resized container.'); pause(.05); drawnow;
end
labels = findall(graph.Axes,'Tag','pipeline-graph-name');
label = labels(arrayfun(@(h)strcmp(h.UserData,nodes(1).name),labels));
assert(numel(label.String)<numel(nodes(1).name) && strcmp(label.UserData,nodes(1).name));
labels = [labels;findall(graph.Axes,'Tag','pipeline-graph-state')];
for label = reshape(labels,1,[])
    extent = label.Extent;
    assert(extent(1)+extent(3)<=.94,'A resized module label extends beyond its card.');
end
figure.Position(3) = 720;
started = tic;
while graph.Axes.Parent.InnerPosition(3)<650 || ...
        abs(graph.Axes.InnerPosition(3)-graph.Axes.Parent.InnerPosition(3))>2
    assert(toc(started)<12,'Graph did not expand with its container.'); pause(.05); drawnow;
end
% Branch lanes consume horizontal space too. Check full restoration on the
% original chain, where the initial label fitted the same width.
graph.show(nodes,original,1);
labels = findall(graph.Axes,'Tag','pipeline-graph-name');
label = labels(arrayfun(@(h)strcmp(h.UserData,nodes(1).name),labels));
assert(strcmp(label.String,nodes(1).name),'Expanding the widget did not restore the full module name.');
graph.show(nodes,struct([]),1); assert(isempty(findall(graph.Axes,'Tag','pipeline-graph-edge')));
bad = original(1); bad.from = 'absent'; graph.show(nodes,bad,1);
assert(isempty(graph.Model.routes) && isscalar(graph.Model.issues) && contains(status.Text,'absent'));
% Node IDs, rather than row numbers or saved layouts, select endpoints.
reordered = nodes([7 6 5 4 3 2 1]); graph.show(reordered,original,1);
assert(all([graph.Model.routes.lane]>0));
assert(isequal({graph.Model.routes.key}, ...
    {detecdivui.PipelineGraphLayout.build(nodes,original).routes.key}));
disp('Pipeline graph test passed: exact declared endpoints, downward chains, independent branch/back/self routes, resource styles, port inspection, stale clicks and no fabricated links.');
end
