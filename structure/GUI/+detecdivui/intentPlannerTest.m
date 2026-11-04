function intentPlannerTest()
%INTENTPLANNERTEST Pure proposals, context coverage and immutable input graphs.
p = shallow(); p.io.file = 'Intent fixture'; p.fov.id = 'Position';
p.fov.srcpath = {'Z:\missing-raw-source'};
for k = 1:2
    r = roi(sprintf('ROI%d',k),[1 1 10 10]);
    r.path = fullfile(tempdir,'nonexistent-intent-data');
    r.display.channel = {'BF','Masks','GT_cells'}; r.display.indexed = [false true true];
    r.setExtractionStatus('extracted','previous_run'); p.fov.roi(k) = r;
end
s = detecdivui.Session(p); s.selectZone(1);
state = detecdivui.ProjectInventory.inspect(s);
assert(isempty(p.fov.roi(1).image) && isequal(state.masks,{'Masks'}));
assert(strcmp(state.maskState,'unverified') && strcmp(state.images,'declared'));
catalogue = detecdiv_modules_list('Root',fileparts(fileparts(fileparts(fileparts(mfilename('fullpath'))))),'PluginRoots',{});
base = detecdivui.IntentPlanner.snapshot([]);
choices = struct('track','module:legacy.classifier.trackastra');
plan = detecdivui.IntentPlanner.propose(base,state,'track_cells',choices,catalogue);
assert(plan.canApply && isscalar(plan.nodes) && strcmp(plan.nodes.pkg,'trackastra'));
assert(any(strcmp(plan.statuses,'Existing · unverified')) && ~any(strcmp({plan.nodes.pkg},'cellposesam')));
assert(any(contains(string(plan.questions),'provenance')));
measure = struct('measure','module:legacy.processor.computeMetrics');
measured = detecdivui.IntentPlanner.propose(base,state,'measure_signals',measure,catalogue);
assert(measured.canApply && isscalar(measured.nodes) && strcmp(measured.nodes.pkg,'computeMetrics'));
cavity = struct('cavity','module:legacy.processor.selectCavityTrajectory');
trajectory = detecdivui.IntentPlanner.propose(base,state,'cavity_trajectory',cavity,catalogue);
assert(~trajectory.canApply && any(contains(string(trajectory.questions),'Identities and Parentage')));
module = catalogue(strcmp({catalogue.pkg},'cellLatentModel')); cavity.identity = ['module:' module.id];
trajectory = detecdivui.IntentPlanner.propose(base,state,'cavity_trajectory',cavity,catalogue);
assert(trajectory.canApply && numel(trajectory.nodes)==2 && strcmp(trajectory.nodes(1).pkg,'cellLatentModel'));
module = catalogue(strcmp({catalogue.pkg},'roiManual'));
definition = detecdivui.IntentPlanner.propose(base,state,'define_rois',struct('rois',['module:' module.id]),catalogue);
assert(definition.canApply && isscalar(definition.nodes) && strcmp(definition.nodes.pkg,'roiManual'));
% No mask for the second ROI: whole-FOV coverage is partial, never reusable.
p.fov.roi(2).display.indexed = [false false true]; s.selectZone(0);
partial = detecdivui.ProjectInventory.inspect(s);
assert(strcmp(partial.maskState,'partial') && isempty(partial.masks));
plan = detecdivui.IntentPlanner.propose(base,partial,'track_cells',choices,catalogue);
assert(any(strcmp(plan.statuses,'Existing · partial')));
% Missing masks adds a prerequisite; no method is invented.
p.fov.roi(1).display.indexed = [false false true];
missing = detecdivui.ProjectInventory.inspect(s);
plan = detecdivui.IntentPlanner.propose(base,missing,'track_cells',choices,catalogue);
assert(~plan.canApply && any(strcmp(plan.statuses,'Choose method')));
choices.segment = 'module:detecdiv.cellposesam';
plan = detecdivui.IntentPlanner.propose(base,missing,'track_cells',choices,catalogue);
assert(plan.canApply && numel(plan.nodes)==2 && isscalar(plan.edges));
config = struct('nodes',plan.nodes,'edges',plan.edges,'branches',struct([]));
assert(strcmp(detecdivui.IntentPlanner.configurationSignature(config), ...
    detecdivui.IntentPlanner.configurationSignature(jsondecode(jsonencode(config)))));
