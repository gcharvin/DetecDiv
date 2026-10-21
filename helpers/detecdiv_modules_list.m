function [modules, diagnostics] = detecdiv_modules_list(varargin)
%DETECDIV_MODULES_LIST Read the common catalogue without loading module code.
% [modules, diagnostics] = detecdiv_modules_list('Root', repoRoot, ...
%     'PluginRoots', {pluginRepo}, 'PackagePaths', {absolutePackageDirectory})
% Explicit PluginRoots={} disables registered and conventional plugin roots.
% Discovery does not modify the MATLAB path, preferences or module data, and
% never calls setparam, executionSpec, Python or a module execution function.

opts = localOptions(varargin{:});
modules = repmat(localEmptyModule(), 1, 0);
diagnostics = localEmptyDiagnostics();
seen = {};
schemaFile = fullfile(fileparts(fileparts(mfilename('fullpath'))), ...
    'docs', 'schemas', 'detecdiv-module-v1.schema.json');
schema = jsondecode(localReadJsonText(schemaFile));

if ~isfolder(opts.Root)
    diagnostics(end+1) = localDiagnostic('warning', 'ROOT_MISSING', ...
        'DetecDiv catalogue root does not exist.', opts.Root, '');
end
families = {'dataloading', 'dataLoader'; 'processor', 'processor'; ...
    'classification', 'classifier'};
for i = 1:size(families, 1)
    scan(fullfile(opts.Root, 'engine', families{i,1}), families{i,2}, 'bundled');
end

if isempty(opts.PluginRoots) && ~opts.PluginRootsSpecified
    [opts.PluginRoots, prefDiagnostics] = localRegisteredRoots(opts.Root);
    diagnostics = [diagnostics prefDiagnostics];
end
for r = 1:numel(opts.PluginRoots)
    root = localCanonical(opts.PluginRoots{r});
    if ~isfolder(root)
        diagnostics(end+1) = localDiagnostic('warning', 'PLUGIN_ROOT_MISSING', ...
            'Plugin root does not exist.', root, ''); %#ok<AGROW>
        continue;
    end
    scan(fullfile(root, 'plugins', 'processor'), 'processor', 'external');
    scan(fullfile(root, 'plugins', 'classifier'), 'classifier', 'external');
end
for i = 1:numel(opts.PackagePaths)
    if ~java.io.File(opts.PackagePaths{i}).isAbsolute()
        diagnostics(end+1) = localDiagnostic('error', 'PACKAGE_PATH_INVALID', ...
            'PackagePaths must be absolute +package directories.', opts.PackagePaths{i}, ''); %#ok<AGROW>
        continue;
    end
    packagePath = localCanonical(opts.PackagePaths{i});
    [~, folderName] = fileparts(packagePath);
    if ~isfolder(packagePath) || ~startsWith(folderName, '+')
        diagnostics(end+1) = localDiagnostic('error', 'PACKAGE_PATH_INVALID', ...
            'PackagePaths must identify existing +package directories.', packagePath, ''); %#ok<AGROW>
        continue;
    end
    append(packagePath, '', 'external');
end

% Retain every conflicting candidate. Stable IDs are case-sensitive; package
% names are compared case-insensitively on Windows, like filesystem paths.
for i = 1:numel(modules)
    for j = i+1:numel(modules)
        if strcmp(modules(i).id, modules(j).id)
            conflict(i, j, 'DUPLICATE_ID', 'Module identifier occurs at multiple paths.');
        end
        if localSamePackage(modules(i).pkg, modules(j).pkg)
            conflict(i, j, 'DUPLICATE_PACKAGE', 'MATLAB package is installed at multiple paths.');
        end
    end
end

    function scan(parent, family, distribution)
        if ~isfolder(parent), return; end
        folders = dir(fullfile(parent, '+*'));
        folders = folders([folders.isdir]);
        [~, order] = sort({folders.name});
        folders = folders(order);
        for k = 1:numel(folders)
            append(fullfile(parent, folders(k).name), family, distribution);
        end
    end

    function append(packagePath, family, distribution)
        packagePath = localCanonical(packagePath);
        key = localPathKey(packagePath);
        if any(strcmp(seen, key)), return; end
        seen{end+1} = key;
        [item, itemDiagnostics, include] = localReadPackage(packagePath, family, distribution, schema);
        diagnostics = [diagnostics itemDiagnostics];
        if include, modules(end+1) = item; end
    end

    function conflict(i, j, code, message)
        for index = [i j]
            if ~strcmp(modules(index).status, 'invalid')
                modules(index).status = 'conflict';
            end
            modules(index).issues{end+1} = message;
            diagnostics(end+1) = localDiagnostic('error', code, message, ...
                modules(index).path, modules(index).id);
        end
    end
