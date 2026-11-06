function tests = testRoiH5ReadRetry
tests = functiontests(localfunctions);
end

function setupOnce(~)
root = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(genpath(root));
end

function testTransientFailurePreservesPixelsAndDatatype(testCase)
expected = reshape(uint16(1:24), [2 3 1 4]);
attempts = 0;
state = warning('off', 'loadROI:H5ReadRetry');
cleanup = onCleanup(@() warning(state)); %#ok<NASGU>
actual = detecdiv_h5read_dataset('network.h5', '/tracks', @read);
verifyEqual(testCase, attempts, 2);
verifyEqual(testCase, actual, expected);
    function data = read(~, ~)
        attempts = attempts + 1;
        if attempts == 1, driverFailure(); end
        data = expected;
    end
end

function testPersistentFailureIsBoundedAndKeepsContext(testCase)
attempts = 0;
state = warning('off', 'loadROI:H5ReadRetry');
cleanup = onCleanup(@() warning(state)); %#ok<NASGU>
try
    detecdiv_h5read_dataset('network.h5', '/tracks', @read);
    verifyFail(testCase, 'Persistent I/O failure must not return data.');
catch err
    verifyEqual(testCase, err.identifier, 'loadROI:H5ReadFailed');
    verifyTrue(testCase, contains(err.message, 'network.h5'));
    verifyTrue(testCase, contains(err.message, '/tracks'));
    verifyNumElements(testCase, err.cause, 2);
end
verifyEqual(testCase, attempts, 2);
    function data = read(~, ~)
        data = []; %#ok<NASGU>
        attempts = attempts + 1;
        driverFailure();
    end
end

function testOtherFailuresAreNotRetried(testCase)
attempts = 0;
verifyError(testCase, @() detecdiv_h5read_dataset('bad.h5', '/missing', @read), ...
    'test:DatasetMissing');
verifyEqual(testCase, attempts, 1);
    function data = read(~, ~)
        data = []; %#ok<NASGU>
        attempts = attempts + 1;
        error('test:DatasetMissing', 'Dataset not found.');
    end
end

function testDefaultReaderLoadsRealHdf5(testCase)
filename = [tempname '.h5'];
cleanup = onCleanup(@() delete(filename)); %#ok<NASGU>
expected = reshape(uint16(1:24), [2 3 1 4]);
h5create(filename, '/raw', size(expected), 'Datatype', 'uint16');
h5write(filename, '/raw', expected);
verifyEqual(testCase, detecdiv_h5read_dataset(filename, '/raw'), expected);
end

function driverFailure()
error('test:H5Read', 'H5FD_read    driver read request failed');
end
