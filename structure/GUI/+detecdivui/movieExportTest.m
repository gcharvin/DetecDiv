function movieExportTest(preview)
%MOVIEEXPORTTEST Frozen Display parity, real movie/PDF I/O and UI isolation.
if nargin<1, preview=''; end
folder=tempname; mkdir(folder); files=onCleanup(@()rmdir(folder,'s'));
p=shallow(); p.io.file='Movie export'; p.fov.id='Position'; p.fov.interval=2.5;
r=roi('Cells',[1 1 40 32]); r.path=folder;
r.image=zeros(32,40,3,3,'uint16');
for frame=1:3
    r.image(:,:,1,frame)=uint16(repmat(1:40,32,1)*100+frame*200);
    r.image(:,:,2,frame)=uint16(repmat((1:32)',1,40)*50);
    r.image(7:14,11:19,3,frame)=uint16(frame);
end
r.channelid=1:3; r.display.channel={'Phase','Signal','Mask'}; r.display.indexed=[false false true];
r.display.intensity=[1 1 1;1 1 1;0 0 0]; r.display.selectedchannel=[true false false];
r.save([],false); r.load('Silent');
second=roi('Other Cells',r.value); second.path=folder; second.image=r.image; second.channelid=r.channelid; second.display=r.display;
p.fov.roi=[r second];
v=detecdiv_ui(p,'Visible','off','DiscoverWorkspace',false,'LayoutFile','','AutoSaveLayout',false, ...
    'RecentProjectsFile','','RecentPipelinesFile','','RecentClassifiersFile','');
cleanup=onCleanup(@()closeViewer(v));
tree=findall(v.widgetFigure('Projects'),'Tag','projects-tree'); nodes=findall(tree,'Tag','roi-node');
tree.SelectedNodes=nodes(arrayfun(@(n)n.UserData.roi==1,nodes)); tree.SelectionChangedFcn(tree,[]);
v.selectDisplayLayer('Signal'); v.selectDisplayLayer('Mask');
v.DisplayModel.setLimits(1,[500 5000]); v.DisplayModel.setLimits(2,[0 2000]);
v.DisplayModel.setColor(2,'0 1 0'); v.DisplayModel.setOpacity(2,.4);
v.DisplayModel.setOpacity(3,.6); v.DisplayModel.setLabelStyle(3,'Fill + Contours',2);
v.openMasksTool(); d=v.Masks.current(); d.edit(1,'paint',[28 23],7,2,false); v.contourChanged();
pixels=r.image; metadata=r.display; layerState=v.DisplayModel.Layers;
v.Host.findCommand('Export Movie...').invoke(); widget=v.MovieExport;
assert(~isempty(widget) && isempty(widget.LastError));
body=v.widgetFigure('Display'); assert(strcmp(findall(body,'Tag','movie-page').Visible,'on'));
assert(isempty(findall(body,'Type','uitabgroup','Visible','on')));
assert(findall(body,'Tag','movie-interval').Value==2.5);
job=widget.makeJob(); expected=v.DisplayModel.compose(1,3); actual=job.frameViews(1,1);
assert(numel(v.movieSources('open'))==1);
allJob=detecdivui.MovieExportJob(v.movieSources('fov'),widget.readSettings(),v.Masks.Drafts);
assert(numel(allJob.Entries)==2 && allJob.Options.Ncol==2);
assert(isequal(expected.pixels,actual{1}.pixels)&&isequal(expected.vectors,actual{1}.vectors));
assert(isequal(r.image,pixels)&&isequal(r.display,metadata));
% The snapshot keeps its settings and draft pixels after live edits/navigation.
v.DisplayModel.setColor(2,'1 0 0'); d.undo(); v.contourChanged();
frozen=job.frameViews(1,1); assert(isequal(actual{1}.pixels,frozen{1}.pixels));
v.DisplayModel.setColor(2,'0 1 0'); d.redo(); v.contourChanged();
v.closeContourTool();
options=widget.editOptions(); options.Controls.title.Value='Time lapse';
options.Controls.crop.Value='3 4 30 24'; options.Controls.rotation.Value='90';
options.Controls.scale.Value=2; options.Controls.background.Value=[.1 .1 .1];
assert(options.apply()); delete(options);
transformed=widget.makeJob(); views=transformed.frameViews(1,1);
assert(isequal(size(views{1}.pixels),[60 48 3]));
% A real three-frame movie is decoded again and has the requested FPS.
format=findall(body,'Tag','movie-format'); format.Value='Motion JPEG AVI'; format.ValueChangedFcn(format,[]);
path=widget.exportNow(fullfile(folder,'test.avi'));
assert(~isempty(path)&&isempty(widget.LastError),'Movie export failed: %s',widget.LastError);
reader=VideoReader(path); assert(abs(reader.FrameRate-20)<.01);
count=0; while hasFrame(reader), frame=readFrame(reader); assert(size(frame,3)==3); count=count+1; end
assert(count==3 && ~widget.Busy && ~widget.Progress.Active); clear reader;
assert(isequal(r.image,pixels)&&isequal(r.display,metadata)&&d.Dirty);
% Sequence/PDF uses Score's isolated full-canvas print path.
format.Value='PDF Sequence'; format.ValueChangedFcn(format,[]);
pdf=widget.exportNow(fullfile(folder,'sequence.pdf')); assert(isfile(pdf)&&isempty(widget.LastError));
fid=fopen(pdf,'r'); signature=char(fread(fid,4,'*char')'); fclose(fid); assert(strcmp(signature,'%PDF'));
% Cancellation leaves an existing destination intact and no partial files.
job=widget.makeJob(); job.Cancel=@()true; before=dir(pdf); failed=false;
try, job.write(pdf,true); catch err, failed=strcmp(err.identifier,'score:ExportCancelled'); end
after=dir(pdf); assert(failed && before.bytes==after.bytes && before.datenum==after.datenum);
assert(numel(dir(fullfile(folder,'*.pdf')))==1);
% Native preview remains independent of the live viewport and can be closed.
fig=widget.preview(); assert(isgraphics(fig)&&isempty(widget.LastError)); delete(fig);
back=findall(body,'Tag','movie-done'); back.ButtonPushedFcn(back,[]);
assert(strcmp(findall(body,'Tag','movie-page').Visible,'off'));
assert(strcmp(findall(body,'Tag','display-page').Visible,'on'));
assert(isequal(v.DisplayModel.Layers,layerState));
if ~isempty(preview)
    v.openMovieExport(); v.Host.show(); drawnow; pause(.3); v.Host.capture(preview);
end
assert(isequal(detecdivui.MovieExportJob.parseFrames('1:2:3',3),[1 3]));
failed=false; try, detecdivui.MovieExportJob.parseFrames('system(1)',3); catch, failed=true; end; assert(failed);
disp('Movie export passed: Display/draft pixel parity, frozen state, crop/rotation, video FPS/frame count, PDF, cancellation, isolated preview and flat UI.');
end
function closeViewer(v)
if ~isvalid(v), return; end
if ~isempty(v.Masks)&&isvalid(v.Masks)
    for k=1:numel(v.Masks.Drafts), d=v.Masks.Drafts{k}; if d.Dirty&&~d.SaveFailed, d.discard(); end; end
end
delete(v);
end