assert(strcmp(plan.edges.fromPort,'roiList') && strcmp(plan.edges.toPort,'roiList'));
% Reuse the effective node without mutating the original independent template.
t = pipeline(); t.strid = 'Existing'; t.nodes = plan.nodes(1); t.nodes.params.diameter = 17;
original = t.nodes; effective = original; effective.params.diameter = 21;
base = detecdivui.IntentPlanner.snapshot(t,effective);
choices = struct('track','module:legacy.classifier.trackastra');
plan = detecdivui.IntentPlanner.propose(base,missing,'track_cells',choices,catalogue);
assert(plan.canApply && any(strcmp(plan.statuses,'Reused step')));
assert(plan.nodes(1).params.diameter==21 && isequaln(t.nodes,original));
assert(isequaln(jsondecode(plan.baseSignature).nodes.params,base.nodes.params));
% Disabled and probability-only steps cannot satisfy segmentation.
base.nodes.enabled = false;
plan = detecdivui.IntentPlanner.propose(base,missing,'track_cells',choices,catalogue); assert(~plan.canApply);
base.nodes.enabled = true; base.nodes.params.outputType = 'probability';
plan = detecdivui.IntentPlanner.propose(base,missing,'track_cells',choices,catalogue); assert(~plan.canApply);
% Ambiguous existing steps need an explicit node choice.
base.nodes = [original original]; base.nodes(2).id = 'other_segment';
plan = detecdivui.IntentPlanner.propose(base,missing,'track_cells',choices,catalogue); assert(~plan.canApply);
choices.segment = ['step:' original.id];
plan = detecdivui.IntentPlanner.propose(base,missing,'track_cells',choices,catalogue); assert(plan.canApply);
% Existing advanced edges are preserved and backward dependencies are refused.
base.nodes(2).pkg = 'trackastra'; base.nodes(2).type = 'classifier';
base.edges = struct('from','other_segment','to',original.id,'fromPort','roiList','toPort','roiList','condition','');
plan = detecdivui.IntentPlanner.propose(base,missing,'track_cells',struct(),catalogue);
assert(~plan.canApply && any(contains(string(plan.questions),'cycle')) && isequal(plan.edges,base.edges));
% Non-ROI context has no inference, model migration or implicit file read.
s.selectZone(1); r = p.fov.roi(1); r.setExtractionStatus('stale');
stale = detecdivui.ProjectInventory.inspect(s); assert(strcmp(stale.images,'stale'));
assert(~strcmp(state.signature,stale.signature) && isempty(r.image) && isempty(fieldnames(r.cellModel)));
% Cached model metadata changes are detected without JSON expansion or uint64 rounding.
r.cellModel = cellModel.create(r.id); r.cellModel.instances.track_id = uint64(9007199254740992)+uint64(1);
a = detecdivui.ProjectInventory.inspect(s);
r.cellModel.instances.track_id = r.cellModel.instances.track_id+uint64(1);
b = detecdivui.ProjectInventory.inspect(s); assert(~strcmp(a.signature,b.signature) && numel(a.signature)==64);
empty = detecdivui.ProjectInventory.inspect(detecdivui.Session());
plan = detecdivui.IntentPlanner.propose(detecdivui.IntentPlanner.snapshot([]),empty,'define_rois',struct(),catalogue);
assert(~plan.canApply);
disp('Intent planner test passed: metadata-only inventory, missing/partial/stale resources, GT exclusion, recipe dependencies, exact effective-step reuse, ambiguous methods, advanced graph preservation and cycles.');
end
