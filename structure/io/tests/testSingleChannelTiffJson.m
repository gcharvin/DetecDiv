function tests=testSingleChannelTiffJson
tests=functiontests(localfunctions);
end
function testNoncontiguousPageMapSurvivesSingleChannelJson(testCase)
folder=tempname;mkdir(folder);cleanup=onCleanup(@()rmdir(folder,'s')); %#ok<NASGU>
source=fullfile(folder,'raw.tif');
for page=1:4
    im=uint16(page*ones(6,7));
    if page==1,imwrite(im,source);else,imwrite(im,source,'WriteMode','append');end
end
sh=shallow();sh.io.path=folder;sh.io.file='single_channel';
f=fov();f.id='position';f.channel={'DIC'};f.frames=2;f.interval=1;
f.srcpath={folder};f.isMultiTiff=true;f.tiffSource={source};f.pageMap={[2 4]};f.roi=roi.empty;
sh.fov=f;path=fullfile(folder,'single_channel.json');shallowProjectExportLight(sh,path);
loaded=shallowProjectImportLight(path);
verifyTrue(testCase,iscell(loaded.fov(1).pageMap));
verifyEqual(testCase,loaded.fov(1).pageMap{1},[2 4]);
verifyEqual(testCase,loaded.fov(1).readImage(2,1),uint16(4*ones(6,7)));
end
