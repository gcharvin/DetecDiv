function report = roiPartialSaveRegressionTest()
% roiPartialSaveRegressionTest  Ensure partial ROI saves preserve H5 channels.

testRoot = tempname;
mkdir(testRoot);
cleanup = onCleanup(@() localCleanup(testRoot)); %#ok<NASGU>

r = roi('partial_save_test', [1 1 9 8]);
r.path = testRoot;

H = 8;
W = 9;
T = 3;
firstValues = uint16(100 + reshape(1:(H*W*T), H, W, 1, T));
r.image = firstValues;
r.channelid = 1;
r.display.channel = {'ch1'};
r.display.intensity = [1 1 1];
r.display.rgb = [1 1 1];
r.display.indexed = false;
r.display.alpha = 1;
r.display.contour = false;
r.display.width = 1;
r.display.selectedchannel = 1;

for iChannel = 2:5
    values = uint16(100 * iChannel + reshape(1:(H*W*T), H, W, 1, T));
    r.addChannel(values, sprintf('ch%d', iChannel), [1 1 1], [1 1 1]);
end
r.save([], false);

h5File = fullfile(testRoot, ['im_' r.id '.h5']);
gfpBefore = h5read(h5File, '/ch2');

% A cleared image cache deliberately retains the complete display and
% channelid metadata, as happens for persisted classifier ROIs.
r.image = [];
r.load('Channel', {'ch1','ch5'}, 'Silent');
assert(size(r.image,3) == 2, ...
    'roiPartialSaveRegressionTest:NonCompactImage', ...
    'Partial load created placeholder image planes.');
assert(isequal(double(r.channelid), [1 5]), ...
    'roiPartialSaveRegressionTest:NonCompactMapping', ...
    'Partial load did not create the expected compact channel mapping.');

result = zeros(H, W, 1, T, 'uint16');
r.addChannel(result, 'results_partial_save_test', [1 1 1], [0 0 0]);
assert(isequal(double(r.channelid), [1 5 6]), ...
    'roiPartialSaveRegressionTest:BadAddedChannelMapping', ...
    'addChannel did not map the result to its display channel row.');
assert(isequal(r.findChannelID('results_partial_save_test'), 3), ...
    'roiPartialSaveRegressionTest:BadAddedChannelIndex', ...
    'The result channel does not map to its image plane.');

r.save([], false);
gfpAfter = h5read(h5File, '/ch2');
assert(isequal(gfpBefore, gfpAfter), ...
    'roiPartialSaveRegressionTest:UntouchedChannelChanged', ...
    'A compact partial save changed an unloaded H5 channel.');

% Also protect objects created by the old loader: their channelid length
% exceeded the image C dimension and the intermediate image planes were
% zero placeholders. Such a mapping must result in no image write.
compact = r.image;
stale = zeros(H, W, 5, T, 'like', compact);
stale(:,:,1,:) = compact(:,:,1,:);
stale(:,:,5,:) = compact(:,:,2,:);
r.image = stale;
r.channelid = 1:6;
didSave = r.save([], false);
gfpAfterStaleSave = h5read(h5File, '/ch2');
assert(~didSave, ...
    'roiPartialSaveRegressionTest:StaleMappingWasSaved', ...
    'save accepted an ambiguous stale partial-load mapping.');
assert(isequal(gfpBefore, gfpAfterStaleSave), ...
    'roiPartialSaveRegressionTest:StaleMappingChangedChannel', ...
    'A stale partial-load mapping changed an unloaded H5 channel.');

report = struct( ...
    'compactChannelId', [1 5], ...
    'addedChannelId', [1 5 6], ...
    'untouchedChannelPreserved', true, ...
    'staleMappingRejected', true);
fprintf('roiPartialSaveRegressionTest: PASS\n');
end

function localCleanup(testRoot)
try
    root = char(string(testRoot));
    tempBase = char(string(tempdir));
    if isfolder(root) && startsWith(root, tempBase, 'IgnoreCase', true) && ...
            ~strcmpi(root, tempBase)
        rmdir(root, 's');
    end
catch
end
end
