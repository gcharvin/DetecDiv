function measurementsTest(preview)
%MEASUREMENTSTEST Score sampling, physical values and contextual geometry.
if nargin<1, preview=''; end
folder=tempname; mkdir(folder); files=onCleanup(@()rmdir(folder,'s'));
[y,x]=ndgrid(1:20,1:24); raw=uint16(x+2*y);
imwrite(raw,fullfile(folder,'raw1.tif')); imwrite(raw+100,fullfile(folder,'raw2.tif'));
r=roi('Cells',[1 1 24 20]); r.path=folder;
r.image=zeros(20,24,6,2,'uint16');
for f=1:2
    r.image(:,:,1,f)=raw+(f-1)*100; r.image(:,:,2,f)=raw*800;
    r.image(:,:,3,f)=uint16(100*x); r.image(:,:,5,f)=uint16(50*y); r.image(:,:,6,f)=200;
    r.image(4:8,5:10,4,f)=1;
end
r.channelid=[1 2 3 4 3 3]; r.display.channel={'Phase','Signal','RGB','Masks'};
r.display.intensity=[1 1 1;1 1 1;1 1 1;0 0 0]; r.display.rgb=ones(4,3);
r.display.selectedchannel=true(1,4); r.display.indexed=[false false false true]; r.display.frame=1;
transform=score_channelValueTransform([],0); r.display.valueTransform=repmat(transform,1,4);
r.display.valueTransform(2)=struct('mode','physical','unit','a.u.','physicalRange',[-3 3], ...
    'encodedRange',[0 65535],'transform','linear');
other=roi('Other',[1 1 24 20]); other.path=folder; other.image=r.image;
other.channelid=r.channelid; other.display=r.display;
pixels=r.image; metadata=r.display;
p=shallow(); p.io.file='Intensity measurements'; p.fov.id='Position'; p.fov.channel={'Raw'};
p.fov.srcpath={folder}; p.fov.srclist={dir(fullfile(folder,'raw*.tif'))}; p.fov.frames=2; p.fov.roi=[r other];
v=detecdiv_ui(p,'Visible','off','DiscoverWorkspace',false,'LayoutFile','','AutoSaveLayout',false, ...
    'RecentProjectsFile','','RecentPipelinesFile','','RecentClassifiersFile','');
cleanup=onCleanup(@()closeViewer(v));
assert(isempty(v.Measurements)&&~v.Host.isWidgetVisible('Measurements'));
% Opening the tool before loading pixels must stay metadata-only.
beforeOpening=v.Host.App.DocumentLayout;
v.Host.findCommand('Measure Intensity...').invoke(); assert(v.Measurements.Active&&isempty(v.Measurements.Results));
assert(isempty(findall(v.Figure,'Type','image')));
tree=findall(v.widgetFigure('Projects'),'Tag','projects-tree'); selectROI(1);
m=v.Measurements; line=[2 5;20 5]; m.setGeometry('Line',line);
assert(v.Host.Widgets.measurements.Showing,'The Measurements document is not showing after opening.');
initial=v.Host.App.DocumentLayout;
assertWithDisplay(initial);
assert(isequal(initial.tileCoverage,beforeOpening.tileCoverage)&&isequal(initial.rowWeights,beforeOpening.rowWeights), ...
    'Opening Measurements split the image workspace.');
assert(numel(m.Results)==3&&~any(strcmp({m.Results.layer},'Masks')));
expected=improfile(double(raw),line(:,1),line(:,2)); assert(isequal(m.Results(1).sample.values,expected));
assert(abs(m.Results(1).sample.x(end)-18)<eps);
encoded=improfile(double(r.image(:,:,2,1)),line(:,1),line(:,2));
assert(max(abs(m.Results(2).sample.values-(-3+double(encoded)*6/65535)))<1e-12);
assert(strcmp(m.Results(2).sample.unit,'a.u.'));
rgb=.2989*double(r.image(:,:,3,1))+.5870*double(r.image(:,:,5,1))+.1140*double(r.image(:,:,6,1));
assert(isequal(m.Results(3).sample.values,improfile(rgb,line(:,1),line(:,2))));
assert(~v.objectsBrowserActive()&&(isempty(v.Masks)||~v.Masks.Active));

% Changing Display contrast never changes the sampled scientific values.
v.DisplayModel.setLimits(1,[0 20]); v.selectDisplayLayer('Phase');
assert(isequal(m.Results(1).sample.values,expected));
setFrame(2); assert(isequal(m.Results(1).sample.values,expected+100));
assert(isequal(m.Shape.Position,line));
csv=m.exportCSV(fullfile(folder,'line.csv'));
exported=readtable(csv,'Delimiter',',','ReadVariableNames',true,'VariableNamingRule','preserve');
assert(height(exported)==sum(arrayfun(@(item)numel(item.sample.values),m.Results))&&all(exported.Frame==2));

% Moving shapes previews measurements and temporarily owns image gestures.
generation=m.Revision; moved=[3 6;18 6]; m.Shape.Position=moved;
m.geometryChanged(generation,true); assert(v.contourGestureActive());
v.Host.findCommand('Previous Frame').invoke();
assert(v.annotationFrame()==2);
m.geometryChanged(generation,false); assert(~v.contourGestureActive());
assert(isequal(m.Results(1).sample.values,improfile(double(raw+100),moved(:,1),moved(:,2))));
old=m.Revision; setFrame(1); m.geometryChanged(old,false); assert(isequal(m.Shape.Position,moved));

