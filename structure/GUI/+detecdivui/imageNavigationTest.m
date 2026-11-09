function imageNavigationTest(preview)
%IMAGENAVIGATIONTEST Still-image keys, mode buttons and export viewport.
if nargin<1, preview=''; end
p=shallow(); p.io.file='Navigation'; p.fov.id='Position';
r=roi('Still',[1 1 90 60]); r.image=uint16(reshape(1:5400,60,90));
r.channelid=1; r.display.channel={'Phase'}; p.fov.roi=r; original=r.image;
v=detecdiv_ui(p,'Visible','off','DiscoverWorkspace',false,'LayoutFile','','AutoSaveLayout',false, ...
    'RecentProjectsFile','','RecentPipelinesFile','','RecentClassifiersFile','');
cleanup=onCleanup(@()delete(v));
tree=findall(v.widgetFigure('Projects'),'Tag','projects-tree'); node=findall(tree,'Tag','roi-node');
tree.SelectedNodes=node; tree.SelectionChangedFcn(tree,[]); v.Host.show(); v.Host.focusWidget('Image'); settle();
windows=matlab.internal.webwindowmanager.instance.windowList;
window=windows(find(arrayfun(@(w)contains(w.URL,v.Host.App.Tag),windows),1));
ax=v.roiAxes(); keyboard=findall(v.Figure,'Tag','image-keyboard');
assert(keyboard.Data.enabled,'A still image must accept zoom keys.');
sendKey('7'); assert(isequal(ax.XLim,[.5 30.5])&&isequal(ax.YLim,[.5 20.5]));
sendKey('0'); assert(isequal(ax.XLim,[.5 90.5])&&isequal(ax.YLim,[.5 60.5]));
zoom=findall(v.Figure,'Tag','image-zoom'); pan=findall(v.Figure,'Tag','image-pan');
disableDefaultInteractivity(ax); % Simulate automatic suppression by image callbacks.
zoom.Value=true; zoom.ValueChangedFcn(zoom,[]); settle();
assert(v.imageNavigationActive()&&zoom.Value);
assert(strcmp(ax.InteractionContainer.CurrentMode,'zoom'));
pan.Value=true; pan.ValueChangedFcn(pan,[]); settle(); assert(pan.Value&&~zoom.Value);
ax.XLim=[20 45]; ax.YLim=[10 35];
source=v.movieSources('current'); assert(isequal(source.viewport,[20 45 10 35]));
sendKey('m'); assert(findall(v.Figure,'Tag','frame-number').Value==1);
reset=findall(v.Figure,'Tag','image-reset'); reset.ButtonPushedFcn(reset,[]);
assert(isequal(ax.XLim,[.5 90.5])&&isequal(ax.YLim,[.5 60.5]));
assert(isequal(r.image,original)&&findall(v.Figure,'Tag','frame-number').Value==1);
if ~isempty(preview), drawnow; v.Host.capture(preview); end
disp('Image navigation passed: still-image keypad, mode buttons, reset, export viewport and source preservation.');
    function sendKey(key)
        script="(()=>{const f=Array.from(document.querySelectorAll('iframe')).find(f=>f.src.includes('/imageKeyboard.html'));"+ ...
            "const t=f.closest('.gbtFigureLayoutContainer').querySelector('canvas div');t.dispatchEvent(new KeyboardEvent('keydown',{key:"+ ...
            jsonencode(key)+",code:"+jsonencode(['Numpad' key])+",bubbles:true,cancelable:true}));})()";
        window.executeJS(char(script),5); settle();
    end
end
function settle()
drawnow; pause(.2); drawnow;
end
