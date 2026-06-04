function T = pipelineModuleAudit()
% pipelineModuleAudit  Summarize pipeline module contracts and setparam fields.
%
% The audit is intentionally read-only. It helps decide which module
% parameters belong in visible runtime controls versus static/template
% settings without encoding those decisions inside pipeline2.

    modules = discoverPipelineModules();
    rows = cell(numel(modules), 10);

    for i = 1:numel(modules)
        node = struct( ...
            'id', modules(i).pkg, ...
            'type', modules(i).type, ...
            'pkg', modules(i).pkg, ...
            'params', struct('pkg', modules(i).pkg));

        try
            contract = pipelineNodeContract(node);
            contractStatus = 'OK';
        catch ME
            contract = struct();
            contract.summary = ['CONTRACT ERROR: ' ME.message];
            contractStatus = 'ERROR';
        end

        [fields, setparamStatus] = setparamFields(modules(i).pkg);

        rows{i,1} = modules(i).type;
        rows{i,2} = modules(i).pkg;
        rows{i,3} = joinResourceSummary(getNestedField(contract, {'resources','in'}, struct([])));
        rows{i,4} = joinResourceSummary(getNestedField(contract, {'resources','out'}, struct([])));
        rows{i,5} = joinParamSummary(contract, 'run');
        rows{i,6} = joinStaticParamSummary(contract);
        rows{i,7} = strjoin(fields, ', ');
        rows{i,8} = contractStatus;
        rows{i,9} = setparamStatus;
        rows{i,10} = char(string(getFieldLocal(contract, 'summary', '')));
    end

    T = cell2table(rows, 'VariableNames', { ...
        'Type', 'Package', 'BindingInputs', 'BindingOutputs', ...
        'RuntimeParams', 'StaticParams', 'SetparamFields', ...
        'ContractStatus', 'SetparamStatus', 'Summary'});
end

function modules = discoverPipelineModules()
    specs = {
        fullfile('engine','dataloading'), 'dataLoader';
        fullfile('engine','classification'), 'classifier';
        fullfile('engine','processor'), 'processor'};

    modules = struct('type', {}, 'pkg', {});
    for s = 1:size(specs, 1)
        root = specs{s, 1};
        moduleType = specs{s, 2};
        if exist(root, 'dir') ~= 7
            continue;
        end
        dirs = dir(fullfile(root, '+*'));
        dirs = dirs([dirs.isdir]);
        [~, order] = sort({dirs.name});
        dirs = dirs(order);
        for i = 1:numel(dirs)
            pkg = dirs(i).name(2:end);
            if strcmpi(moduleType, 'dataLoader')
                type = pkg;
            else
                type = moduleType;
            end
            modules(end+1) = struct('type', type, 'pkg', pkg); %#ok<AGROW>
        end
    end
end

function [fields, status] = setparamFields(pkg)
    fields = {};
    status = 'MISSING';
    fn = [char(string(pkg)) '.setparam'];
    if isempty(which(fn))
        return;
    end
    status = 'OK';
    try
        p = feval(fn, struct());
    catch
        try
            p = feval(fn);
        catch ME
            status = 'ERROR';
            fields = {['ERROR: ' ME.message]};
            return;
        end
    end
    if isstruct(p)
        fields = fieldnames(p)';
    else
        try
            fields = {class(p)};
        catch
            fields = {'<non-struct>'};
        end
    end
end

function txt = joinParamSummary(contract, mode)
    txt = '';
    params = getFieldLocal(contract, 'parameters', struct());
    if ~isstruct(params)
        return;
    end
    switch lower(char(string(mode)))
        case 'run'
            vals = unique([toCellstr(getFieldLocal(params, 'run', {})), ...
                toCellstr(getFieldLocal(params, 'data', {}))], 'stable');
        otherwise
            vals = toCellstr(getFieldLocal(params, mode, {}));
    end
    txt = strjoin(vals, ', ');
end

function txt = joinStaticParamSummary(contract)
    params = getFieldLocal(contract, 'parameters', struct());
    if ~isstruct(params)
        txt = '';
        return;
    end
    vals = unique([ ...
        toCellstr(getFieldLocal(params, 'static', {})), ...
        toCellstr(getFieldLocal(params, 'fixed', {})), ...
        toCellstr(getFieldLocal(params, 'design', {})), ...
        toCellstr(getFieldLocal(params, 'template', {}))], 'stable');
    txt = strjoin(vals, ', ');
end

function txt = joinResourceSummary(resources)
    txt = '';
    if isempty(resources) || ~isstruct(resources)
        return;
    end
    parts = {};
    for i = 1:numel(resources)
        type = char(string(getFieldLocal(resources(i), 'type', '')));
        if isempty(type)
            continue;
        end
        role = char(string(getFieldLocal(resources(i), 'role', '')));
        param = char(string(getFieldLocal(resources(i), 'param', '')));
        parts{end+1} = sprintf('%s/%s:%s', type, role, param); %#ok<AGROW>
    end
    txt = strjoin(parts, '; ');
end

function value = getNestedField(s, path, defaultValue)
    value = defaultValue;
    try
        cur = s;
        for i = 1:numel(path)
            key = path{i};
            if ~isstruct(cur) || ~isfield(cur, key)
                return;
            end
            cur = cur.(key);
        end
        if ~isempty(cur)
            value = cur;
        end
    catch
        value = defaultValue;
    end
end

function value = getFieldLocal(s, fieldName, defaultValue)
    value = defaultValue;
    if isstruct(s) && isfield(s, fieldName) && ~isempty(s.(fieldName))
        value = s.(fieldName);
    end
end

function vals = toCellstr(value)
    vals = {};
    if isempty(value)
        return;
    end
    if iscell(value)
        vals = cellfun(@(x)char(string(x)), value(:)', 'UniformOutput', false);
    elseif ischar(value) || isstring(value)
        vals = cellstr(string(value(:)))';
    else
        try
            vals = cellstr(string(value(:)))';
        catch
            vals = {};
        end
    end
    vals = vals(~cellfun(@isempty, vals));
end
