function report = pipelineContractSmokeTest()
% pipelineContractSmokeTest  Smoke tests for resource-based pipeline contracts.

repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(genpath(repoRoot));

tests = {};
tests{end+1} = @testAllKnownModuleContracts; %#ok<AGROW>
tests{end+1} = @testDynamicCellposeSamContract; %#ok<AGROW>
tests{end+1} = @testDynamicCnnLstmContract; %#ok<AGROW>
tests{end+1} = @testDynamicCombineMultipleChannelsContract; %#ok<AGROW>
tests{end+1} = @testDynamicComputeMetricsContract; %#ok<AGROW>
tests{end+1} = @testStaleSavedContractIgnored; %#ok<AGROW>
tests{end+1} = @testRoiExtractStaleSymbolicSourceDoesNotBlockValidation; %#ok<AGROW>
tests{end+1} = @testCombineMultipleChannelsThreeSlotValidation; %#ok<AGROW>
tests{end+1} = @testProbabilityChannelPropagatesDownstream; %#ok<AGROW>
tests{end+1} = @testPipelineSaveLoadStripsDerivedNodeFields; %#ok<AGROW>

items = struct('name', {}, 'status', {}, 'message', {});
for i = 1:numel(tests)
    name = func2str(tests{i});
    try
        tests{i}();
        items(end+1) = struct('name', name, 'status', 'passed', 'message', ''); %#ok<AGROW>
    catch ME
        items(end+1) = struct('name', name, 'status', 'failed', 'message', ME.message); %#ok<AGROW>
    end
end

failed = strcmp({items.status}, 'failed');
report = struct( ...
    'ok', ~any(failed), ...
    'tests', items, ...
    'passed', sum(~failed), ...
    'failed', sum(failed));

if ~report.ok
    msgs = cell(1, sum(failed));
    bad = items(failed);
    for i = 1:numel(bad)
        msgs{i} = sprintf('%s: %s', bad(i).name, bad(i).message);
    end
    error('pipelineContractSmokeTest:Failed', '%s', strjoin(msgs, ' | '));
end

disp(sprintf('pipelineContractSmokeTest: %d passed, %d failed.', report.passed, report.failed));
end

function testAllKnownModuleContracts()
cases = knownModuleCases();
for i = 1:numel(cases)
    node = makeNode(cases(i).type, cases(i).pkg, defaultParams(cases(i).type, cases(i).pkg));
    contract = pipelineNodeContract(node);
    assert(isstruct(contract), 'Contract is not a struct for %s/%s.', cases(i).type, cases(i).pkg);
    assert(isfield(contract, 'resources') && isstruct(contract.resources), ...
        'Missing resources for %s/%s.', cases(i).type, cases(i).pkg);
    [inputs, outputs] = pipelineContractPortNames(contract);
    assert(iscell(inputs) && iscell(outputs), 'Port-name derivation failed for %s/%s.', cases(i).type, cases(i).pkg);
end
end

function testDynamicCellposeSamContract()
node = makeNode('classifier', 'cellposesam', struct( ...
    'pkg', 'cellposesam', ...
    'channel', 'TL_z1', ...
    'outputName', 'cellposeSAM', ...
    'probabilityOutputName', 'cellposeSAM_prob', ...
    'outputType', 'segmentation'));
c1 = pipelineNodeContract(node);
assert(numel(c1.resources.out) == 1, 'CellposeSAM segmentation should expose one output resource.');
node.params.outputType = 'probability';
c2 = pipelineNodeContract(node);
assert(numel(c2.resources.out) == 1, 'CellposeSAM probability should expose one output resource.');
assert(strcmp(c2.resources.out(1).nameParam, 'probabilityOutputName'), 'Probability output should bind probabilityOutputName.');
node.params.outputType = 'both';
c3 = pipelineNodeContract(node);
assert(numel(c3.resources.out) == 2, 'CellposeSAM both should expose two output resources.');
assert(any(strcmp({c3.resources.out.nameParam}, 'outputName')), 'Missing segmentation outputName binding.');
assert(any(strcmp({c3.resources.out.nameParam}, 'probabilityOutputName')), 'Missing probabilityOutputName binding.');
end

function testDynamicCnnLstmContract()
node = makeNode('classifier', 'cnn_lstm', struct( ...
    'pkg', 'cnn_lstm', ...
    'channel', 'TL_z1', ...
    'outputName', 'div_lstm', ...
    'cnnOutputName', 'div_cnn', ...
    'outputMode', 'lstm_only'));
