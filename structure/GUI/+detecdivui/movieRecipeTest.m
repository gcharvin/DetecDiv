function movieRecipeTest()
%MOVIERECIPETEST Exercise isolated recipes without building a viewer shell.
folder=tempname; mkdir(folder); cleanup=onCleanup(@()rmdir(folder,'s'));
p=shallow(); p.fov.id='Position'; r=roi('A',[1 1 40 32]); r.path=folder;
r.image=zeros(32,40,3,3,'uint16'); r.image(:,1:32,1,:)=repmat(uint16(magic(32)*30),1,1,1,3);
% magic(32) is square: extend to the requested width.
r.image(:,33:40,1,:)=r.image(:,1:8,1,:);
r.image(:,:,2,:)=300; r.image(8:14,8:14,3,:)=1;
r.channelid=1:3; r.display.channel={'Phase','Signal','Mask'}; r.display.indexed=[false false true];
r.display.intensity=[1 1 1;1 1 1;0 0 0]; r.display.selectedchannel=[true true true]; p.fov.roi=r;
s=detecdivui.Session(p); s.selectZone(1); model=detecdivui.LayerModel(); model.configure(s,1);
model.setLimits(1,[0 32000]); model.setLimits(2,[0 600]); model.setColor(2,'0 1 0'); model.setLabelStyle(3,'Contours',2);
sources=struct('session',s,'model',model,'position',1,'zone',1,'frame',1,'channel','Phase','overlay',false,'outlines',false);
settings=detecdivui.MovieExportJob.defaults(); settings.profile='Motion JPEG AVI'; settings.fps=7;
job=detecdivui.MovieExportJob(sources,settings); original=model.separate(1,1); actual=job.frameViews(1,1);
assert(numel(actual)==2&&isequal(actual{1}.vectors,original{1}.vectors));
assert(isequal(actual{2}.pixels,original{2}.pixels));
movie=job.write(fullfile(folder,'movie.avi')); assert(isfile(movie));
reader=VideoReader(movie); assert(abs(reader.FrameRate-7)<.01);
clear reader;
flag=containers.Map({'cancel'},{false}); job.Cancel=@()flag('cancel'); job.Progress=@(f)cancelAfterFrame(flag,f);
before=dir(movie); failed=false;
try, job.write(movie,true); catch err, failed=strcmp(err.identifier,'score:ExportCancelled'); end
after=dir(movie); assert(failed&&before.bytes==after.bytes&&before.datenum==after.datenum);
assert(numel(dir(fullfile(folder,'*.avi')))==1,'Partial movie files were left after cancellation.');
% Same recipe handles mosaic and a selected data group through Score.
other=roi('B',r.value); other.path=folder; other.image=r.image; other.display=r.display; other.channelid=r.channelid;
ds=dataseries(); ds.groupid='Metrics'; ds.type='temporal'; ds.data=table([1;3;2],'VariableNames',{'Area'});
r.data=ds; ds2=dataseries(); ds2.groupid=ds.groupid; ds2.type=ds.type; ds2.data=ds.data; other.data=ds2;
p.fov.roi=[r other]; selection=struct('source',r,'data',ds,'groupid','Metrics','variables',{{'Area'}},'label','Area');
sources(2)=sources(1); sources(2).zone=2; sources(2).overlay=false;
settings.mode='sequence'; settings.includeData=true; settings.events={true,2,3,'Treatment',1.5};
job=detecdivui.MovieExportJob(sources,settings,{},selection);
pdf=job.write(fullfile(folder,'data.pdf')); assert(isfile(pdf));
% Raw FOV frames are read on demand from an independent metadata snapshot.
for frame=1:3, imwrite(uint16(ones(16,18)*frame*100),fullfile(folder,sprintf('raw%d.tif',frame))); end
raw=shallow(); raw.fov.id='Raw'; raw.fov.channel={'Phase'}; raw.fov.frames=3;
raw.fov.srcpath={folder}; raw.fov.srclist={dir(fullfile(folder,'raw*.tif'))};
session=detecdivui.Session(raw); layers=detecdivui.LayerModel(); layers.configure(session,1); layers.setLimits(1,[0 400]);
source=struct('session',session,'model',layers,'position',1,'zone',0,'frame',1,'channel','Phase','overlay',true,'outlines',false);
settings.includeData=false; settings.crop=[]; settings.rotation=0; settings.scale=1;
job=detecdivui.MovieExportJob(source,settings); one=job.frameViews(1,1); three=job.frameViews(1,3);
assert(mean(three{1}.pixels,'all')>mean(one{1}.pixels,'all'));
assert(isfile(job.write(fullfile(folder,'raw.pdf'))));
disp('Movie recipes passed: separated Display, real AVI, mosaic PDF with Score data/events, and lazy raw FOV export.');
end
function cancelAfterFrame(flag,fraction)
if fraction>0, flag('cancel')=true; end
end
