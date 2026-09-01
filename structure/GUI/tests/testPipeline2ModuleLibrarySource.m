function tests = testPipeline2ModuleLibrarySource
%TESTPIPELINE2MODULELIBRARYSOURCE Guard subtype enumeration from node callbacks.
tests = functiontests(localfunctions);
end

function testSubtypeEnumerationDoesNotUseClassifierLinkState(testCase)
sourcePath = fullfile(fileparts(fileparts(mfilename('fullpath'))), ...
    'pipeline2_extracted.m');
source = fileread(sourcePath);
block = regexp(source, ...
    'function items = moduleLibraryPackagesForType.*?(?=\n\s*function )', ...
    'match', 'once');

verifyNotEmpty(testCase, block);
verifyFalse(testCase, contains(block, 'executionPkg'));
verifyFalse(testCase, contains(block, 'classiObj'));
verifyFalse(testCase, contains(block, 'app.Data.nodes'));
end