c1 = pipelineNodeContract(node);
assert(numel(c1.resources.out) == 1, 'cnn_lstm lstm_only should expose one output resource.');
node.params.outputMode = 'cnn_only';
c2 = pipelineNodeContract(node);
assert(numel(c2.resources.out) == 1, 'cnn_lstm cnn_only should expose one output resource.');
assert(strcmp(c2.resources.out(1).nameParam, 'cnnOutputName'), 'cnn_only should bind cnnOutputName.');
node.params.outputMode = 'both';
c3 = pipelineNodeContract(node);
assert(numel(c3.resources.out) == 2, 'cnn_lstm both should expose two output resources.');
end

function testDynamicCombineMultipleChannelsContract()
node = makeNode('processor', 'combineMultipleChannels', struct( ...
    'pkg', 'combineMultipleChannels', ...
    'requiredChannelCount', 2, ...
    'Channel1', 'TL_z1', ...
    'Channel2', 'GFP', ...
    'outputChannelName', 'combo'));
contract = pipelineNodeContract(node);
assert(numel(contract.resources.in) == 2, 'combineMultipleChannels should expose exactly two input slots.');
assert(numel(contract.binding.selectorKeys) == 2, 'combineMultipleChannels selectorKeys should match slot count.');
end

function testDynamicComputeMetricsContract()
node = makeNode('processor', 'computeMetrics', struct( ...
    'pkg', 'computeMetrics', ...
    'maskChannelCount', 3, ...
    'scoreChannelCount', 2, ...
    'mask1_name', 'cellposeSAM', ...
    'mask2_name', 'nucleusMask', ...
    'mask3_name', 'budMask', ...
    'channel1_name', 'TL_z1', ...
    'channel2_name', 'GFP', ...
    'BrightestPixels', 20));
contract = pipelineNodeContract(node);
assert(numel(contract.resources.in) == 5, 'computeMetrics should expose mask + score channel slots.');
assert(numel(contract.binding.selectorKeys) == 5, 'computeMetrics selectorKeys should match dynamic slot count.');
assert(any(strcmp(contract.parameters.static, 'maskChannelCount')), 'Missing maskChannelCount static parameter.');
assert(any(strcmp(contract.parameters.static, 'scoreChannelCount')), 'Missing scoreChannelCount static parameter.');

n1 = makeNode('roiExtract', 'roiExtract', struct('extractChannels', {{'TL_z1','GFP','cellposeSAM','nucleusMask','budMask'}}));
n1.id = 'roiextract_1';
node.id = 'computeMetrics_1';
pipe = struct( ...
    'nodes', [n1 node], ...
    'edges', makeEdges({'roiextract_1','computeMetrics_1'}), ...
    'branches', struct([]));
ctx = struct('images', 1, 'roiList', 1, 'channels', {{'TL_z1','GFP','cellposeSAM','nucleusMask','budMask'}});
[pipe, ~] = pipelineResolveBindings(pipe, ctx, struct('allowGui', false));
[ok, validation] = validatePipeline(pipe, ctx, struct('allowGui', false));
assert(ok, 'Dynamic computeMetrics validation failed: %s', strjoin(validation.errors, ' | '));
key = matlab.lang.makeValidName('computeMetrics_1');
assert(strcmp(validation.binding.nodes.(key).status, 'resolved'), ...
    'computeMetrics binding should be resolved with all dynamic slots filled.');
end

function testStaleSavedContractIgnored()
old = struct('resources', struct('out', resourceStruct('mask', 'segmentation', 'masks', 'outputName', 'masks', 'outputName', false, 'roiMasks')));
node = makeNode('classifier', 'cellposesam', struct( ...
    'pkg', 'cellposesam', ...
    'channel', 'TL_z1', ...
    'outputType', 'both', ...
    'outputName', 'cellposeSAM', ...
    'probabilityOutputName', 'cellposeSAM_prob'));
node.contract = old;
contract = pipelineNodeContract(node);
assert(numel(contract.resources.out) == 2, 'Stale saved CellposeSAM contract masked dynamic output resources.');
end

function testRoiExtractStaleSymbolicSourceDoesNotBlockValidation()
n1 = makeNode('dataLoader', 'dataLoader', struct('channelFilter', {{'TL_z1','TL_z2','TL_z3'}}));
n1.id = 'dataloader_5';
n2 = makeNode('roiExtract', 'roiExtract', struct('extractChannels', '@roipattern_4.channels'));
n2.id = 'roiextract_3';
pipe = struct( ...
    'nodes', [n1 n2], ...
    'edges', makeEdges({'dataloader_5','roiextract_3'}), ...
    'branches', struct([]));
