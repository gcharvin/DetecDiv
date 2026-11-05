function liveDisplayTest()
%LIVEDISPLAYTEST Preview before release, exact commits and stale-gesture guards.
timers = numel(timerfindall('Tag','DetecDivLiveDisplay'));
project = shallow(); project.io.file = 'Live display'; project.fov.id = 'Position';
for index = 1:2
    r = roi(sprintf('Cells %d',index),[1 1 20 20]);
    for frame = 1:4
        plane = uint16(reshape(1:400,20,20)+100*(frame-1)+index);
        r.image(:,:,:,frame) = cat(3,plane,plane/2);
    end
    r.channelid = 1:2; r.display.channel = {'Phase','GFP'};
    r.display.rgb = [1 1 1;0 1 0]; r.display.selectedchannel = [true true];
    project.fov.roi(index) = r;
end
source = project.fov.roi(1); pixels = source.image; metadata = source.display;
viewer = detecdiv_ui(project,'Visible','off','DiscoverWorkspace',false, ...
    'LayoutFile','','AutoSaveLayout',false,'RecentProjectsFile','');
cleanup = onCleanup(@()delete(viewer));
stop(timerfindall('Tag','DetecDivDockMenu'));
tree = findall(viewer.widgetFigure('Projects'),'Tag','projects-tree');
nodes = findall(tree,'Tag','roi-node');
first = nodes(arrayfun(@(node)node.UserData.roi == 1,nodes));
second = nodes(arrayfun(@(node)node.UserData.roi == 2,nodes));
tree.SelectedNodes = first; tree.SelectionChangedFcn(tree,[]);
slider = findall(viewer.Figure,'Tag','time-slider');
frameField = findall(viewer.Figure,'Tag','frame-number');
histogram = findall(viewer.widgetFigure('Display'),'Tag','display-histogram');
original = imagePixels(viewer);
% ValueChanging uses event.Value while the slider's committed Value is old.
slider.ValueChangingFcn(slider,struct('Value',2.1));
waitUntil(@()frameField.Value == 2);
assert(slider.Value == 1 && any(imagePixels(viewer) ~= original,'all'));
assert(histogram.Data.stats.median == median(double(source.image(:,:,1,2)),'all'));
slider.ValueChangingFcn(slider,struct('Value',3));
slider.ValueChangingFcn(slider,struct('Value',4));
waitUntil(@()frameField.Value == 4);
slider.ValueChangingFcn(slider,struct('Value',2));
slider.Value = 3; slider.ValueChangedFcn(slider,[]);
settle(); assert(frameField.Value == 3 && slider.Value == 3);
overlay = findall(viewer.widgetFigure('Display'),'Tag','display-overlay');
overlay.Value = false; overlay.ValueChangedFcn(overlay,[]);
slider.ValueChangingFcn(slider,struct('Value',4));
waitUntil(@()frameField.Value == 4);
assert(numel(findall(viewer.Figure,'Type','image')) == 2 && ~overlay.Value);
slider.Value = 3; slider.ValueChangedFcn(slider,[]);
overlay.Value = true; overlay.ValueChangedFcn(overlay,[]);
% Native range preview changes rendered pixels/numeric fields before release.
display = viewer.widgetFigure('Display'); range = findall(display,'Tag','contrast-range');
before = imagePixels(viewer); committed = range.Value;
limits = [committed(1)+10 committed(2)-20];
range.ValueChangingFcn(range,struct('Value',limits));
waitUntil(@()isequal(viewer.DisplayModel.Layers(1).limits,limits));
assert(isequal(range.Value,committed) && any(imagePixels(viewer) ~= before,'all'));
minimum = findall(display,'Tag','contrast-min'); assert(minimum.Value == limits(1));
range.ValueChangingFcn(range,struct('Value',limits+[1 -1]));
final = limits+[2 -2]; range.Value = final; range.ValueChangedFcn(range,[]);
settle(); assert(isequal(viewer.DisplayModel.Layers(1).limits,final));
% A pending drag belongs to its original ROI; navigation cancels it.
slider.ValueChangingFcn(slider,struct('Value',4));
tree.SelectedNodes = second; tree.SelectionChangedFcn(tree,[]);
selected = frameField.Value; settle(); assert(frameField.Value == selected);
tree.SelectedNodes = first; tree.SelectionChangedFcn(tree,[]);
viewer.Host.show(); viewer.Host.focusWidget('Display'); settle();
windows = matlab.internal.webwindowmanager.instance.windowList;
window = windows(arrayfun(@(w)contains(w.URL,viewer.Host.App.Tag),windows)); assert(isscalar(window));
% Exercise the embedded pointer handlers through uihtml. Only native pointer
% capture is stubbed for these synthetic events; a real drag is checked on OS.
before = viewer.DisplayModel.Layers(1).limits; rendered = imagePixels(viewer);
browser(window,"window.chart=doc.getElementById('chart');window.capture=chart.setPointerCapture;chart.setPointerCapture=()=>{};" + ...
    "window.marker=doc.querySelector('.level');window.svgPoint=chart.createSVGPoint();" + ...
    "marker.onpointerdown({preventDefault(){},pointerId:41});" + ...
    "const rect=chart.getBoundingClientRect();chart.onpointermove({pointerId:41,clientX:rect.left+rect.width*.45});");
