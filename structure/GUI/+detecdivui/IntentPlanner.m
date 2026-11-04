classdef IntentPlanner
    % Pure proposals over value snapshots. Never runs a module or changes a template.
    methods (Static)
        function proposal = propose(base,state,intent,choices,catalogue)
            profile = detecdivui.IntentProfile.get(intent);
            proposal = struct('id',char(matlab.lang.internal.uuid),'intent',intent,'label',profile.label, ...
                'baseSignature',jsonencode(base),'inventorySignature',state.signature,'scope',state.scope, ...
                'nodes',base.nodes,'edges',base.edges,'branches',base.branches, ...
                'viewNodes',base.nodes,'viewEdges',base.edges,'statuses',{{}}, ...
                'questions',{{}},'changes',cell(1,1),'canApply',true);
            proposal.changes = cell(0,4);
            proposal.statuses = repmat({'Unchanged'},1,numel(base.nodes));
            roles = detecdivui.IntentPlanner.roles(state,intent); last = '';
            if state.scope.fov==0
                proposal.questions{end+1} = 'Select a FOV or ROI.'; proposal.canApply = false;
            end
            if strcmp(intent,'define_rois') || any(strcmp(roles,'rois'))
                text = 'Raw images referenced'; if ~state.rawReferenced, text = 'Raw images missing'; end
                [proposal,last] = input(proposal,'raw',text,'Check source');
                if ~state.rawReferenced, proposal.questions{end+1} = 'Import or relink raw image sources before ROI generation.'; end
            elseif state.roiCount>0
                [proposal,last] = input(proposal,'images','ROI images',['Existing · ' state.images]);
                if ~strcmp(state.images,'declared')
                    proposal.questions{end+1} = ['ROI images are ' state.images '; resolve their availability before execution.'];
                end
            end
            for k = 1:numel(roles)
                role = roles{k};
                % Existing scientific resources remain distinct from reused code steps.
                if strcmp(role,'segment') && ~strcmp(intent,'segment_cells') && ~strcmp(state.maskState,'missing')
                    status = ['Existing · ' state.maskState];
                    [proposal,id] = input(proposal,'masks','Existing Masks',status);
                    proposal = connect(proposal,last,id,true); last = id;
                    proposal.questions{end+1} = ['Check mask provider, frame coverage and provenance (' state.maskState ').'];
                    continue;
                elseif strcmp(role,'identity') && ~strcmp(state.familyState,'missing')
                    [proposal,id] = input(proposal,'model','Existing Cell Model',['Existing · ' state.familyState]);
                    proposal = connect(proposal,last,id,true); last = id;
                    proposal.questions{end+1} = ['Check model family, stable identities, parentage and coverage (' state.familyState ').'];
                    continue;
                end
                [node,stateLabel,question] = choose(base,role,choices,catalogue);
                if isempty(node)
                    node = struct('id',uniqueId(proposal.viewNodes,['need_' role]), ...
                        'name',detecdivui.IntentProfile.label(role),'type','question','pkg','','params',struct());
                    proposal.viewNodes = append(proposal.viewNodes,node);
                    proposal.statuses{end+1} = 'Choose method'; proposal.canApply = false;
                elseif strcmp(stateLabel,'Reused step')
                    at = find(strcmp({proposal.viewNodes.id},node.id),1);
                    proposal.statuses{at} = stateLabel;
                else
                    node.id = uniqueId(proposal.viewNodes,['intent_' role]);
                    proposal.nodes = append(proposal.nodes,node);
                    proposal.viewNodes = append(proposal.viewNodes,node);
                    proposal.statuses{end+1} = stateLabel;
                    proposal.questions{end+1} = ['Configure and validate ' node.name ' inputs, outputs and method settings.'];
                end
                proposal.changes(end+1,:) = {node.id,detecdivui.IntentProfile.label(role),stateLabel,question};
                if ~isempty(question), proposal.questions{end+1} = question; end
                proposal = connect(proposal,last,node.id,false); last = node.id;
            end
            proposal.questions = unique(proposal.questions,'stable');
            if isequaln(proposal.nodes,base.nodes) && isequaln(proposal.edges,base.edges)
                proposal.canApply = false; % Inspect a reused plan, do not create duplicate revisions.
            end
            proposal = orderView(proposal);
        end
        function methods = methods(role,catalogue)
            packages = detecdivui.IntentProfile.packages(role);
            methods = catalogue(ismember(lower(string({catalogue.pkg})),lower(string(packages))) & ...
                strcmp({catalogue.status},'ok') & [catalogue.onPath]);
        end
        function roles = roles(state,intent)
            profile = detecdivui.IntentProfile.get(intent); roles = profile.roles;
            if state.roiCount==0 && ~strcmp(intent,'define_rois'), roles = [{'rois','extract'} roles];
            elseif ~strcmp(intent,'define_rois') && strcmp(state.images,'missing'), roles = [{'extract'} roles]; end
        end
        function yes = needsMethod(state,intent,role)
            yes = ~(strcmp(role,'segment') && ~strcmp(intent,'segment_cells') && ~strcmp(state.maskState,'missing')) && ...
                ~(strcmp(role,'identity') && ~strcmp(state.familyState,'missing'));
        end
        function snapshot = snapshot(template,nodes)
            snapshot = struct('name','Workflow','path','','nodes',struct([]),'edges',struct([]),'branches',struct([]), ...
                'version','1.0','runProfiles',struct());
            if isempty(template), return; end
            snapshot.name = template.strid; snapshot.path = template.path;
            snapshot.version = template.version; snapshot.runProfiles = template.runProfiles;
            snapshot.nodes = template.nodes; snapshot.edges = template.edges; snapshot.branches = template.branches;
            if nargin>1, snapshot.nodes = nodes; end
        end
        function signature = configurationSignature(value)
            % Match JSON transport: numeric classes and row/column object
            % arrays alone do not constitute a parameter change.
            signature = detecdivui.ProjectInventory.fingerprint(jsonencode(canonical(value)));
        end
    end