% Ellipse pixels, histogram and statistics share Score's source-unit helper.
m.setGeometry('Ellipse',[12 10 7 4 20]); mask=createMask(m.Shape,raw);
values=double(raw(mask)); sample=m.Results(1).sample;
assert(sample.count==nnz(mask)&&sum(sample.counts)==nnz(mask));
assert(sample.median==median(values)&&abs(sample.mean-mean(values))<eps);
constant=score_measureIntensity(ones(5),'Region',true(5));
assert(constant.count==25&&sum(constant.counts)==25&&constant.std==0);
empty=score_measureIntensity(nan(5),'Region',true(5)); assert(empty.count==0&&isempty(empty.counts));
% Legacy Score wrappers consume the same sampling contract and keep their UI.
legacy=figure('Visible','off'); legacyCleanup=onCleanup(@()delete(legacy)); ax=axes(legacy);
app=struct('UIROITable',struct('Data',{{true}}),'content',struct('ROIList',{{r}}), ...
    'UIChannelTable',struct('Data',{{true;true;true}}),'UIProfileAxes',ax);
score_updateIntensityProfile(app,line);
curves=findall(ax,'Type','line'); assert(numel(curves)==3);
actual=cellfun(@(value)reshape(value,[],1),get(curves,'YData'),'UniformOutput',false);
assert(any(cellfun(@(value)isequal(value,expected),actual)));
% Compare the exact selected region. MATLAB tessellates independent native
% ellipses differently on classic versus web axes even at equal radii.
score_updateEllipticalProfile(app,m.Shape);
curves=findall(ax,'Type','stair'); assert(numel(curves)==3);
assert(any(arrayfun(@(curve)isequal(curve.YData(:),sample.counts(:)),curves)), ...
    'Legacy region plot differs (ROI frame %d; viewer frame %d; expected N %d; plotted counts %s).', ...
    r.display.frame,v.annotationFrame(),sample.count,mat2str(arrayfun(@(curve)sum(curve.YData),curves)));

% Keep a geometry per image context, never transfer it into another ROI.
selectROI(2); assert(isempty(m.Results)&&isempty(m.Shape));
m.geometryChanged(old,false); assert(isempty(m.Shape));
selectROI(1); assert(isa(m.Shape,'images.roi.Ellipse')&&isequal(m.Shape.Center,[12 10]));
v.Host.setDocked('Measurements',false); v.Host.setDocked('Measurements',true);
assert(~isempty(m.Results)&&m.Active);
v.Host.saveLayout(fullfile(folder,'layout.json')); assert(v.Host.restoreLayout(fullfile(folder,'layout.json')));
v.Host.closeWidget('Measurements'); assert(~m.Active&&isempty(m.Shape));
v.openMeasurements(); assert(v.Measurements==m&&~isempty(m.Shape));
v.selectDisplayLayer('Masks'); v.openContourTool(); assert(~m.Active&&isempty(m.Shape)&&v.Masks.Active);
v.Host.setDocked('Measurements',false); v.Host.setDocked('Measurements',true);
assert(~m.Active&&v.Masks.Active,'Redocking a suspended measurement changed the active drawing tool.');
v.openMeasurements(); assert(m.Active&&~v.Masks.Active);

% Raw FOV sampling uses the same tool with no project ROI construction.
back=findall(v.Figure,'Tag','parent-fov'); back.ButtonPushedFcn(back,[]);
assert(isempty(m.Shape)); m.setGeometry('Line',line);
assert(isscalar(m.Results)&&strcmp(m.Results(1).sample.unit,'raw'));
assert(isequal(m.Results(1).sample.values,expected));
assert(isequal(r.image,pixels)&&isequal(r.display,metadata)&&isempty(dir(fullfile(folder,'*.h5'))));
selectROI(1); v.Host.resetLayout(); v.openMeasurements(); assertWithDisplay(v.Host.App.DocumentLayout);
v.Host.show(); v.Host.focusWidget('Measurements'); drawnow;
assert(v.Host.Widgets.measurements.Docked&&v.Host.Widgets.measurements.Showing, ...
    'Final measurement document: docked=%d showing=%d layout=%s', ...
    v.Host.Widgets.measurements.Docked,v.Host.Widgets.measurements.Showing,jsonencode(v.Host.App.DocumentLayout));
if ~isempty(preview), v.Host.capture(preview); end
disp('Measurements passed: Score parity, RGB/physical units, live geometry/frame updates, view isolation, stale callbacks, CSV, drawing ownership and native docking/layout.');
    function selectROI(index)
        nodes=findall(tree,'Tag','roi-node'); node=nodes(arrayfun(@(n)n.UserData.roi==index,nodes));
        tree.SelectedNodes=node; tree.SelectionChangedFcn(tree,[]);
    end
    function setFrame(frame)
        control=findall(v.Figure,'Tag','frame-number'); control.Value=frame; control.ValueChangedFcn(control,[]);
    end
end
function closeViewer(v)
if ~isvalid(v), return; end
if ~isempty(v.Masks), for k=1:numel(v.Masks.Drafts), v.Masks.Drafts{k}.discard(); end; end
delete(v);
end
function assertWithDisplay(layout)
image=detecdivui.WorkspaceLayout.tile(layout,'workspace_image');
measurement=detecdivui.WorkspaceLayout.tile(layout,'workspace_measurements');
display=detecdivui.WorkspaceLayout.tile(layout,'workspace_display');
assert(~isempty(image)&&~isempty(measurement)&&measurement==display&&measurement~=image, ...
    'Measurements must open in the Display tab group.');
end
