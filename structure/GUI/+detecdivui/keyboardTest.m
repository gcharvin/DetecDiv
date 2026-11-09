function keyboardTest()
%KEYBOARDTEST Real CEF key events, focus isolation and floating Image document.
project = shallow(); project.io.file = 'Keyboard test'; project.fov.id = 'Position';
r = roi('Sequence',[1 1 12 12]);
r.image = repmat(reshape(uint16(1:25),1,1,1,25),12,12,1,1);
r.image(:,:,2,:) = r.image+50;
r.image(:,:,3,:) = 0; r.image(4:8,4:8,3,:) = 1;
r.channelid = 1:3; r.display.channel = {'Phase','GFP','Cells'};
r.display.rgb = [1 1 1;0 1 0;1 0 0]; r.display.indexed = [false false true];
r.display.selectedchannel = [true false false]; r.display.alpha = [1 1 .5];
r.display.contour = [false false true]; project.fov.roi = r;
source = r.image;
viewer = detecdiv_ui(project,'Visible','off','DiscoverWorkspace',false, ...
    'LayoutFile','','AutoSaveLayout',false,'RecentProjectsFile','','RecentPipelinesFile','');
cleanup = onCleanup(@()delete(viewer));
stop(timerfindall('Tag','DetecDivDockMenu'));
tree = findall(viewer.widgetFigure('Projects'),'Tag','projects-tree');
node = findall(tree,'Tag','roi-node'); tree.SelectedNodes = node; tree.SelectionChangedFcn(tree,[]);
viewer.Host.show(); viewer.Host.focusWidget('Image'); settle();
frame = findall(viewer.Figure,'Tag','frame-number');
[~,keys] = detecdiv_prefs_get_shortcuts(); jump = keys{3};
window = imageWindow();
% Use real browser focus, not a synthetic target inside the canvas fallback.
assert(key(window,'ArrowRight','',false)); waitFrame(2);
assert(key(window,'ArrowLeft','',false)); waitFrame(1);
assert(key(window,jump{2},'canvas div',false)); waitFrame(11);
assert(key(window,jump{2},'canvas div',false)); waitFrame(21);
assert(key(window,jump{2},'canvas div',false)); waitFrame(25);
assert(key(window,jump{1},'canvas div',false)); waitFrame(15);
assert(key(window,'ArrowRight','canvas div',false)); waitFrame(16);
assert(key(window,'ArrowRight','canvas div',false)); waitFrame(17);
% Arrow editing and Ctrl combinations must retain their native behavior.
assert(~key(window,'ArrowLeft','input',false)); settle(); assert(frame.Value == 17);
assert(~key(window,'ArrowLeft','canvas div',true)); settle(); assert(frame.Value == 17);
assert(~key(window,'Delete','canvas div',false)); settle(); assert(frame.Value == 17);
% Real native button clicks leave focus on role=button, not on the canvas.
% Focus that button before invoking its actual DOM click handler, then send
% successive keys to the focused element without selecting the Image tab.
clickButton(window,'›'); waitFrame(18);
assert(key(window,'ArrowRight','',false)); waitFrame(19);
assert(key(window,'ArrowLeft','',false)); waitFrame(18);
clickButton(window,'‹'); waitFrame(17);
assert(key(window,'ArrowRight','',false)); waitFrame(18);
assert(key(window,'ArrowLeft','',false)); waitFrame(17);
viewer.Host.findCommand('Back 10 Frames').invoke(); assert(frame.Value == 7);
viewer.Host.findCommand('Forward 10 Frames').invoke(); assert(frame.Value == 17);
viewer.openROITool(); viewer.Host.focusWidget('Image'); settle();
assert(~key(window,'ArrowLeft','canvas div',false)); settle(); assert(frame.Value == 1);
viewer.closeROITool();
% ROI definition switches the central image to raw FOV coordinates. Return
% explicitly to the cached ROI sequence before testing frame navigation.
tree.SelectedNodes = node; tree.SelectionChangedFcn(tree,[]);
viewer.Host.focusWidget('Image'); settle(); assert(frame.Value == 17);
gesture = viewer.beginROIGesture(); %#ok<NASGU>
settle();
assert(~key(window,'ArrowLeft','canvas div',false)); settle(); assert(frame.Value == 17);
clear gesture; settle();
% Native controls, source data and zoom remain synchronized with key navigation.
ax = viewer.roiAxes(); ax.XLim = [2 8]; ax.YLim = [3 9];
assert(key(window,'ArrowRight','canvas div',false)); waitFrame(18);
image = findall(ax,'Type','image'); assert(all(image.CData(:) == 18));
assert(isequal(ax.XLim,[2 8]) && isequal(ax.YLim,[3 9]));
slider = findall(viewer.Figure,'Tag','time-slider'); assert(slider.Value == 18);
% Committing a layout choice returns focus to Image. Repeated arrows retain
% channel panels, checked layers, mask fill/contours, contrast and linked zoom.
display = viewer.widgetFigure('Display'); layout = findall(display,'Tag','display-overlay');
for channel = 1:3, viewer.DisplayModel.setVisible(channel,true); end
viewer.DisplayModel.setLimits(1,[0 25]); viewer.DisplayModel.setLimits(2,[0 100]);
viewer.DisplayModel.setColor(3,'1 0 0');
layout.Value = false; layout.ValueChangedFcn(layout,[]); settle();
assert(key(window,'ArrowRight','',false)); waitFrame(19); assertLayers(2);
assert(key(window,'ArrowRight','',false)); waitFrame(20); assertLayers(2);
assert(key(window,'ArrowLeft','',false)); waitFrame(19); assertLayers(2);
layout.Value = true; layout.ValueChangedFcn(layout,[]); settle();
assert(key(window,'ArrowLeft','',false)); waitFrame(18); assertLayers(1);
assert(key(window,'ArrowRight','',false)); waitFrame(19); assertLayers(1);
layout.Value = false; layout.ValueChangedFcn(layout,[]); settle();
assert(key(window,'ArrowLeft','',false)); waitFrame(18); assertLayers(2);
viewer.Host.setDocked('Image',false); window = imageWindow();
assert(key(window,'ArrowLeft','',false)); waitFrame(17); assertLayers(2);
viewer.Host.setDocked('Image',true); viewer.Host.focusWidget('Image'); window = imageWindow();
assert(key(window,'ArrowLeft','',false)); waitFrame(16); assertLayers(2);
viewer.Host.findCommand('Keyboard Shortcuts...').invoke();
help = findall(groot,'Tag','keyboard-shortcuts'); assert(isscalar(help));
rows = findall(help,'Tag','keyboard-shortcuts-table');
assert(strcmpi(rows.Data{4,1},jump{2}));
assert(strcmpi(viewer.Host.findCommand('Forward 10 Frames').Shortcut,jump{2}));
viewer.Host.syncMenus();
command = viewer.Host.findCommand('Previous Frame');
label = viewer.Host.menuScript(sprintf( ...
    'document.querySelector(''[data-command="%s"] .dd-shortcut'').textContent',command.Id));