end
function value = canonical(value)
if isstruct(value)
    value = orderfields(value); names = fieldnames(value);
    for row = 1:numel(value)
        for k = 1:numel(names), name = names{k}; value(row).(name) = canonical(value(row).(name)); end
    end
elseif iscell(value)
    for k = 1:numel(value), value{k} = canonical(value{k}); end
end
end
function [node,status,question] = choose(base,role,choices,catalogue)
node = []; status = 'Choose method'; question = '';
selection = 'auto'; if isfield(choices,role), selection = choices.(role); end
candidates = base.nodes(arrayfun(@(n)detecdivui.IntentProfile.matches(n,role),base.nodes));
if startsWith(selection,'step:')
    candidates = candidates(strcmp({candidates.id},selection(6:end)));
    if isscalar(candidates), node = candidates; status = 'Reused step'; return; end
elseif strcmp(selection,'auto') && isscalar(candidates)
    node = candidates; status = 'Reused step'; return;
end
methods = detecdivui.IntentPlanner.methods(role,catalogue);
if strcmp(role,'extract') && strcmp(selection,'auto') && isscalar(methods)
    selection = ['module:' methods.id];
end
if startsWith(selection,'module:')
    methods = methods(strcmp({methods.id},selection(8:end)));
    if isscalar(methods)
        m = methods; node = struct('id','','name',detecdivui.IntentProfile.label(role), ...
            'type',m.type,'pkg',m.pkg,'func',m.entrypoint,'params',struct('pkg',m.pkg),'enabled',true);
        % No setparam/executionSpec: unknown settings stay explicitly unresolved.
        status = 'Added'; question = ['Settings needed for ' m.name '.']; return;
    end
