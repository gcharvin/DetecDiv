function tests = testOmeZarrChannelNames
tests = functiontests(localfunctions);
end

function testAcquisitionNamesAndSparseZMapping(testCase)
attrs = acquisitionMetadata();
out = parseMetadata(attrs);
verifyEqual(testCase, out.channelname, ...
    {'0 TL _z1','0 TL _z2','RoGFPlow10_z2','SB GFP10_z2','0 TL _z3'});
verifyEqual(testCase, out.omeZarrChannelIndices, [0 0 1 2 0]);
verifyEqual(testCase, out.omeZarrZIndices, [0 1 1 1 2]);
end

function testOmeroLabelsHavePriority(testCase)
attrs = acquisitionMetadata();
attrs.omero.channels = struct('label', {'transmitted','redox405','redox488'});
out = parseMetadata(attrs);
verifyEqual(testCase, out.channelname, ...
    {'transmitted_z1','transmitted_z2','redox405_z2','redox488_z2','transmitted_z3'});
end

function testNamesFollowStoredIndicesRegardlessOfFrameOrder(testCase)
attrs = acquisitionMetadata();
attrs.ome_writers.frame_metadata = attrs.ome_writers.frame_metadata([1 2 5 3 4]);
out = parseMetadata(attrs);
verifyEqual(testCase, out.channelname, ...
    {'0 TL _z1','0 TL _z2','0 TL _z3','RoGFPlow10_z2','SB GFP10_z2'});
verifyEqual(testCase, out.omeZarrChannelIndices, [0 0 0 1 2]);
verifyEqual(testCase, out.omeZarrZIndices, [0 1 2 1 1]);
end

function testNestedOmeroAndPartialLabels(testCase)
attrs = acquisitionMetadata();
attrs.ome.omero.channels = struct('label', {'transmitted','','redox488'});
out = parseMetadata(attrs);
verifyEqual(testCase, out.channelname, ...
    {'transmitted_z1','transmitted_z2','RoGFPlow10_z2','redox488_z2','transmitted_z3'});
end

function testMissingLabelsKeepGenericNames(testCase)
attrs = acquisitionMetadata();
attrs = rmfield(attrs, 'pymmcore_plus');
out = parseMetadata(attrs);
verifyEqual(testCase, out.channelname, ...
    {'ch1_z1','ch1_z2','ch2_z2','ch3_z2','ch1_z3'});
end

function testMismatchedSequenceDoesNotGuessIndices(testCase)
attrs = acquisitionMetadata();
attrs.pymmcore_plus.summary_metadata.mda_sequence.channels(3) = [];
out = parseMetadata(attrs);
verifyEqual(testCase, out.channelname, ...
    {'ch1_z1','ch1_z2','ch2_z2','ch3_z2','ch1_z3'});
end

function testDuplicateNamesFailBeforeAmbiguousBindings(testCase)
attrs = acquisitionMetadata();
attrs.pymmcore_plus.summary_metadata.mda_sequence.channels(2).config = 'SB GFP10';
verifyError(testCase, @()parseMetadata(attrs), 'buildomezarr:DuplicateChannelNames');
end

function attrs = acquisitionMetadata()
attrs = struct();
attrs.pymmcore_plus.summary_metadata.mda_sequence.channels = ...
    struct('config', {'0 TL ', 'RoGFPlow10', 'SB GFP10'});
indices = {[0 0 0], [0 0 1], [0 1 1], [0 2 1], [0 0 2]};
attrs.ome_writers.frame_metadata = cellfun(@(v)struct('storage_index', v), indices);
end

function pos = parseMetadata(attrs)
root = tempname;
arrayDir = fullfile(root, '1', '0');
mkdir(arrayDir);
cleanup = onCleanup(@()rmdir(root, 's')); %#ok<NASGU>
writeJson(fullfile(root, 'zarr.json'), struct('zarr_format', 3));
writeJson(fullfile(root, '1', 'zarr.json'), struct('attributes', attrs));
array = struct('shape', [160 3 3 4 5], 'data_type', 'uint16', ...
    'dimension_names', {{'t','c','z','y','x'}}, ...
    'chunk_grid', struct('configuration', struct('chunk_shape', [1 1 1 4 5])));
writeJson(fullfile(arrayDir, 'zarr.json'), array);
out = buildomezarr({root}, struct('pos', struct(), 'comments', ''), []);
pos = out.pos;
end

function writeJson(path, value)
fid = fopen(path, 'w');
cleanup = onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s', jsonencode(value));
end