ctx = struct('images', 1, 'roiList', 1, 'channels', {{'TL_z1','TL_z2','TL_z3'}});
[pipe, ~] = pipelineResolveBindings(pipe, ctx, struct('allowGui', false));
[ok, validation] = validatePipeline(pipe, ctx, struct('allowGui', false));
assert(ok, 'Stale roiExtract symbolic source should not block validation: %s', strjoin(validation.errors, ' | '));
key = matlab.lang.makeValidName('roiextract_3');
assert(strcmp(validation.binding.nodes.(key).status, 'resolved'), ...
    'Stale roiExtract symbolic source should resolve to the source channel inventory.');
end

function testCombineMultipleChannelsThreeSlotValidation()
n1 = makeNode('roiExtract', 'roiExtract', struct('extractChannels', {{'TL_z1','TL_z2','TL_z3'}}));
n1.id = 'roiextract_3';
n2 = makeNode('processor', 'combineMultipleChannels', struct( ...
    'pkg', 'combineMultipleChannels', ...
    'requiredChannelCount', 3, ...
    'Channel1', 'TL_z1', ...
    'Channel2', 'TL_z2', ...
    'Channel3', 'TL_z3', ...
    'outputChannelName', 'CombinedChannel'));
n2.id = 'combineMultipleChannels';
pipe = struct( ...
    'nodes', [n1 n2], ...
    'edges', makeEdges({'roiextract_3','combineMultipleChannels'}), ...
    'branches', struct([]));
ctx = struct('images', 1, 'roiList', 1, 'channels', {{'TL_z1','TL_z2','TL_z3'}});
[pipe, ~] = pipelineResolveBindings(pipe, ctx, struct('allowGui', false));
[ok, validation] = validatePipeline(pipe, ctx, struct('allowGui', false));
assert(ok, 'Three configured combineMultipleChannels slots should validate: %s', strjoin(validation.errors, ' | '));
key = matlab.lang.makeValidName('combineMultipleChannels');
assert(strcmp(validation.binding.nodes.(key).status, 'resolved'), ...
    'combineMultipleChannels binding should be resolved with three filled slots.');
end

function testProbabilityChannelPropagatesDownstream()
n1 = makeNode('roiExtract', 'roiExtract', struct('extractChannels', {{'TL_z1'}}));
n1.id = 'roiExtract_1';
n2 = makeNode('classifier', 'cellposesam', struct( ...
    'pkg', 'cellposesam', ...
    'channel', 'TL_z1', ...
    'outputType', 'both', ...
    'outputName', 'cellposeSAM', ...
    'probabilityOutputName', 'cellposeSAM_prob'));
n2.id = 'cellpose_1';
n3 = makeNode('processor', 'computeMaxProjection', struct( ...
    'pkg', 'computeMaxProjection', ...
    'channel', 'cellposeSAM_prob', ...
    'outputChannelName', 'max_prob'));
n3.id = 'processor_1';
pipe = struct('nodes', [n1 n2 n3], 'edges', struct([]), 'branches', struct([]));
ctx = struct('images', 1, 'roiList', 1, 'channels', {{'TL_z1'}});
[ok, validation] = validatePipeline(pipe, ctx, struct('allowGui', false));
assert(ok, 'Validation failed: %s', strjoin(validation.errors, ' | '));
key = matlab.lang.makeValidName('processor_1');
assert(any(strcmp(validation.binding.nodes.(key).availableChannels, 'cellposeSAM_prob')), ...
    'Probability channel was not visible downstream.');
end

function testPipelineSaveLoadStripsDerivedNodeFields()
tmpRoot = tempname;
mkdir(tmpRoot);
cleanupObj = onCleanup(@()cleanupDir(tmpRoot)); %#ok<NASGU>

node = makeNode('classifier', 'cellposesam', struct( ...
    'pkg', 'cellposesam', ...
    'channel', 'TL_z1', ...
    'outputType', 'both', ...
    'outputName', 'cellposeSAM', ...
    'probabilityOutputName', 'cellposeSAM_prob'));
node.contract = pipelineNodeContract(node);
node.inputs = {'roiList'};
node.outputs = {'roiList','masks','channels'};

pipeObj = pipeline('', 'contract_smoke', 1);
pipeObj.setPath(tmpRoot, 'contract_smoke');
pipeObj.nodes = node;
pipeObj.edges = struct([]);
pipeObj.branches = struct([]);
pipelineSave(pipeObj);

