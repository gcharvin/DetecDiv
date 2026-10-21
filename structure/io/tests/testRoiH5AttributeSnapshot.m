function tests = testRoiH5AttributeSnapshot
tests = functiontests(localfunctions);
end

function setup(tc)
folder=tempname; mkdir(folder);
tc.TestData.folder=folder;
r=roi('attribute_test',[1 1 5 4]); r.path=folder;
tc.TestData.roi=r;
file=fullfile(folder,'im_attribute_test.h5');
raw=reshape(uint16(1:60),[4 5 1 3]);
h5create(file,'/raw',size(raw),'Datatype','uint16');
h5write(file,'/raw',raw);
h5writeatt(file,'/raw','channel_name','BF central');
h5writeatt(file,'/raw','channel_indices',1);
h5writeatt(file,'/raw','frames',1:3);
h5writeatt(file,'/raw','display_intensity',[.2 .8 1]);
h5writeatt(file,'/raw','display_displaylim',[10;600]);
h5writeatt(file,'/raw','display_alpha',.35);
h5writeatt(file,'/raw','value_mode','physical');
h5writeatt(file,'/raw','physical_unit','ratio');
h5writeatt(file,'/raw','physical_min',0);
h5writeatt(file,'/raw','physical_max',4);
h5writeatt(file,'/raw','encoded_min',0);
h5writeatt(file,'/raw','encoded_max',65535);
tc.TestData.file=file; tc.TestData.raw=raw;
end

function teardown(tc)
delete(tc.TestData.roi);
rmdir(tc.TestData.folder,'s');
end

function testFullLoadPreservesPixelsAndMetadata(tc)
r=tc.TestData.roi; r.load('Data',false,'Silent');
verifyEqual(tc,r.image,tc.TestData.raw);
verifyEqual(tc,r.display.channel,{'BF central'});
verifyEqual(tc,r.display.intensity,[.2 .8 1]);
verifyEqual(tc,r.display.displaylim,[10;600]);
verifyEqual(tc,r.display.alpha,.35);
verifyEqual(tc,r.display.valueTransform.mode,'physical');
verifyEqual(tc,r.display.valueTransform.unit,'ratio');
verifyEqual(tc,r.display.valueTransform.physicalRange,[0 4]);
end

function testSingleChannelLoadUsesSameAttributeValues(tc)
r=tc.TestData.roi;
r.load('Channel','BF central','Data',false,'Silent');
verifyEqual(tc,r.image,tc.TestData.raw);
verifyEqual(tc,r.display.channel,{'BF central'});
verifyEqual(tc,r.display.intensity,[.2 .8 1]);
verifyEqual(tc,r.display.alpha,.35);
verifyEqual(tc,r.display.valueTransform.physicalRange,[0 4]);
end

function testNextLoadObservesChangedDiskAttributes(tc)
r=tc.TestData.roi; r.load('Data',false,'Silent');
h5writeatt(tc.TestData.file,'/raw','physical_max',8);
r2=roi('attribute_test',[1 1 5 4]); r2.path=tc.TestData.folder;
cleanup=onCleanup(@()delete(r2)); %#ok<NASGU>
r2.load('Data',false,'Silent');
verifyEqual(tc,r2.display.valueTransform.physicalRange,[0 8]);
end
