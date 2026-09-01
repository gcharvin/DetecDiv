function tests = testRoiExtractChannelGeometry
%TESTROIEXTRACTCHANNELGEOMETRY Mixed-binning raw-channel regression tests.
tests = functiontests(localfunctions);
end

function setupOnce(~)
repoRoot = fileparts(fileparts(fileparts(fileparts( ...
    mfilename('fullpath')))));
addpath(repoRoot);
detecdiv_setup_path;
end

function testSmallerChannelCoversCompleteReferenceGrid(testCase)
gfp = uint16(400 .* ones(16,16));
gfp(5:8,6:9) = 2000;

actual = roiExtract.resizeToReferenceGrid(gfp,32,32);
expected = imresize(gfp,[32 32]);

verifyEqual(testCase,size(actual),[32 32]);
verifyClass(testCase,actual,'uint16');
verifyEqual(testCase,actual,expected);
verifyTrue(testCase,all(actual(:) > 0), ...
    'A binned channel must not be zero-padded outside its native corner.');
end

function testMatchingGridIsUnchanged(testCase)
image = reshape(uint16(1:30),5,6);
actual = roiExtract.resizeToReferenceGrid(image,5,6);
verifyEqual(testCase,actual,image);
end

function testInvalidGridFailsClearly(testCase)
verifyError(testCase, ...
    @()roiExtract.resizeToReferenceGrid(uint16(ones(2)),0,4), ...
    'roiExtract:InvalidReferenceGrid');
end
