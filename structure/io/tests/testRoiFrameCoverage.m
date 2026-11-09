function tests = testRoiFrameCoverage
tests = functiontests(localfunctions);
end
function setupOnce(~)
addpath(genpath(fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))))));
end
function setup(t)
t.TestData.folder = tempname; mkdir(t.TestData.folder);
t.TestData.r = roi('coverage', []); t.TestData.r.path = t.TestData.folder;
end
function teardown(t)
rmdir(t.TestData.folder, 's');
end
function testShortDiskStoreWinsOverPaddedMemory(t)
r = t.TestData.r; writeChannel(r, 'instances', 70);
r.image = zeros(4,5,1,220,'uint16'); r.display.channel = {'instances'};
verifyError(t, @()roiAssertFrameCoverage(r, {'instances'}, 1:220), 'runPipeline:IncompleteROI');
roiAssertFrameCoverage(r, {'instances'}, 1:70);
roiAssertFrameCoverage(r, {'instances'}, 1:220, false);
end
function testEveryRoiAndChannelIsChecked(t)
r = t.TestData.r; writeChannel(r, 'BF', 220); writeChannel(r, 'instances', 144);
roiAssertFrameCoverage(r, {'BF'}, 1:220);
verifyError(t, @()roiAssertFrameCoverage(r, {'BF','instances'}, 1:220), 'runPipeline:IncompleteROI');
end
function testBlockFrameAttributeDoesNotTruncateExtent(t)
r = t.TestData.r; writeChannel(r, 'BF', 220);
h5writeatt(fullfile(r.path, ['im_' r.id '.h5']), '/BF', 'frames', 1:7);
roiAssertFrameCoverage(r, {'BF'}, 1:220);
end
function testPlannedRepairDefersButExecutionRejectsPartialInputs(t)
r = t.TestData.r; writeChannel(r, 'instances', 70);
n = struct('id','lineage','type','processor','pkg','trackMotherLineageViterbi', ...
    'func','trackMotherLineageViterbi.process','enabled',true, ...
    'params',struct('instanceChannelName','instances','outputChannelName','V'));
ctx = struct('roiList',r,'sel',struct('frames',1:220));
verifyError(t, @()pipelineAssertRoiCompleteness(n,ctx,true), 'runPipeline:IncompleteROI');
ex = n; ex.id='extract'; ex.type='roiExtract'; ex.pkg='roiExtract';
ex.func='roiExtract.process'; ex.params=struct();
pipelineAssertRoiCompleteness([ex n],ctx,true);
verifyError(t, @()pipelineAssertRoiCompleteness(n,ctx), 'runPipeline:IncompleteROI');
end
function testDirectTrackerRejectsOutOfRangeBeforeIndexing(t)
r = t.TestData.r; r.image = zeros(4,5,1,2,'uint16');
r.display.channel={'instances'}; r.channelid=1;
p=trackMotherLineageViterbi.setparam(struct());p.instanceChannelName={'instances','instances'};
verifyError(t,@()trackMotherLineageViterbi.core(p,r,1:3),'trackMotherLineageViterbi:IncompleteInput');
end
function testAllFramesSelectionUsesAcquisitionLength(t)
r=t.TestData.r; writeChannel(r,'instances',70);
f=fov(); f.id='Pos1'; f.channel={'instances'}; f.frames=220; f.roi=r;
ctx=struct('roiList',r,'fovList',f);
n=struct('id','lineage','type','processor','pkg','trackMotherLineageViterbi', ...
    'params',struct('instanceChannelName','instances','outputChannelName','V'));
verifyError(t,@()pipelineAssertRoiCompleteness(n,ctx),'runPipeline:IncompleteROI');
end
function writeChannel(r,name,count)
file=fullfile(r.path,['im_' r.id '.h5']);
h5create(file,['/' name],[4 5 1 count],'Datatype','uint16');
h5writeatt(file,['/' name],'channel_name',name);
h5writeatt(file,['/' name],'num_subchannels',1);
end
