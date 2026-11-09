function movieSnapshotTest()
%MOVIESNAPSHOTTEST Portable worker recipe and lossless image-sequence parity.
folder=tempname; mkdir(folder); cleanup=onCleanup(@()rmdir(folder,'s'));
p=shallow(); p.fov.id='Position'; r=roi('Snapshot cells',[1 1 30 24]); r.path=folder;
r.image=zeros(24,30,3,4,'uint16');
for frame=1:4
    r.image(:,:,1,frame)=uint16(repmat(1:30,24,1)*100+frame*20);
    r.image(:,:,2,frame)=uint16(repmat((1:24)',1,30)*80);
    r.image(7:12,9:16,3,frame)=frame;
end
r.channelid=1:3; r.display.channel={'Phase','Signal','Masks'}; r.display.indexed=[false false true];
r.display.intensity=[1 1 1;1 1 1;0 0 0]; r.display.selectedchannel=[true true true]; p.fov.roi=r;
session=detecdivui.Session(p); session.selectZone(1);
model=detecdivui.LayerModel(); model.configure(session,1); model.setLimits(1,[0 3500]); model.setLimits(2,[0 2400]);
model.setColor(2,'0 1 0'); model.setOpacity(2,.25); model.setLabelStyle(3,'Fill + Contours',1.5);
source=struct('session',session,'model',model,'position',1,'zone',1,'frame',2,'channel','Phase','overlay',false,'outlines',false, ...
    'viewport',[4.5 24.5 3.5 20.5]);
settings=detecdivui.MovieExportJob.defaults(); settings.mode='images'; settings.frames='2:2:4'; settings.interval=2.5;
job=detecdivui.MovieExportJob(source,settings);
cropped=job.frameViews(1,2); assert(isequal(size(cropped{1}.pixels),[17 20 3]));
before=r.image; descriptor=job.saveSnapshot(fullfile(folder,'snapshot'));
assert(isequal(r.image,before));
restored=detecdivui.MovieExportJob.fromSnapshot(descriptor.path,descriptor.sha256);
for frame=[2 4]
    original=job.frameViews(1,frame); replay=restored.frameViews(1,frame);
    for k=1:numel(original)
        assert(isequal(original{k}.pixels,replay{k}.pixels)&&isequal(original{k}.vectors,replay{k}.vectors));
    end
end
% Later source/display edits cannot change the submitted snapshot.
r.image(:)=0; model.setColor(2,'1 0 0');
assert(~isequal(r.image,before));
left=job.frameViews(1,2); right=restored.frameViews(1,2); assert(isequal(left{1}.pixels,right{1}.pixels));
local=job.write(fullfile(folder,'local_png'));
ctx=struct('params',struct('sourceType','viewer_snapshot','snapshotPath','/export/snapshot/snapshot.mat', ...
    'snapshotChecksum',descriptor.sha256,'outputPath','/export/worker_png','overwrite',false));
ctx.execution.worker_path_mappings=struct('source','/export','target',folder);
result=movieExport.process(ctx); remote=result.artifacts.path;
for frame=[2 4]
    name=sprintf('frame_%06d.png',frame);
    assert(isequal(imread(fullfile(local,name)),imread(fullfile(remote,name))), ...
        'Worker-rendered PNG differs from the local Display recipe.');
end
assert(numel(dir(fullfile(remote,'*.png')))==2);
% The existing Score submission helper and real pipeline runner use the same
% snapshot, even though the live project has changed since it was frozen.
p.io.path=folder; p.io.file='Project';
params=ctx.params; params.snapshotPath=descriptor.path; params.outputPath=fullfile(folder,'pipeline_png');
[run,report]=detecdiv_movie_export_submit(p,params,'Target','local');
assert(strcmp(report.status,'done')&&strcmp(run.status,'done'));
assert(isequal(imread(fullfile(params.outputPath,'frame_000002.png')),imread(fullfile(local,'frame_000002.png'))));
settings.imageFormat='tif'; tiff=detecdivui.MovieExportJob(source,settings);
path=tiff.write(fullfile(folder,'tiff.frames')); assert(numel(dir(fullfile(path,'*.tif')))==2);
assert(strcmp(path,fullfile(folder,'tiff.frames')));
% A platform/layout discrepancy is rejected before publishing an output.
stored=load(descriptor.path,'payload'); payload=stored.payload;
payload.options.expectedCanvas=payload.options.expectedCanvas+[2 0];
bad=fullfile(folder,'snapshot','wrong_canvas.mat'); save(bad,'payload','-v7.3');
wrong=detecdivui.MovieExportJob.fromSnapshot(bad,detecdivui.MovieExportSnapshot.hashFile(bad));
failed=false;
try, wrong.write(fullfile(folder,'wrong_canvas'));
catch err, failed=strcmp(err.identifier,'score:ExportLayoutMismatch'); end
assert(failed&&~isfolder(fullfile(folder,'wrong_canvas')));
payload.renderSignature='different-renderer'; save(bad,'payload','-v7.3'); failed=false;
try, detecdivui.MovieExportJob.fromSnapshot(bad,detecdivui.MovieExportSnapshot.hashFile(bad));
catch err, failed=strcmp(err.identifier,'detecdivui:SnapshotRenderer'); end
assert(failed);
% Both metadata and pixel assets are checksum protected before rendering.
file=fullfile(folder,'snapshot','pixels_001.h5');
h5write(file,'/layer_001',uint16(123),[1 1 1 1],[1 1 1 1]);
failed=false; try, detecdivui.MovieExportJob.fromSnapshot(descriptor.path,descriptor.sha256);
catch err, failed=strcmp(err.identifier,'detecdivui:SnapshotChecksum'); end
assert(failed);
fid=fopen(descriptor.path,'a'); fwrite(fid,uint8(1)); fclose(fid);
failed=false; try, detecdivui.MovieExportJob.fromSnapshot(descriptor.path,descriptor.sha256);
catch err, failed=strcmp(err.identifier,'detecdivui:SnapshotChecksum'); end
assert(failed);
known=fullfile(folder,'known.txt'); fid=fopen(known,'w'); fwrite(fid,'hello','char'); fclose(fid);
assert(strcmp(detecdivui.MovieExportSnapshot.hashFile(known),'2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824'));
disp('Movie snapshots passed: selected frames only, frozen Display parity, PNG/TIFF sequences, worker path mapping, exact decoded PNG equality and tamper rejection.');
end