jsonPath = fullfile(pipeObj.path, 'pipeline.json');
txt = fileread(jsonPath);
assert(isempty(strfind(txt, '"contract"')), 'Saved JSON still contains node.contract.');
assert(isempty(strfind(txt, '"inputs"')), 'Saved JSON still contains node.inputs.');
assert(isempty(strfind(txt, '"outputs"')), 'Saved JSON still contains node.outputs.');

[loaded, msg] = pipelineLoad(jsonPath);
assert(isempty(msg) && ~isempty(loaded), 'pipelineLoad failed: %s', msg);
assert(~isfield(loaded.nodes, 'contract'), 'Loaded nodes should not keep contract fields.');
assert(~isfield(loaded.nodes, 'inputs'), 'Loaded nodes should not keep inputs fields.');
assert(~isfield(loaded.nodes, 'outputs'), 'Loaded nodes should not keep outputs fields.');
end

function cases = knownModuleCases()
raw = { ...
    'dataLoader', 'dataLoader'; ...
    'roiPattern', 'roiPattern'; ...
    'roiManual', 'roiManual'; ...
    'roiGrid', 'roiGrid'; ...
    'roiTracked', 'roiTracked'; ...
    'roiExtract', 'roiExtract'; ...
    'processor', 'basicObjectTracking'; ...
    'processor', 'combineMultipleChannels'; ...
    'processor', 'computeLineage'; ...
    'processor', 'computeMaxProjection'; ...
    'processor', 'computeMetrics'; ...
    'processor', 'computeRLS'; ...
    'processor', 'formatInDataSeries'; ...
    'processor', 'trackMotherLineageViterbi'; ...
    'classifier', 'cellposesam'; ...
    'classifier', 'cnn'; ...
    'classifier', 'cnn_lstm'};
cases = struct('type', {}, 'pkg', {});
for i = 1:size(raw, 1)
    cases(end+1) = struct('type', raw{i,1}, 'pkg', raw{i,2}); %#ok<AGROW>
end
end

function node = makeNode(type, pkg, params)
node = struct();
node.id = lower(regexprep([char(string(type)) '_' char(string(pkg))], '[^A-Za-z0-9]+', '_'));
node.type = char(string(type));
node.pkg = char(string(pkg));
node.func = defaultFunction(type, pkg);
node.params = params;
end

function params = defaultParams(type, pkg)
params = struct();
if any(strcmpi(type, {'dataLoader','roiPattern','roiManual','roiGrid','roiTracked','roiExtract'}))
    try
        params = feval([char(string(pkg)) '.setparam'], struct());
    catch
        params = struct();
    end
elseif strcmpi(type, 'processor')
    try
        params = feval([char(string(pkg)) '.setparam'], struct());
    catch
        params = struct();
    end
    params.pkg = char(string(pkg));
elseif strcmpi(type, 'classifier')
    params.pkg = char(string(pkg));
    switch lower(char(string(pkg)))
        case 'cellposesam'
            params.outputType = 'segmentation';
            params.outputName = 'cellposeSAM';
            params.probabilityOutputName = 'cellposeSAM_prob';
        case 'cnn_lstm'
            params.outputMode = 'lstm_only';
            params.outputName = 'div_lstm';
            params.cnnOutputName = 'div_cnn';
        otherwise
            params.outputName = char(string(pkg));
    end
end
end

function fun = defaultFunction(type, pkg)
switch lower(char(string(type)))
    case 'dataloader'
        fun = 'dataLoader.process';
    case {'roipattern','roiidentify'}
        fun = 'roiPattern.process';
    case 'roimanual'
        fun = 'roiManual.process';
    case 'roigrid'
        fun = 'roiGrid.process';
    case 'roitracked'
        fun = 'roiTracked.process';
    case 'roiextract'
        fun = 'roiExtract.process';
    case 'processor'
        fun = [char(string(pkg)) '.process'];
    case 'classifier'
        fun = [char(string(pkg)) '.classify'];
    otherwise
        fun = '';
end
end

function r = resourceStruct(type, role, symbol, param, port, nameParam, required, transfer)
r = struct( ...
    'type', type, ...
    'role', role, ...
    'symbol', symbol, ...
    'param', param, ...
    'port', port, ...
    'nameParam', nameParam, ...
    'required', required, ...
    'transfer', transfer);
end

function edges = makeEdges(raw)
edges = struct('from', {}, 'to', {});
for i = 1:size(raw, 1)
    edges(end+1) = struct('from', raw{i,1}, 'to', raw{i,2}); %#ok<AGROW>
end
end

function cleanupDir(pathStr)
if exist(pathStr, 'dir') == 7
    try
        rmdir(pathStr, 's');
    catch
    end
end
end