end

function opts = localOptions(varargin)
p = inputParser;
addParameter(p, 'Root', fileparts(fileparts(mfilename('fullpath'))), @localIsText);
addParameter(p, 'PluginRoots', {}, @localIsPaths);
addParameter(p, 'PackagePaths', {}, @localIsPaths);
parse(p, varargin{:});
opts = p.Results;
opts.Root = localCanonical(char(opts.Root));
opts.PluginRootsSpecified = ~any(strcmp(p.UsingDefaults, 'PluginRoots'));
opts.PluginRoots = localPaths(opts.PluginRoots);
opts.PackagePaths = localPaths(opts.PackagePaths);
end

function tf = localIsText(v)
tf = (ischar(v) && isrow(v) && ~isempty(v)) || ...
    (isstring(v) && isscalar(v) && ~ismissing(v) && strlength(v)>0);
end

function tf = localIsPaths(v)
tf = isempty(v) || localIsText(v) || ...
    (isstring(v) && all(~ismissing(v(:)) & strlength(v(:))>0)) || ...
    (iscell(v) && all(cellfun(@localIsText, v(:))));
end

function values = localPaths(v)
if isempty(v), values = {}; else, values = cellstr(string(v)); values = values(:)'; end
end

function [roots, diagnostics] = localRegisteredRoots(repoRoot)
% detecdiv_plugins_roots currently loads/migrates/saves preferences. Read the
% same saved roots directly so catalogue inspection is genuinely read-only.
roots = {};
diagnostics = localEmptyDiagnostics();
if ispc
    preferenceFile = fullfile(prefdir, 'Detecdiv', 'userprefs.mat');
else
    preferenceFile = fullfile(getenv('HOME'), 'Detecdiv', 'userprefs.mat');
end
if isfile(preferenceFile)
    try
        saved = load(preferenceFile, 'userprefs');
        if isfield(saved, 'userprefs') && isstruct(saved.userprefs) && ...
                isfield(saved.userprefs, 'plugins') && isstruct(saved.userprefs.plugins) && ...
                isfield(saved.userprefs.plugins, 'roots')
            value = saved.userprefs.plugins.roots;
            if ~localIsPaths(value), error('Invalid saved plugin roots.'); end
            roots = localPaths(value);
        end
    catch ME
        diagnostics(end+1) = localDiagnostic('warning', 'PLUGIN_PREFERENCES_INVALID', ...
            ME.message, preferenceFile, '');
    end
end
conventional = fullfile(fileparts(repoRoot), 'DetecDiv-plugins');
if isfolder(conventional), roots{end+1} = conventional; end
end

function item = localEmptyModule()
item = struct('id', '', 'name', '', 'type', '', 'pkg', '', 'path', '', ...
    'root', '', 'distribution', '', 'entrypoint', '', ...
    'entrypoints', struct('execute','','parameters',''), 'adapterVersion', '', ...
    'descriptorStatus', 'legacy', 'compatibility', struct(), ...
    'capabilities', {{}}, 'provenance', struct(), 'extensions', struct(), 'manifest', struct(), ...
    'manifestPath', '', 'summary', '', 'status', 'ok', 'issues', {{}}, ...
    'resolvedEntrypoint', '', 'onPath', false);
end

function [m, diagnostics, include] = localReadPackage(packagePath, family, distribution, schema)
m = localEmptyModule();
diagnostics = localEmptyDiagnostics();
[pkg, root] = localPackageName(packagePath);
if isempty(family)
    if isfile(fullfile(packagePath, 'classify.m')), family = 'classifier';
    elseif isfile(fullfile(packagePath, 'process.m')), family = 'processor';
    else, family = 'unknown'; end
end
if strcmp(family, 'dataLoader')
    if strcmpi(pkg, 'phyloCellLoader'), family = 'dataLoader'; else, family = pkg; end
