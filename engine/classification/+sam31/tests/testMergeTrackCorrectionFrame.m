function tests = testMergeTrackCorrectionFrame
tests = functiontests(localfunctions);
end

function testTransfersIdentityFromStrongMatchingObject(testCase)
labels = zeros(12, 12, 'uint16');
labels(2:4, 2:4) = 2;
labels(7:10, 7:10) = 12;
candidate = false(12, 12);
candidate(7:10, 7:10) = true;

[merged, action] = sam31.mergeTrackCorrectionFrame(labels, candidate, 2, struct());

verifyTrue(testCase, action.applied);
verifyEqual(testCase, action.reassignedLabel, 12);
verifyEqual(testCase, nnz(merged == 12), 0);
verifyEqual(testCase, nnz(merged == 2), nnz(candidate));
verifyEqual(testCase, nnz(merged(2:4, 2:4)), 0);
end

function testSkipsAmbiguousMultiObjectCollision(testCase)
labels = zeros(12, 12, 'uint16');
labels(5:8, 4:6) = 7;
labels(5:8, 7:9) = 8;
candidate = false(12, 12);
candidate(5:8, 4:9) = true;

[merged, action] = sam31.mergeTrackCorrectionFrame(labels, candidate, 2, struct());

verifyTrue(testCase, action.skipped);
verifyFalse(testCase, action.applied);
verifyEqual(testCase, merged, labels);
end

function testClipsSmallIncidentalOverlap(testCase)
labels = zeros(12, 12, 'uint16');
labels(8:10, 8:10) = 9;
candidate = false(12, 12);
candidate(3:9, 3:9) = true;

[merged, action] = sam31.mergeTrackCorrectionFrame(labels, candidate, 2, struct());

verifyTrue(testCase, action.applied);
verifyTrue(testCase, action.clipped);
verifyEqual(testCase, nnz(merged == 9), 9);
verifyEqual(testCase, nnz(merged == 2), nnz(candidate & labels == 0));
end
