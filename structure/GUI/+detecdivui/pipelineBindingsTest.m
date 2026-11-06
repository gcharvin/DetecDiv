function pipelineBindingsTest()
%PIPELINEBINDINGSTEST Semantic metadata, exact symbolic wiring and no resolution.
resource = @(type,role,param,port,nameParam)struct('type',type,'role',role, ...
    'param',param,'port',port,'nameParam',nameParam,'symbol',role,'required',true);
source = makeNode('segment',struct('outputName','cells'));
source.contract.resources.out = resource('mask','segmentation','outputName','masks','outputName');
target = makeNode('track',struct('mask','@resource:segmentation:segment','gain',2,'channel','source'));
target.contract.resources.in = resource('mask','segmentation','mask','masks','');
target.contract.parameters.static = {'gain','channel'};
target.contract.binding.selectorKeys = {'channel'};
nodes = [source target]; before = nodes;
[rows,keys] = detecdivui.PipelineBindings.describe(target,nodes);
assert(isscalar(rows) && strcmp(rows.direction,'Input') && strcmp(rows.param,'mask'));
assert(strcmp(rows.value,'@resource:segmentation:segment') && strcmp(rows.text,rows.value));
% Saved parameter declarations of generic nodes are not merged by the
% backend contract. The UI follows that authoritative contract unchanged.
assert(isempty(keys) && strcmp(rows.scope,'template'), ...
    'Binding kind must be independent of template/run scope.');
assert(isequal(rows.choices,{'<segmentation output from segment / cells>'}));
assert(strcmp(detecdivui.PipelineBindings.storeValue(rows.choices{1}),rows.value));
declared = struct('from','segment','to','track','metadata','retained');
edges = detecdivui.PipelineBindings.edges(nodes,declared);
assert(numel(edges)==2 && strcmp(edges(1).metadata,'retained'));
assert(strcmp(edges(2).condition,'resourceBinding') && strcmp(edges(2).fromPort,'masks') && strcmp(edges(2).toPort,'masks'));
again = detecdivui.PipelineBindings.edges(nodes,edges); assert(isequaln(edges,again));
assert(isequaln(nodes,before) && ~isfield(declared,'condition'));

% Literal physical names never fabricate symbolic edges or lineage roles.
target.params.mask = 'results_hoct_cell'; nodes(2) = target;
assert(isempty(detecdivui.PipelineBindings.edges(nodes,struct([]))));
target.params.mask = '@missing.masks'; nodes(2) = target;
missing = detecdivui.PipelineBindings.edges(nodes,struct([]));
assert(isscalar(missing) && strcmp(missing.from,'missing') && strcmp(missing.fromPort,'masks'));

% Selected choice values, collections and old human-readable labels retain
% their symbolic dependency; no runtime path or source object is needed.
target.params.mask = {'literal','@resource:segmentation:segment','@resource:segmentation:segment'};
nodes(2) = target; selected = detecdivui.PipelineBindings.edges(nodes,struct([]));
assert(isscalar(selected) && strcmp(selected.from,'segment'));
target.params.mask = '<segmentation output from segment / cells>';
nodes(2) = target; legacy = detecdivui.PipelineBindings.edges(nodes,struct([]));
assert(isscalar(legacy) && strcmp(legacy.from,'segment'));
[from,port,role] = detecdivui.PipelineBindings.symbol('@resource:metrics:measure / meanArea');
assert(strcmp(from,'measure') && isempty(port) && strcmp(role,'metrics'));
assert(strcmp(detecdivui.PipelineBindings.storeValue('<metrics output from measure / measurements / meanArea>'), ...
    '@resource:metrics:measure / meanArea'));

pattern = struct('id','pattern','type','roiPattern','pkg','roiPattern', ...
    'params',struct('threshold',.5,'channel','@raw.channels','channelIndex',1,'referenceFrame',1));
[patternRows,patternKeys] = detecdivui.PipelineBindings.describe(pattern,pattern);
assert(isequal(patternKeys,{'threshold'}) && strcmp(patternRows.param,'channel'));
assert(strcmp(patternRows.scope,'run'));
disp('Pipeline bindings test passed: independent parameter kind/scope, exact symbolic resources, no fabricated links, dangling references, legacy labels and unchanged definitions.');
end

function node = makeNode(id,params)
node = struct('id',id,'type','probe','pkg','','params',params,'contract',struct());
node.contract.resources = struct('in',struct([]),'out',struct([]));
node.contract.parameters = struct('static',{{}},'run',{{}});
node.contract.binding = struct('selectorKeys',{{}});
end