waitUntil(@()viewer.DisplayModel.Layers(1).limits(1) > before(1));
assert(any(imagePixels(viewer) ~= rendered,'all'));
assert(browserValue(window,"doc.querySelector('.level')===marker"),'Histogram redraw interrupted its active gesture.');
live = viewer.DisplayModel.Layers(1).limits(1);
browser(window,"const rect=chart.getBoundingClientRect();chart.onpointermove({pointerId:41,clientX:rect.left+rect.width*.6});");
waitUntil(@()viewer.DisplayModel.Layers(1).limits(1) > live);
browser(window,"chart.onpointerup({pointerId:41});chart.setPointerCapture=capture;");
settle(); committed = viewer.DisplayModel.Layers(1).limits;
assert(isequal(histogram.Data.limits,committed));
browser(window,"chart.setPointerCapture=()=>{};doc.querySelectorAll('.level')[1].onpointerdown({preventDefault(){},pointerId:43});" + ...
    "const rect=chart.getBoundingClientRect();chart.onpointermove({pointerId:43,clientX:rect.left+rect.width*.9});");
waitUntil(@()viewer.DisplayModel.Layers(1).limits(2) > committed(2));
assert(viewer.DisplayModel.Layers(1).limits(1) == committed(1));
browser(window,"chart.onpointerup({pointerId:43});chart.setPointerCapture=capture;");
settle(); committed = viewer.DisplayModel.Layers(1).limits;
% Pointer cancellation restores the limits from the start of that gesture.
browser(window,"chart.setPointerCapture=()=>{};doc.querySelector('.level').onpointerdown({preventDefault(){},pointerId:42});" + ...
    "const rect=chart.getBoundingClientRect();chart.onpointermove({pointerId:42,clientX:rect.left+rect.width*.7});");
waitUntil(@()viewer.DisplayModel.Layers(1).limits(1) > committed(1));
browser(window,"chart.onpointercancel();chart.setPointerCapture=capture;");
waitUntil(@()isequal(viewer.DisplayModel.Layers(1).limits,committed));
% A new frame invalidates queued old histogram previews and commits.
stale = struct('revision',histogram.Data.revision,'action','limits','value',[1 2], ...
    'context',histogram.Data.context,'sequence',histogram.Data.ack+1,'phase','commit');
slider.Value = 1; slider.ValueChangedFcn(slider,[]);
histogram.DataChangedFcn(histogram,struct('Data',stale));
assert(isequal(viewer.DisplayModel.Layers(1).limits,committed));
assert(isequal(source.image,pixels) && isequal(source.display,metadata));
delete(viewer); clear cleanup;
assert(numel(timerfindall('Tag','DetecDivLiveDisplay')) == timers);
disp('Live display test passed: frames/contrast before release, latest-value coalescing, exact final values, retained histogram gesture, stale-context rejection and timer cleanup.');
end
function value = imagePixels(viewer)
image = findall(viewer.roiAxes(),'Type','image'); assert(isscalar(image)); value = image.CData;
end
function browser(window,source)
browserValue(window,source+"return true;");
end
function result = browserValue(window,source)
script = "(()=>{const frame=Array.from(document.querySelectorAll('iframe')).find(f=>f.src.includes('/histogram.html'));" + ...
    "const doc=frame.contentDocument;";
if startsWith(source,"doc."), source = "return "+source+";"; end
result = jsondecode(window.executeJS(char(script+source+"})()"),5));
end
function waitUntil(condition)
started = tic;
while ~condition()
    assert(toc(started)<12,'Live display did not update before release.'); pause(.03); drawnow;
end
end
function settle()
pause(.2); drawnow; pause(.2); drawnow;
end
