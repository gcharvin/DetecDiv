function tests = testResolveCorrectionProvider
tests = functiontests(localfunctions);
end

function testAnnotationChannelHintFallsBackToSeparateMaskSource(testCase)
r = mockRoi();
opts = struct('annotationPix', 6, ...
    'candidateProviderName', 'latent_model_1_cell');

[pix, name, info] = sam31.resolveCorrectionProvider(r, opts);

verifyEqual(testCase, pix, 5);
verifyEqual(testCase, name, 'results_cellposeSAM_cell');
verifyEqual(testCase, info.source, 'mask-channel-fallback');
verifySubstring(testCase, info.message, 'Ignored');
end

function testExplicitSeparateMaskSourceIsKept(testCase)
r = mockRoi();
opts = struct('annotationPix', 6, ...
    'candidateProviderName', 'results_cellposeSAM_cell');

[pix, name, info] = sam31.resolveCorrectionProvider(r, opts);

verifyEqual(testCase, pix, 5);
verifyEqual(testCase, name, 'results_cellposeSAM_cell');
verifyEqual(testCase, info.source, 'explicit-channel-name');
end

function testPhysicalProviderIndexReportsLogicalChannelName(testCase)
r = mockRoi();
opts = struct('annotationPix', 6, 'candidateProviderPix', 5);

[pix, name, info] = sam31.resolveCorrectionProvider(r, opts);

verifyEqual(testCase, pix, 5);
verifyEqual(testCase, name, 'results_cellposeSAM_cell');
verifyEqual(testCase, info.source, 'explicit-pixel-index');
end

function testNoSeparateMaskSourceLeavesSam31FallbackAvailable(testCase)
r = roi('R_without_provider', [1 1 8 8]);
r.image = zeros(8, 8, 2, 3, 'uint16');
r.channelid = [1 2];
r.display.channel = {'Channel1_z2', 'latent_model_1_cell'};
opts = struct('annotationPix', 2, ...
    'candidateProviderName', 'latent_model_1_cell');

[pix, name, info] = sam31.resolveCorrectionProvider(r, opts);

verifyEmpty(testCase, pix);
verifyEmpty(testCase, name);
verifyEqual(testCase, info.source, 'none');
verifySubstring(testCase, info.message, 'Ignored');
end

function r = mockRoi()
r = roi('Pos0_1_25', [1 1 8 8]);
r.image = zeros(8, 8, 6, 3, 'uint16');
% CombinedChannel owns three physical planes.  The two indexed mask
% channels are therefore physical planes 5 and 6, not logical rows 3/4.
r.channelid = [1 2 2 2 3 4];
r.display.channel = { ...
    'Channel1_z2', 'CombinedChannel', ...
    'results_cellposeSAM_cell', 'latent_model_1_cell'};
end
