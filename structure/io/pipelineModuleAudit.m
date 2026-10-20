function [T, diagnostics] = pipelineModuleAudit(varargin)
% pipelineModuleAudit  Audit the common module catalogue without loading code.
%
% T = pipelineModuleAudit(...) forwards Root, PluginRoots and PackagePaths to
% detecdiv_modules_list. The first ten table columns retain the historical
% audit layout. ContractStatus and SetparamStatus are NOT_INSPECTED by default.
% Use 'InspectContracts', true to inspect contracts/defaults of valid, unique
% modules already resolved from their own package directory on the MATLAB path.
% This opt-in calls module metadata functions, but never the execution engine.
% No package directory is added to the MATLAB path by this audit.

    [inspectContracts, catalogueOptions] = auditOptions(varargin);
    [modules, diagnostics] = detecdiv_modules_list(catalogueOptions{:});
    rows = cell(numel(modules), 25);

    for i = 1:numel(modules)
        module = modules(i);
        contract = struct();
        fields = {};
        contractStatus = 'NOT_INSPECTED';
        setparamStatus = 'NOT_INSPECTED';
        summary = module.summary;
        if inspectContracts
            inspectionStatus = inspectionEligibility(module);
            if isempty(inspectionStatus)
                node = struct('id', module.pkg, 'type', module.type, ...
                    'pkg', module.pkg, 'func', module.entrypoint, ...
                    'params', struct('pkg', module.pkg));
                try
                    contract = pipelineNodeContract(node);
                    contractStatus = 'OK';
                    summary = getFieldLocal(contract, 'summary', summary);
                catch ME
                    summary = ['CONTRACT ERROR: ' ME.message];
                    contractStatus = 'ERROR';
                end
                [fields, setparamStatus] = setparamFields(module.pkg);
            else
                contractStatus = inspectionStatus;
                setparamStatus = inspectionStatus;
            end
        end

        rows{i,1} = module.type;
        rows{i,2} = module.pkg;
        rows{i,3} = joinResourceSummary(getNestedField(contract, {'resources','in'}, struct([])));
        rows{i,4} = joinResourceSummary(getNestedField(contract, {'resources','out'}, struct([])));
        rows{i,5} = joinParamSummary(contract, 'run');
        rows{i,6} = joinStaticParamSummary(contract);
        rows{i,7} = strjoin(fields, ', ');
        rows{i,8} = contractStatus;
        rows{i,9} = setparamStatus;
        rows{i,10} = char(string(summary));
        rows{i,11} = module.id;
        rows{i,12} = module.name;
        rows{i,13} = module.distribution;
        rows{i,14} = module.adapterVersion;
        rows{i,15} = module.descriptorStatus;
        rows{i,16} = module.status;
        rows{i,17} = module.path;
        rows{i,18} = module.root;
        rows{i,19} = module.manifestPath;
        rows{i,20} = strjoin(toCellstr(module.capabilities), ', ');
        rows{i,21} = metadataSummary(module.provenance);
        rows{i,22} = metadataSummary(module.compatibility);
        rows{i,23} = module.onPath;
        rows{i,24} = module.resolvedEntrypoint;
        rows{i,25} = strjoin(toCellstr(module.issues), ' | ');
    end

    T = cell2table(rows, 'VariableNames', { ...
        'Type', 'Package', 'BindingInputs', 'BindingOutputs', ...
        'RuntimeParams', 'StaticParams', 'SetparamFields', ...
        'ContractStatus', 'SetparamStatus', 'Summary', ...
        'ModuleId', 'Name', 'Distribution', 'AdapterVersion', ...
        'DescriptorStatus', 'CatalogueStatus', 'SourcePath', 'Root', ...
        'ManifestPath', 'Capabilities', 'Provenance', 'Compatibility', ...
        'OnPath', 'ResolvedEntrypoint', 'Issues'});
end

function [inspectContracts, options] = auditOptions(args)
    inspectContracts = false;
    options = {};
    if mod(numel(args), 2) ~= 0
        error('pipelineModuleAudit:Options', 'Options must be name/value pairs.');
    end
    for i = 1:2:numel(args)
        if strcmpi(string(args{i}), 'InspectContracts')
            value = args{i+1};
            if ~isscalar(value) || ~(islogical(value) || ...
                    (isnumeric(value) && any(value == [0 1])))
                error('pipelineModuleAudit:InspectContracts', ...
                    'InspectContracts must be a logical scalar.');
            end
            inspectContracts = logical(value);
        else
            options(end+1:end+2) = args(i:i+1); %#ok<AGROW>
        end
    end
end

function status = inspectionEligibility(module)
    status = '';
    if strcmp(module.status, 'conflict')
        status = 'SKIPPED_CONFLICT';
        return;
    end
    if ~strcmp(module.status, 'ok') || strcmp(module.descriptorStatus, 'invalid')
        status = 'SKIPPED_INVALID';
        return;
    end
    if ~module.onPath || isempty(module.entrypoint)
        status = 'NOT_ON_PATH';
        return;
    end
    % Check every declared metadata entry point as well as the legacy names
    % called internally by pipelineNodeContract and setparamFields. A second
    % package on the path must never supply metadata for this catalogue row.
    functions = {module.entrypoint, [module.pkg '.executionSpec'], ...
        [module.pkg '.setparam']};
    declared = module.entrypoints;
    declaredNames = fieldnames(declared);
    for i = 1:numel(declaredNames)
        fn = char(string(declared.(declaredNames{i})));
        if isempty(fn)
            continue;
        end
        if isempty(which(fn))
            status = 'NOT_ON_PATH';
            return;
        end
        functions{end+1} = fn; %#ok<AGROW>
    end
    if strcmpi(module.pkg, 'customModule') || strcmpi(module.type, 'custom')
        functions{end+1} = 'customModule.contract';
    end
    for i = 1:numel(functions)
        resolved = which(functions{i});
        if ~isempty(resolved) && ~entrypointInPackage(resolved, functions{i}, module)
            status = 'SKIPPED_SHADOWED';
            return;
        end
    end
end

function tf = entrypointInPackage(resolved, entrypoint, module)
    [folder, name] = fileparts(resolved);
    parts = strsplit(entrypoint, '.');
    tf = strcmp(name, parts{end});
    folder = char(java.io.File(folder).getCanonicalPath());
    folder = strrep(folder, '\', '/');
    packagePath = strrep(module.path, '\', '/');
    if ispc
        tf = tf && strcmpi(folder, packagePath);
    else
        tf = tf && strcmp(folder, packagePath);
    end
end

function txt = metadataSummary(value)
    if isempty(value) || (isstruct(value) && isempty(fieldnames(value)))
        txt = '';
    elseif ischar(value) || isstring(value)
        txt = char(string(value));
    else
        txt = jsonencode(value);
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
