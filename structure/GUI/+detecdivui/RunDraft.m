classdef RunDraft < handle
    % Session-local run overrides; templates and scientific objects stay intact.
    properties (SetAccess = private)
        Overrides = struct('id',{},'params',{})
        Settings = struct()
    end
    properties (Access = private)
        Project = []
        Template = []
        Records = struct('project',{},'template',{},'overrides',{},'settings',{},'trusted',{})
        Trusted = struct('id',{},'keys',{})
        Discarded = 0
    end
    methods
        function select(obj,project,template)
            if obj.same(obj.Project,project) && obj.same(obj.Template,template), obj.reconcile(); return; end
            obj.Project = project; obj.Template = template;
            obj.Overrides = struct('id',{},'params',{});
            obj.Settings = struct();
            obj.Trusted = struct('id',{},'keys',{});
            for k = 1:numel(obj.Records)
                if obj.same(obj.Records(k).project,project) && obj.same(obj.Records(k).template,template)
                    obj.Overrides = obj.Records(k).overrides;
                    obj.Settings = obj.Records(k).settings;
                    obj.Trusted = obj.Records(k).trusted; break;
                end
            end
            obj.reconcile();
        end
        function nodes = effectiveNodes(obj)
            obj.reconcile();
            nodes = struct([]);
            if ~isempty(obj.Template) && isvalid(obj.Template)
                nodes = pipelineApplyRunNodeParams(obj.Template.nodes,obj.Overrides);
            end
        end
        function configure(obj,settings)
            obj.Settings = settings; obj.store();
        end
        function import(obj,settings,overrides)
            if ~isempty(overrides) && ~isfield(overrides,'id')
                nodes = pipelineApplyRunNodeParams(obj.Template.nodes,overrides);
                records = struct('id',{},'params',{});
                for k = 1:numel(nodes), records(end+1) = struct('id',nodes(k).id,'params',nodes(k).params); end %#ok<AGROW>
                overrides = records;
            end
            obj.Trusted = struct('id',{},'keys',{});
            for k = 1:numel(overrides)
                obj.Trusted(end+1) = struct('id',overrides(k).id,'keys',{fieldnames(overrides(k).params)});
            end
            obj.Settings = settings; obj.Overrides = overrides;
            obj.reconcile(); obj.store();
        end
        function newRun(obj)
            obj.Overrides = struct('id',{},'params',{});
            obj.Trusted = struct('id',{},'keys',{});
            obj.Settings = struct(); obj.store();
        end
        function set(obj,nodeId,key,value)
            nodeId = char(string(nodeId));
            obj.reconcile();
            node = obj.node(nodeId);
            assert(isfield(node.params,key),'detecdivui:RunParameter','Unknown parameter: %s',key);
            assert(strcmp(pipelineParamScope(node,key),'run'),'detecdivui:TemplateParameter', ...
                'Use Editor to change template parameters.');
            base = node.params.(key); kind = obj.valueKind(base);
            switch kind
                case 'number'
                    validateattributes(value,{'numeric'},{'scalar','real','finite'});
                    if isinteger(base)
                        assert(abs(double(value)) <= flintmax && value == fix(value) && value >= double(intmin(class(base))) && ...
                            value <= double(intmax(class(base))),'detecdivui:RunNumber','Enter an integer within the parameter range.');
                    end
                    value = cast(value,class(base));
                    assert(isfinite(value),'detecdivui:RunNumber','Value is outside the parameter range.');
                case 'logical'
                    validateattributes(value,{'logical'},{'scalar'});
                case 'text'
                    assert((ischar(value) && (isrow(value) || isempty(value))) || ...
                        (isstring(value) && isscalar(value)),'detecdivui:RunText','Enter a text value.');
                    if ischar(base), value = char(value); else, value = string(value); end
                case 'choice'
                    chosen = char(string(value)); choices = cellstr(string(base(1:end-1)));
                    assert(any(strcmp(choices,chosen)),'detecdivui:RunChoice','Select an available value.');
                    value = base;
                    if isstring(base{end}), value{end} = string(chosen); else, value{end} = chosen; end
                otherwise
                    error('detecdivui:RunParameterType','Use Editor for arrays and structured parameters.');
            end
            if isequaln(value,base), obj.reset(nodeId,key); return; end
            index = find(strcmp({obj.Overrides.id},nodeId),1);
            if isempty(index)
                obj.Overrides(end+1) = struct('id',char(nodeId),'params',struct());
                index = numel(obj.Overrides);
            end
            obj.Overrides(index).params.(key) = value; obj.untrust(nodeId,key); obj.store();
        end
        function reset(obj,nodeId,key)
            nodeId = char(string(nodeId));
            obj.untrust(nodeId,key);
            index = find(strcmp({obj.Overrides.id},nodeId),1);
            if isempty(index), return; end
            if isfield(obj.Overrides(index).params,key)
                obj.Overrides(index).params = rmfield(obj.Overrides(index).params,key);
                if isempty(fieldnames(obj.Overrides(index).params)), obj.Overrides(index) = []; end
            end
            obj.store();
        end
        function value = has(obj,nodeId,key)
            nodeId = char(string(nodeId));
            index = find(strcmp({obj.Overrides.id},nodeId),1);
            value = ~isempty(index) && isfield(obj.Overrides(index).params,key);
        end
        function reconcile(obj)
            if isempty(obj.Template) || ~isvalid(obj.Template) || isempty(obj.Overrides), return; end
            nodes = obj.Template.nodes; removed = 0;
            for k = numel(obj.Overrides):-1:1
                index = [];
                if isfield(nodes,'id'), index = find(strcmp(string({nodes.id}),obj.Overrides(k).id)); end
                keys = fieldnames(obj.Overrides(k).params);
                for j = 1:numel(keys)
                    key = keys{j}; valid = false;
                    if isscalar(index) && isfield(nodes(index),'params') && isfield(nodes(index).params,key)
                        base = nodes(index).params.(key); value = obj.Overrides(k).params.(key);
                        kind = obj.valueKind(base);
                        imported = obj.trusted(obj.Overrides(k).id,key);
                        valid = strcmp(pipelineParamScope(nodes(index),key),'run') && ...
                            (imported || (strcmp(kind,obj.valueKind(value)) && strcmp(class(base),class(value))));
                        if valid && ~imported && strcmp(kind,'choice'), valid = isequaln(base(1:end-1),value(1:end-1)); end
                    elseif isscalar(index) && obj.trusted(obj.Overrides(k).id,key)
                        valid = strcmp(pipelineParamScope(nodes(index),key),'run');
                    end
                    if ~valid
                        obj.Overrides(k).params = rmfield(obj.Overrides(k).params,key); removed = removed+1;
                    end
                end
                if isempty(fieldnames(obj.Overrides(k).params)), obj.Overrides(k) = []; end
            end
            if removed > 0, obj.Discarded = obj.Discarded+removed; obj.store(); end
        end
        function count = takeDiscarded(obj)
            count = obj.Discarded; obj.Discarded = 0;
        end
        function forgetProject(obj,project)
            obj.Records = obj.Records(~arrayfun(@(r)obj.same(r.project,project),obj.Records));
            if obj.same(obj.Project,project)
                obj.Project = []; obj.Overrides = struct('id',{},'params',{}); obj.Settings = struct();
            end
        end
        function rebindProject(obj,oldProject,newProject)
            for k = 1:numel(obj.Records)
                if obj.same(obj.Records(k).project,oldProject), obj.Records(k).project = newProject; end
            end
            if obj.same(obj.Project,oldProject), obj.Project = newProject; end
        end
        function forgetTemplate(obj,template)
            obj.Records = obj.Records(~arrayfun(@(r)obj.same(r.template,template),obj.Records));
            if obj.same(obj.Template,template)
                obj.Template = []; obj.Overrides = struct('id',{},'params',{}); obj.Settings = struct();
            end
        end
    end
    methods (Access = private)
        function node = node(obj,id)
            assert(~isempty(obj.Template) && isvalid(obj.Template),'detecdivui:Pipeline','Select a pipeline.');
            nodes = obj.Template.nodes;
            assert(isfield(nodes,'id'),'detecdivui:RunNode','No pipeline steps available.');
            index = find(strcmp(string({nodes.id}),string(id)));
            assert(isscalar(index),'detecdivui:RunNode','Select a uniquely identified step.');
            node = nodes(index);
        end
        function store(obj)
            index = [];
            for k = 1:numel(obj.Records)
                if obj.same(obj.Records(k).project,obj.Project) && obj.same(obj.Records(k).template,obj.Template)
                    index = k; break;
                end
            end
            if isempty(index), index = numel(obj.Records)+1; end
            obj.Records(index) = struct('project',obj.Project,'template',obj.Template, ...
                'overrides',obj.Overrides,'settings',obj.Settings,'trusted',obj.Trusted);
        end
        function yes = trusted(obj,id,key)
            index = find(strcmp({obj.Trusted.id},id),1);
            yes = ~isempty(index) && any(strcmp(obj.Trusted(index).keys,key));
        end
        function untrust(obj,id,key)
            index = find(strcmp({obj.Trusted.id},id),1);
            if isempty(index), return; end
            obj.Trusted(index).keys(strcmp(obj.Trusted(index).keys,key)) = [];
        end
    end
    methods (Static)
        function kind = valueKind(value)
            kind = 'complex';
            if islogical(value) && isscalar(value), kind = 'logical';
            elseif isnumeric(value) && isscalar(value) && isreal(value) && isfinite(value) && ...
                    (~isinteger(value) || abs(double(value)) <= flintmax), kind = 'number';
            elseif (ischar(value) && (isrow(value) || isempty(value))) || (isstring(value) && isscalar(value)), kind = 'text';
            elseif iscell(value) && numel(value) >= 2
                scalarText = cellfun(@(item)(ischar(item) && isrow(item)) || ...
                    (isstring(item) && isscalar(item)),value);
                if all(scalarText(:)) && any(strcmp(string(value{end}),string(value(1:end-1))))
                    kind = 'choice';
                end
            end
        end
    end
    methods (Static, Access = private)
        function yes = same(left,right)
            yes = isempty(left) && isempty(right);
            if ~isempty(left) && ~isempty(right) && strcmp(class(left),class(right)) && isvalid(left) && isvalid(right)
                yes = left == right;
            end
        end
    end
end