end
executeName = 'process';
if strcmpi(family, 'classifier'), executeName = 'classify'; end
m.pkg = pkg;
m.id = ['legacy.' family '.' pkg];
m.name = pkg;
m.type = family;
m.root = root;
m.path = packagePath;
m.distribution = distribution;
m.entrypoint = [pkg '.' executeName];
m.summary = ['Legacy ' family ' package: ' pkg];
descriptor = fullfile(packagePath, 'module.json');
legacyDescriptor = fullfile(packagePath, 'plugin.json');
include = isfile(descriptor) || isfile(legacyDescriptor) || ...
    isfile(fullfile(packagePath, [executeName '.m']));
if ~include, return; end

if isfile(descriptor)
    m.manifestPath = descriptor;
    m.descriptorStatus = 'declared';
    try
        source = localReadJsonText(descriptor);
        m.manifest = jsondecode(source);
        problems = localValidate(m.manifest, schema, schema, 'module', localJsonShape(source));
        if ~isempty(problems), error('%s', strjoin(problems, '; ')); end
        manifest = m.manifest;
        m.id = manifest.id;
        m.name = manifest.name;
        m.type = manifest.type;
        m.summary = manifest.summary;
        m.adapterVersion = localNullableText(manifest.adapterVersion);
        m.compatibility = manifest.compatibility;
        m.capabilities = localPaths(manifest.capabilities);
        m.provenance = manifest.provenance;
        if isfield(manifest,'extensions'), m.extensions=manifest.extensions; end
        m.entrypoint = manifest.entrypoints.execute;
        m.entrypoints.execute = m.entrypoint;
        if isfield(manifest.entrypoints, 'parameters')
            m.entrypoints.parameters = manifest.entrypoints.parameters;
        end
        if isfield(manifest.entrypoints, 'contract')
            m.entrypoints.contract = manifest.entrypoints.contract;
        end
        for hook = {'validate','prepare'}
            if isfield(manifest.entrypoints, hook{1})
                m.entrypoints.(hook{1}) = manifest.entrypoints.(hook{1});
            end
        end
        if ~strcmp(manifest.package, pkg)
            error('Declared package %s differs from package directory %s.', manifest.package, pkg);
        end
        if any(strcmpi(family, {'classifier','processor'})) && ~strcmpi(m.type, family)
            error('Declared type %s differs from discovery family %s.', m.type, family);
        end
        declared = struct2cell(m.entrypoints);
        for k = 1:numel(declared)
            if ~isempty(declared{k}), localValidateEntrypoint(declared{k}, m); end
        end
    catch ME
        m = localInvalid(m, ME.message);
        diagnostics(end+1) = localDiagnostic('error', 'INVALID_DESCRIPTOR', ...
            ME.message, descriptor, m.id);
    end
elseif isfile(legacyDescriptor)
    m.manifestPath = legacyDescriptor;
    try
        manifest = jsondecode(localReadJsonText(legacyDescriptor));
        if ~isstruct(manifest) || ~isscalar(manifest), error('plugin.json must contain an object.'); end
        m.manifest = manifest;
        for field = {'name','entrypoint','summary','version'}
            key = field{1};
            if isfield(manifest, key) && ~localIsText(manifest.(key))
                error('plugin.json.%s must be a nonempty string.', key);
            end
        end
        if isfield(manifest,'entrypoint'), m.entrypoint = manifest.entrypoint; end
        if isfield(manifest,'name'), m.name = manifest.name; end
        if isfield(manifest,'summary'), m.summary = manifest.summary; end
        if isfield(manifest,'version'), m.adapterVersion = manifest.version; end
        localValidateEntrypoint(m.entrypoint, m);
    catch ME
        m = localInvalid(m, ME.message);
        diagnostics(end+1) = localDiagnostic('error', 'INVALID_LEGACY_DESCRIPTOR', ...
            ME.message, legacyDescriptor, m.id);
    end
end
m.entrypoints.execute = m.entrypoint;
if strcmp(m.descriptorStatus, 'legacy') && isfile(fullfile(packagePath,'executionSpec.m'))
    m.entrypoints.parameters = [pkg '.executionSpec'];
elseif strcmp(m.descriptorStatus, 'legacy') && isfile(fullfile(packagePath,'setparam.m'))
    m.entrypoints.parameters = [pkg '.setparam'];
end
if ~strcmp(m.status, 'invalid')
    try
        localValidateEntrypoint(m.entrypoint, m);
    catch ME
        m = localInvalid(m, ME.message);
        diagnostics(end+1) = localDiagnostic('error', 'ENTRYPOINT_INVALID', ME.message, packagePath, m.id);
    end