assert(strcmp(jsondecode(label),'Left Arrow'));
viewer.Host.findCommand('Keyboard Shortcuts...').invoke();
assert(isscalar(findall(groot,'Tag','keyboard-shortcuts')));
assert(isequal(r.image,source));
delete(viewer); assert(~isvalid(help)); clear cleanup;
disp('Keyboard test passed: actual figure focus, Score preferences, stable channel layouts/masks, frame bounds, focus isolation, zoom, float/redock and help.');

    function waitFrame(expected)
        started = tic;
        while frame.Value ~= expected
            assert(toc(started) < 12,'Keyboard navigation did not reach frame %d (actual %d).',expected,frame.Value);
            settle();
        end
        settle(); assert(frame.Value == expected,'A key was handled more than once.');
    end
    function assertLayers(count)
        axes = [findall(viewer.Figure,'Tag','image-view');findall(viewer.Figure,'Tag','channel-view')];
        assert(numel(axes) == count && all([viewer.DisplayModel.Layers.visible]));
        assert(layout.Value == (count == 1));
        assert(isequal(viewer.DisplayModel.Layers(1).limits,[0 25]));
        assert(isequal(viewer.DisplayModel.Layers(2).limits,[0 100]));
        for panel = reshape(axes,1,[])
            assert(isscalar(findall(panel,'Tag','mask-contour')));
            rendered = findall(panel,'Type','image'); rgb = rendered.CData;
            assert(rgb(5,5,1) > rgb(5,5,2),'Mask fill disappeared during frame navigation.');
            assert(isequal(panel.XLim,[2 8]) && isequal(panel.YLim,[3 9]));
        end
    end
    function window = imageWindow()
        started = tic;
        while true
            windows = matlab.internal.webwindowmanager.instance.windowList;
            for k = 1:numel(windows)
                if ~contains(windows(k).URL,viewer.Host.App.Tag) && ~contains(windows(k).URL,'undocked.html'), continue; end
                try
                    found = jsondecode(windows(k).executeJS( ...
                        '!!Array.from(document.querySelectorAll("iframe")).find(f=>f.src.includes("/imageKeyboard.html")&&f.closest(".figureContainerNode")?.getBoundingClientRect().width>0&&f.closest(".figureContainerNode")?.querySelector("canvas div")&&f.contentDocument&&f.contentDocument.body.dataset.ready==="true")',5));
                catch
                    % A just-redocked CEF window can remain in this inventory.
                    continue;
                end
                if found, window = windows(k); return; end
            end
            assert(toc(started) < 15,'Image keyboard bridge did not attach.'); settle();
        end
    end
end
function clickButton(window,label)
script = "(()=>{const f=Array.from(document.querySelectorAll('iframe')).find(f=>f.src.includes('/imageKeyboard.html')&&f.closest('.figureContainerNode')?.getBoundingClientRect().width>0);" + ...
    "const scope=f.closest('.gbtFigureLayoutContainer');const button=Array.from(scope.querySelectorAll('[role=button],button')).find(b=>b.textContent.trim()===" + ...
    jsonencode(label) + ");if(!button)throw Error('Frame button missing');button.focus();button.click();})()";
window.executeJS(char(script),5);
end
function consumed = key(window,keyName,selector,ctrl)
script = "(()=>{const f=Array.from(document.querySelectorAll('iframe')).find(f=>f.src.includes('/imageKeyboard.html')&&f.closest('.figureContainerNode')?.getBoundingClientRect().width>0&&f.closest('.figureContainerNode')?.querySelector('canvas div'));" + ...
    "const scope=f.closest('.figureContainerNode');const selector=" + jsonencode(selector) + ...
    ";const target=selector?scope.querySelector(selector):document.activeElement;if(selector)target.focus();const event=new KeyboardEvent('keydown',{key:" + jsonencode(keyName) + ...
    ",bubbles:true,cancelable:true,ctrlKey:" + lower(string(ctrl)) + ...
    "});target.dispatchEvent(event);return event.defaultPrevented;})()";
consumed = jsondecode(window.executeJS(char(script),5));
end
function settle()
drawnow; pause(.15); drawnow;
end