end
question = ['Choose a method for ' detecdivui.IntentProfile.label(role) '.'];
if numel(candidates)>1, question = ['Choose the existing step or a new method for ' detecdivui.IntentProfile.label(role) '.']; end
end
function [proposal,id] = input(proposal,key,name,status)
id = uniqueId(proposal.viewNodes,['input_' key]);
node = struct('id',id,'name',name,'type','resource','pkg','','params',struct());
proposal.viewNodes = append(proposal.viewNodes,node); proposal.statuses{end+1} = status;
proposal.changes(end+1,:) = {id,name,status,'Resource availability is not execution validation.'};
end
function proposal = connect(proposal,from,to,viewOnly)
if isempty(from) || strcmp(from,to), return; end
if reaches(proposal.viewEdges,to,from)
    proposal.questions{end+1} = ['A dependency would create a cycle at ' to '; review the advanced graph.'];
    proposal.canApply = false; return;
end
edge = struct('from',from,'to',to,'fromPort','roiList','toPort','roiList','condition','');
if ~hasEdge(proposal.viewEdges,from,to), proposal.viewEdges = append(proposal.viewEdges,edge); end
ids = {}; if ~isempty(proposal.nodes), ids = {proposal.nodes.id}; end
if ~viewOnly && all(ismember({from,to},ids)) && ~hasEdge(proposal.edges,from,to)
    source = proposal.nodes(strcmp(ids,from)); dest = proposal.nodes(strcmp(ids,to));
    a = pipelineNodeContract(source); b = pipelineNodeContract(dest);
    if any(strcmp({a.out.name},'roiList')) && any(strcmp({b.in.name},'roiList'))
        proposal.edges = append(proposal.edges,edge);
    else
        proposal.questions{end+1} = ['Bind the inputs between ' from ' and ' to ' in Advanced.'];
    end
end
end
function yes = hasEdge(edges,a,b)
yes = false; if isempty(edges), return; end
yes = any(strcmp({edges.from},a) & strcmp({edges.to},b));
end
function yes = reaches(edges,from,to)
front = {from}; visited = {}; yes = false;
while ~isempty(front)
    current = front{1}; front(1) = [];
    if strcmp(current,to), yes = true; return; end
    if any(strcmp(visited,current)) || isempty(edges), continue; end
    visited{end+1} = current; %#ok<AGROW>
    front = [front {edges(strcmp({edges.from},current)).to}]; %#ok<AGROW>
end
end
function id = uniqueId(nodes,base)
ids = {}; if ~isempty(nodes), ids = {nodes.id}; end
id = base; k = 1;
while any(strcmp(ids,id)), id = sprintf('%s_%d',base,k); k = k+1; end
end
function values = append(values,item)
if isempty(values), values = item; return; end
names = union(fieldnames(values),fieldnames(item),'stable');
for k = 1:numel(names)
    name = names{k};
    if ~isfield(values,name), [values.(name)] = deal([]); end
    if ~isfield(item,name), item.(name) = []; end
end
values(end+1) = orderfields(item,values);
end
function proposal = orderView(proposal)
% Display dependencies before consumers; never reorder the executable snapshot.
nodes = proposal.viewNodes; if isempty(nodes), return; end
ids = {nodes.id}; edges = proposal.viewEdges; degree = zeros(1,numel(nodes));
for k = 1:numel(edges)
    to = find(strcmp(ids,edges(k).to),1); from = find(strcmp(ids,edges(k).from),1);
    if ~isempty(from) && ~isempty(to), degree(to) = degree(to)+1; end
end
order = []; seen = false(1,numel(nodes));
while numel(order)<numel(nodes)
    at = find(~seen & degree==0,1); if isempty(at), return; end
    seen(at) = true; order(end+1) = at; %#ok<AGROW>
    for k = 1:numel(edges)
        if ~strcmp(edges(k).from,ids{at}), continue; end
        to = find(strcmp(ids,edges(k).to),1); if ~isempty(to), degree(to) = degree(to)-1; end
    end
end
proposal.viewNodes = nodes(order); proposal.statuses = proposal.statuses(order);
end