end
if ~strcmp(m.status, 'invalid')
    resolved = which(m.entrypoint);
    if ~isempty(resolved)
        m.resolvedEntrypoint = resolved;
        m.onPath = strcmp(localPathKey(fileparts(localCanonical(resolved))), localPathKey(m.path));
        if ~m.onPath
            m.status = 'conflict';
            message = ['MATLAB resolves this entrypoint outside its discovered package: ' resolved];
            m.issues{end+1} = message;
            diagnostics(end+1) = localDiagnostic('error', 'ENTRYPOINT_SHADOWED', message, m.path, m.id);
        end
    end
end
end

function m = localInvalid(m, message)
m.status = 'invalid';
m.descriptorStatus = 'invalid';
m.issues{end+1} = message;
end

function localValidateEntrypoint(value, m)
prefix = [m.pkg '.'];
if ~all(cellfun(@isvarname,strsplit(m.pkg,'.'))) || ...
        ~localIsText(value) || ~startsWith(value, prefix)
    error('Entrypoint must belong to package %s.', m.pkg);
end
functionName = value(numel(prefix)+1:end);
if ~isvarname(functionName) || ~isfile(fullfile(m.path,[functionName '.m']))
    error('Entrypoint file is missing or invalid: %s.', value);
end
end

function problems = localValidate(value, rule, schema, location, shape)
% Validate the JSON Schema subset used by the checked-in descriptor schema.
% No module code or external JSON/Python runtime is needed for this check.
problems = {};
refKey = matlab.lang.makeValidName('$ref');
if isfield(rule,'$ref'), refKey='$ref'; end
if isfield(rule, refKey)
    pointer = rule.(refKey);
    if ~startsWith(pointer, '#/'), error('Only local descriptor schema references are supported.'); end
    keys = strsplit(pointer(3:end), '/');
    resolvedRule = schema;
    for i=1:numel(keys)
        key=keys{i};
        if ~isfield(resolvedRule,key), key=matlab.lang.makeValidName(key); end
        resolvedRule = resolvedRule.(key);
    end
    problems = localValidate(value, resolvedRule, schema, location, shape);
    return;
end
if isfield(rule, 'type')
    types = localPaths(rule.type);
    matches = any(strcmp(types, shape.kind));
    if ~matches, problems = {[location ': expected ' strjoin(types, ' or ')]}; return; end
end
if isfield(rule, 'const') && ~isequal(value, rule.const)
    problems{end+1} = [location ': unsupported value'];
end
if isfield(rule,'enum') && ~any(cellfun(@(choice)isequal(value,choice),localPaths(rule.enum)))
    problems{end+1} = [location ': unsupported value'];
end
if isfield(rule,'allOf')
    for i=1:numel(rule.allOf)
        if iscell(rule.allOf), subrule=rule.allOf{i}; else, subrule=rule.allOf(i); end
        problems=[problems localValidate(value,subrule,schema,location,shape)]; %#ok<AGROW>
    end
end
ifKey=matlab.lang.makeValidName('if');
if isfield(rule,'if'), ifKey='if'; end
if isfield(rule,ifKey) && isempty(localValidate(value,rule.(ifKey),schema,location,shape)) && isfield(rule,'then')
    problems=[problems localValidate(value,rule.then,schema,location,shape)];
end
if ischar(value)
    if isfield(rule, 'minLength') && numel(value)<rule.minLength
        problems{end+1} = [location ': string is empty'];
    end
    if isfield(rule, 'pattern') && isempty(regexp(value, rule.pattern, 'once'))
        problems{end+1} = [location ': invalid identifier'];
    end
end
if strcmp(shape.kind, 'object')
    names = shape.names;
    if numel(unique(names))~=numel(names)
        problems{end+1} = [location ': duplicate object keys'];
    end
    if isfield(rule, 'required')
        required = localPaths(rule.required);
        for i=1:numel(required)
            if ~any(strcmp(names,required{i})), problems{end+1} = [location '.' required{i} ': missing required field']; end %#ok<AGROW>
        end
    end
    for i=1:numel(names)
        key = names{i};
        if isfield(rule, 'properties') && isfield(rule.properties,key)
            problems = [problems localValidate(value.(key),rule.properties.(key),schema, ...
                [location '.' key],shape.children{i})]; %#ok<AGROW>
        elseif isfield(rule,'additionalProperties') && isequal(rule.additionalProperties,false)
            problems{end+1} = [location '.' key ': unknown field']; %#ok<AGROW>
        elseif isfield(rule,'additionalProperties') && isstruct(rule.additionalProperties)
            valueKey=key;
            if ~isfield(value,valueKey), valueKey=matlab.lang.makeValidName(key); end
            problems=[problems localValidate(value.(valueKey),rule.additionalProperties,schema, ...
                [location '.' key],shape.children{i})]; %#ok<AGROW>
        end
    end
