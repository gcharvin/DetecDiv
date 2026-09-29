function tests = testCellposeInputChannelAliases
%TESTCELLPOSEINPUTCHANNELALIASES Canonical and display-name input resolution.
tests = functiontests(localfunctions);
end

function setupOnce(~)
repoRoot = fileparts(fileparts(fileparts(fileparts(fileparts(mfilename('fullpath'))))));
addpath(genpath(repoRoot));
end

function testResolvesAliasesAndCanonicalNamesTogether(testCase)
folder = tempname;
mkdir(folder);
addTeardown(testCase, @()removeFolder(folder));

r = roi('R1', [1 1 4 4]);
r.path = folder;
r.image = uint16(ones(4, 4, 2, 3));
r.channelid = [1 2];
r.display.channel = {'brightfield', 'fluorescence'};
r.display.channelAlias = {'Channel0', 'Channel1'};

[pix, missing] = cellposesam.utils.resolveInputChannels( ...
    r, {'Channel1', 'brightfield', 'missing'});

verifyEqual(testCase, pix, [2 1]);
verifyEqual(testCase, missing, {'missing'});
end

function removeFolder(folder)
if isfolder(folder), rmdir(folder, 's'); end
end
