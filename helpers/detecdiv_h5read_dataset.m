function data = detecdiv_h5read_dataset(filename, dataset, readFcn)
%DETECDIV_H5READ_DATASET Retry one transient HDF5 driver read failure.
% A fresh h5read call reopens the file. Never return partial data or suppress
% a persistent failure. The optional reader supports deterministic I/O tests.
if nargin < 3
    readFcn = @h5read;
end
try
    data = readFcn(filename, dataset);
    return;
catch firstError
    if ~isDriverReadFailure(firstError)
        rethrow(firstError);
    end
end
warning('loadROI:H5ReadRetry', ...
    'HDF5 driver read failed for "%s", dataset "%s". Retrying once.', ...
    filename, dataset);
try
    data = readFcn(filename, dataset);
catch retryError
    failure = MException('loadROI:H5ReadFailed', ...
        ['Cannot read HDF5 file "%s", dataset "%s" after reopening it. ' ...
         'No image data from this failed read were loaded. Check file and ' ...
         'network availability; a verified local copy can distinguish a ' ...
         'storage access problem from a damaged file.'], filename, dataset);
    failure = addCause(failure, firstError);
    failure = addCause(failure, retryError);
    throw(failure);
end
end

function tf = isDriverReadFailure(err)
tf = contains(err.message, 'H5FD_read') && ...
    contains(err.message, 'driver read request failed');
end