elseif strcmp(shape.kind, 'array')
    if isfield(rule,'uniqueItems') && rule.uniqueItems
        if iscell(value)
            encoded = cellfun(@jsonencode,value,'UniformOutput',false);
            if numel(unique(encoded))~=numel(encoded), problems{end+1} = [location ': duplicate array items']; end
        end
    end
    if isfield(rule,'items')
        for i=1:numel(shape.children)
            if iscell(value), item=value{i}; else, item=value(i); end
            problems = [problems localValidate(item,rule.items,schema, ...
                sprintf('%s[%d]',location,i),shape.children{i})]; %#ok<AGROW>
        end
    end
end
end

function shape = localJsonShape(source)
% jsondecode validates syntax but maps invalid object keys to MATLAB names
% and represents both null and [] as []. Retain original key names and token
% types so those transformations cannot bypass the descriptor schema.
tokens = regexp(source, ...
    '"(?:[^"\\]|\\.)*"|[{}\[\],:]|-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?|true|false|null', 'match');
position = 1;
shape = readValue();

    function node = readValue()
        token = tokens{position}; position = position+1;
        node = struct('kind','','names',{{}},'children',{{}});
        if strcmp(token,'{')
            node.kind = 'object';
            while ~strcmp(tokens{position},'}')
                node.names{end+1} = jsondecode(tokens{position});
                position = position+2; % key and colon; syntax already checked
                node.children{end+1} = readValue();
                if strcmp(tokens{position},','), position=position+1; else, break; end
            end
            position = position+1;
        elseif strcmp(token,'[')
            node.kind = 'array';
            while ~strcmp(tokens{position},']')
                node.children{end+1} = readValue();
                if strcmp(tokens{position},','), position=position+1; else, break; end
            end
            position = position+1;
        elseif startsWith(token,'"'), node.kind='string';
        elseif strcmp(token,'null'), node.kind='null';
        elseif any(strcmp(token,{'true','false'})), node.kind='boolean';
        else, node.kind='number'; end
    end
end

function value = localNullableText(value)
if isempty(value), value = ''; else, value = char(value); end
end

function source = localReadJsonText(filename)
% Decode JSON consistently across Windows system locales. Existing external
% manifests may have a UTF-8 BOM, which jsondecode does not accept directly.
fid = fopen(filename, 'rb');
if fid<0, error('detecdiv_modules_list:ReadFailed','Cannot read %s.',filename); end
cleanup = onCleanup(@()fclose(fid)); %#ok<NASGU>
bytes = fread(fid, Inf, '*uint8');
source = native2unicode(bytes(:)', 'UTF-8');
if ~isempty(source) && double(source(1))==65279, source=source(2:end); end
end

function [pkg, root] = localPackageName(packagePath)
parts = {};
root = packagePath;
while true
    [parent, name] = fileparts(root);
    if ~startsWith(name,'+'), break; end
    parts = [{name(2:end)} parts]; %#ok<AGROW>
    root = parent;
end
pkg = strjoin(parts,'.');
end

function pathValue = localCanonical(pathValue)
pathValue = char(java.io.File(char(pathValue)).getCanonicalPath());
end

function key = localPathKey(pathValue)
% All callers pass paths already canonicalized at discovery/resolution.
% Avoid a second filesystem round trip for the same directory.
key = char(pathValue);
if ispc, key = lower(key); end
end

function tf = localSamePackage(a,b)
if ispc, tf=strcmpi(a,b); else, tf=strcmp(a,b); end
end

function diagnostics = localEmptyDiagnostics()
diagnostics = struct('severity',{},'code',{},'message',{},'path',{},'moduleId',{});
end

function d = localDiagnostic(severity, code, message, pathValue, moduleId)
d = struct('severity',severity,'code',code,'message',message,'path',pathValue,'moduleId',moduleId);
end
