function runDraftTest()
%RUNDRAFTTEST Preserve types, exact IDs, per-project drafts and template intent.
a = shallow(); b = shallow();
template = pipelineConstruct();
params = struct('referenceFrame',uint8(2),'keepExisting',false, ...
    'patternPreset','Default','channel',{{'Phase','GFP','Phase'}}, ...
    'threshold',0.5,'patternImage',ones(2));
node = struct('id','source-1','type','roiPattern','pkg','roiPattern','params',params);
template.nodes = [node,node]; template.nodes(2).id = 'source_1';
original = template.nodes;
draft = detecdivui.RunDraft(); draft.select(a,template);
draft.set('source-1','referenceFrame',4);
draft.set('source-1','keepExisting',true);
draft.set('source-1','patternPreset','Experiment');
draft.set('source-1','channel','GFP');
nodes = draft.effectiveNodes();
assert(isa(nodes(1).params.referenceFrame,'uint8') && nodes(1).params.referenceFrame == 4);
assert(nodes(1).params.keepExisting && strcmp(nodes(1).params.channel{end},'GFP'));
assert(nodes(2).params.referenceFrame == 2);
assert(isequal(template.nodes,original));
before = draft.Overrides;
reject(@()draft.set('source-1','threshold',0.8));
reject(@()draft.set('source-1','patternImage',zeros(2)));
reject(@()draft.set('source-1','channel','Unknown'));
reject(@()draft.set('source-1','referenceFrame',256));
reject(@()draft.set('source-1','referenceFrame',2.5));
reject(@()draft.set('source-1','keepExisting',1));
assert(isequal(draft.Overrides,before));
draft.select(b,template); assert(isempty(draft.Overrides));
draft.select(a,template); assert(isequal(draft.Overrides,before));
draft.reset('source-1','referenceFrame');
nodes = draft.effectiveNodes(); assert(nodes(1).params.referenceFrame == 2);
draft.set('source-1','referenceFrame',4);
template.nodes(1).params.referenceFrame = [1 2];
changed = template.nodes; nodes = draft.effectiveNodes();
assert(~draft.has('source-1','referenceFrame') && draft.takeDiscarded() == 1);
assert(isequal(nodes(1).params.referenceFrame,[1 2]) && isequal(template.nodes,changed));
template.nodes = original; draft.set('source-1','referenceFrame',4);
template.nodes = struct([]); assert(isempty(draft.effectiveNodes()) && isempty(draft.Overrides));
template.nodes = original; draft.takeDiscarded();
draft.forgetProject(a); draft.select(a,template); assert(isempty(draft.Overrides));
assert(strcmp(detecdivui.RunDraft.valueKind(uint64(intmax('uint64'))),'complex'));
assert(isequal(template.nodes,original));
% Advanced forms can return scalar text choices and complex run selectors.
advanced = pipelineConstruct(); advanced.nodes = node; advanced.nodes.params.frames = [];
draft.select(a,advanced);
records = struct('id',node.id,'params',struct('frames',[1 3 5],'channel','GFP'));
draft.import(struct('runId','advanced'),records);
effective = draft.effectiveNodes();
assert(isequal(effective.params.frames,[1 3 5]) && strcmp(effective.params.channel,'GFP'));
draft.select(b,advanced); draft.select(a,advanced);
assert(isequal(draft.effectiveNodes().params.frames,[1 3 5]));
draft.reset(node.id,'channel'); assert(iscell(draft.effectiveNodes().params.channel));
draft.newRun(); assert(isempty(draft.Overrides));
disp('Run draft test passed: scope, types, exact IDs, reset, isolation and immutable templates.');
end
function reject(action)
failed = false;
try action(); catch, failed = true; end
assert(failed,'Invalid run parameter was accepted.');
end
