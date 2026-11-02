function tests = testOmeZarrAxes
tests = functiontests(localfunctions);
end

function testV3TimeSeriesWithoutZ(testCase)
checkLayout(testCase, 3, {'t','c','y','x'}, [3 2 4 5], 2);
end

function testV3RealZStack(testCase)
checkLayout(testCase, 3, {'t','c','z','y','x'}, [3 2 2 4 5], 4);
end

function testV2TimeSeriesWithoutZ(testCase)
checkLayout(testCase, 2, {'t','c','y','x'}, [3 2 4 5], 2);
end

function testV2RealZStack(testCase)
checkLayout(testCase, 2, {'t','c','z','y','x'}, [3 2 2 4 5], 4);
end

function testLegacyUnnamedArrays(testCase)
for version = [2 3]
    checkLayout(testCase, version, {}, [3 2 4 5], 2);
    checkLayout(testCase, version, {}, [3 2 2 4 5], 4);
end
end

function checkLayout(testCase, version, axes, shape, expectedChannels)
root = tempname;
mkdir(root);
cleanup = onCleanup(@()rmdir(root, 's')); %#ok<NASGU>
series = fullfile(root, '0');
mkdir(series);
chunks = ones(size(shape));
chunks(end-1:end) = shape(end-1:end);
if version == 3
    arrayDir = fullfile(series, '0');
    mkdir(arrayDir);
    writeJson(fullfile(root, 'zarr.json'), struct('zarr_format', 3));
    meta = struct('attributes', struct());
    % Include writer indices for both time-only and true Z acquisitions.
    if numel(shape) == 4
        indices = {[0 0], [0 1], [1 0], [1 1]};
    else
        indices = {[0 0 0], [0 1 0], [0 0 1], [0 1 1]};
    end
    frames = cellfun(@(v)struct('storage_index', v), indices);
    meta.attributes.ome_writers.frame_metadata = frames;
    writeJson(fullfile(series, 'zarr.json'), meta);
    array = struct('shape', shape, 'data_type', 'uint16', ...
        'chunk_grid', struct('configuration', struct('chunk_shape', chunks)));
    if ~isempty(axes)
        array.dimension_names = axes;
    end
    writeJson(fullfile(arrayDir, 'zarr.json'), array);
else
    writeJson(fullfile(root, '.zgroup'), struct('zarr_format', 2));
    writeJson(fullfile(root, '.zattrs'), struct());
    writeJson(fullfile(series, '.zarray'), ...
        struct('shape', shape, 'chunks', chunks, 'dtype', '<u2'));
    if ~isempty(axes)
        % jsonencode cannot emit the leading underscore in a struct field.
        fid = fopen(fullfile(series, '.zattrs'), 'w');
        fprintf(fid, '{"_ARRAY_DIMENSIONS":%s}', jsonencode(axes));
        fclose(fid);
    end
end
out = buildomezarr({root}, struct('pos', struct(), 'comments', ''), []);
p = out.pos;
verifyEqual(testCase, numel(p), 1);
verifyEqual(testCase, p.channels, expectedChannels);
verifyEqual(testCase, p.frames, repmat(3, 1, expectedChannels));
verifyEqual(testCase, p.omeZarrShape, shape);
verifyEqual(testCase, numel(p.filelist{1}), 3);
if numel(shape) == 4
    verifyEqual(testCase, p.channelname, {'ch1','ch2'});
    verifyEqual(testCase, p.omeZarrChannelIndices, [0 1]);
    verifyEqual(testCase, p.omeZarrZIndices, [0 0]);
    verifyFalse(testCase, any(strcmp(p.omeZarrDimensionNames, 'z')));
else
    verifyEqual(testCase, p.channelname, {'ch1_z1','ch2_z1','ch1_z2','ch2_z2'});
    verifyEqual(testCase, p.omeZarrChannelIndices, [0 1 0 1]);
    verifyEqual(testCase, p.omeZarrZIndices, [0 0 1 1]);
end
if version == 3
    checkPixelReads(testCase, p, arrayDir);
end
end

function checkPixelReads(testCase, p, arrayDir)
obj = fov;
obj.channel = p.channelname;
obj.frames = p.frames;
obj.interval = p.interval;
obj.srcpath = p.pathlist;
obj.srclist = p.filelist;
fields = {'isOMEZarr','omeZarrPath','omeZarrSeries','omeZarrArrayPath', ...
    'omeZarrShape','omeZarrChunkShape','omeZarrDtype', ...
    'omeZarrDimensionNames','omeZarrChannelIndices','omeZarrZIndices'};
for k = 1:numel(fields)
    obj.(fields{k}) = p.(fields{k});
end
for t = [1 3]
    for ch = 1:p.channels
        coord = [t-1 p.omeZarrChannelIndices(ch)];
        if any(strcmp(p.omeZarrDimensionNames, 'z'))
            coord(end+1) = p.omeZarrZIndices(ch);
        end
        coord = [coord 0 0]; %#ok<AGROW>
        parts = arrayfun(@num2str, coord, 'UniformOutput', false);
        chunkPath = fullfile(arrayDir, 'c', parts{:});
        mkdir(fileparts(chunkPath));
        expected = uint16(reshape(1:20, 4, 5) + 100*t + 1000*ch);
        fid = fopen(chunkPath, 'w', 'ieee-le');
        fwrite(fid, expected.', 'uint16');
        fclose(fid);
        verifyEqual(testCase, obj.readImage(t, ch), expected);
    end
end
end

function writeJson(path, value)
fid = fopen(path, 'w');
cleanup = onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s', jsonencode(value));
end
