classdef PipelineBindings
    % Metadata-only views of the shared pipeline resource/parameter contracts.
    % This adapter never resolves bindings or loads images/classifier objects.
    methods (Static)
        function [rows,staticKeys] = describe(node,nodes)
            if nargin < 2, nodes = node; end
            contract = detecdivui.PipelineBindings.contract(node);
            resources = detecdivui.PipelineBindings.field(contract,'resources',struct());
            params = detecdivui.PipelineBindings.field(node,'params',struct());
            rows = struct('direction',{},'resource',{},'param',{},'value',{},'text',{}, ...
                'choices',{},'scope',{},'type',{},'role',{},'port',{},'required',{});
            bindingKeys = {};
            for direction = {'Input','Output'}
                input = strcmp(direction{1},'Input'); field = 'out'; if input, field = 'in'; end
                specs = detecdivui.PipelineBindings.field(resources,field,struct([]));
                for k = 1:numel(specs)
                    spec = specs(k); type = detecdivui.PipelineBindings.text(spec,'type');
                    if isempty(type), continue; end
                    key = detecdivui.PipelineBindings.text(spec,'param');
                    if ~input
                        nameKey = detecdivui.PipelineBindings.text(spec,'nameParam');
                        if ~isempty(nameKey), key = nameKey; end
                    end
                    if isempty(key), continue; end
                    value = ''; if isfield(params,key), value = params.(key); end
                    role = detecdivui.PipelineBindings.text(spec,'role');
                    choices = {};
                    if input, choices = detecdivui.PipelineBindings.choices(nodes,node,spec); end
                    label = role; if isempty(label), label = type; end
                    rows(end+1) = struct('direction',direction{1},'resource',strrep(label,'_',' '), ...
                        'param',key,'value',{value},'text',detecdivui.PipelineBindings.valueText(value), ...
                        'choices',{choices},'scope',pipelineParamScope(node,key),'type',type,'role',role, ...
                        'port',detecdivui.PipelineBindings.text(spec,'port'), ...
                        'required',logical(detecdivui.PipelineBindings.field(spec,'required',false))); %#ok<AGROW>
                    bindingKeys{end+1} = key; %#ok<AGROW>
                end
            end
            groups = detecdivui.PipelineBindings.field(contract,'parameters',struct());
            staticKeys = {};
            for field = {'static','fixed','design','template'}
                value = detecdivui.PipelineBindings.field(groups,field{1},{});
                staticKeys = [staticKeys reshape(cellstr(string(value)),1,[])]; %#ok<AGROW>
            end
            nodeType = detecdivui.PipelineBindings.text(node,'type');
            declared = setdiff(staticKeys,{'pkg','moduleVar','modulePath','moduleId','description','category'});
            if isempty(declared) && any(strcmpi(nodeType,{'processor','classifier','custom'}))
                % Legacy packages may expose defaults without a complete
                % parameter contract. Offer their stored non-runtime values,
                % while leaving selectors/references in Bindings.
                staticKeys = reshape(fieldnames(params),1,[]);
                runtime = {};
                for field = {'run','data'}
                    runtime = [runtime reshape(cellstr(string( ...
                        detecdivui.PipelineBindings.field(groups,field{1},{}))),1,[])]; %#ok<AGROW>
                end
                staticKeys = setdiff(staticKeys,[runtime {'frames','fovIndex','roiIndex','roiList'}],'stable');
            end
            selectors = detecdivui.PipelineBindings.field(contract,'binding',struct());
            bindingKeys = [bindingKeys reshape(cellstr(string( ...
                detecdivui.PipelineBindings.field(selectors,'selectorKeys',{}))),1,[])];
            hidden = {'pkg','tip','paramTooltip','moduleVar','modulePath','moduleId','description','category', ...
                'customPackageRoot','customPackageDir','customPackageLoadedAt'};
            staticKeys = setdiff(unique(staticKeys,'stable'),[bindingKeys hidden],'stable');
            staticKeys = staticKeys(ismember(staticKeys,fieldnames(params)));
        end

        function combined = edges(nodes,declared)
            if nargin < 2, declared = struct([]); end
            combined = declared;
            fields = {'from','to','fromPort','toPort','condition'};
            if isempty(combined)
                combined = struct('from',{},'to',{},'fromPort',{},'toPort',{},'condition',{});
            else
                for k = 1:numel(fields)
                    if ~isfield(combined,fields{k}), [combined.(fields{k})] = deal(''); end
                end
            end
            for k = 1:numel(nodes)
                node = nodes(k); contract = detecdivui.PipelineBindings.contract(node);
                resources = detecdivui.PipelineBindings.field(contract,'resources',struct());
                inputs = detecdivui.PipelineBindings.field(resources,'in',struct([]));
                params = detecdivui.PipelineBindings.field(node,'params',struct());
                for j = 1:numel(inputs)
                    spec = inputs(j); key = detecdivui.PipelineBindings.text(spec,'param');
                    if isempty(key) || ~isfield(params,key), continue; end
                    values = detecdivui.PipelineBindings.textValues(params.(key));
                    for v = 1:numel(values)
                        [source,port,role] = detecdivui.PipelineBindings.symbol(values{v});
                        if isempty(source), continue; end
                        if isempty(port)
                            index = find(strcmp({nodes.id},source),1);
                            if ~isempty(index)
                                srcContract = detecdivui.PipelineBindings.contract(nodes(index));
                                outputs = detecdivui.PipelineBindings.field( ...
                                    detecdivui.PipelineBindings.field(srcContract,'resources',struct()),'out',struct([]));
                                for o = 1:numel(outputs)
                                    out = outputs(o);
                                    if ~isempty(role) && ~strcmpi(detecdivui.PipelineBindings.canonicalRole( ...
                                            detecdivui.PipelineBindings.text(out,'role')),role), continue; end
                                    if detecdivui.PipelineBindings.compatible(spec,out)
                                        port = detecdivui.PipelineBindings.text(out,'port'); break;
                                    end
                                end
                            end
                        end
                        edge = struct('from',source,'to',char(string(node.id)),'fromPort',port, ...
                            'toPort',detecdivui.PipelineBindings.text(spec,'port'),'condition','resourceBinding');
                        exists = false;
                        for e = 1:numel(combined)
                            exists = all(cellfun(@(field)strcmp(char(string(combined(e).(field))),edge.(field)),fields));
                            if exists, break; end
                        end
                        if exists, continue; end
                        extra = setdiff(fieldnames(combined),fields);
                        for e = 1:numel(extra), edge.(extra{e}) = []; end
                        edge = orderfields(edge,combined); combined(end+1) = edge; %#ok<AGROW>
                    end
                end
            end
        end

        function value = storeValue(label)
            value = pipelineSymbolicBindingFromLabel(label);
        end

        function [source,port,role] = symbol(value)
            source = ''; port = ''; role = '';
            if ~(ischar(value) || isstring(value)) || ~isscalar(string(value)), return; end
            value = strtrim(char(string(value)));
            if startsWith(value,'<') && endsWith(value,'>'), value = pipelineSymbolicBindingFromLabel(value); end
            if ~startsWith(value,'@'), return; end
            if startsWith(value,'@resource:')
                tokens = regexp(value,'^@resource:([^:]+):([^/]+)(?:/.*)?$','tokens','once');
                if isempty(tokens), return; end
                role = detecdivui.PipelineBindings.canonicalRole(strtrim(tokens{1})); source = strtrim(tokens{2});
            else
                tokens = regexp(value,'^@([^./\s]+)\.([^/\s]+)(?:\s*/.*)?$','tokens','once');
                if isempty(tokens), return; end
                source = tokens{1}; port = tokens{2};
            end
        end

        function text = valueText(value)
            if strcmp(detecdivui.RunDraft.valueKind(value),'choice'), value = value{end}; end
            if (ischar(value) && (isrow(value) || isempty(value))) || isstring(value) && isscalar(value)
                text = char(string(value));
            elseif isnumeric(value) || islogical(value)
                text = mat2str(value);
            elseif iscellstr(value) || isstring(value)
                text = strjoin(cellstr(string(value)),', ');
            elseif isstruct(value)
                text = sprintf('[%s struct]',strjoin(string(size(value)),' x '));
            else
                text = class(value);
            end
        end
    end
    methods (Static, Access = private)
        function choices = choices(nodes,node,spec)
            choices = {};
            for k = 1:numel(nodes)
                source = nodes(k);
                if strcmp(char(string(source.id)),char(string(node.id))), continue; end
                contract = detecdivui.PipelineBindings.contract(source);
                resources = detecdivui.PipelineBindings.field(contract,'resources',struct());
                outputs = detecdivui.PipelineBindings.field(resources,'out',struct([]));
                for o = 1:numel(outputs)
                    out = outputs(o);
                    if ~detecdivui.PipelineBindings.compatible(spec,out), continue; end
                    name = detecdivui.PipelineBindings.outputName(source,out);
                    role = detecdivui.PipelineBindings.text(out,'role');
                    if isempty(role), role = detecdivui.PipelineBindings.text(out,'type'); end
                    label = sprintf('<%s output from %s',role,char(string(source.id)));
                    if ~isempty(name), label = [label ' / ' name]; end %#ok<AGROW>
                    choices{end+1} = [label '>']; %#ok<AGROW>
                end
            end
            choices = unique(choices,'stable');
        end
        function name = outputName(node,spec)
            name = ''; params = detecdivui.PipelineBindings.field(node,'params',struct());
            keys = {detecdivui.PipelineBindings.text(spec,'nameParam'),detecdivui.PipelineBindings.text(spec,'param')};
            for k = 1:numel(keys)
                if isempty(keys{k}) || ~isfield(params,keys{k}), continue; end
                value = detecdivui.PipelineBindings.textValues(params.(keys{k}));
                if isscalar(value), name = value{1}; end
                if ~isempty(name) && ~startsWith(name,'@'), break; end
                name = '';
            end
            if isempty(name)
                role = detecdivui.PipelineBindings.text(spec,'role');
                if strcmpi(role,'roi_image'), return; end
                name = detecdivui.PipelineBindings.text(spec,'concreteName');
                if isempty(name), name = detecdivui.PipelineBindings.text(spec,'symbol'); end
                if contains(name,'.'), tokens = strsplit(name,'.'); name = tokens{end}; end
                if isempty(name), name = char(string(node.id)); end
            end
            name = pipelinePhysicalResourceOutputName(node,spec,name);
        end
        function yes = compatible(wanted,available)
            type = lower(detecdivui.PipelineBindings.text(wanted,'type'));
            otherType = lower(detecdivui.PipelineBindings.text(available,'type'));
            role = lower(detecdivui.PipelineBindings.text(wanted,'role'));
            otherRole = lower(detecdivui.PipelineBindings.text(available,'role'));
            yes = false;
            scorable = {'roi_image','score_roi_image','derived_roi_image','probability','tracking', ...
                'lineage_mask','lineage_cell_mask','lineage_confidence','lineage_mother_mask','lineage_bud_mask'};
            if strcmp(type,otherType)
                yes = isempty(role) || isempty(otherRole) || strcmp(role,otherRole);
                if ~yes && any(strcmp(role,{'roi_image','score_roi_image','brightfield_image', ...
                        'legacy_gfp_fluorescence','division_nucleus_fluorescence','bud_neck_fluorescence'}))
                    yes = any(strcmp(otherRole,scorable));
                elseif ~yes && strcmp(role,'mask_roi_image')
                    yes = any(strcmp(otherRole,setdiff(scorable,{'score_roi_image','probability'})));
                end
            elseif strcmp(type,'dataseriesvariable') && strcmp(otherType,'dataseries')
                yes = isempty(role) || isempty(otherRole) || strcmp(role,'numeric_trace') || strcmp(role,otherRole);
                if any(strcmp(role,{'metric_variable','metrics_variable'})), yes = strcmp(otherRole,'metrics'); end
                if any(strcmp(role,{'classification_label','classification_variable'})), yes = strcmp(otherRole,'classification'); end
            elseif strcmp(type,'channel') && strcmp(role,'mask_roi_image')
                yes = strcmp(otherType,'mask') && strcmp(otherRole,'segmentation');
            end
        end
        function values = textValues(value)
            values = {};
            if strcmp(detecdivui.RunDraft.valueKind(value),'choice'), value = value{end}; end
            if ischar(value) && (isrow(value) || isempty(value)), values = {value};
            elseif isstring(value), values = reshape(cellstr(value),1,[]);
            elseif iscell(value)
                for k = 1:numel(value)
                    values = [values detecdivui.PipelineBindings.textValues(value{k})]; %#ok<AGROW>
                end
            end
        end
        function role = canonicalRole(role)
            switch lower(role)
                case {'lineage_cell','lineage_cell_mask','lineage_mask','lineage_mother_mask'}, role = 'lineage_mother';
                case {'lineage_conf','lineage_confidence','lineage_bud_mask'}, role = 'lineage_bud';
            end
        end
        function contract = contract(node)
            try
                contract = pipelineNodeContract(node);
            catch
                contract = detecdivui.PipelineBindings.field(node,'contract',struct());
            end
        end
        function value = text(s,key)
            value = char(string(detecdivui.PipelineBindings.field(s,key,'')));
        end
        function value = field(s,key,fallback)
            value = fallback; if isstruct(s) && isfield(s,key), value = s.(key); end
        end
    end
end
