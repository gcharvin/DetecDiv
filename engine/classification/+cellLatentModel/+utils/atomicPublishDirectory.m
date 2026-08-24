function atomicPublishDirectory(stageDir, finalDir)
%CELLLATENTMODEL.UTILS.ATOMICPUBLISHDIRECTORY Rename without replacement.
% MATLAB movefile nests a source directory inside an existing destination.
% That behavior is unsafe for immutable scientific versions. Java NIO's
% same-volume ATOMIC_MOVE performs one rename and never requests REPLACE.

stageDir = canonicalPath(stageDir);
finalDir = canonicalPath(finalDir);
if ~isfolder(stageDir)
    error('cellLatentModel:BenchmarkPublishFailed', ...
        'Benchmark staging directory is missing: %s', stageDir);
end
if ~strcmpi(fileparts(stageDir), fileparts(finalDir))
    error('cellLatentModel:BenchmarkPublishFailed', ...
        'Atomic publication requires staging and final directories to be siblings.');
end
if isfolder(finalDir) || isfile(finalDir)
    error('cellLatentModel:ImmutableBenchmarkExists', ...
        'Refusing to replace immutable benchmark target: %s', finalDir);
end

emptyStrings = javaArray('java.lang.String', 0);
stagePath = java.nio.file.Paths.get(stageDir, emptyStrings);
finalPath = java.nio.file.Paths.get(finalDir, emptyStrings);
options = javaArray('java.nio.file.CopyOption', 1);
options(1) = java.nio.file.StandardCopyOption.ATOMIC_MOVE;
try
    java.nio.file.Files.move(stagePath, finalPath, options);
catch ME
    if isfolder(finalDir) || isfile(finalDir)
        error('cellLatentModel:ImmutableBenchmarkExists', ...
            ['Immutable benchmark target appeared during publication; ' ...
             'the staging directory was preserved: %s'], finalDir);
    end
    error('cellLatentModel:BenchmarkPublishFailed', ...
        'Atomic benchmark publication failed: %s', ME.message);
end
if isfolder(stageDir) || ~isfolder(finalDir)
    error('cellLatentModel:BenchmarkPublishFailed', ...
        'Atomic benchmark publication did not complete as one rename.');
end
end

function value = canonicalPath(raw)
value = char(java.io.File(char(string(raw))).getCanonicalPath());
end
