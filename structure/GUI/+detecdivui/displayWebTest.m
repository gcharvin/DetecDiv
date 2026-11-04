function displayWebTest(previewPath)
%DISPLAYWEBTEST Exercise real uihtml DOM events through the embedded browser.
if nargin < 1, previewPath = ''; end
viewer = detecdivui.displayTest('',true); cleanup = onCleanup(@()delete(viewer));
% Direct CEF test commands must not race the host's menu polling commands.
stop(timerfindall('Tag','DetecDivDockMenu'));
viewer.Host.show(); viewer.Host.focusWidget('Display'); drawnow; pause(.3);
windows = matlab.internal.webwindowmanager.instance.windowList;
window = windows(arrayfun(@(w)contains(w.URL,viewer.Host.App.Tag),windows));
assert(isscalar(window));
figure = viewer.widgetFigure('Display');
histogram = findall(figure,'Tag','display-histogram');
% Actual browser click/change events traverse JavaScript -> uihtml -> MATLAB.
browser(window,'layers', ...
    'const rows=doc.querySelectorAll(".row");if(rows.length!==3)throw Error("Missing rows");rows[0].querySelector("input[type=checkbox]").click();');
settle(); assert(~viewer.DisplayModel.Layers(1).visible);
browser(window,'layers','doc.querySelectorAll(".name")[1].click();');
settle(); assert(histogram.Data.selected == 2);
browser(window,'layers', ...
    'const input=doc.querySelectorAll("input[type=color]")[1];input.value="#ff0000";input.dispatchEvent(new Event("change",{bubbles:true}));');
settle(); assert(strcmp(viewer.DisplayModel.Layers(2).color,'1 0 0'));
browser(window,'layers', ...
    'const input=doc.querySelector(".selected input[aria-label^=Low]");input.value="250";input.dispatchEvent(new Event("change",{bubbles:true}));');
settle(); assert(viewer.DisplayModel.Layers(2).limits(1) == 250);
% Histogram overlay and keyboard level markers use the same contrast state.
before = viewer.DisplayModel.Layers(2).limits;
browser(window,'histogram','const marker=doc.querySelector(".level");if(!marker)throw Error("Missing marker");marker.dispatchEvent(new KeyboardEvent("keydown",{key:"ArrowRight",bubbles:true}));');
settle(); assert(viewer.DisplayModel.Layers(2).limits(1) > before(1));
browser(window,'histogram','doc.getElementById("log").click();');
settle(); assert(~histogram.Data.logCounts);
% Frame update and float/redock keep the same custom component/event bridge.
floating = floatingCount(); viewer.Host.setDocked('Display',false);
waitUntil(@()floatingCount() > floating);
viewer.Host.setDocked('Display',true); waitUntil(@()floatingCount() == floating);
viewer.Host.focusWidget('Display');
viewer.Host.App.waitForPendingAsyncOperations(); settle(); pause(.5);
browser(window,'layers','doc.querySelectorAll(".name")[2].click();');
settle(); assert(strcmp(histogram.Data.kind,'Labels'));
browser(window,'layers','doc.querySelectorAll(".name")[1].click();'); settle();
if ~isempty(previewPath), viewer.Host.focusWidget('Display'); drawnow; viewer.Host.capture(previewPath); end
disp('Display web test passed: browser selection, visibility, color, inline levels, histogram events and redocking.');
end
function browser(window,name,source)
script = "(()=>{const frame=Array.from(document.querySelectorAll('iframe')).find(f=>f.src.includes('/" + ...
    name + ".html'));if(!frame||!frame.contentDocument)return false;const doc=frame.contentDocument;" + ...
    source + ";return true;})()";
started = tic;
while true
    if jsondecode(window.executeJS(char(script),5)), return; end
    assert(toc(started) < 15,'Custom view did not attach to the docking window.');
    settle();
end
end
function settle()
drawnow; pause(.25); drawnow;
end
function count = floatingCount()
windows = matlab.internal.webwindowmanager.instance.windowList;
count = nnz(arrayfun(@(w)contains(w.URL,'undocked.html') && w.isVisible(),windows));
end
function waitUntil(condition)
started = tic;
while ~condition()
    assert(toc(started) < 15,'Docking operation timed out.'); settle();
end
end
